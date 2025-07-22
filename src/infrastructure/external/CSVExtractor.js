// =============================================================================
// CSV Extractor basado en el código Python exitoso
// Archivo: src/infrastructure/external/CSVExtractor.js
// =============================================================================

const axios = require('axios');
const logger = require('../../config/logger');

class CSVExtractor {
    constructor() {
        this.requestTimeout = 10000;
        this.retryAttempts = 3;
    }

    /**
     * Extraer contenido CSV del HTML usando la misma lógica del Python
     */
    extraerCSVDeHTML(htmlContent) {
        try {
            // Método 1: Buscar contenido dentro de etiquetas <xmp> (específico del sistema)
            const xmpMatch = htmlContent.match(/<xmp>(.*?)<\/xmp>/s);
            if (xmpMatch) {
                logger.info('✅ CSV encontrado en etiquetas <xmp>');
                return xmpMatch[1];
            }
            
            // Método 2: Alternativas si no se encuentra <xmp>
            const preMatch = htmlContent.match(/<pre[^>]*>(.*?)<\/pre>/s);
            if (preMatch) {
                logger.info('✅ CSV encontrado en etiquetas <pre>');
                return preMatch[1];
            }
            
            const textareaMatch = htmlContent.match(/<textarea[^>]*>(.*?)<\/textarea>/s);
            if (textareaMatch) {
                logger.info('✅ CSV encontrado en etiquetas <textarea>');
                return textareaMatch[1];
            }
            
            logger.warn('❌ No se encontró CSV en el HTML');
            return null;
            
        } catch (error) {
            logger.error('Error al extraer CSV de HTML:', error.message);
            return null;
        }
    }

    /**
     * Limpiar texto HTML y caracteres no deseados
     */
    limpiarTextoHTML(texto) {
        if (typeof texto === 'string') {
            // Eliminar etiquetas HTML y caracteres especiales
            return texto.replace(/<[^>]+>|<[^>]+$/g, '').trim();
        }
        return texto;
    }

    /**
     * Filtrar líneas con formato correcto (7 columnas como en Python)
     */
    filtrarLineasCorrectas(csvContent) {
        const lineas = csvContent.trim().split('\n');
        const lineas7Columnas = [];
        
        for (const linea of lineas) {
            const campos = linea.trim().split(',');
            // Aceptar líneas con 7 columnas (como en Python)
            if (campos.length === 7) {
                lineas7Columnas.push(linea);
            }
        }
        
        if (lineas7Columnas.length > 0) {
            logger.info(`📊 Filtradas ${lineas7Columnas.length} líneas con 7 columnas de ${lineas.length} total`);
            return lineas7Columnas.join('\n');
        }
        
        logger.warn('⚠️ No se encontraron líneas con formato de 7 columnas');
        return null;
    }

    /**
     * Procesar CSV y extraer datos como el Python
     */
    procesarCSV(csvContent) {
        try {
            const lineas = csvContent.trim().split('\n');
            const registros = [];
            
            for (let i = 0; i < lineas.length; i++) {
                const linea = lineas[i].trim();
                if (!linea) continue;
                
                const campos = linea.split(',');
                if (campos.length !== 7) continue;
                
                // Mapear campos según el formato Python
                const [serial, familia, numeroParte, station, line, event, timestamp] = campos;
                
                // Limpiar timestamp de posible HTML
                let timestampLimpio = this.limpiarTextoHTML(timestamp);
                
                try {
                    // Convertir timestamp (formato MM/DD/YYYY HH:MM:SS)
                    const fechaObj = this.convertirTimestamp(timestampLimpio);
                    
                    if (fechaObj) {
                        registros.push({
                            serial: this.limpiarTextoHTML(serial),
                            familia: this.limpiarTextoHTML(familia),
                            numeroParte: this.limpiarTextoHTML(numeroParte),
                            station: this.limpiarTextoHTML(station),
                            line: this.limpiarTextoHTML(line),
                            event: this.limpiarTextoHTML(event),
                            timestamp: fechaObj,
                            timestampOriginal: timestampLimpio,
                            rawLine: linea
                        });
                    }
                } catch (fechaError) {
                    logger.warn(`Error procesando timestamp '${timestampLimpio}':`, fechaError.message);
                    continue;
                }
            }
            
            logger.info(`✅ Procesados ${registros.length} registros válidos de ${lineas.length} líneas`);
            return registros;
            
        } catch (error) {
            logger.error('Error procesando CSV:', error.message);
            return [];
        }
    }

    /**
     * Convertir timestamp desde formato MM/DD/YYYY HH:MM:SS
     */
    convertirTimestamp(timestampStr) {
        try {
            // Formato esperado: MM/DD/YYYY HH:MM:SS
            const match = timestampStr.match(/(\d{1,2})\/(\d{1,2})\/(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})/);
            
            if (match) {
                const [, mes, dia, año, hora, minuto, segundo] = match;
                
                // JavaScript Date constructor usa 0-based months
                const fecha = new Date(
                    parseInt(año),
                    parseInt(mes) - 1, // Mes base 0
                    parseInt(dia),
                    parseInt(hora),
                    parseInt(minuto),
                    parseInt(segundo)
                );
                
                if (!isNaN(fecha.getTime())) {
                    return fecha;
                }
            }
            
            // Fallback: intentar parseado automático
            const fechaAuto = new Date(timestampStr);
            if (!isNaN(fechaAuto.getTime())) {
                return fechaAuto;
            }
            
            return null;
            
        } catch (error) {
            logger.warn(`Error convirtiendo timestamp '${timestampStr}':`, error.message);
            return null;
        }
    }

    /**
     * Obtener datos CSV reales usando la misma lógica del Python exitoso
     */
    async obtenerDatosCSV(url, equipmentId) {
        try {
            logger.info(`🔍 Obteniendo datos CSV para ${equipmentId} desde ${url}`);
            
            // Configuración de request similar al Python
            const requestConfig = {
                method: 'GET',
                url: url,
                timeout: this.requestTimeout,
                headers: {
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                    'Accept-Encoding': 'gzip, deflate',
                    'Connection': 'keep-alive',
                    'Cache-Control': 'no-cache'
                },
                validateStatus: (status) => status >= 200 && status < 400,
                maxRedirects: 3
            };

            const response = await axios(requestConfig);
            
            logger.info(`📡 Respuesta recibida - Status: ${response.status}, Tamaño: ${response.data.length} chars`);
            logger.debug(`📄 Primeros 200 caracteres: ${response.data.substring(0, 200)}`);

            // Verificar si es HTML (esperado)
            if (response.data.includes('<html') || response.data.includes('<!DOCTYPE')) {
                logger.info('📄 Respuesta HTML detectada, extrayendo CSV...');
                
                // Extraer CSV del HTML usando el método del Python
                const csvContent = this.extraerCSVDeHTML(response.data);
                
                if (csvContent) {
                    // Filtrar líneas con formato correcto
                    const csvFiltrado = this.filtrarLineasCorrectas(csvContent);
                    
                    if (csvFiltrado) {
                        // Procesar el CSV filtrado
                        const registros = this.procesarCSV(csvFiltrado);
                        
                        if (registros.length > 0) {
                            logger.info(`✅ ${equipmentId}: ${registros.length} registros extraídos exitosamente`);
                            
                            return {
                                equipmentId,
                                records: registros,
                                recordCount: registros.length,
                                lastUpdate: new Date(),
                                isReal: true,
                                method: 'CSV extraído de HTML'
                            };
                        }
                    }
                }
                
                logger.warn(`⚠️ ${equipmentId}: No se pudo extraer CSV válido del HTML`);
            } else {
                logger.info('📄 Respuesta directa CSV detectada');
                // Si por alguna razón devuelve CSV directo
                const registros = this.procesarCSV(response.data);
                
                if (registros.length > 0) {
                    return {
                        equipmentId,
                        records: registros,
                        recordCount: registros.length,
                        lastUpdate: new Date(),
                        isReal: true,
                        method: 'CSV directo'
                    };
                }
            }
            
            // Si llegamos aquí, no pudimos extraer datos
            logger.warn(`❌ ${equipmentId}: No se pudieron extraer datos válidos`);
            return this.generarDatosFallback(equipmentId);
            
        } catch (error) {
            logger.error(`❌ Error obteniendo CSV para ${equipmentId}:`, error.message);
            return this.generarDatosFallback(equipmentId);
        }
    }

    /**
     * Generar datos de fallback si no se pueden obtener datos reales
     */
    generarDatosFallback(equipmentId) {
        return {
            equipmentId,
            records: [],
            recordCount: Math.floor(Math.random() * 500) + 300,
            lastUpdate: new Date(),
            isReal: false,
            method: 'Fallback simulado',
            reason: 'No se pudo extraer CSV del HTML'
        };
    }
}

module.exports = CSVExtractor;