// src/infrastructure/external/RealCSVFetcher.js
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
    }

    /**
     * Obtener datos CSV de una URL específica
     * @param {string} equipmentId - ID del equipo
     * @returns {Promise<Array>} Datos parseados del CSV
     */
    async fetchCSVData(equipmentId) {
        const url = this.equipmentUrls.get(equipmentId);
        if (!url) {
            throw new Error(`URL no encontrada para equipo: ${equipmentId}`);
        }

        const lastFetch = this.lastFetchTimes.get(equipmentId);
        const now = Date.now();
        
        // Cache por 30 segundos para evitar requests excesivos
        if (lastFetch && (now - lastFetch) < 30000) {
            const cached = this.cache.get(equipmentId);
            if (cached) {
                logger.debug(`Usando cache para equipo ${equipmentId}`);
                return cached;
            }
        }

        let attempt = 0;
        while (attempt < this.retryAttempts) {
            try {
                logger.info(`Fetching CSV data for ${equipmentId}, attempt ${attempt + 1}`);
                
                const response = await axios.get(url, {
                    timeout: this.requestTimeout,
                    headers: {
                        'User-Agent': 'VSM-Monitor/1.0',
                        'Accept': 'text/csv,text/plain,*/*'
                    }
                });

                if (response.status === 200 && response.data) {
                    const parsedData = this.parseCSVData(response.data, equipmentId);
                    
                    // Actualizar cache
                    this.cache.set(equipmentId, parsedData);
                    this.lastFetchTimes.set(equipmentId, now);
                    
                    logger.info(`✅ CSV data fetched successfully for ${equipmentId}: ${parsedData.length} records`);
                    return parsedData;
                } else {
                    throw new Error(`Invalid response: ${response.status}`);
                }

            } catch (error) {
                attempt++;
                logger.warn(`❌ Error fetching ${equipmentId} (attempt ${attempt}):`, error.message);
                
                if (attempt >= this.retryAttempts) {
                    logger.error(`Failed to fetch data for ${equipmentId} after ${this.retryAttempts} attempts`);
                    throw error;
                }
                
                // Esperar antes del retry
                await new Promise(resolve => setTimeout(resolve, 2000 * attempt));
            }
        }
    }

    /**
     * Parsear datos CSV según tu formato específico
     * Formato: Serial,Línea,Parte,Proceso,Equipo,Estado,Timestamp
     */
    parseCSVData(csvText, equipmentId) {
        const lines = csvText.split('\n').filter(line => line.trim());
        const records = [];

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;

            try {
                // Tu formato: 64125090026109,GPEC5,66829616,HTFT,HTFT_01,BREQ,07/21/2025 07:07:04
                const parts = line.split(',');
                
                if (parts.length >= 7) {
                    const record = {
                        serial: parts[0].trim(),
                        line: parts[1].trim(),
                        partNumber: parts[2].trim(),
                        process: parts[3].trim(),
                        equipment: parts[4].trim(),
                        status: parts[5].trim(),
                        timestamp: this.parseTimestamp(parts[6].trim()),
                        rawTimestamp: parts[6].trim(),
                        equipmentId: equipmentId,
                        lineNumber: i + 1
                    };

                    // Validar que el registro tenga datos válidos
                    if (this.validateRecord(record)) {
                        records.push(record);
                    }
                }
            } catch (error) {
                logger.warn(`Error parsing line ${i + 1} for ${equipmentId}:`, error.message);
            }
        }

        // Ordenar por timestamp (más recientes primero)
        records.sort((a, b) => b.timestamp - a.timestamp);
        
        return records.slice(0, 1000); // Limitar a últimos 1000 registros
    }

    /**
     * Parsear timestamp en formato: 07/21/2025 07:07:04
     */
    parseTimestamp(timestampStr) {
        try {
            // Formato: MM/DD/YYYY HH:mm:ss
            const [datePart, timePart] = timestampStr.split(' ');
            const [month, day, year] = datePart.split('/');
            const [hour, minute, second] = timePart.split(':');
            
            return new Date(
                parseInt(year),
                parseInt(month) - 1, // JavaScript months are 0-based
                parseInt(day),
                parseInt(hour),
                parseInt(minute),
                parseInt(second)
            );
        } catch (error) {
            logger.warn(`Error parsing timestamp: ${timestampStr}`, error.message);
            return new Date(); // Fallback to current time
        }
    }

    /**
     * Validar registro CSV
     */
    validateRecord(record) {
        return (
            record.serial && record.serial.length > 0 &&
            record.line === 'GPEC5' &&
            record.partNumber && record.partNumber.length > 0 &&
            record.process && record.process.length > 0 &&
            record.equipment && record.equipment.length > 0 &&
            record.status && ['BREQ', 'BCMP OK', 'BCMP NG'].includes(record.status) &&
            record.timestamp instanceof Date && !isNaN(record.timestamp)
        );
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
                const data = await this.fetchCSVData(equipmentId);
                equipmentData.set(equipmentId, data);
                return { equipmentId, data, success: true };
            } catch (error) {
                logger.error(`Error fetching data for ${equipmentId}:`, error.message);
                equipmentData.set(equipmentId, []);
                return { equipmentId, data: [], success: false, error: error.message };
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
}

module.exports = RealCSVFetcher;