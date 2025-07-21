// =============================================================================
// src/core/services/calculation/OutlierDetectionService.js
// Servicio para detección automática de outliers usando ±2σ
// =============================================================================

const ss = require('simple-statistics');
const logger = require('../../../../config/logger');

/**
 * Servicio de detección de outliers para datos de ciclo de tiempo VSM
 * Implementa algoritmo de detección estadística usando desviación estándar
 */
class OutlierDetectionService {
    constructor(config = {}) {
        // Configuración por defecto
        this.config = {
            // Multiplicador de desviación estándar (±2σ = 95.4% de datos normales)
            standardDeviationMultiplier: config.standardDeviationMultiplier || 2.0,
            
            // Tamaño mínimo de muestra para análisis válido
            minimumSampleSize: config.minimumSampleSize || 5,
            
            // Máximo porcentaje de outliers permitidos (para validar calidad de datos)
            maxOutlierPercentage: config.maxOutlierPercentage || 25,
            
            // Ventana deslizante para análisis temporal
            rollingWindowSize: config.rollingWindowSize || 50,
            
            // Configurar logging detallado
            enableDetailedLogging: config.enableDetailedLogging || false
        };
    }

    /**
     * Detectar outliers en conjunto de datos de tiempo de ciclo
     * @param {Array<number>} cycleTimeData - Array de tiempos de ciclo
     * @param {Object} options - Opciones adicionales
     * @returns {Object} Resultado de análisis con outliers detectados
     */
    detectOutliers(cycleTimeData, options = {}) {
        try {
            // Validaciones iniciales
            const validationResult = this.validateInput(cycleTimeData);
            if (!validationResult.isValid) {
                return {
                    success: false,
                    error: validationResult.error,
                    data: null
                };
            }

            // Filtrar datos válidos (números positivos)
            const cleanData = this.cleanData(cycleTimeData);
            
            if (cleanData.length < this.config.minimumSampleSize) {
                return {
                    success: false,
                    error: `Insuficientes datos válidos. Mínimo requerido: ${this.config.minimumSampleSize}`,
                    data: {
                        totalRecords: cycleTimeData.length,
                        validRecords: cleanData.length,
                        invalidRecords: cycleTimeData.length - cleanData.length
                    }
                };
            }

            // Calcular estadísticas básicas
            const statistics = this.calculateStatistics(cleanData);
            
            // Determinar umbrales de outliers
            const thresholds = this.calculateThresholds(statistics);
            
            // Detectar outliers
            const outlierResults = this.identifyOutliers(cleanData, thresholds, options);
            
            // Validar calidad del análisis
            const qualityCheck = this.validateAnalysisQuality(outlierResults, cleanData.length);
            
            // Preparar resultado final
            const result = {
                success: true,
                timestamp: new Date().toISOString(),
                data: {
                    // Resumen de datos procesados
                    summary: {
                        totalRecords: cycleTimeData.length,
                        validRecords: cleanData.length,
                        invalidRecords: cycleTimeData.length - cleanData.length,
                        outliersDetected: outlierResults.outliers.length,
                        outlierPercentage: (outlierResults.outliers.length / cleanData.length) * 100,
                        normalRecords: cleanData.length - outlierResults.outliers.length
                    },
                    
                    // Estadísticas descriptivas
                    statistics: {
                        mean: statistics.mean,
                        median: statistics.median,
                        standardDeviation: statistics.standardDeviation,
                        variance: statistics.variance,
                        min: statistics.min,
                        max: statistics.max,
                        range: statistics.max - statistics.min
                    },
                    
                    // Umbrales de detección
                    thresholds: {
                        lower: thresholds.lower,
                        upper: thresholds.upper,
                        multiplier: this.config.standardDeviationMultiplier
                    },
                    
                    // Outliers detectados
                    outliers: outlierResults.outliers,
                    
                    // Datos normales (para referencia)
                    normalData: outlierResults.normalData,
                    
                    // Calidad del análisis
                    qualityIndicators: qualityCheck,
                    
                    // Recomendaciones
                    recommendations: this.generateRecommendations(outlierResults, statistics, qualityCheck)
                }
            };

            // Logging detallado si está habilitado
            if (this.config.enableDetailedLogging) {
                logger.debug('Análisis de outliers completado:', {
                    totalRecords: result.data.summary.totalRecords,
                    outliersDetected: result.data.summary.outliersDetected,
                    outlierPercentage: result.data.summary.outlierPercentage.toFixed(2) + '%',
                    mean: result.data.statistics.mean.toFixed(2),
                    stdDev: result.data.statistics.standardDeviation.toFixed(2)
                });
            }

            return result;

        } catch (error) {
            logger.error('Error en detección de outliers:', error);
            return {
                success: false,
                error: 'Error interno en análisis estadístico',
                details: process.env.NODE_ENV === 'development' ? error.message : undefined,
                data: null
            };
        }
    }

    /**
     * Detectar outliers en tiempo real (ventana deslizante)
     * @param {Array<number>} recentData - Datos recientes 
     * @param {Array<number>} historicalData - Datos históricos para contexto
     * @returns {Object} Resultado de análisis en tiempo real
     */
    detectOutliersRealTime(recentData, historicalData = []) {
        try {
            // Combinar datos para ventana deslizante
            const combinedData = [...historicalData, ...recentData]
                .slice(-this.config.rollingWindowSize);

            // Análisis estándar
            const analysis = this.detectOutliers(combinedData, { 
                focusOnRecent: true,
                recentCount: recentData.length 
            });

            if (!analysis.success) {
                return analysis;
            }

            // Identificar cuáles de los datos recientes son outliers
            const recentOutliers = analysis.data.outliers.filter(outlier => 
                recentData.includes(outlier.value)
            );

            return {
                ...analysis,
                data: {
                    ...analysis.data,
                    // Información específica de tiempo real
                    realTimeAnalysis: {
                        recentRecords: recentData.length,
                        recentOutliers: recentOutliers.length,
                        recentOutlierPercentage: (recentOutliers.length / recentData.length) * 100,
                        windowSize: combinedData.length,
                        isDataStable: recentOutliers.length === 0,
                        trend: this.detectTrend(combinedData.slice(-10)) // Últimos 10 puntos
                    },
                    recentOutliers
                }
            };

        } catch (error) {
            logger.error('Error en análisis tiempo real:', error);
            return {
                success: false,
                error: 'Error en análisis de tiempo real'
            };
        }
    }

    /**
     * Validar datos de entrada
     * @param {Array} data - Datos a validar
     * @returns {Object} Resultado de validación
     */
    validateInput(data) {
        if (!Array.isArray(data)) {
            return {
                isValid: false,
                error: 'Los datos deben ser un arreglo'
            };
        }

        if (data.length === 0) {
            return {
                isValid: false,
                error: 'El arreglo de datos está vacío'
            };
        }

        return { isValid: true };
    }

    /**
     * Limpiar y filtrar datos válidos
     * @param {Array} data - Datos crudos
     * @returns {Array<number>} Datos limpios
     */
    cleanData(data) {
        return data
            .filter(value => {
                // Filtrar valores válidos: números positivos
                return typeof value === 'number' && 
                       !isNaN(value) && 
                       isFinite(value) && 
                       value > 0;
            })
            .map(value => Number(value)); // Asegurar tipo numérico
    }

    /**
     * Calcular estadísticas descriptivas
     * @param {Array<number>} data - Datos limpios
     * @returns {Object} Estadísticas calculadas
     */
    calculateStatistics(data) {
        return {
            mean: ss.mean(data),
            median: ss.median(data),
            standardDeviation: ss.standardDeviation(data),
            variance: ss.variance(data),
            min: ss.min(data),
            max: ss.max(data),
            count: data.length
        };
    }

    /**
     * Calcular umbrales de detección de outliers
     * @param {Object} statistics - Estadísticas básicas
     * @returns {Object} Umbrales superior e inferior
     */
    calculateThresholds(statistics) {
        const { mean, standardDeviation } = statistics;
        const multiplier = this.config.standardDeviationMultiplier;

        return {
            lower: mean - (multiplier * standardDeviation),
            upper: mean + (multiplier * standardDeviation)
        };
    }

    /**
     * Identificar outliers en los datos
     * @param {Array<number>} data - Datos a analizar
     * @param {Object} thresholds - Umbrales de detección
     * @param {Object} options - Opciones adicionales
     * @returns {Object} Outliers y datos normales
     */
    identifyOutliers(data, thresholds, options = {}) {
        const outliers = [];
        const normalData = [];

        data.forEach((value, index) => {
            const isOutlier = value < thresholds.lower || value > thresholds.upper;
            
            if (isOutlier) {
                // Calcular qué tanto se desvía del umbral
                const deviationFromLower = Math.abs(value - thresholds.lower);
                const deviationFromUpper = Math.abs(value - thresholds.upper);
                const deviation = Math.min(deviationFromLower, deviationFromUpper);
                
                outliers.push({
                    index,
                    value,
                    type: value < thresholds.lower ? 'low' : 'high',
                    deviation,
                    deviationMultiple: deviation / this.calculateStatistics(data).standardDeviation,
                    severity: this.classifyOutlierSeverity(deviation, this.calculateStatistics(data).standardDeviation)
                });
            } else {
                normalData.push({
                    index,
                    value
                });
            }
        });

        return { outliers, normalData };
    }

    /**
     * Clasificar severidad del outlier
     * @param {number} deviation - Desviación del outlier
     * @param {number} standardDeviation - Desviación estándar de los datos
     * @returns {string} Nivel de severidad
     */
    classifyOutlierSeverity(deviation, standardDeviation) {
        const multiple = deviation / standardDeviation;
        
        if (multiple >= 3) return 'extreme';     // ±3σ o más
        if (multiple >= 2.5) return 'severe';   // Entre ±2.5σ y ±3σ
        if (multiple >= 2) return 'moderate';   // Entre ±2σ y ±2.5σ
        return 'mild';                          // Entre ±1.5σ y ±2σ
    }

    /**
     * Validar calidad del análisis estadístico
     * @param {Object} outlierResults - Resultados de detección
     * @param {number} totalRecords - Total de registros
     * @returns {Object} Indicadores de calidad
     */
    validateAnalysisQuality(outlierResults, totalRecords) {
        const outlierPercentage = (outlierResults.outliers.length / totalRecords) * 100;
        
        return {
            isHighQuality: outlierPercentage <= this.config.maxOutlierPercentage,
            outlierPercentage,
            qualityLevel: this.determineQualityLevel(outlierPercentage),
            recommendations: this.getQualityRecommendations(outlierPercentage),
            dataStability: outlierResults.outliers.length === 0 ? 'stable' : 
                          outlierPercentage < 5 ? 'mostly_stable' : 
                          outlierPercentage < 15 ? 'unstable' : 'highly_unstable'
        };
    }

    /**
     * Determinar nivel de calidad basado en porcentaje de outliers
     * @param {number} outlierPercentage - Porcentaje de outliers
     * @returns {string} Nivel de calidad
     */
    determineQualityLevel(outlierPercentage) {
        if (outlierPercentage <= 2) return 'excellent';
        if (outlierPercentage <= 5) return 'good';
        if (outlierPercentage <= 10) return 'fair';
        if (outlierPercentage <= 20) return 'poor';
        return 'critical';
    }

    /**
     * Generar recomendaciones basadas en análisis
     * @param {Object} outlierResults - Resultados de outliers
     * @param {Object} statistics - Estadísticas
     * @param {Object} qualityCheck - Verificación de calidad
     * @returns {Array<string>} Lista de recomendaciones
     */
    generateRecommendations(outlierResults, statistics, qualityCheck) {
        const recommendations = [];

        // Recomendaciones por calidad de datos
        if (qualityCheck.qualityLevel === 'critical') {
            recommendations.push('⚠️ Calidad de datos crítica - Revisar configuración de equipos');
            recommendations.push('🔍 Verificar calibración y mantenimiento de sensores');
        }

        // Recomendaciones por tipo de outliers
        const highOutliers = outlierResults.outliers.filter(o => o.type === 'high').length;
        const lowOutliers = outlierResults.outliers.filter(o => o.type === 'low').length;

        if (highOutliers > lowOutliers * 2) {
            recommendations.push('⏰ Múltiples tiempos de ciclo altos detectados - Posible cuello de botella');
        }
        
        if (lowOutliers > highOutliers * 2) {
            recommendations.push('⚡ Múltiples tiempos bajos detectados - Verificar calidad o pasos omitidos');
        }

        // Recomendaciones por variabilidad
        const coefficientOfVariation = (statistics.standardDeviation / statistics.mean) * 100;
        if (coefficientOfVariation > 20) {
            recommendations.push('📊 Alta variabilidad en proceso - Considerar estandarización');
        }

        // Recomendaciones por severidad
        const extremeOutliers = outlierResults.outliers.filter(o => o.severity === 'extreme').length;
        if (extremeOutliers > 0) {
            recommendations.push(`🚨 ${extremeOutliers} outliers extremos detectados - Investigación urgente requerida`);
        }

        return recommendations;
    }

    /**
     * Detectar tendencia en datos recientes
     * @param {Array<number>} data - Datos para análisis de tendencia  
     * @returns {Object} Información de tendencia
     */
    detectTrend(data) {
        if (data.length < 3) {
            return { direction: 'insufficient_data', confidence: 0 };
        }

        // Regresión lineal simple para detectar tendencia
        const n = data.length;
        const x = Array.from({length: n}, (_, i) => i);
        const y = data;

        const sumX = x.reduce((a, b) => a + b, 0);
        const sumY = y.reduce((a, b) => a + b, 0);
        const sumXY = x.reduce((sum, xi, i) => sum + xi * y[i], 0);
        const sumX2 = x.reduce((sum, xi) => sum + xi * xi, 0);

        const slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
        const correlationCoeff = this.calculateCorrelation(x, y);

        let direction = 'stable';
        if (Math.abs(slope) > 0.5) { // Umbral ajustable
            direction = slope > 0 ? 'increasing' : 'decreasing';
        }

        return {
            direction,
            slope,
            confidence: Math.abs(correlationCoeff),
            strength: Math.abs(correlationCoeff) > 0.7 ? 'strong' : 
                     Math.abs(correlationCoeff) > 0.3 ? 'moderate' : 'weak'
        };
    }

    /**
     * Calcular coeficiente de correlación
     * @param {Array<number>} x - Variables independientes
     * @param {Array<number>} y - Variables dependientes  
     * @returns {number} Coeficiente de correlación
     */
    calculateCorrelation(x, y) {
        try {
            return ss.sampleCorrelation(x, y);
        } catch (error) {
            return 0;
        }
    }

    /**
     * Obtener recomendaciones de calidad
     * @param {number} outlierPercentage - Porcentaje de outliers
     * @returns {Array<string>} Recomendaciones específicas
     */
    getQualityRecommendations(outlierPercentage) {
        const recommendations = [];
        
        if (outlierPercentage > 20) {
            recommendations.push('Considerar recalibración de equipos');
            recommendations.push('Revisar procedimientos operativos');
        } else if (outlierPercentage > 10) {
            recommendations.push('Monitorear de cerca la variabilidad del proceso');
        } else if (outlierPercentage > 5) {
            recommendations.push('Proceso dentro de parámetros normales con variabilidad moderada');
        } else {
            recommendations.push('Proceso estable con excelente control estadístico');
        }

        return recommendations;
    }
}

module.exports = OutlierDetectionService;