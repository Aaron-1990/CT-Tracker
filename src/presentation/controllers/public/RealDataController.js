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
     * Obtener configuración de equipos y procesos
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
                error: 'Error obteniendo configuración',
                message: error.message
            });
        }
    }

    /**
     * GET /api/gpec5/data/live
     * Obtener datos en tiempo real de toda la línea
     */
    async getLiveData(req, res) {
        try {
            logger.info('📊 Fetching live GPEC5 data...');
            const lineData = await this.csvFetcher.fetchLineData();
            
            // Procesar datos para VSM
            const vsmData = this.processLineDataForVSM(lineData);
            
            // Guardar últimos datos
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
     * Obtener datos de un proceso específico
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
     * Iniciar polling automático
     */
    async startPolling(req, res) {
        try {
            if (this.isPolling) {
                return res.json({
                    success: true,
                    message: 'Polling ya está activo',
                    data: { polling: true }
                });
            }

            this.pollingInterval = this.csvFetcher.startPolling((lineData) => {
                this.lastLineData = this.processLineDataForVSM(lineData);
                this.broadcastToClients('data_update', this.lastLineData);
            });

            this.isPolling = true;
            logger.info('🔄 Polling iniciado para línea GPEC5');

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
     * Detener polling automático
     */
    stopPolling(req, res) {
        try {
            if (this.pollingInterval) {
                clearInterval(this.pollingInterval);
                this.pollingInterval = null;
            }
            
            this.isPolling = false;
            logger.info('⏹️ Polling detenido para línea GPEC5');

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
     * Procesar datos de línea completa para VSM
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
     * Procesar datos de proceso individual para VSM
     */
    processProcessDataForVSM(processData) {
        const { processName, processConfig, equipmentData } = processData;
        
        // Calcular métricas VSM para el proceso
        const cycleTimes = [];
        const pieces = { total: 0, ok: 0, ng: 0 };
        const equipmentMetrics = [];

        // Procesar cada equipo del proceso
        for (const [equipmentId, records] of equipmentData) {
            const equipmentAnalysis = this.analyzeEquipmentRecords(records, equipmentId);
            equipmentMetrics.push(equipmentAnalysis);
            
            cycleTimes.push(...equipmentAnalysis.cycleTimes);
            pieces.total += equipmentAnalysis.pieces.total;
            pieces.ok += equipmentAnalysis.pieces.ok;
            pieces.ng += equipmentAnalysis.pieces.ng;
        }

        // Calcular métricas agregadas del proceso
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
     * Analizar registros de un equipo individual
     */
    analyzeEquipmentRecords(records, equipmentId) {
        const cycleTimes = [];
        const pieces = { total: 0, ok: 0, ng: 0 };
        const breqMap = new Map();
        
        // Agrupar BREQ y BCMP por serial
        records.forEach(record => {
            const key = record.serial;
            
            if (record.status === 'BREQ') {
                breqMap.set(key, record);
            } else if (record.status.startsWith('BCMP')) {
                const breqRecord = breqMap.get(key);
                if (breqRecord) {
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

        // Análisis estadístico
        const outlierAnalysis = this.detectOutliers(cycleTimes.map(ct => ct.cycleTime));
        
        return {
            equipmentId,
            cycleTimes,
            pieces,
            outlierAnalysis,
            lastUpdate: records.length > 0 ? records[0].timestamp : new Date(),
            recordCount: records.length
        };
    }

    /**
     * Calcular métricas VSM para un proceso
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

        // Tiempo real: según tu especificación - último par válido promediado
        const recentCycles = allCycleTimes.slice(0, 10); // Últimos 10 ciclos
        const realTime = recentCycles.reduce((sum, time) => sum + time, 0) / recentCycles.length;

        // Promedio 1h con filtro ±2σ (tu especificación)
        const hourlyData = allCycleTimes.slice(0, 60); // Simular 1 hora de datos
        const hourlyAverage = this.removeOutliersAndAverage(hourlyData, 2.0);

        // OEE: promedio ponderado de equipos (tu especificación)
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
            // Para secuencial, basado en eficiencia vs tiempo diseño
            oee = Math.max(85, (processConfig.designTime / realTime) * 100);
        }

        // Eficiencia vs diseño
        const efficiency = (processConfig.designTime / realTime) * 100;

        // Análisis de outliers
        const outlierAnalysis = this.detectOutliers(allCycleTimes);
        const outlierStatus = this.classifyOutlierStatus(outlierAnalysis.outlierPercentage);

        // Throughput (piezas por hora)
        const throughput = realTime > 0 ? 3600 / realTime : 0;

        return {
            realTime: Math.round(realTime * 10) / 10,
            hourlyAverage: Math.round(hourlyAverage * 10) / 10,
            oee: Math.round(oee * 10) / 10,
            efficiency: Math.round(efficiency * 10) / 10,
            outlierPercentage: Math.round(outlierAnalysis.outlierPercentage * 10) / 10,
            outlierStatus,
            throughput: Math.round(throughput * 10) / 10,
            cycleCount: allCycleTimes.length,
            outlierCount: outlierAnalysis.outliers.length
        };
    }

    /**
     * Detectar outliers con método ±2σ (tu especificación)
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
     * Remover outliers y calcular promedio (tu especificación ±2σ)
     */
    removeOutliersAndAverage(data, stdMultiplier = 2.0) {
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
     * Calcular resumen de línea completa
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
            uptime: Math.min(100, Math.max(90, avgOEE)), // Aproximación de uptime basada en OEE
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
     * Manejar conexión WebSocket
     */
    handleWebSocketConnection(ws) {
        this.connectedClients.add(ws);
        logger.info(`🔗 Cliente WebSocket conectado. Total: ${this.connectedClients.size}`);

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
            logger.info(`🔌 Cliente WebSocket desconectado. Total: ${this.connectedClients.size}`);
        });

        ws.on('error', (error) => {
            logger.error('WebSocket error:', error.message);
            this.connectedClients.delete(ws);
        });
    }

    /**
     * Obtener estadísticas del sistema
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
                error: 'Error obteniendo estadísticas del sistema',
                message: error.message
            });
        }
    }

    /**
     * Cleanup al cerrar la aplicación
     */
    cleanup() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
        }
        this.connectedClients.clear();
        logger.info('🧹 RealDataController cleanup completed');
    }
}

module.exports = RealDataController;