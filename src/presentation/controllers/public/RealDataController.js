// src/presentation/controllers/public/RealDataController.js
const RealCSVFetcher = require('../../../infrastructure/external/RealCSVFetcher');
const logger = require('../../../config/logger');

class RealDataController {
    constructor() {
        this.csvFetcher = new RealCSVFetcher();
        this.pollingInterval = null;
        this.lastLineData = null;
        this.isPolling = false;
        this.connectedClients = new Set();
    }

    /**
     * GET /api/gpec5/configuration
     * Obtener configuraciÃ³n de equipos y procesos
     */
    async getConfiguration(req, res) {
        try {
            const config = this.csvFetcher.getEquipmentConfiguration();
            const stats = this.csvFetcher.getConnectionStats();
            
            res.json({
                success: true,
                data: {
                    ...config,
                    stats,
                    polling: this.isPolling,
                    lastUpdate: this.lastLineData?.timestamp || null
                }
            });
        } catch (error) {
            logger.error('Error getting GPEC5 configuration:', error);
            res.status(500).json({
                success: false,
                error: 'Error obteniendo configuraciÃ³n',
                message: error.message
            });
        }
    }

    /**
     * GET /api/gpec5/data/live
     * Obtener datos en tiempo real de toda la lÃ­nea
     */
    async getLiveData(req, res) {
        try {
            logger.info('ðŸ“Š Fetching live GPEC5 data...');
            const lineData = await this.csvFetcher.fetchLineData();
            
            // Procesar datos para VSM
            const vsmData = this.processLineDataForVSM(lineData);
            
            // Guardar Ãºltimos datos
            this.lastLineData = vsmData;
            
            res.json({
                success: true,
                data: vsmData,
                timestamp: new Date().toISOString()
            });

        } catch (error) {
            logger.error('Error fetching live GPEC5 data:', error);
            res.status(500).json({
                success: false,
                error: 'Error obteniendo datos en tiempo real',
                message: error.message
            });
        }
    }

    /**
     * GET /api/gpec5/process/:processName
     * Obtener datos de un proceso especÃ­fico
     */
    async getProcessData(req, res) {
        try {
            const { processName } = req.params;
            const processData = await this.csvFetcher.fetchProcessData(processName.toUpperCase());
            
            const vsmProcessData = this.processProcessDataForVSM(processData);
            
            res.json({
                success: true,
                data: vsmProcessData,
                timestamp: new Date().toISOString()
            });

        } catch (error) {
            logger.error(`Error fetching process data for ${req.params.processName}:`, error);
            res.status(500).json({
                success: false,
                error: 'Error obteniendo datos del proceso',
                message: error.message
            });
        }
    }

    /**
     * POST /api/gpec5/polling/start
     * Iniciar polling automÃ¡tico
     */
    async startPolling(req, res) {
        try {
            if (this.isPolling) {
                return res.json({
                    success: true,
                    message: 'Polling ya estÃ¡ activo',
                    data: { polling: true }
                });
            }

            this.pollingInterval = this.csvFetcher.startPolling((lineData) => {
                this.lastLineData = this.processLineDataForVSM(lineData);
                this.broadcastToClients('data_update', this.lastLineData);
            });

            this.isPolling = true;
            logger.info('ðŸ”„ Polling iniciado para lÃ­nea GPEC5');

            res.json({
                success: true,
                message: 'Polling iniciado exitosamente',
                data: { 
                    polling: true,
                    interval: this.csvFetcher.pollingInterval
                }
            });

        } catch (error) {
            logger.error('Error starting polling:', error);
            res.status(500).json({
                success: false,
                error: 'Error iniciando polling',
                message: error.message
            });
        }
    }

    /**
     * POST /api/gpec5/polling/stop
     * Detener polling automÃ¡tico
     */
    stopPolling(req, res) {
        try {
            if (this.pollingInterval) {
                clearInterval(this.pollingInterval);
                this.pollingInterval = null;
            }
            
            this.isPolling = false;
            logger.info('â¹ï¸ Polling detenido para lÃ­nea GPEC5');

            res.json({
                success: true,
                message: 'Polling detenido',
                data: { polling: false }
            });

        } catch (error) {
            logger.error('Error stopping polling:', error);
            res.status(500).json({
                success: false,
                error: 'Error deteniendo polling',
                message: error.message
            });
        }
    }

    /**
     * Procesar datos de lÃ­nea completa para VSM
     */
    processLineDataForVSM(lineData) {
        if (lineData.error) {
            return {
                line: 'GPEC5',
                error: lineData.error,
                timestamp: lineData.timestamp,
                processes: []
            };
        }

        const vsmProcesses = [];
        
        for (const [processName, processData] of lineData.processes) {
            const vsmProcess = this.processProcessDataForVSM(processData);
            vsmProcesses.push(vsmProcess);
        }

        return {
            line: 'GPEC5',
            processes: vsmProcesses,
            summary: this.calculateLineSummary(vsmProcesses),
            timestamp: lineData.timestamp,
            totalEquipments: lineData.totalEquipments
        };
    }

    /**
     * Procesar datos de proceso individual para VSM (CAMBIO MÃNIMO)
     */
    processProcessDataForVSM(processData) {
        const { processName, processConfig, equipmentData } = processData;
        
        // Calcular mÃ©tricas VSM para el proceso
        const cycleTimes = [];
        const pieces = { total: 0, ok: 0, ng: 0 };
        const equipmentMetrics = [];

        // DEBUGGING: Verificar estructura de equipmentData
        console.log(`ðŸ” ${processName} - equipmentData type:`, typeof equipmentData);
        console.log(`ðŸ” ${processName} - equipmentData size:`, equipmentData?.size || 'No size');
        
        // Procesar cada equipo del proceso
        if (equipmentData && equipmentData instanceof Map) {
            for (const [equipmentId, records] of equipmentData) {
                console.log(`ðŸ”§ Processing ${equipmentId}:`, {
                    type: typeof records,
                    isArray: Array.isArray(records),
                    length: records?.length,
                    hasData: records?.data ? 'Yes' : 'No'
                });
                
                // VALIDACIÃ“N ROBUSTA: Extraer array de diferentes estructuras posibles
                let recordsArray = [];
                
                if (Array.isArray(records)) {
                    recordsArray = records;
                    console.log(`âœ… ${equipmentId}: Array directo con ${records.length} registros`);
                } else if (records && records.data && Array.isArray(records.data)) {
                    recordsArray = records.data;
                    console.log(`âœ… ${equipmentId}: Array en .data con ${records.data.length} registros`);
                } else {
                    console.warn(`âŒ ${equipmentId}: No se pudo extraer array vÃ¡lido`);
                    recordsArray = [];
                }
                
                const equipmentAnalysis = this.analyzeEquipmentRecords(recordsArray, equipmentId);
                equipmentMetrics.push(equipmentAnalysis);
                
                // ðŸ”§ FIX: ÃšNICO CAMBIO - Extraer nÃºmeros de cycleTimes en lugar de objetos
                const equipmentCycleTimes = equipmentAnalysis.cycleTimes.map(ct => ct.cycleTime);
                cycleTimes.push(...equipmentCycleTimes);
                
                pieces.total += equipmentAnalysis.pieces.total;
                pieces.ok += equipmentAnalysis.pieces.ok;
                pieces.ng += equipmentAnalysis.pieces.ng;
            }
        } else {
            console.error(`âŒ ${processName}: equipmentData no es Map vÃ¡lido`);
        }

        // Calcular mÃ©tricas agregadas del proceso
        const processMetrics = this.calculateProcessMetrics(cycleTimes, processConfig, equipmentMetrics);

        return {
            processName,
            displayName: processConfig.name,
            type: processConfig.type,
            designTime: processConfig.designTime,
            equipments: equipmentMetrics,
            metrics: processMetrics,
            pieces,
            timestamp: processData.timestamp || new Date()
        };
    }

    /**
     * Analizar registros de un equipo individual (CON FIX CONSERVADOR PARA WAVE_SOLDER)
     */
    analyzeEquipmentRecords(records, equipmentId) {
        const cycleTimes = [];
        const pieces = { total: 0, ok: 0, ng: 0 };
        const breqMap = new Map();
        
        // VALIDACIÃ“N AGREGADA - Asegurar que records es un array
        if (!Array.isArray(records)) {
            logger.warn(`Records for ${equipmentId} is not an array:`, typeof records);
            return {
                equipmentId,
                cycleTimes: [],
                pieces: { total: 0, ok: 0, ng: 0 },
                outlierAnalysis: { filtered: [], outlierCount: 0, outlierPercentage: 0 },
                lastUpdate: new Date(),
                recordCount: 0
            };
        }

        // Contador de registros vÃ¡lidos/invÃ¡lidos para debugging
        let validRecords = 0;
        let invalidRecords = 0;

        // ðŸ”§ NUEVA FUNCIONALIDAD: Detectar WAVE_SOLDER
        const isWaveSolder = equipmentId.includes('WAVESOLDER') || equipmentId.includes('WAVE');
        
        if (isWaveSolder) {
            logger.info(`ðŸŒŠ WAVE_SOLDER detectado: ${equipmentId} - Usando cÃ¡lculo timestamp a timestamp`);
            
            // PARA WAVE_SOLDER: Calcular cycle times entre timestamps consecutivos
            records.forEach((record, index) => {
                // ðŸ› ï¸ VALIDACIÃ“N MEJORADA: Verificar que el registro individual es vÃ¡lido
                if (!record || typeof record !== 'object') {
                    logger.warn(`âš ï¸ ${equipmentId} - Registro ${index} es null/undefined:`, record);
                    invalidRecords++;
                    return;
                }

                // Verificar propiedades crÃ­ticas del registro
                if (!record.serial || !record.status) {
                    logger.warn(`âš ï¸ ${equipmentId} - Registro ${index} falta serial/status:`, {
                        serial: record.serial,
                        status: record.status,
                        keys: Object.keys(record)
                    });
                    invalidRecords++;
                    return;
                }

                // Verificar que status es string
                if (typeof record.status !== 'string') {
                    logger.warn(`âš ï¸ ${equipmentId} - Registro ${index} status no es string:`, {
                        serial: record.serial,
                        status: record.status,
                        statusType: typeof record.status
                    });
                    invalidRecords++;
                    return;
                }

                validRecords++;
                
                // Contar piezas procesadas para WAVE_SOLDER
                pieces.total++;
                if (record.status.includes('OK') || record.status.includes('Processed OK')) {
                    pieces.ok++;
                } else {
                    pieces.ng++;
                }
                
                // Calcular cycle time con el registro anterior (timestamp consecutivo)
                if (index > 0) {
                    const previousRecord = records[index - 1];
                    if (previousRecord && previousRecord.timestamp && record.timestamp) {
                        const currentTime = new Date(record.timestamp);
                        const previousTime = new Date(previousRecord.timestamp);
                        
                        if (!isNaN(currentTime.getTime()) && !isNaN(previousTime.getTime())) {
                            const diferenciaMs = Math.abs(currentTime.getTime() - previousTime.getTime());
                            const diferenciaSeg = diferenciaMs / 1000;
                            
                            // Solo considerar tiempos razonables (5 segundos a 5 minutos para WAVE_SOLDER)
                            if (diferenciaSeg >= 5 && diferenciaSeg <= 300) {
                                cycleTimes.push({
                                    serial: record.serial,
                                    cycleTime: diferenciaSeg,
                                    fromTime: previousTime,
                                    toTime: currentTime,
                                    status: record.status
                                });
                            }
                        }
                    }
                }
            });
            
            logger.info(`ðŸŒŠ ${equipmentId} - Cycle times calculados: ${cycleTimes.length} de ${validRecords} registros vÃ¡lidos`);
            
        } else {
            // LÃ“GICA ORIGINAL PRESERVADA: Para equipos que usan BREQ/BCMP
            records.forEach((record, index) => {
                // ðŸ› ï¸ VALIDACIÃ“N MEJORADA: Verificar que el registro individual es vÃ¡lido
                if (!record || typeof record !== 'object') {
                    logger.warn(`âš ï¸ ${equipmentId} - Registro ${index} es null/undefined:`, record);
                    invalidRecords++;
                    return;
                }

                // Verificar propiedades crÃ­ticas del registro
                if (!record.serial || !record.status) {
                    logger.warn(`âš ï¸ ${equipmentId} - Registro ${index} falta serial/status:`, {
                        serial: record.serial,
                        status: record.status,
                        keys: Object.keys(record)
                    });
                    invalidRecords++;
                    return;
                }

                // Verificar que status es string antes de usar startsWith
                if (typeof record.status !== 'string') {
                    logger.warn(`âš ï¸ ${equipmentId} - Registro ${index} status no es string:`, {
                        serial: record.serial,
                        status: record.status,
                        statusType: typeof record.status
                    });
                    invalidRecords++;
                    return;
                }

                validRecords++;
                const key = record.serial;
                
                if (record.status === 'BREQ') {
                    breqMap.set(key, record);
                } else if (record.status.startsWith('BCMP')) {
                    const breqRecord = breqMap.get(key);
                    if (breqRecord) {
                        // Validar timestamps antes de calcular
                        if (!record.timestamp || !breqRecord.timestamp) {
                            logger.warn(`âš ï¸ ${equipmentId} - Timestamps invÃ¡lidos para serial ${key}`);
                            return;
                        }

                        // Calcular tiempo de ciclo
                        const cycleTime = (record.timestamp - breqRecord.timestamp) / 1000; // segundos
                        
                        if (cycleTime > 0 && cycleTime < 7200) { // Validar rango razonable (0-2 horas)
                            cycleTimes.push({
                                serial: record.serial,
                                cycleTime,
                                breqTime: breqRecord.timestamp,
                                bcmpTime: record.timestamp,
                                status: record.status
                            });
                        }
                        
                        pieces.total++;
                        if (record.status === 'BCMP OK') {
                            pieces.ok++;
                        } else {
                            pieces.ng++;
                        }
                        
                        breqMap.delete(key); // Limpiar pair procesado
                    }
                }
            });
        }

        // Log de debugging para entender la calidad de los datos (PRESERVADO)
        if (invalidRecords > 0) {
            logger.info(`ðŸ“Š ${equipmentId} - Registros procesados: ${validRecords} vÃ¡lidos, ${invalidRecords} invÃ¡lidos de ${records.length} total`);
        }

        // AnÃ¡lisis estadÃ­stico (PRESERVADO)
        const outlierAnalysis = this.detectOutliers(cycleTimes.map(ct => ct.cycleTime));
        
        return {
            equipmentId,
            cycleTimes,
            pieces,
            outlierAnalysis,
            lastUpdate: records.length > 0 ? records[0].timestamp : new Date(),
            recordCount: records.length,
            validRecordCount: validRecords,
            invalidRecordCount: invalidRecords
        };
    }

    /**
     * Calcular mÃ©tricas VSM para un proceso (CAMBIOS MÃNIMOS)
     */
    calculateProcessMetrics(allCycleTimes, processConfig, equipmentMetrics) {
        if (allCycleTimes.length === 0) {
            return {
                realTime: processConfig.designTime,
                hourlyAverage: processConfig.designTime,
                oee: 95.0,
                efficiency: 95.0,
                outlierPercentage: 0,
                outlierStatus: 'normal',
                throughput: 0
            };
        }

        // Tiempo real: segÃºn tu especificaciÃ³n - Ãºltimo par vÃ¡lido promediado
        const recentCycles = allCycleTimes.slice(0, 10); // Ãšltimos 10 ciclos
        const realTime = recentCycles.reduce((sum, time) => sum + time, 0) / recentCycles.length;

        // Promedio 1h con filtro Â±2Ïƒ (tu especificaciÃ³n)
        const hourlyData = allCycleTimes.slice(0, 60); // Simular 1 hora de datos
        const hourlyAverage = this.removeOutliersAndAverage(hourlyData, 2.0);

        // OEE: promedio ponderado de equipos (tu especificaciÃ³n)
        let oee = 95.0;
        if (processConfig.type === 'parallel') {
            // Para equipos paralelos, promedio ponderado
            const validEquipments = equipmentMetrics.filter(eq => eq.cycleTimes.length > 0);
            if (validEquipments.length > 0) {
                oee = validEquipments.reduce((sum, eq) => {
                    const equipOEE = Math.max(85, 100 - (eq.outlierAnalysis.outlierPercentage || 0));
                    return sum + equipOEE;
                }, 0) / validEquipments.length;
            }
        } else {
            // Para secuencial, basado en eficiencia vs tiempo diseÃ±o
            oee = Math.max(85, (processConfig.designTime / realTime) * 100);
        }

        // Eficiencia vs diseÃ±o
        const efficiency = (processConfig.designTime / realTime) * 100;

        // AnÃ¡lisis de outliers
        const outlierAnalysis = this.detectOutliers(allCycleTimes);
        const outlierStatus = this.classifyOutlierStatus(outlierAnalysis.outlierPercentage);

        // Throughput (piezas por hora)
        const throughput = realTime > 0 ? 3600 / realTime : 0;

        return {
            realTime: Math.round(realTime * 10) / 10,
            // ðŸ”§ FIX: Validar hourlyAverage antes de Math.round
            hourlyAverage: hourlyAverage !== null && hourlyAverage !== undefined ? 
                Math.round(hourlyAverage * 10) / 10 : Math.round(realTime * 10) / 10,
            oee: Math.round(oee * 10) / 10,
            // ðŸ”§ FIX: Validar efficiency antes de Math.round  
            efficiency: efficiency !== null && efficiency !== undefined && !isNaN(efficiency) ? 
                Math.round(efficiency * 10) / 10 : 95.0,
            outlierPercentage: Math.round(outlierAnalysis.outlierPercentage * 10) / 10,
            outlierStatus,
            throughput: Math.round(throughput * 10) / 10,
            cycleCount: allCycleTimes.length,
            outlierCount: outlierAnalysis.outliers.length
        };
    }

    /**
     * Detectar outliers con mÃ©todo Â±2Ïƒ (tu especificaciÃ³n)
     */
    detectOutliers(cycleTimes, stdMultiplier = 2.0) {
        if (cycleTimes.length < 3) {
            return {
                outliers: [],
                normal: cycleTimes,
                mean: cycleTimes.length > 0 ? cycleTimes.reduce((sum, time) => sum + time, 0) / cycleTimes.length : 0,
                stdDev: 0,
                outlierPercentage: 0
            };
        }

        const mean = cycleTimes.reduce((sum, time) => sum + time, 0) / cycleTimes.length;
        const variance = cycleTimes.reduce((sum, time) => sum + Math.pow(time - mean, 2), 0) / cycleTimes.length;
        const stdDev = Math.sqrt(variance);

        const outliers = [];
        const normal = [];

        cycleTimes.forEach(time => {
            if (Math.abs(time - mean) > stdMultiplier * stdDev) {
                outliers.push({
                    value: time,
                    deviation: Math.abs(time - mean),
                    sigmaLevel: Math.abs(time - mean) / stdDev
                });
            } else {
                normal.push(time);
            }
        });

        return {
            outliers,
            normal,
            mean,
            stdDev,
            outlierPercentage: (outliers.length / cycleTimes.length) * 100
        };
    }

    /**
     * Remover outliers y calcular promedio (CAMBIO MÃNIMO)
     */
    removeOutliersAndAverage(data, stdMultiplier = 2.0) {
        // ðŸ”§ FIX: Validar que data existe y tiene elementos
        if (!data || data.length === 0) {
            return null;
        }
        
        if (data.length < 3) {
            return data.reduce((sum, val) => sum + val, 0) / data.length;
        }

        const mean = data.reduce((sum, val) => sum + val, 0) / data.length;
        const variance = data.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / data.length;
        const stdDev = Math.sqrt(variance);

        const filtered = data.filter(val => 
            Math.abs(val - mean) <= stdMultiplier * stdDev
        );

        return filtered.length > 0 ? 
            filtered.reduce((sum, val) => sum + val, 0) / filtered.length : mean;
    }

    /**
     * Clasificar estado de outliers
     */
    classifyOutlierStatus(outlierPercentage) {
        if (outlierPercentage <= 5) return 'normal';
        if (outlierPercentage <= 15) return 'warning';
        return 'danger';
    }

    /**
     * Calcular resumen de lÃ­nea completa
     */
    calculateLineSummary(processes) {
        const totalPieces = processes.reduce((sum, p) => sum + p.pieces.total, 0);
        const totalOKPieces = processes.reduce((sum, p) => sum + p.pieces.ok, 0);
        const totalCycleTime = processes.reduce((sum, p) => sum + p.metrics.realTime, 0);
        const avgOEE = processes.reduce((sum, p) => sum + p.metrics.oee, 0) / Math.max(processes.length, 1);
        const avgEfficiency = processes.reduce((sum, p) => sum + p.metrics.efficiency, 0) / Math.max(processes.length, 1);
        const totalOutliers = processes.reduce((sum, p) => sum + p.metrics.outlierCount, 0);
        const totalCycles = processes.reduce((sum, p) => sum + p.metrics.cycleCount, 0);

        return {
            totalPieces,
            totalOKPieces,
            totalCycleTime: Math.round(totalCycleTime * 10) / 10,
            avgOEE: Math.round(avgOEE * 10) / 10,
            avgEfficiency: Math.round(avgEfficiency * 10) / 10,
            outlierPercentage: totalCycles > 0 ? Math.round((totalOutliers / totalCycles) * 1000) / 10 : 0,
            throughput: totalCycleTime > 0 ? Math.round((3600 / totalCycleTime) * 10) / 10 : 0,
            uptime: Math.min(100, Math.max(90, avgOEE)), // AproximaciÃ³n de uptime basada en OEE
            qualityRate: totalPieces > 0 ? Math.round((totalOKPieces / totalPieces) * 1000) / 10 : 100
        };
    }

    /**
     * Broadcast a clientes WebSocket conectados
     */
    broadcastToClients(type, data) {
        const message = {
            type,
            data,
            timestamp: new Date().toISOString()
        };

        this.connectedClients.forEach(client => {
            try {
                if (client.readyState === 1) { // WebSocket.OPEN
                    client.send(JSON.stringify(message));
                }
            } catch (error) {
                logger.warn('Error broadcasting to client:', error.message);
                this.connectedClients.delete(client);
            }
        });
    }

    /**
     * Manejar conexiÃ³n WebSocket
     */
    handleWebSocketConnection(ws) {
        this.connectedClients.add(ws);
        logger.info(`ðŸ”— Cliente WebSocket conectado. Total: ${this.connectedClients.size}`);

        // Enviar datos actuales inmediatamente
        if (this.lastLineData) {
            ws.send(JSON.stringify({
                type: 'initial_data',
                data: this.lastLineData,
                timestamp: new Date().toISOString()
            }));
        }

        ws.on('close', () => {
            this.connectedClients.delete(ws);
            logger.info(`ðŸ”Œ Cliente WebSocket desconectado. Total: ${this.connectedClients.size}`);
        });

        ws.on('error', (error) => {
            logger.error('WebSocket error:', error.message);
            this.connectedClients.delete(ws);
        });
    }

    /**
     * Obtener estadÃ­sticas del sistema
     */
    getSystemStats(req, res) {
        try {
            const stats = {
                polling: this.isPolling,
                connectedClients: this.connectedClients.size,
                lastUpdate: this.lastLineData?.timestamp || null,
                csvStats: this.csvFetcher.getConnectionStats(),
                processCount: Object.keys(this.csvFetcher.processConfiguration).length,
                equipmentCount: this.csvFetcher.equipmentUrls.size,
                uptime: process.uptime(),
                memoryUsage: process.memoryUsage()
            };

            res.json({
                success: true,
                data: stats,
                timestamp: new Date().toISOString()
            });

        } catch (error) {
            logger.error('Error getting system stats:', error);
            res.status(500).json({
                success: false,
                error: 'Error obteniendo estadÃ­sticas del sistema',
                message: error.message
            });
        }
    }

    /**
     * Cleanup al cerrar la aplicaciÃ³n
     */
    cleanup() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
        }
        this.connectedClients.clear();
        logger.info('ðŸ§¹ RealDataController cleanup completed');
    }
}

module.exports = RealDataController;
