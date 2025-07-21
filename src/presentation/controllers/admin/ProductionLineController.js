// =============================================================================
// src/presentation/controllers/admin/ProductionLineController.js
// Controlador para gestión de líneas de producción VSM - VERSIÓN REFACTORIZADA
// =============================================================================

const logger = require('../../../../config/logger');
const { validationResult } = require('express-validator');

/**
 * Controlador para gestión de líneas de producción
 * Implementa Clean Architecture con responsabilidad única
 * 
 * Responsabilidades:
 * - Validar entrada HTTP
 * - Orquestar casos de uso
 * - Formatear respuestas HTTP
 * - Manejo de errores de presentación
 */
class ProductionLineController {
    constructor(dependencies) {
        // Inyección de dependencias estructurada
        this.useCases = {
            create: dependencies.createProductionLineUseCase,
            update: dependencies.updateProductionLineUseCase,
            delete: dependencies.deleteProductionLineUseCase,
            getList: dependencies.getProductionLinesUseCase,
            getDetail: dependencies.getProductionLineDetailUseCase,
            changeStatus: dependencies.changeLineStatusUseCase,
            resetMetrics: dependencies.resetLineMetricsUseCase,
            generateReport: dependencies.generatePerformanceReportUseCase,
            validateCSV: dependencies.validateCSVConfigurationUseCase,
            duplicate: dependencies.duplicateLineUseCase,
            exportConfig: dependencies.exportConfigurationUseCase,
            importConfig: dependencies.importConfigurationUseCase,
            getStats: dependencies.getQuickStatsUseCase,
            getHistory: dependencies.getLineHistoryUseCase
        };

        // Servicios de infraestructura
        this.notificationService = dependencies.notificationService;
        this.errorHandler = dependencies.errorHandler;
        
        // Bind methods para preservar contexto
        this._bindMethods();
    }

    /**
     * Bind de métodos para preservar contexto en rutas
     */
    _bindMethods() {
        this.createLine = this.createLine.bind(this);
        this.updateLine = this.updateLine.bind(this);
        this.deleteLine = this.deleteLine.bind(this);
        this.getLines = this.getLines.bind(this);
        this.getLineDetail = this.getLineDetail.bind(this);
        this.changeLineStatus = this.changeLineStatus.bind(this);
        this.resetLineMetrics = this.resetLineMetrics.bind(this);
        this.generatePerformanceReport = this.generatePerformanceReport.bind(this);
        this.validateCSVConfiguration = this.validateCSVConfiguration.bind(this);
        this.duplicateLine = this.duplicateLine.bind(this);
        this.exportLineConfiguration = this.exportLineConfiguration.bind(this);
        this.importLineConfiguration = this.importLineConfiguration.bind(this);
        this.getQuickStats = this.getQuickStats.bind(this);
        this.getLineHistory = this.getLineHistory.bind(this);
    }

    // =========================================================================
    // OPERACIONES CRUD PRINCIPALES
    // =========================================================================

    /**
     * Crear nueva línea de producción
     * POST /api/admin/production-lines
     */
    async createLine(req, res) {
        try {
            // 1. Validar entrada HTTP
            const validationErrors = validationResult(req);
            if (!validationErrors.isEmpty()) {
                return this._respondValidationError(res, validationErrors.array());
            }

            // 2. Extraer datos y contexto
            const lineData = req.body;
            const userContext = this._extractUserContext(req);

            logger.info('Creando nueva línea de producción:', { 
                name: lineData.name, 
                code: lineData.code,
                user: userContext.username
            });

            // 3. Ejecutar caso de uso
            const result = await this.useCases.create.execute(lineData, userContext);

            // 4. Manejar resultado
            if (result.isSuccess()) {
                // Notificar evento
                await this._notifyLineCreated(result.getData());
                
                return this._respondSuccess(res, {
                    message: 'Línea de producción creada exitosamente',
                    data: result.getData()
                }, 201);
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'createLine');
        }
    }

    /**
     * Actualizar línea de producción existente
     * PUT /api/admin/production-lines/:id
     */
    async updateLine(req, res) {
        try {
            const validationErrors = validationResult(req);
            if (!validationErrors.isEmpty()) {
                return this._respondValidationError(res, validationErrors.array());
            }

            const lineId = req.params.id;
            const updateData = req.body;
            const userContext = this._extractUserContext(req);

            logger.info('Actualizando línea de producción:', { 
                id: lineId, 
                name: updateData.name,
                user: userContext.username
            });

            const result = await this.useCases.update.execute(lineId, updateData, userContext);

            if (result.isSuccess()) {
                await this._notifyLineUpdated(result.getData());
                
                return this._respondSuccess(res, {
                    message: 'Línea de producción actualizada exitosamente',
                    data: result.getData()
                });
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'updateLine');
        }
    }

    /**
     * Eliminar línea de producción
     * DELETE /api/admin/production-lines/:id
     */
    async deleteLine(req, res) {
        try {
            const lineId = req.params.id;
            const userContext = this._extractUserContext(req);

            logger.info('Eliminando línea de producción:', { 
                id: lineId,
                user: userContext.username
            });

            const result = await this.useCases.delete.execute(lineId, userContext);

            if (result.isSuccess()) {
                await this._notifyLineDeleted(lineId);
                
                return this._respondSuccess(res, {
                    message: 'Línea de producción eliminada exitosamente'
                });
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'deleteLine');
        }
    }

    /**
     * Obtener todas las líneas de producción
     * GET /api/admin/production-lines
     */
    async getLines(req, res) {
        try {
            const queryOptions = this._extractQueryOptions(req);

            logger.debug('Obteniendo líneas de producción:', queryOptions);

            const result = await this.useCases.getList.execute(queryOptions);

            if (result.isSuccess()) {
                return this._respondSuccess(res, {
                    data: result.getData(),
                    pagination: result.getPagination()
                });
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'getLines');
        }
    }

    /**
     * Obtener detalle de una línea específica
     * GET /api/admin/production-lines/:id
     */
    async getLineDetail(req, res) {
        try {
            const lineId = req.params.id;
            const options = {
                includeMetrics: req.query.metrics === 'true',
                includeEquipmentStatus: req.query.equipment === 'true',
                includeHistory: req.query.history === 'true'
            };

            logger.debug('Obteniendo detalle de línea:', { id: lineId, options });

            const result = await this.useCases.getDetail.execute(lineId, options);

            if (result.isSuccess()) {
                return this._respondSuccess(res, {
                    data: result.getData()
                });
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'getLineDetail');
        }
    }

    // =========================================================================
    // OPERACIONES AVANZADAS
    // =========================================================================

    /**
     * Cambiar estado de línea
     * PATCH /api/admin/production-lines/:id/status
     */
    async changeLineStatus(req, res) {
        try {
            const lineId = req.params.id;
            const { status, reason } = req.body;
            const userContext = this._extractUserContext(req);

            logger.info('Cambiando estado de línea:', { 
                id: lineId, 
                newStatus: status,
                reason: reason || 'No especificado',
                user: userContext.username
            });

            const result = await this.useCases.changeStatus.execute(
                lineId, 
                status, 
                reason, 
                userContext
            );

            if (result.isSuccess()) {
                await this._notifyStatusChanged(result.getData());
                
                return this._respondSuccess(res, {
                    message: `Estado de línea cambiado a: ${status}`,
                    data: result.getData()
                });
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'changeLineStatus');
        }
    }

    /**
     * Resetear métricas de línea
     * POST /api/admin/production-lines/:id/reset-metrics
     */
    async resetLineMetrics(req, res) {
        try {
            const lineId = req.params.id;
            const { resetType = 'daily', confirmReset } = req.body;
            const userContext = this._extractUserContext(req);

            if (!confirmReset) {
                return this._respondValidationError(res, [{
                    msg: 'Confirmación de reset requerida',
                    param: 'confirmReset',
                    location: 'body'
                }]);
            }

            logger.warn('Reseteando métricas de línea:', { 
                id: lineId, 
                resetType,
                user: userContext.username
            });

            const result = await this.useCases.resetMetrics.execute(
                lineId, 
                resetType, 
                userContext
            );

            if (result.isSuccess()) {
                await this._notifyMetricsReset(result.getData());
                
                return this._respondSuccess(res, {
                    message: `Métricas reseteadas exitosamente (${resetType})`,
                    data: result.getData()
                });
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'resetLineMetrics');
        }
    }

    /**
     * Generar reporte de rendimiento
     * GET /api/admin/production-lines/:id/performance-report
     */
    async generatePerformanceReport(req, res) {
        try {
            const lineId = req.params.id;
            const reportOptions = {
                startDate: req.query.startDate,
                endDate: req.query.endDate,
                includeDetails: req.query.includeDetails === 'true',
                format: req.query.format || 'json'
            };

            logger.info('Generando reporte de rendimiento:', { 
                lineId, 
                options: reportOptions
            });

            const result = await this.useCases.generateReport.execute(lineId, reportOptions);

            if (result.isSuccess()) {
                const reportData = result.getData();
                
                // Configurar headers según formato
                if (reportOptions.format === 'pdf') {
                    res.setHeader('Content-Type', 'application/pdf');
                    res.setHeader('Content-Disposition', 
                        `attachment; filename="performance_report_${lineId}.pdf"`);
                }

                return this._respondSuccess(res, {
                    data: reportData
                });
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'generatePerformanceReport');
        }
    }

    /**
     * Validar configuración CSV
     * POST /api/admin/production-lines/:id/validate-csv
     */
    async validateCSVConfiguration(req, res) {
        try {
            const lineId = req.params.id;

            logger.info('Validando configuración CSV de línea:', { id: lineId });

            const result = await this.useCases.validateCSV.execute(lineId);

            if (result.isSuccess()) {
                return this._respondSuccess(res, {
                    data: result.getData()
                });
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'validateCSVConfiguration');
        }
    }

    /**
     * Duplicar línea de producción
     * POST /api/admin/production-lines/:id/duplicate
     */
    async duplicateLine(req, res) {
        try {
            const lineId = req.params.id;
            const { newName, newCode } = req.body;
            const userContext = this._extractUserContext(req);

            logger.info('Duplicando línea de producción:', { 
                originalId: lineId,
                newName,
                newCode,
                user: userContext.username
            });

            const result = await this.useCases.duplicate.execute(
                lineId, 
                { newName, newCode }, 
                userContext
            );

            if (result.isSuccess()) {
                await this._notifyLineCreated(result.getData());
                
                return this._respondSuccess(res, {
                    message: 'Línea duplicada exitosamente',
                    data: result.getData()
                }, 201);
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'duplicateLine');
        }
    }

    /**
     * Exportar configuración de línea
     * GET /api/admin/production-lines/:id/export
     */
    async exportLineConfiguration(req, res) {
        try {
            const lineId = req.params.id;
            const format = req.query.format || 'json';
            const userContext = this._extractUserContext(req);

            logger.info('Exportando configuración de línea:', { 
                id: lineId, 
                format,
                user: userContext.username
            });

            const result = await this.useCases.exportConfig.execute(
                lineId, 
                format, 
                userContext
            );

            if (result.isSuccess()) {
                const exportData = result.getData();
                
                // Configurar headers de descarga
                res.setHeader('Content-Type', exportData.mimeType);
                res.setHeader('Content-Disposition', exportData.filename);
                
                return res.send(exportData.content);
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'exportLineConfiguration');
        }
    }

    /**
     * Importar configuración de línea
     * POST /api/admin/production-lines/import
     */
    async importLineConfiguration(req, res) {
        try {
            const configData = req.body;
            const options = {
                overwriteExisting: req.query.overwrite === 'true',
                validateOnly: req.query.validate === 'true'
            };
            const userContext = this._extractUserContext(req);

            logger.info('Importando configuración de línea:', { 
                lineName: configData.line?.name,
                options,
                user: userContext.username
            });

            const result = await this.useCases.importConfig.execute(
                configData, 
                options, 
                userContext
            );

            if (result.isSuccess()) {
                const responseData = result.getData();
                
                // Si es solo validación, no crear línea
                if (options.validateOnly) {
                    return this._respondSuccess(res, {
                        message: 'Configuración válida',
                        validation: responseData
                    });
                } else {
                    await this._notifyLineCreated(responseData);
                    
                    return this._respondSuccess(res, {
                        message: 'Configuración importada exitosamente',
                        data: responseData
                    }, 201);
                }
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'importLineConfiguration');
        }
    }

    /**
     * Obtener estadísticas rápidas
     * GET /api/admin/production-lines/stats
     */
    async getQuickStats(req, res) {
        try {
            logger.debug('Obteniendo estadísticas rápidas de líneas');

            const result = await this.useCases.getStats.execute();

            if (result.isSuccess()) {
                return this._respondSuccess(res, {
                    data: result.getData(),
                    timestamp: new Date().toISOString()
                });
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'getQuickStats');
        }
    }

    /**
     * Obtener historial de cambios
     * GET /api/admin/production-lines/:id/history
     */
    async getLineHistory(req, res) {
        try {
            const lineId = req.params.id;
            const paginationOptions = {
                limit: parseInt(req.query.limit) || 50,
                offset: parseInt(req.query.offset) || 0,
                eventType: req.query.eventType,
                startDate: req.query.startDate,
                endDate: req.query.endDate
            };

            logger.debug('Obteniendo historial de línea:', { id: lineId, options: paginationOptions });

            const result = await this.useCases.getHistory.execute(lineId, paginationOptions);

            if (result.isSuccess()) {
                return this._respondSuccess(res, {
                    data: result.getData(),
                    pagination: result.getPagination()
                });
            } else {
                return this._respondBusinessError(res, result);
            }

        } catch (error) {
            return this._handleInternalError(res, error, 'getLineHistory');
        }
    }

    // =========================================================================
    // MÉTODOS AUXILIARES PRIVADOS
    // =========================================================================

    /**
     * Extraer contexto de usuario de la request
     */
    _extractUserContext(req) {
        return {
            userId: req.user?.id,
            username: req.user?.username || 'system',
            role: req.user?.role || 'admin',
            permissions: req.user?.permissions || [],
            ip: req.ip,
            userAgent: req.get('User-Agent')
        };
    }

    /**
     * Extraer opciones de consulta de la request
     */
    _extractQueryOptions(req) {
        return {
            page: parseInt(req.query.page) || 1,
            limit: parseInt(req.query.limit) || 20,
            sortBy: req.query.sortBy || 'createdAt',
            sortOrder: req.query.sortOrder || 'desc',
            search: req.query.search,
            status: req.query.status,
            filters: {
                active: req.query.active ? req.query.active === 'true' : undefined,
                hasIssues: req.query.hasIssues ? req.query.hasIssues === 'true' : undefined
            }
        };
    }

    /**
     * Responder con éxito
     */
    _respondSuccess(res, payload, statusCode = 200) {
        return res.status(statusCode).json({
            success: true,
            ...payload
        });
    }

    /**
     * Responder error de validación
     */
    _respondValidationError(res, errors) {
        return res.status(400).json({
            success: false,
            message: 'Datos de entrada inválidos',
            errors: errors
        });
    }

    /**
     * Responder error de negocio
     */
    _respondBusinessError(res, result) {
        const statusCode = this._mapErrorToStatusCode(result.getError());
        
        return res.status(statusCode).json({
            success: false,
            message: result.getError().message,
            errorCode: result.getError().code,
            details: result.getError().details
        });
    }

    /**
     * Mapear error de dominio a código HTTP
     */
    _mapErrorToStatusCode(error) {
        const errorCodeMap = {
            'NOT_FOUND': 404,
            'VALIDATION_ERROR': 400,
            'BUSINESS_RULE_VIOLATION': 422,
            'UNAUTHORIZED': 401,
            'FORBIDDEN': 403,
            'CONFLICT': 409
        };

        return errorCodeMap[error.code] || 500;
    }

    /**
     * Manejar errores internos
     */
    _handleInternalError(res, error, operation) {
        logger.error(`Error en ${operation}:`, error);
        
        return res.status(500).json({
            success: false,
            message: 'Error interno del servidor',
            errorId: this.errorHandler.logError(error, { operation }),
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }

    // =========================================================================
    // NOTIFICACIONES (Delegadas al servicio)
    // =========================================================================

    async _notifyLineCreated(lineData) {
        try {
            await this.notificationService.broadcast({
                type: 'production_line_created',
                data: lineData,
                timestamp: new Date().toISOString()
            });
        } catch (error) {
            logger.warn('Error enviando notificación de línea creada:', error);
        }
    }

    async _notifyLineUpdated(lineData) {
        try {
            await this.notificationService.broadcast({
                type: 'production_line_updated',
                data: lineData,
                timestamp: new Date().toISOString()
            });
        } catch (error) {
            logger.warn('Error enviando notificación de línea actualizada:', error);
        }
    }

    async _notifyLineDeleted(lineId) {
        try {
            await this.notificationService.broadcast({
                type: 'production_line_deleted',
                lineId: lineId,
                timestamp: new Date().toISOString()
            });
        } catch (error) {
            logger.warn('Error enviando notificación de línea eliminada:', error);
        }
    }

    async _notifyStatusChanged(statusData) {
        try {
            await this.notificationService.broadcast({
                type: 'production_line_status_changed',
                data: statusData,
                timestamp: new Date().toISOString()
            });
        } catch (error) {
            logger.warn('Error enviando notificación de cambio de estado:', error);
        }
    }

    async _notifyMetricsReset(resetData) {
        try {
            await this.notificationService.broadcast({
                type: 'line_metrics_reset',
                data: resetData,
                timestamp: new Date().toISOString()
            });
        } catch (error) {
            logger.warn('Error enviando notificación de reset de métricas:', error);
        }
    }
}

module.exports = ProductionLineController;