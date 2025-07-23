// src/infrastructure/external/RealCSVFetcher.js
const CSVExtractor = require('./CSVExtractor');
const axios = require('axios');
const logger = require('../../config/logger');

class RealCSVFetcher {
    constructor() {
        this.equipmentUrls = new Map([
            // Wave Solder - Proceso individual
            ['WAVESOLDER_01', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_WAVESOLDER.csv'],
            
            // Continuity - 3 equipos paralelos
            ['CONTINUITY_01', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_CONTINUITY_GPEC5_CONT01.csv'],
            ['CONTINUITY_02', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_CONTINUITY_GPEC5_CONT02.csv'],
            ['CONTINUITY_03', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_CONTINUITY_GPEC5_CONT03.csv'],
            
            // Racetrack - Plasma (2 equipos R1/R2)
            ['PLASMA_R1', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_PLASMA_GPEC5STA3.csv'],
            ['PLASMA_R2', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_PLASMA_GPEC5STA3_B.csv'],
            
            // PCB Press (2 equipos R1/R2)
            ['PCBPRESS_R1', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_PCBPRESS_GPEC5STA4.csv'],
            ['PCBPRESS_R2', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_PCBPRESS_GPEC5STA4_B.csv'],
            
            // Cover Dispense (2 equipos R1/R2)
            ['COVERDISP_R1', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_COVERDISP_GPEC5STA4.csv'],
            ['COVERDISP_R2', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_COVERDISP_GPEC5STA4_B.csv'],
            
            // Cover Press (2 equipos R1/R2)
            ['COVERPRESS_R1', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_COVERPRESS_GPEC5STA2.csv'],
            ['COVERPRESS_R2', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_COVERPRESS_GPEC5STA2_B.csv'],
            
            // Hot Test - 10 equipos paralelos
            ['HTFT_01', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_HTFT_HTFT_01.csv'],
            ['HTFT_02', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_HTFT_HTFT_02.csv'],
            ['HTFT_03', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_HTFT_HTFT_03.csv'],
            ['HTFT_04', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_HTFT_HTFT_04.csv'],
            ['HTFT_06', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_HTFT_HTFT_06.csv'],
            ['HTFT_07', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_HTFT_HTFT_07.csv'],
            ['HTFT_08', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_HTFT_HTFT_08.csv'],
            ['HTFT_09', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_HTFT_HTFT_09.csv'],
            ['HTFT_10', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_HTFT_HTFT_10.csv'],
            ['HTFT_11', 'http://mxryfis4.global.borgwarner.net/std_public/viewfiles?debuglevel=0&mode=1&sort=0&order=0&bdir=0&edir=&view=CycleRec_HTFT_HTFT_11.csv']
        ]);

        // Configuración de procesos según tu línea GPEC5
        this.processConfiguration = {
            'WAVE_SOLDER': {
                name: 'Wave Solder',
                equipments: ['WAVESOLDER_01'],
                type: 'sequential',
                designTime: 45, // segundos estimados
                aggregationMethod: 'individual'
            },
            'CONTINUITY': {
                name: 'Continuity Test',
                equipments: ['CONTINUITY_01', 'CONTINUITY_02', 'CONTINUITY_03'],
                type: 'parallel',
                designTime: 30,
                aggregationMethod: 'weighted_average'
            },
            'PLASMA': {
                name: 'Plasma Treatment',
                equipments: ['PLASMA_R1', 'PLASMA_R2'],
                type: 'parallel',
                designTime: 25,
                aggregationMethod: 'weighted_average'
            },
            'PCB_PRESS': {
                name: 'PCB Press',
                equipments: ['PCBPRESS_R1', 'PCBPRESS_R2'],
                type: 'parallel',
                designTime: 35,
                aggregationMethod: 'weighted_average'
            },
            'COVER_DISPENSE': {
                name: 'Cover Dispense',
                equipments: ['COVERDISP_R1', 'COVERDISP_R2'],
                type: 'parallel',
                designTime: 20,
                aggregationMethod: 'weighted_average'
            },
            'COVER_PRESS': {
                name: 'Cover Press',
                equipments: ['COVERPRESS_R1', 'COVERPRESS_R2'],
                type: 'parallel',
                designTime: 40,
                aggregationMethod: 'weighted_average'
            },
            'HOT_TEST': {
                name: 'Hot Test (HTFT)',
                equipments: ['HTFT_01', 'HTFT_02', 'HTFT_03', 'HTFT_04', 'HTFT_06', 'HTFT_07', 'HTFT_08', 'HTFT_09', 'HTFT_10', 'HTFT_11'],
                type: 'parallel',
                designTime: 60,
                aggregationMethod: 'weighted_average'
            }
        };

        this.requestTimeout = 10000; // 10 segundos timeout
        this.retryAttempts = 3;
        this.pollingInterval = 30000; // 30 segundos
        this.cache = new Map();
        this.lastFetchTimes = new Map();
        this.csvExtractor = new CSVExtractor();
    }

    // AGREGAR este método después del constructor:
    /**
     * Obtener ID de equipo desde URL
     */
    getEquipmentIdFromUrl(url) {
        for (const [equipmentId, equipmentUrl] of this.equipmentUrls) {
            if (equipmentUrl === url) {
                return equipmentId;
            }
        }
        
        // Fallback: extraer del parámetro view en la URL
        const match = url.match(/view=CycleRec_([^.]+)\.csv/);
        return match ? match[1] : 'UNKNOWN';
    }

    /**
     * Obtener datos CSV de una URL específica
     * @param {string} equipmentId - ID del equipo
     * @returns {Promise<Array>} Datos parseados del CSV
     */
    async fetchCSVData(url, retries = 0) {
        const equipmentId = this.getEquipmentIdFromUrl(url);
        
        try {
            logger.info(`🔍 Fetching CSV data for ${equipmentId}, attempt ${retries + 1}`);
            
            // Usar el extractor de CSV real
            const result = await this.csvExtractor.obtenerDatosCSV(url, equipmentId);
            
            if (result.isReal && result.records.length > 0) {
                // Datos reales obtenidos exitosamente
                logger.info(`✅ CSV data fetched successfully for ${equipmentId}: ${result.recordCount} records (REAL DATA)`);
                
                // Procesar los registros para nuestro formato
                return this.procesarRegistrosReales(result);
                
            } else {
                // Fallback a datos simulados
                logger.warn(`⚠️ Using fallback data for ${equipmentId}: ${result.reason || 'Unknown reason'}`);
                return this.generateFallbackData(equipmentId);
            }
            
        } catch (error) {
            logger.error(`❌ Error fetching CSV from ${url}:`, error.message);
            
            if (retries < this.retryAttempts) {
                logger.info(`🔄 Retrying... (${retries + 1}/${this.retryAttempts})`);
                await new Promise(resolve => setTimeout(resolve, 1000 * (retries + 1)));
                return this.fetchCSVData(url, retries + 1);
            }
            
            // Fallback final
            logger.warn(`🔄 Max retries reached for ${equipmentId}, using fallback data`);
            return this.generateFallbackData(equipmentId);
        }
    }

    
    /**
     * Obtener datos de todos los equipos de un proceso
     */
    async fetchProcessData(processName) {
        const processConfig = this.processConfiguration[processName];
        if (!processConfig) {
            throw new Error(`Proceso no configurado: ${processName}`);
        }

        const equipmentData = new Map();
        const promises = processConfig.equipments.map(async (equipmentId) => {
            try {
                // CORREGIR: pasar URL, no equipmentId
                const url = this.equipmentUrls.get(equipmentId);
                if (!url) {
                    throw new Error(`URL not found for equipment ${equipmentId}`);
                }
                
                const data = await this.fetchCSVData(url);
                equipmentData.set(equipmentId, data);
                return { equipmentId, data, success: true };
            } catch (error) {
                logger.error(`Error fetching data for ${equipmentId}:`, error.message);
                const fallbackData = this.generateFallbackData(equipmentId);
                equipmentData.set(equipmentId, fallbackData);
                return { equipmentId, data: fallbackData, success: false, error: error.message };
            }
        });

        const results = await Promise.allSettled(promises);
        
        return {
            processName,
            processConfig,
            equipmentData,
            results: results.map(r => r.status === 'fulfilled' ? r.value : r.reason),
            timestamp: new Date()
        };
    }

    /**
     * Obtener datos de toda la línea GPEC5
     */
    async fetchLineData() {
        const lineData = new Map();
        const processNames = Object.keys(this.processConfiguration);
        
        logger.info(`🔄 Fetching data for entire GPEC5 line (${processNames.length} processes)`);

        for (const processName of processNames) {
            try {
                const processData = await this.fetchProcessData(processName);
                lineData.set(processName, processData);
                logger.info(`✅ Process ${processName} data fetched: ${processData.equipmentData.size} equipments`);
            } catch (error) {
                logger.error(`❌ Error fetching process ${processName}:`, error.message);
                lineData.set(processName, {
                    processName,
                    processConfig: this.processConfiguration[processName],
                    equipmentData: new Map(),
                    results: [],
                    error: error.message,
                    timestamp: new Date()
                });
            }
        }

        return {
            line: 'GPEC5',
            processes: lineData,
            timestamp: new Date(),
            totalEquipments: this.equipmentUrls.size
        };
    }

    /**
     * Iniciar polling automático
     */
    startPolling(callback) {
        logger.info(`🔄 Starting CSV polling every ${this.pollingInterval}ms`);
        
        const poll = async () => {
            try {
                const lineData = await this.fetchLineData();
                callback(lineData);
            } catch (error) {
                logger.error('❌ Error in polling cycle:', error.message);
                callback({ error: error.message, timestamp: new Date() });
            }
        };

        // Primera ejecución inmediata
        poll();

        // Configurar polling periódico
        return setInterval(poll, this.pollingInterval);
    }

    /**
     * Obtener configuración de equipos para frontend
     */
    getEquipmentConfiguration() {
        const config = {
            equipments: Array.from(this.equipmentUrls.entries()).map(([id, url]) => ({
                id,
                url,
                name: this.getEquipmentDisplayName(id)
            })),
            processes: this.processConfiguration,
            pollingInterval: this.pollingInterval,
            totalEquipments: this.equipmentUrls.size
        };

        return config;
    }

    /**
     * Obtener nombre display para equipos
     */
    getEquipmentDisplayName(equipmentId) {
        const displayNames = {
            'WAVESOLDER_01': 'Wave Solder',
            'CONTINUITY_01': 'Continuity Test 1',
            'CONTINUITY_02': 'Continuity Test 2', 
            'CONTINUITY_03': 'Continuity Test 3',
            'PLASMA_R1': 'Plasma R1',
            'PLASMA_R2': 'Plasma R2',
            'PCBPRESS_R1': 'PCB Press R1',
            'PCBPRESS_R2': 'PCB Press R2',
            'COVERDISP_R1': 'Cover Dispense R1',
            'COVERDISP_R2': 'Cover Dispense R2',
            'COVERPRESS_R1': 'Cover Press R1',
            'COVERPRESS_R2': 'Cover Press R2',
            'HTFT_01': 'Hot Test 1',
            'HTFT_02': 'Hot Test 2',
            'HTFT_03': 'Hot Test 3',
            'HTFT_04': 'Hot Test 4',
            'HTFT_06': 'Hot Test 6',
            'HTFT_07': 'Hot Test 7',
            'HTFT_08': 'Hot Test 8',
            'HTFT_09': 'Hot Test 9',
            'HTFT_10': 'Hot Test 10',
            'HTFT_11': 'Hot Test 11'
        };

        return displayNames[equipmentId] || equipmentId;
    }

    /**
     * Obtener estadísticas de conexión
     */
    getConnectionStats() {
        return {
            totalEquipments: this.equipmentUrls.size,
            cachedEquipments: this.cache.size,
            lastFetchCount: this.lastFetchTimes.size,
            cacheHitRate: this.cache.size / Math.max(this.lastFetchTimes.size, 1),
            pollingInterval: this.pollingInterval,
            requestTimeout: this.requestTimeout,
            retryAttempts: this.retryAttempts
        };
    }

    /**
     * Procesar registros reales en nuestro formato VSM (VERSIÓN CORREGIDA)
     */
    procesarRegistrosReales(result) {
        const { equipmentId, records, recordCount, lastUpdate } = result;
        
        if (!records || records.length === 0) {
            logger.warn(`No records found for ${equipmentId}`);
            return this.generateFallbackData(equipmentId);
        }
        
        logger.info(`🔄 Processing ${records.length} records for ${equipmentId}`);
        
        // Transformar registros para que tengan el formato esperado por analyzeEquipmentRecords
        const transformedRecords = [];
        let validRecords = 0;
        
        records.forEach((registro, index) => {
            try {
                // Mapear campos dinámicamente basado en lo que está disponible
                const transformedRecord = {
                    serial: registro.serial || `unknown_${index}`,
                    line: registro.line || 'GPEC5',
                    partNumber: registro.numeroParte || registro.numeeroParte || registro.numerroParte || registro.partNumber || 'Unknown',
                    process: registro.process || registro.processo || 'Unknown',
                    equipment: registro.station || registro.equipment || equipmentId,
                    // CRÍTICO: Mapear event/status al campo status esperado
                    status: registro.event || registro.status || 'UNKNOWN',
                    timestamp: registro.timestamp || new Date(),
                    equipmentId: equipmentId,
                    // Campos adicionales para debugging
                    rawData: registro
                };
                
                // Validar el registro transformado
                if (this.validateTransformedRecord(transformedRecord, equipmentId, index)) {
                    transformedRecords.push(transformedRecord);
                    validRecords++;
                }
            } catch (error) {
                logger.warn(`Error transforming record ${index} for ${equipmentId}:`, error.message);
            }
        });
        
        logger.info(`✅ Transformed ${validRecords} valid records from ${records.length} total for ${equipmentId}`);
        
        if (transformedRecords.length === 0) {
            logger.warn(`⚠️ No valid records after transformation for ${equipmentId}, using fallback`);
            return this.generateFallbackData(equipmentId);
        }
        
        // Calcular métricas reales basadas en los datos transformados
        const tiemposCiclo = [];
        const pieces = { total: 0, ok: 0, ng: 0 };
        const breqMap = new Map();
        
        // Procesar registros BREQ/BCMP para calcular tiempos de ciclo
        transformedRecords.forEach(record => {
            const key = record.serial;
            
            if (record.status === 'BREQ') {
                breqMap.set(key, record);
            } else if (record.status && (record.status.startsWith('BCMP') || record.status.includes('OK') || record.status.includes('FAIL'))) {
                const breqRecord = breqMap.get(key);
                if (breqRecord && record.timestamp && breqRecord.timestamp) {
                    // Calcular tiempo de ciclo
                    const diferenciaMs = record.timestamp.getTime() - breqRecord.timestamp.getTime();
                    const diferenciaSeg = Math.abs(diferenciaMs) / 1000;
                    
                    // Solo considerar tiempos de ciclo razonables (1 segundo a 10 minutos)
                    if (diferenciaSeg >= 1 && diferenciaSeg <= 600) {
                        tiemposCiclo.push(diferenciaSeg);
                    }
                    
                    pieces.total++;
                    if (record.status.includes('OK') || record.status === 'BCMP OK') {
                        pieces.ok++;
                    } else {
                        pieces.ng++;
                    }
                    
                    breqMap.delete(key); // Limpiar pair procesado
                }
            }
        });
        
        // Si no hay pares BREQ/BCMP, estimar basado en timestamps
        if (tiemposCiclo.length === 0 && transformedRecords.length > 1) {
            logger.info(`📊 No BREQ/BCMP pairs found for ${equipmentId}, estimating from timestamps`);
            for (let i = 1; i < Math.min(transformedRecords.length, 20); i++) {
                const current = transformedRecords[i];
                const previous = transformedRecords[i - 1];
                
                if (current.timestamp && previous.timestamp) {
                    const diferenciaMs = Math.abs(current.timestamp.getTime() - previous.timestamp.getTime());
                    const diferenciaSeg = diferenciaMs / 1000;
                    
                    if (diferenciaSeg >= 5 && diferenciaSeg <= 300) {
                        tiemposCiclo.push(diferenciaSeg);
                    }
                }
            }
            
            // Estimar piezas basado en registros
            pieces.total = Math.min(transformedRecords.length, 50);
            pieces.ok = Math.floor(pieces.total * 0.95); // Asumir 95% OK
            pieces.ng = pieces.total - pieces.ok;
        }
        
        // Calcular estadísticas
        let tiempoCicloPromedio = 45; // Default
        let tiempoCicloActual = 45;   // Default
        
        if (tiemposCiclo.length > 0) {
            tiempoCicloPromedio = tiemposCiclo.reduce((sum, t) => sum + t, 0) / tiemposCiclo.length;
            tiempoCicloActual = tiemposCiclo[tiemposCiclo.length - 1] || tiempoCicloPromedio;
        }
        
        // Análisis de outliers
        const outlierAnalysis = this.analizarOutliers(tiemposCiclo);
        
        // Obtener timestamp más reciente
        const timestamps = transformedRecords.map(r => r.timestamp).filter(t => t && !isNaN(t.getTime()));
        const ultimoTimestamp = timestamps.length > 0 ? 
            new Date(Math.max(...timestamps.map(t => t.getTime()))) : 
            (lastUpdate || new Date());
        
        logger.info(`📊 ${equipmentId} metrics - Cycle times: ${tiemposCiclo.length}, Avg: ${tiempoCicloPromedio.toFixed(1)}s, Pieces: ${pieces.total}`);
        
        return {
            equipmentId,
            data: transformedRecords,
            records: transformedRecords,
            cycleTimes: tiemposCiclo,
            metrics: {
                currentCycleTime: Math.round(tiempoCicloActual * 10) / 10,
                averageCycleTime: Math.round(tiempoCicloPromedio * 10) / 10,
                totalPieces: pieces.total,
                okPieces: pieces.ok,
                ngPieces: pieces.ng,
                qualityRate: pieces.total > 0 ? Math.round((pieces.ok / pieces.total) * 100 * 10) / 10 : 100
            },
            outlierAnalysis,
            timestamp: ultimoTimestamp,
            lastUpdate: ultimoTimestamp.toISOString(),
            recordCount: recordCount || transformedRecords.length,
            validRecordCount: validRecords,
            isRealData: true,
            dataSource: 'CSV extraído de sistema Mantis'
        };
    }

    /**
     * Validar registro transformado (NUEVA FUNCIÓN)
     */
    validateTransformedRecord(record, equipmentId, index) {
        // Validaciones básicas
        if (!record.serial || record.serial.length === 0) {
            logger.debug(`${equipmentId}[${index}] - Missing serial`);
            return false;
        }

        if (!record.status || record.status.length === 0) {
            logger.debug(`${equipmentId}[${index}] - Missing status (serial: ${record.serial})`);
            return false;
        }

        // Validar timestamp
        if (!record.timestamp || isNaN(record.timestamp.getTime())) {
            logger.debug(`${equipmentId}[${index}] - Invalid timestamp (serial: ${record.serial})`);
            return false;
        }

        return true;
    }

    /**
     * Analizar outliers usando ±2σ como en el sistema original
     */
    analizarOutliers(tiemposCiclo) {
        if (tiemposCiclo.length < 3) {
            return {
                outliers: [],
                normal: tiemposCiclo,
                mean: tiemposCiclo.length > 0 ? tiemposCiclo.reduce((sum, t) => sum + t, 0) / tiemposCiclo.length : 0,
                stdDev: 0,
                outlierPercentage: 0
            };
        }
        
        // Calcular media y desviación estándar
        const mean = tiemposCiclo.reduce((sum, t) => sum + t, 0) / tiemposCiclo.length;
        const variance = tiemposCiclo.reduce((sum, t) => sum + Math.pow(t - mean, 2), 0) / tiemposCiclo.length;
        const stdDev = Math.sqrt(variance);
        
        // Detectar outliers (±2σ)
        const lowerBound = mean - (2 * stdDev);
        const upperBound = mean + (2 * stdDev);
        
        const outliers = [];
        const normal = [];
        
        tiemposCiclo.forEach(tiempo => {
            if (tiempo < lowerBound || tiempo > upperBound) {
                outliers.push(tiempo);
            } else {
                normal.push(tiempo);
            }
        });
        
        return {
            outliers,
            normal,
            mean: Math.round(mean * 10) / 10,
            stdDev: Math.round(stdDev * 10) / 10,
            outlierPercentage: Math.round((outliers.length / tiemposCiclo.length) * 100 * 10) / 10
        };
    }

    /**
     * Mejorar el método generateFallbackData existente
     */
    generateFallbackData(equipmentId) {
        const now = new Date();
        
        // Generar datos más realistas basados en el equipo
        const equipmentProfiles = {
            'WAVESOLDER_01': { baseCycle: 45, variance: 5, quality: 0.95 },
            'CONTINUITY_01': { baseCycle: 25, variance: 3, quality: 0.98 },
            'CONTINUITY_02': { baseCycle: 24, variance: 3, quality: 0.97 },
            'CONTINUITY_03': { baseCycle: 26, variance: 3, quality: 0.98 },
            'PLASMA_R1': { baseCycle: 35, variance: 8, quality: 0.92 },
            'PLASMA_R2': { baseCycle: 33, variance: 7, quality: 0.94 }
            // ... agregar más según necesidad
        };
        
        const profile = equipmentProfiles[equipmentId] || { baseCycle: 45, variance: 5, quality: 0.90 };
        
        // Simular algunos datos recientes
        const simulatedRecords = [];
        const simulatedCycleTimes = [];
        
        for (let i = 0; i < 10; i++) {
            const cycleTime = profile.baseCycle + (Math.random() - 0.5) * profile.variance;
            simulatedCycleTimes.push(cycleTime);
            
            const timestamp = new Date(now.getTime() - (i * 30000)); // Cada 30 segundos
            simulatedRecords.push({
                serial: `SIM_${equipmentId}_${i}`,
                event: Math.random() < profile.quality ? 'PASS' : 'FAIL',
                timestamp: timestamp,
                station: equipmentId
            });
        }
        
        const totalPieces = Math.floor(Math.random() * 10) + 5;
        const okPieces = Math.floor(totalPieces * profile.quality);
        
        return {
            equipmentId,
            data: simulatedRecords,
            records: simulatedRecords,
            cycleTimes: simulatedCycleTimes,
            metrics: {
                currentCycleTime: profile.baseCycle + (Math.random() - 0.5) * profile.variance,
                averageCycleTime: profile.baseCycle,
                totalPieces: totalPieces,
                okPieces: okPieces,
                ngPieces: totalPieces - okPieces,
                qualityRate: (okPieces / totalPieces) * 100
            },
            outlierAnalysis: {
                outliers: [],
                normal: simulatedCycleTimes,
                mean: profile.baseCycle,
                stdDev: profile.variance / 2,
                outlierPercentage: Math.random() * 5
            },
            timestamp: now,
            lastUpdate: now.toISOString(),
            recordCount: Math.floor(Math.random() * 500) + 300,
            isRealData: false,
            dataSource: 'Simulación realista'
        };
    }
}

module.exports = RealCSVFetcher;