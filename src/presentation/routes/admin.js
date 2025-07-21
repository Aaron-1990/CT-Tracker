// =============================================================================
// src/presentation/routes/admin.js
// Rutas de administración para el sistema VSM - VERSIÓN COMPLETA
// =============================================================================

const express = require('express');
const { body, param, query } = require('express-validator');
const router = express.Router();

// Middleware
const authenticationMiddleware = require('../middleware/authenticationMiddleware');
const validationMiddleware = require('../middleware/validationMiddleware');
const rateLimitMiddleware = require('../middleware/rateLimitMiddleware');
const cacheMiddleware = require('../middleware/cacheMiddleware');

// Controllers - Se inyectarán dinámicamente
let productionLineController;
let processController;
let equipmentController;
let configurationController;
let lineBuilderController;
let analyticsController;

// =============================================================================
// INICIALIZACIÓN DE CONTROLADORES CON INYECCIÓN DE DEPENDENCIAS
// =============================================================================

/**
 * Inicializa todos los controladores con sus dependencias
 * Se llama desde server.js durante la inicialización de la aplicación
 */
function initializeControllers(dependencies) {
    const { 
        // Use Cases - Production Lines
        createProductionLineUseCase,
        updateProductionLineUseCase,
        deleteProductionLineUseCase,
        getProductionLinesUseCase,
        getProductionLineDetailUseCase,
        changeLineStatusUseCase,
        resetLineMetricsUseCase,
        generatePerformanceReportUseCase,
        validateCSVConfigurationUseCase,
        duplicateLineUseCase,
        exportConfigurationUseCase,
        importConfigurationUseCase,
        getQuickStatsUseCase,
        getLineHistoryUseCase,
        
        // Use Cases - Processes
        createProcessUseCase,
        updateProcessUseCase,
        deleteProcessUseCase,
        getProcessesUseCase,
        getProcessDetailUseCase,
        reorderProcessesUseCase,
        
        // Use Cases - Equipment
        createEquipmentUseCase,
        updateEquipmentUseCase,
        deleteEquipmentUseCase,
        getEquipmentUseCase,
        testEquipmentConnectionUseCase,
        
        // Services
        notificationService,
        errorHandler,
        validationService
    } = dependencies;

    // Inicializar ProductionLineController
    productionLineController = new (require('../controllers/admin/ProductionLineController'))({
        createProductionLineUseCase,
        updateProductionLineUseCase,
        deleteProductionLineUseCase,
        getProductionLinesUseCase,
        getProductionLineDetailUseCase,
        changeLineStatusUseCase,
        resetLineMetricsUseCase,
        generatePerformanceReportUseCase,
        validateCSVConfigurationUseCase,
        duplicateLineUseCase,
        exportConfigurationUseCase,
        importConfigurationUseCase,
        getQuickStatsUseCase,
        getLineHistoryUseCase,
        notificationService,
        errorHandler
    });

    // Inicializar ProcessController
    processController = new (require('../controllers/admin/ProcessController'))({
        createProcessUseCase,
        updateProcessUseCase,
        deleteProcessUseCase,
        getProcessesUseCase,
        getProcessDetailUseCase,
        reorderProcessesUseCase,
        notificationService,
        errorHandler
    });

    // Inicializar EquipmentController
    equipmentController = new (require('../controllers/admin/EquipmentController'))({
        createEquipmentUseCase,
        updateEquipmentUseCase,
        deleteEquipmentUseCase,
        getEquipmentUseCase,
        testEquipmentConnectionUseCase,
        notificationService,
        errorHandler
    });

    // TODO: Inicializar otros controladores cuando estén implementados
    // configurationController = new ConfigurationController(...);
    // lineBuilderController = new LineBuilderController(...);
    // analyticsController = new AnalyticsController(...);
}

// =============================================================================
// MIDDLEWARE GLOBAL PARA RUTAS ADMIN
// =============================================================================

// Aplicar autenticación a todas las rutas admin
router.use(authenticationMiddleware);

// Rate limiting más estricto para operaciones admin
router.use(rateLimitMiddleware.createAdminLimiter());

// Cache para consultas frecuentes (solo GET)
router.use(cacheMiddleware.createSmartCache({
    ttl: 300, // 5 minutos
    onlyGET: true,
    excludePaths: ['/stats', '/history', '/validate-csv']
}));

// =============================================================================
// VALIDADORES REUTILIZABLES
// =============================================================================

const productionLineValidators = {
    // Validadores para crear/actualizar línea
    create: [
        body('name')
            .notEmpty()
            .withMessage('Nombre es requerido')
            .isLength({ min: 3, max: 100 })
            .withMessage('Nombre debe tener entre 3 y 100 caracteres')
            .trim()
            .escape(),
        body('code')
            .optional()
            .isLength({ max: 20 })
            .withMessage('Código no puede exceder 20 caracteres')
            .matches(/^[A-Z0-9_-]+$/)
            .withMessage('Código solo puede contener letras mayúsculas, números, guiones y guiones bajos')
            .trim(),
        body('description')
            .optional()
            .isLength({ max: 500 })
            .withMessage('Descripción no puede exceder 500 caracteres')
            .trim(),
        body('targetPiecesPerHour')
            .optional()
            .isFloat({ min: 0.1, max: 10000 })
            .withMessage('Objetivo piezas/hora debe estar entre 0.1 y 10,000'),
        body('targetOeePercentage')
            .optional()
            .isFloat({ min: 1, max: 100 })
            .withMessage('OEE objetivo debe estar entre 1% y 100%'),
        body('plannedProductionTimeHours')
            .optional()
            .isFloat({ min: 0.1, max: 24 })
            .withMessage('Tiempo producción planificado debe estar entre 0.1 y 24 horas'),
        body('lineColor')
            .optional()
            .matches(/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/)
            .withMessage('Color debe ser un código hexadecimal válido'),
        body('processes')
            .optional()
            .isArray({ max: 20 })
            .withMessage('Una línea no puede tener más de 20 procesos')
    ],

    // Validadores para procesos dentro de línea
    processes: [
        body('processes.*.name')
            .if(body('processes').exists())
            .notEmpty()
            .withMessage('Nombre del proceso es requerido')
            .isLength({ min: 2, max: 100 })
            .withMessage('Nombre del proceso debe tener entre 2 y 100 caracteres'),
        body('processes.*.sequence')
            .if(body('processes').exists())
            .isInt({ min: 1 })
            .withMessage('Secuencia del proceso debe ser un número entero positivo'),
        body('processes.*.designCycleTimeSeconds')
            .optional()
            .isFloat({ min: 1, max: 7200 })
            .withMessage('Tiempo de ciclo debe estar entre 1 y 7200 segundos'),
        body('processes.*.designProcessTimeSeconds')
            .optional()
            .isFloat({ min: 1, max: 7200 })
            .withMessage('Tiempo de proceso debe estar entre 1 y 7200 segundos'),
        body('processes.*.targetOeePercentage')
            .optional()
            .isFloat({ min: 1, max: 100 })
            .withMessage('OEE objetivo del proceso debe estar entre 1% y 100%'),
        body('processes.*.equipment')
            .optional()
            .isArray({ max: 10 })
            .withMessage('Un proceso no puede tener más de 10 equipos')
    ],

    // Validador para ID de línea
    lineId: [
        param('id')
            .isUUID()
            .withMessage('ID de línea debe ser un UUID válido')
    ],

    // Validadores para consultas
    query: [
        query('page')
            .optional()
            .isInt({ min: 1 })
            .withMessage('Página debe ser un número entero positivo'),
        query('limit')
            .optional()
            .isInt({ min: 1, max: 100 })
            .withMessage('Límite debe estar entre 1 y 100'),
        query('sortBy')
            .optional()
            .isIn(['name', 'code', 'createdAt', 'updatedAt', 'status', 'targetOeePercentage'])
            .withMessage('Campo de ordenamiento inválido'),
        query('sortOrder')
            .optional()
            .isIn(['asc', 'desc'])
            .withMessage('Orden debe ser asc o desc'),
        query('search')
            .optional()
            .isLength({ max: 100 })
            .withMessage('Búsqueda no puede exceder 100 caracteres')
            .trim(),
        query('status')
            .optional()
            .isIn(['draft', 'active', 'inactive', 'maintenance'])
            .withMessage('Estado inválido')
    ]
};

// =============================================================================
// RUTAS DE LÍNEAS DE PRODUCCIÓN
// =============================================================================

/**
 * @route GET /api/admin/production-lines/stats
 * @desc Obtener estadísticas rápidas de líneas
 * @access Admin
 */
router.get('/production-lines/stats',
    cacheMiddleware.shortTerm(60), // Cache 1 minuto
    (req, res) => productionLineController.getQuickStats(req, res)
);

/**
 * @route POST /api/admin/production-lines/validate
 * @desc Validar configuración de línea antes de guardar
 * @access Admin
 */
router.post('/production-lines/validate',
    rateLimitMiddleware.createLimiter(100, 15), // 100 validaciones por 15 min
    [
        ...productionLineValidators.create,
        ...productionLineValidators.processes
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.validateLineConfiguration(req, res)
);

/**
 * @route POST /api/admin/production-lines/import
 * @desc Importar configuración de línea
 * @access Admin
 */
router.post('/production-lines/import',
    rateLimitMiddleware.createLimiter(10, 60), // 10 importaciones por hora
    [
        body('line')
            .exists()
            .withMessage('Datos de línea son requeridos'),
        body('line.name')
            .notEmpty()
            .withMessage('Nombre de línea es requerido'),
        query('overwrite')
            .optional()
            .isBoolean()
            .withMessage('Parámetro overwrite debe ser booleano'),
        query('validate')
            .optional()
            .isBoolean()
            .withMessage('Parámetro validate debe ser booleano')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.importLineConfiguration(req, res)
);

/**
 * @route GET /api/admin/production-lines
 * @desc Obtener todas las líneas de producción
 * @access Admin
 */
router.get('/production-lines',
    productionLineValidators.query,
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.mediumTerm(300), // Cache 5 minutos
    (req, res) => productionLineController.getLines(req, res)
);

/**
 * @route POST /api/admin/production-lines
 * @desc Crear nueva línea de producción
 * @access Admin
 */
router.post('/production-lines',
    rateLimitMiddleware.createLimiter(50, 60), // 50 creaciones por hora
    [
        ...productionLineValidators.create,
        ...productionLineValidators.processes
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.createLine(req, res)
);

/**
 * @route GET /api/admin/production-lines/:id
 * @desc Obtener detalle de una línea específica
 * @access Admin
 */
router.get('/production-lines/:id',
    productionLineValidators.lineId,
    [
        query('metrics')
            .optional()
            .isBoolean()
            .withMessage('Parámetro metrics debe ser booleano'),
        query('equipment')
            .optional()
            .isBoolean()
            .withMessage('Parámetro equipment debe ser booleano'),
        query('history')
            .optional()
            .isBoolean()
            .withMessage('Parámetro history debe ser booleano')
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.shortTerm(120), // Cache 2 minutos
    (req, res) => productionLineController.getLineDetail(req, res)
);

/**
 * @route PUT /api/admin/production-lines/:id
 * @desc Actualizar línea de producción existente
 * @access Admin
 */
router.put('/production-lines/:id',
    productionLineValidators.lineId,
    [
        ...productionLineValidators.create,
        ...productionLineValidators.processes
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.updateLine(req, res)
);

/**
 * @route DELETE /api/admin/production-lines/:id
 * @desc Eliminar línea de producción
 * @access Admin
 */
router.delete('/production-lines/:id',
    rateLimitMiddleware.createLimiter(20, 60), // 20 eliminaciones por hora
    productionLineValidators.lineId,
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.deleteLine(req, res)
);

/**
 * @route POST /api/admin/production-lines/:id/duplicate
 * @desc Duplicar línea de producción existente
 * @access Admin
 */
router.post('/production-lines/:id/duplicate',
    productionLineValidators.lineId,
    [
        body('newName')
            .optional()
            .isLength({ min: 3, max: 100 })
            .withMessage('Nuevo nombre debe tener entre 3 y 100 caracteres'),
        body('newCode')
            .optional()
            .isLength({ max: 20 })
            .withMessage('Nuevo código no puede exceder 20 caracteres')
            .matches(/^[A-Z0-9_-]+$/)
            .withMessage('Código solo puede contener letras mayúsculas, números, guiones y guiones bajos')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.duplicateLine(req, res)
);

/**
 * @route PATCH /api/admin/production-lines/:id/status
 * @desc Cambiar estado de una línea de producción
 * @access Admin
 */
router.patch('/production-lines/:id/status',
    productionLineValidators.lineId,
    [
        body('status')
            .isIn(['draft', 'active', 'inactive', 'maintenance'])
            .withMessage('Estado debe ser: draft, active, inactive o maintenance'),
        body('reason')
            .optional()
            .isLength({ max: 200 })
            .withMessage('Razón no puede exceder 200 caracteres')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.changeLineStatus(req, res)
);

/**
 * @route POST /api/admin/production-lines/:id/reset-metrics
 * @desc Resetear métricas de una línea
 * @access Admin
 */
router.post('/production-lines/:id/reset-metrics',
    rateLimitMiddleware.createLimiter(10, 60), // 10 resets por hora
    productionLineValidators.lineId,
    [
        body('resetType')
            .optional()
            .isIn(['daily', 'weekly', 'monthly', 'all'])
            .withMessage('Tipo de reset debe ser: daily, weekly, monthly o all'),
        body('confirmReset')
            .isBoolean()
            .withMessage('Confirmación de reset es requerida')
            .equals('true')
            .withMessage('Debe confirmar el reset enviando confirmReset: true')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.resetLineMetrics(req, res)
);

/**
 * @route GET /api/admin/production-lines/:id/performance-report
 * @desc Generar reporte de rendimiento de línea
 * @access Admin
 */
router.get('/production-lines/:id/performance-report',
    productionLineValidators.lineId,
    [
        query('startDate')
            .optional()
            .isISO8601()
            .withMessage('Fecha inicio debe ser formato ISO8601'),
        query('endDate')
            .optional()
            .isISO8601()
            .withMessage('Fecha fin debe ser formato ISO8601'),
        query('includeDetails')
            .optional()
            .isBoolean()
            .withMessage('Parámetro includeDetails debe ser booleano'),
        query('format')
            .optional()
            .isIn(['json', 'pdf', 'csv', 'excel'])
            .withMessage('Formato debe ser: json, pdf, csv o excel')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.generatePerformanceReport(req, res)
);

/**
 * @route POST /api/admin/production-lines/:id/validate-csv
 * @desc Validar configuración CSV de equipos de una línea
 * @access Admin
 */
router.post('/production-lines/:id/validate-csv',
    productionLineValidators.lineId,
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.validateCSVConfiguration(req, res)
);

/**
 * @route GET /api/admin/production-lines/:id/export
 * @desc Exportar configuración de línea
 * @access Admin
 */
router.get('/production-lines/:id/export',
    productionLineValidators.lineId,
    [
        query('format')
            .optional()
            .isIn(['json', 'csv', 'xml', 'yaml'])
            .withMessage('Formato debe ser: json, csv, xml o yaml')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.exportLineConfiguration(req, res)
);

/**
 * @route GET /api/admin/production-lines/:id/history
 * @desc Obtener historial de cambios de una línea
 * @access Admin
 */
router.get('/production-lines/:id/history',
    productionLineValidators.lineId,
    [
        query('limit')
            .optional()
            .isInt({ min: 1, max: 200 })
            .withMessage('Límite debe estar entre 1 y 200'),
        query('offset')
            .optional()
            .isInt({ min: 0 })
            .withMessage('Offset debe ser un número no negativo'),
        query('eventType')
            .optional()
            .isIn(['creation', 'update', 'status_change', 'deletion', 'configuration_change'])
            .withMessage('Tipo de evento inválido'),
        query('startDate')
            .optional()
            .isISO8601()
            .withMessage('Fecha inicio debe ser formato ISO8601'),
        query('endDate')
            .optional()
            .isISO8601()
            .withMessage('Fecha fin debe ser formato ISO8601')
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.shortTerm(180), // Cache 3 minutos
    (req, res) => productionLineController.getLineHistory(req, res)
);

// =============================================================================
// RUTAS DE PROCESOS
// =============================================================================

/**
 * @route GET /api/admin/processes
 * @desc Obtener todos los procesos (con filtros opcionales)
 * @access Admin
 */
router.get('/processes',
    [
        query('lineId')
            .optional()
            .isUUID()
            .withMessage('ID de línea debe ser un UUID válido'),
        query('active')
            .optional()
            .isBoolean()
            .withMessage('Parámetro active debe ser booleano'),
        ...productionLineValidators.query
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.mediumTerm(300),
    (req, res) => processController.getProcesses(req, res)
);

/**
 * @route POST /api/admin/processes
 * @desc Crear nuevo proceso
 * @access Admin
 */
router.post('/processes',
    [
        body('lineId')
            .isUUID()
            .withMessage('ID de línea es requerido y debe ser UUID válido'),
        body('name')
            .notEmpty()
            .withMessage('Nombre del proceso es requerido')
            .isLength({ min: 2, max: 100 })
            .withMessage('Nombre debe tener entre 2 y 100 caracteres'),
        body('sequence')
            .isInt({ min: 1 })
            .withMessage('Secuencia debe ser un número entero positivo'),
        body('designCycleTimeSeconds')
            .optional()
            .isFloat({ min: 1, max: 7200 })
            .withMessage('Tiempo de ciclo debe estar entre 1 y 7200 segundos')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => processController.createProcess(req, res)
);

/**
 * @route PUT /api/admin/processes/:id
 * @desc Actualizar proceso existente
 * @access Admin
 */
router.put('/processes/:id',
    [
        param('id')
            .isUUID()
            .withMessage('ID de proceso debe ser un UUID válido'),
        body('name')
            .optional()
            .isLength({ min: 2, max: 100 })
            .withMessage('Nombre debe tener entre 2 y 100 caracteres'),
        body('designCycleTimeSeconds')
            .optional()
            .isFloat({ min: 1, max: 7200 })
            .withMessage('Tiempo de ciclo debe estar entre 1 y 7200 segundos')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => processController.updateProcess(req, res)
);

/**
 * @route DELETE /api/admin/processes/:id
 * @desc Eliminar proceso
 * @access Admin
 */
router.delete('/processes/:id',
    [
        param('id')
            .isUUID()
            .withMessage('ID de proceso debe ser un UUID válido')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => processController.deleteProcess(req, res)
);

/**
 * @route POST /api/admin/processes/reorder
 * @desc Reordenar secuencia de procesos en una línea
 * @access Admin
 */
router.post('/processes/reorder',
    [
        body('lineId')
            .isUUID()
            .withMessage('ID de línea es requerido y debe ser UUID válido'),
        body('processSequences')
            .isArray({ min: 1 })
            .withMessage('Secuencias de procesos son requeridas'),
        body('processSequences.*.processId')
            .isUUID()
            .withMessage('ID de proceso debe ser UUID válido'),
        body('processSequences.*.newSequence')
            .isInt({ min: 1 })
            .withMessage('Nueva secuencia debe ser número entero positivo')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => processController.reorderProcesses(req, res)
);

// =============================================================================
// RUTAS DE EQUIPOS
// =============================================================================

/**
 * @route GET /api/admin/equipment
 * @desc Obtener todos los equipos
 * @access Admin
 */
router.get('/equipment',
    [
        query('processId')
            .optional()
            .isUUID()
            .withMessage('ID de proceso debe ser un UUID válido'),
        query('active')
            .optional()
            .isBoolean()
            .withMessage('Parámetro active debe ser booleano'),
        query('hasConnection')
            .optional()
            .isBoolean()
            .withMessage('Parámetro hasConnection debe ser booleano'),
        ...productionLineValidators.query
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.shortTerm(120),
    (req, res) => equipmentController.getEquipment(req, res)
);

/**
 * @route POST /api/admin/equipment
 * @desc Crear nuevo equipo
 * @access Admin
 */
router.post('/equipment',
    [
        body('processId')
            .isUUID()
            .withMessage('ID de proceso es requerido y debe ser UUID válido'),
        body('name')
            .notEmpty()
            .withMessage('Nombre del equipo es requerido')
            .isLength({ min: 2, max: 100 })
            .withMessage('Nombre debe tener entre 2 y 100 caracteres'),
        body('code')
            .notEmpty()
            .withMessage('Código del equipo es requerido')
            .isLength({ max: 20 })
            .withMessage('Código no puede exceder 20 caracteres'),
        body('csvUrl')
            .optional()
            .isURL()
            .withMessage('URL CSV debe ser una URL válida'),
        body('type')
            .optional()
            .isIn(['serial', 'parallel'])
            .withMessage('Tipo debe ser serial o parallel')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => equipmentController.createEquipment(req, res)
);

/**
 * @route PUT /api/admin/equipment/:id
 * @desc Actualizar equipo existente
 * @access Admin
 */
router.put('/equipment/:id',
    [
        param('id')
            .isUUID()
            .withMessage('ID de equipo debe ser un UUID válido'),
        body('name')
            .optional()
            .isLength({ min: 2, max: 100 })
            .withMessage('Nombre debe tener entre 2 y 100 caracteres'),
        body('csvUrl')
            .optional()
            .isURL()
            .withMessage('URL CSV debe ser una URL válida')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => equipmentController.updateEquipment(req, res)
);

/**
 * @route DELETE /api/admin/equipment/:id
 * @desc Eliminar equipo
 * @access Admin
 */
router.delete('/equipment/:id',
    [
        param('id')
            .isUUID()
            .withMessage('ID de equipo debe ser un UUID válido')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => equipmentController.deleteEquipment(req, res)
);

/**
 * @route POST /api/admin/equipment/:id/test-connection
 * @desc Probar conexión de un equipo
 * @access Admin
 */
router.post('/equipment/:id/test-connection',
    rateLimitMiddleware.createLimiter(30, 5), // 30 tests por 5 minutos
    [
        param('id')
            .isUUID()
            .withMessage('ID de equipo debe ser un UUID válido')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => equipmentController.testEquipmentConnection(req, res)
);

// =============================================================================
// RUTAS DE CONFIGURACIÓN Y UTILIDADES
// =============================================================================

/**
 * @route GET /api/admin/system/health
 * @desc Verificar estado del sistema
 * @access Admin
 */
router.get('/system/health',
    cacheMiddleware.shortTerm(30),
    (req, res) => {
        // TODO: Implementar HealthController
        res.json({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            version: process.env.npm_package_version || '1.0.0',
            environment: process.env.NODE_ENV,
            uptime: process.uptime()
        });
    }
);

/**
 * @route POST /api/admin/system/maintenance
 * @desc Activar/desactivar modo mantenimiento
 * @access Admin
 */
router.post('/system/maintenance',
    rateLimitMiddleware.createLimiter(5, 60), // 5 cambios por hora
    [
        body('enabled')
            .isBoolean()
            .withMessage('Estado de mantenimiento debe ser booleano'),
        body('reason')
            .optional()
            .isLength({ max: 200 })
            .withMessage('Razón no puede exceder 200 caracteres')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar MaintenanceController
        res.json({
            success: true,
            message: 'Modo mantenimiento actualizado',
            maintenanceMode: req.body.enabled,
            reason: req.body.reason || 'No especificada'
        });
    }
);

// =============================================================================
// RUTAS DE ANÁLISIS Y REPORTES
// =============================================================================

/**
 * @route GET /api/admin/analytics/overview
 * @desc Obtener vista general de analíticas del sistema
 * @access Admin
 */
router.get('/analytics/overview',
    [
        query('period')
            .optional()
            .isIn(['today', 'week', 'month', 'quarter', 'year'])
            .withMessage('Período debe ser: today, week, month, quarter o year'),
        query('includeComparisons')
            .optional()
            .isBoolean()
            .withMessage('Parámetro includeComparisons debe ser booleano')
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.mediumTerm(600), // Cache 10 minutos
    (req, res) => {
        // TODO: Implementar analyticsController.getOverview
        res.json({
            message: 'Analytics overview - Pendiente implementación',
            timestamp: new Date().toISOString()
        });
    }
);

/**
 * @route GET /api/admin/analytics/bottlenecks
 * @desc Identificar cuellos de botella en las líneas
 * @access Admin
 */
router.get('/analytics/bottlenecks',
    [
        query('lineId')
            .optional()
            .isUUID()
            .withMessage('ID de línea debe ser UUID válido'),
        query('threshold')
            .optional()
            .isFloat({ min: 0.1, max: 50 })
            .withMessage('Umbral debe estar entre 0.1 y 50'),
        query('period')
            .optional()
            .isIn(['hour', 'day', 'week', 'month'])
            .withMessage('Período debe ser: hour, day, week o month')
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.mediumTerm(300),
    (req, res) => {
        // TODO: Implementar analyticsController.getBottlenecks
        res.json({
            message: 'Bottleneck analysis - Pendiente implementación',
            timestamp: new Date().toISOString()
        });
    }
);

/**
 * @route GET /api/admin/analytics/trends
 * @desc Análisis de tendencias de rendimiento
 * @access Admin
 */
router.get('/analytics/trends',
    [
        query('metric')
            .optional()
            .isIn(['efficiency', 'oee', 'cycleTime', 'throughput', 'quality'])
            .withMessage('Métrica debe ser: efficiency, oee, cycleTime, throughput o quality'),
        query('timeframe')
            .optional()
            .isIn(['24h', '7d', '30d', '90d', '1y'])
            .withMessage('Marco temporal debe ser: 24h, 7d, 30d, 90d o 1y'),
        query('granularity')
            .optional()
            .isIn(['hour', 'day', 'week', 'month'])
            .withMessage('Granularidad debe ser: hour, day, week o month')
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.longTerm(900), // Cache 15 minutos
    (req, res) => {
        // TODO: Implementar analyticsController.getTrends
        res.json({
            message: 'Trend analysis - Pendiente implementación',
            timestamp: new Date().toISOString()
        });
    }
);

/**
 * @route POST /api/admin/analytics/custom-report
 * @desc Generar reporte personalizado
 * @access Admin
 */
router.post('/analytics/custom-report',
    rateLimitMiddleware.createLimiter(20, 60), // 20 reportes por hora
    [
        body('reportType')
            .isIn(['performance', 'efficiency', 'outliers', 'comparison', 'detailed'])
            .withMessage('Tipo reporte debe ser: performance, efficiency, outliers, comparison o detailed'),
        body('dateRange')
            .exists()
            .withMessage('Rango de fechas es requerido'),
        body('dateRange.start')
            .isISO8601()
            .withMessage('Fecha inicio debe ser formato ISO8601'),
        body('dateRange.end')
            .isISO8601()
            .withMessage('Fecha fin debe ser formato ISO8601'),
        body('lineIds')
            .optional()
            .isArray()
            .withMessage('IDs de líneas debe ser un arreglo'),
        body('lineIds.*')
            .if(body('lineIds').exists())
            .isUUID()
            .withMessage('Cada ID de línea debe ser UUID válido'),
        body('format')
            .optional()
            .isIn(['json', 'pdf', 'excel', 'csv'])
            .withMessage('Formato debe ser: json, pdf, excel o csv'),
        body('includeCharts')
            .optional()
            .isBoolean()
            .withMessage('Parámetro includeCharts debe ser booleano')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar analyticsController.generateCustomReport
        res.json({
            message: 'Custom report generation - Pendiente implementación',
            timestamp: new Date().toISOString()
        });
    }
);

// =============================================================================
// RUTAS DE CONFIGURACIÓN AVANZADA
// =============================================================================

/**
 * @route GET /api/admin/config/outlier-settings
 * @desc Obtener configuración de detección de outliers
 * @access Admin
 */
router.get('/config/outlier-settings',
    cacheMiddleware.longTerm(1800), // Cache 30 minutos
    (req, res) => {
        // TODO: Implementar configurationController.getOutlierSettings
        res.json({
            stdMultiplier: parseFloat(process.env.OUTLIER_STD_MULTIPLIER) || 2.0,
            extremeMultiplier: parseFloat(process.env.OUTLIER_EXTREME_MULTIPLIER) || 3.0,
            minSamples: parseInt(process.env.OUTLIER_MIN_SAMPLES) || 5,
            maxPercentage: parseFloat(process.env.OUTLIER_MAX_PERCENTAGE) || 25,
            iqrMultiplier: parseFloat(process.env.OUTLIER_IQR_MULTIPLIER) || 1.5,
            useCombinedMethod: process.env.OUTLIER_USE_COMBINED_METHOD === 'true'
        });
    }
);

/**
 * @route PUT /api/admin/config/outlier-settings
 * @desc Actualizar configuración de detección de outliers
 * @access Admin
 */
router.put('/config/outlier-settings',
    rateLimitMiddleware.createLimiter(10, 60), // 10 cambios por hora
    [
        body('stdMultiplier')
            .optional()
            .isFloat({ min: 1.0, max: 5.0 })
            .withMessage('Multiplicador sigma debe estar entre 1.0 y 5.0'),
        body('extremeMultiplier')
            .optional()
            .isFloat({ min: 2.0, max: 10.0 })
            .withMessage('Multiplicador extremo debe estar entre 2.0 y 10.0'),
        body('minSamples')
            .optional()
            .isInt({ min: 3, max: 50 })
            .withMessage('Mínimo muestras debe estar entre 3 y 50'),
        body('maxPercentage')
            .optional()
            .isFloat({ min: 5, max: 50 })
            .withMessage('Máximo porcentaje debe estar entre 5 y 50'),
        body('iqrMultiplier')
            .optional()
            .isFloat({ min: 1.0, max: 3.0 })
            .withMessage('Multiplicador IQR debe estar entre 1.0 y 3.0'),
        body('useCombinedMethod')
            .optional()
            .isBoolean()
            .withMessage('Usar método combinado debe ser booleano')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar configurationController.updateOutlierSettings
        res.json({
            success: true,
            message: 'Configuración de outliers actualizada',
            timestamp: new Date().toISOString()
        });
    }
);

/**
 * @route GET /api/admin/config/polling-settings
 * @desc Obtener configuración de polling CSV
 * @access Admin
 */
router.get('/config/polling-settings',
    cacheMiddleware.longTerm(1800),
    (req, res) => {
        res.json({
            enabled: process.env.CSV_POLLING_ENABLED === 'true',
            interval: parseInt(process.env.CSV_POLLING_INTERVAL) || 30,
            timeout: parseInt(process.env.CSV_TIMEOUT) || 10000,
            maxRetries: parseInt(process.env.CSV_MAX_RETRIES) || 3,
            retryDelay: parseInt(process.env.CSV_RETRY_DELAY) || 2000,
            maxFileSize: parseInt(process.env.CSV_MAX_FILE_SIZE) || 10485760,
            validateHeaders: process.env.CSV_VALIDATE_HEADERS === 'true'
        });
    }
);

/**
 * @route PUT /api/admin/config/polling-settings
 * @desc Actualizar configuración de polling CSV
 * @access Admin
 */
router.put('/config/polling-settings',
    rateLimitMiddleware.createLimiter(5, 60), // 5 cambios por hora
    [
        body('enabled')
            .optional()
            .isBoolean()
            .withMessage('Habilitado debe ser booleano'),
        body('interval')
            .optional()
            .isInt({ min: 5, max: 300 })
            .withMessage('Intervalo debe estar entre 5 y 300 segundos'),
        body('timeout')
            .optional()
            .isInt({ min: 1000, max: 60000 })
            .withMessage('Timeout debe estar entre 1000 y 60000ms'),
        body('maxRetries')
            .optional()
            .isInt({ min: 0, max: 10 })
            .withMessage('Máximo reintentos debe estar entre 0 y 10'),
        body('retryDelay')
            .optional()
            .isInt({ min: 500, max: 10000 })
            .withMessage('Retraso reintento debe estar entre 500 y 10000ms')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar configurationController.updatePollingSettings
        res.json({
            success: true,
            message: 'Configuración de polling actualizada',
            timestamp: new Date().toISOString()
        });
    }
);

// =============================================================================
// RUTAS DE UTILIDADES Y HERRAMIENTAS
// =============================================================================

/**
 * @route POST /api/admin/tools/validate-csv-url
 * @desc Validar URL CSV antes de asignar a equipo
 * @access Admin
 */
router.post('/tools/validate-csv-url',
    rateLimitMiddleware.createLimiter(50, 60), // 50 validaciones por hora
    [
        body('url')
            .isURL()
            .withMessage('URL debe ser válida'),
        body('expectedHeaders')
            .optional()
            .isArray()
            .withMessage('Headers esperados debe ser un arreglo')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar toolsController.validateCSVUrl
        res.json({
            message: 'CSV URL validation - Pendiente implementación',
            url: req.body.url,
            timestamp: new Date().toISOString()
        });
    }
);

/**
 * @route GET /api/admin/tools/csv-preview/:equipmentId
 * @desc Obtener preview de datos CSV de un equipo
 * @access Admin
 */
router.get('/tools/csv-preview/:equipmentId',
    [
        param('equipmentId')
            .isUUID()
            .withMessage('ID de equipo debe ser UUID válido'),
        query('rows')
            .optional()
            .isInt({ min: 5, max: 100 })
            .withMessage('Número de filas debe estar entre 5 y 100')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar toolsController.getCSVPreview
        res.json({
            message: 'CSV preview - Pendiente implementación',
            equipmentId: req.params.equipmentId,
            timestamp: new Date().toISOString()
        });
    }
);

/**
 * @route POST /api/admin/tools/backup-configuration
 * @desc Crear backup de configuración completa
 * @access Admin
 */
router.post('/tools/backup-configuration',
    rateLimitMiddleware.createLimiter(5, 60), // 5 backups por hora
    [
        body('includeMetrics')
            .optional()
            .isBoolean()
            .withMessage('Incluir métricas debe ser booleano'),
        body('includeHistory')
            .optional()
            .isBoolean()
            .withMessage('Incluir historial debe ser booleano'),
        body('format')
            .optional()
            .isIn(['json', 'sql', 'zip'])
            .withMessage('Formato debe ser: json, sql o zip')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar backupController.createBackup
        res.json({
            message: 'Backup creation - Pendiente implementación',
            timestamp: new Date().toISOString()
        });
    }
);

/**
 * @route POST /api/admin/tools/restore-configuration
 * @desc Restaurar configuración desde backup
 * @access Admin
 */
router.post('/tools/restore-configuration',
    rateLimitMiddleware.createLimiter(2, 60), // 2 restauraciones por hora
    [
        body('backupData')
            .exists()
            .withMessage('Datos de backup son requeridos'),
        body('overwriteExisting')
            .optional()
            .isBoolean()
            .withMessage('Sobreescribir existente debe ser booleano'),
        body('validateBeforeRestore')
            .optional()
            .isBoolean()
            .withMessage('Validar antes de restaurar debe ser booleano')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar backupController.restoreBackup
        res.json({
            message: 'Backup restoration - Pendiente implementación',
            timestamp: new Date().toISOString()
        });
    }
);

// =============================================================================
// MANEJO DE ERRORES Y MIDDLEWARE FINAL
// =============================================================================

/**
 * Middleware para manejar rutas no encontradas en admin
 */
router.use('*', (req, res) => {
    res.status(404).json({
        success: false,
        message: 'Ruta de administración no encontrada',
        path: req.originalUrl,
        method: req.method,
        availableEndpoints: [
            '/production-lines',
            '/processes',
            '/equipment',
            '/analytics',
            '/config',
            '/tools',
            '/system'
        ],
        timestamp: new Date().toISOString()
    });
});

/**
 * Middleware de manejo de errores específico para admin
 */
router.use((err, req, res, next) => {
    // Log del error
    console.error('Error en rutas admin:', {
        error: err.message,
        stack: err.stack,
        url: req.originalUrl,
        method: req.method,
        body: req.body,
        params: req.params,
        query: req.query,
        user: req.user?.username || 'unknown'
    });

    // Determinar código de estado
    const statusCode = err.statusCode || err.status || 500;
    
    // Respuesta de error estructurada
    const errorResponse = {
        success: false,
        message: err.message || 'Error interno en administración',
        errorCode: err.code || 'ADMIN_ERROR',
        timestamp: new Date().toISOString()
    };

    // En desarrollo, incluir stack trace
    if (process.env.NODE_ENV === 'development') {
        errorResponse.stack = err.stack;
        errorResponse.details = {
            url: req.originalUrl,
            method: req.method,
            body: req.body,
            params: req.params,
            query: req.query
        };
    }

    res.status(statusCode).json(errorResponse);
});

// =============================================================================
// EXPORTACIONES
// =============================================================================

module.exports = {
    router,
    initializeControllers
};
// src/presentation/routes/admin.js
// Rutas de administración para el sistema VSM - VERSIÓN COMPLETA
// =============================================================================

const express = require('express');
const { body, param, query } = require('express-validator');
const router = express.Router();

// Middleware
const authenticationMiddleware = require('../middleware/authenticationMiddleware');
const validationMiddleware = require('../middleware/validationMiddleware');
const rateLimitMiddleware = require('../middleware/rateLimitMiddleware');
const cacheMiddleware = require('../middleware/cacheMiddleware');

// Controllers - Se inyectarán dinámicamente
let productionLineController;
let processController;
let equipmentController;
let configurationController;
let lineBuilderController;
let analyticsController;

// =============================================================================
// INICIALIZACIÓN DE CONTROLADORES CON INYECCIÓN DE DEPENDENCIAS
// =============================================================================

/**
 * Inicializa todos los controladores con sus dependencias
 * Se llama desde server.js durante la inicialización de la aplicación
 */
function initializeControllers(dependencies) {
    const { 
        // Use Cases - Production Lines
        createProductionLineUseCase,
        updateProductionLineUseCase,
        deleteProductionLineUseCase,
        getProductionLinesUseCase,
        getProductionLineDetailUseCase,
        changeLineStatusUseCase,
        resetLineMetricsUseCase,
        generatePerformanceReportUseCase,
        validateCSVConfigurationUseCase,
        duplicateLineUseCase,
        exportConfigurationUseCase,
        importConfigurationUseCase,
        getQuickStatsUseCase,
        getLineHistoryUseCase,
        
        // Use Cases - Processes
        createProcessUseCase,
        updateProcessUseCase,
        deleteProcessUseCase,
        getProcessesUseCase,
        getProcessDetailUseCase,
        reorderProcessesUseCase,
        
        // Use Cases - Equipment
        createEquipmentUseCase,
        updateEquipmentUseCase,
        deleteEquipmentUseCase,
        getEquipmentUseCase,
        testEquipmentConnectionUseCase,
        
        // Services
        notificationService,
        errorHandler,
        validationService
    } = dependencies;

    // Inicializar ProductionLineController
    productionLineController = new (require('../controllers/admin/ProductionLineController'))({
        createProductionLineUseCase,
        updateProductionLineUseCase,
        deleteProductionLineUseCase,
        getProductionLinesUseCase,
        getProductionLineDetailUseCase,
        changeLineStatusUseCase,
        resetLineMetricsUseCase,
        generatePerformanceReportUseCase,
        validateCSVConfigurationUseCase,
        duplicateLineUseCase,
        exportConfigurationUseCase,
        importConfigurationUseCase,
        getQuickStatsUseCase,
        getLineHistoryUseCase,
        notificationService,
        errorHandler
    });

    // Inicializar ProcessController
    processController = new (require('../controllers/admin/ProcessController'))({
        createProcessUseCase,
        updateProcessUseCase,
        deleteProcessUseCase,
        getProcessesUseCase,
        getProcessDetailUseCase,
        reorderProcessesUseCase,
        notificationService,
        errorHandler
    });

    // Inicializar EquipmentController
    equipmentController = new (require('../controllers/admin/EquipmentController'))({
        createEquipmentUseCase,
        updateEquipmentUseCase,
        deleteEquipmentUseCase,
        getEquipmentUseCase,
        testEquipmentConnectionUseCase,
        notificationService,
        errorHandler
    });

    // TODO: Inicializar otros controladores cuando estén implementados
    // configurationController = new ConfigurationController(...);
    // lineBuilderController = new LineBuilderController(...);
    // analyticsController = new AnalyticsController(...);
}

// =============================================================================
// MIDDLEWARE GLOBAL PARA RUTAS ADMIN
// =============================================================================

// Aplicar autenticación a todas las rutas admin
router.use(authenticationMiddleware);

// Rate limiting más estricto para operaciones admin
router.use(rateLimitMiddleware.createAdminLimiter());

// Cache para consultas frecuentes (solo GET)
router.use(cacheMiddleware.createSmartCache({
    ttl: 300, // 5 minutos
    onlyGET: true,
    excludePaths: ['/stats', '/history', '/validate-csv']
}));

// =============================================================================
// VALIDADORES REUTILIZABLES
// =============================================================================

const productionLineValidators = {
    // Validadores para crear/actualizar línea
    create: [
        body('name')
            .notEmpty()
            .withMessage('Nombre es requerido')
            .isLength({ min: 3, max: 100 })
            .withMessage('Nombre debe tener entre 3 y 100 caracteres')
            .trim()
            .escape(),
        body('code')
            .optional()
            .isLength({ max: 20 })
            .withMessage('Código no puede exceder 20 caracteres')
            .matches(/^[A-Z0-9_-]+$/)
            .withMessage('Código solo puede contener letras mayúsculas, números, guiones y guiones bajos')
            .trim(),
        body('description')
            .optional()
            .isLength({ max: 500 })
            .withMessage('Descripción no puede exceder 500 caracteres')
            .trim(),
        body('targetPiecesPerHour')
            .optional()
            .isFloat({ min: 0.1, max: 10000 })
            .withMessage('Objetivo piezas/hora debe estar entre 0.1 y 10,000'),
        body('targetOeePercentage')
            .optional()
            .isFloat({ min: 1, max: 100 })
            .withMessage('OEE objetivo debe estar entre 1% y 100%'),
        body('plannedProductionTimeHours')
            .optional()
            .isFloat({ min: 0.1, max: 24 })
            .withMessage('Tiempo producción planificado debe estar entre 0.1 y 24 horas'),
        body('lineColor')
            .optional()
            .matches(/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/)
            .withMessage('Color debe ser un código hexadecimal válido'),
        body('processes')
            .optional()
            .isArray({ max: 20 })
            .withMessage('Una línea no puede tener más de 20 procesos')
    ],

    // Validadores para procesos dentro de línea
    processes: [
        body('processes.*.name')
            .if(body('processes').exists())
            .notEmpty()
            .withMessage('Nombre del proceso es requerido')
            .isLength({ min: 2, max: 100 })
            .withMessage('Nombre del proceso debe tener entre 2 y 100 caracteres'),
        body('processes.*.sequence')
            .if(body('processes').exists())
            .isInt({ min: 1 })
            .withMessage('Secuencia del proceso debe ser un número entero positivo'),
        body('processes.*.designCycleTimeSeconds')
            .optional()
            .isFloat({ min: 1, max: 7200 })
            .withMessage('Tiempo de ciclo debe estar entre 1 y 7200 segundos'),
        body('processes.*.designProcessTimeSeconds')
            .optional()
            .isFloat({ min: 1, max: 7200 })
            .withMessage('Tiempo de proceso debe estar entre 1 y 7200 segundos'),
        body('processes.*.targetOeePercentage')
            .optional()
            .isFloat({ min: 1, max: 100 })
            .withMessage('OEE objetivo del proceso debe estar entre 1% y 100%'),
        body('processes.*.equipment')
            .optional()
            .isArray({ max: 10 })
            .withMessage('Un proceso no puede tener más de 10 equipos')
    ],

    // Validador para ID de línea
    lineId: [
        param('id')
            .isUUID()
            .withMessage('ID de línea debe ser un UUID válido')
    ],

    // Validadores para consultas
    query: [
        query('page')
            .optional()
            .isInt({ min: 1 })
            .withMessage('Página debe ser un número entero positivo'),
        query('limit')
            .optional()
            .isInt({ min: 1, max: 100 })
            .withMessage('Límite debe estar entre 1 y 100'),
        query('sortBy')
            .optional()
            .isIn(['name', 'code', 'createdAt', 'updatedAt', 'status', 'targetOeePercentage'])
            .withMessage('Campo de ordenamiento inválido'),
        query('sortOrder')
            .optional()
            .isIn(['asc', 'desc'])
            .withMessage('Orden debe ser asc o desc'),
        query('search')
            .optional()
            .isLength({ max: 100 })
            .withMessage('Búsqueda no puede exceder 100 caracteres')
            .trim(),
        query('status')
            .optional()
            .isIn(['draft', 'active', 'inactive', 'maintenance'])
            .withMessage('Estado inválido')
    ]
};

// =============================================================================
// RUTAS DE LÍNEAS DE PRODUCCIÓN
// =============================================================================

/**
 * @route GET /api/admin/production-lines/stats
 * @desc Obtener estadísticas rápidas de líneas
 * @access Admin
 */
router.get('/production-lines/stats',
    cacheMiddleware.shortTerm(60), // Cache 1 minuto
    (req, res) => productionLineController.getQuickStats(req, res)
);

/**
 * @route POST /api/admin/production-lines/validate
 * @desc Validar configuración de línea antes de guardar
 * @access Admin
 */
router.post('/production-lines/validate',
    rateLimitMiddleware.createLimiter(100, 15), // 100 validaciones por 15 min
    [
        ...productionLineValidators.create,
        ...productionLineValidators.processes
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.validateLineConfiguration(req, res)
);

/**
 * @route POST /api/admin/production-lines/import
 * @desc Importar configuración de línea
 * @access Admin
 */
router.post('/production-lines/import',
    rateLimitMiddleware.createLimiter(10, 60), // 10 importaciones por hora
    [
        body('line')
            .exists()
            .withMessage('Datos de línea son requeridos'),
        body('line.name')
            .notEmpty()
            .withMessage('Nombre de línea es requerido'),
        query('overwrite')
            .optional()
            .isBoolean()
            .withMessage('Parámetro overwrite debe ser booleano'),
        query('validate')
            .optional()
            .isBoolean()
            .withMessage('Parámetro validate debe ser booleano')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.importLineConfiguration(req, res)
);

/**
 * @route GET /api/admin/production-lines
 * @desc Obtener todas las líneas de producción
 * @access Admin
 */
router.get('/production-lines',
    productionLineValidators.query,
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.mediumTerm(300), // Cache 5 minutos
    (req, res) => productionLineController.getLines(req, res)
);

/**
 * @route POST /api/admin/production-lines
 * @desc Crear nueva línea de producción
 * @access Admin
 */
router.post('/production-lines',
    rateLimitMiddleware.createLimiter(50, 60), // 50 creaciones por hora
    [
        ...productionLineValidators.create,
        ...productionLineValidators.processes
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.createLine(req, res)
);

/**
 * @route GET /api/admin/production-lines/:id
 * @desc Obtener detalle de una línea específica
 * @access Admin
 */
router.get('/production-lines/:id',
    productionLineValidators.lineId,
    [
        query('metrics')
            .optional()
            .isBoolean()
            .withMessage('Parámetro metrics debe ser booleano'),
        query('equipment')
            .optional()
            .isBoolean()
            .withMessage('Parámetro equipment debe ser booleano'),
        query('history')
            .optional()
            .isBoolean()
            .withMessage('Parámetro history debe ser booleano')
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.shortTerm(120), // Cache 2 minutos
    (req, res) => productionLineController.getLineDetail(req, res)
);

/**
 * @route PUT /api/admin/production-lines/:id
 * @desc Actualizar línea de producción existente
 * @access Admin
 */
router.put('/production-lines/:id',
    productionLineValidators.lineId,
    [
        ...productionLineValidators.create,
        ...productionLineValidators.processes
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.updateLine(req, res)
);

/**
 * @route DELETE /api/admin/production-lines/:id
 * @desc Eliminar línea de producción
 * @access Admin
 */
router.delete('/production-lines/:id',
    rateLimitMiddleware.createLimiter(20, 60), // 20 eliminaciones por hora
    productionLineValidators.lineId,
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.deleteLine(req, res)
);

/**
 * @route POST /api/admin/production-lines/:id/duplicate
 * @desc Duplicar línea de producción existente
 * @access Admin
 */
router.post('/production-lines/:id/duplicate',
    productionLineValidators.lineId,
    [
        body('newName')
            .optional()
            .isLength({ min: 3, max: 100 })
            .withMessage('Nuevo nombre debe tener entre 3 y 100 caracteres'),
        body('newCode')
            .optional()
            .isLength({ max: 20 })
            .withMessage('Nuevo código no puede exceder 20 caracteres')
            .matches(/^[A-Z0-9_-]+$/)
            .withMessage('Código solo puede contener letras mayúsculas, números, guiones y guiones bajos')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.duplicateLine(req, res)
);

/**
 * @route PATCH /api/admin/production-lines/:id/status
 * @desc Cambiar estado de una línea de producción
 * @access Admin
 */
router.patch('/production-lines/:id/status',
    productionLineValidators.lineId,
    [
        body('status')
            .isIn(['draft', 'active', 'inactive', 'maintenance'])
            .withMessage('Estado debe ser: draft, active, inactive o maintenance'),
        body('reason')
            .optional()
            .isLength({ max: 200 })
            .withMessage('Razón no puede exceder 200 caracteres')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.changeLineStatus(req, res)
);

/**
 * @route POST /api/admin/production-lines/:id/reset-metrics
 * @desc Resetear métricas de una línea
 * @access Admin
 */
router.post('/production-lines/:id/reset-metrics',
    rateLimitMiddleware.createLimiter(10, 60), // 10 resets por hora
    productionLineValidators.lineId,
    [
        body('resetType')
            .optional()
            .isIn(['daily', 'weekly', 'monthly', 'all'])
            .withMessage('Tipo de reset debe ser: daily, weekly, monthly o all'),
        body('confirmReset')
            .isBoolean()
            .withMessage('Confirmación de reset es requerida')
            .equals('true')
            .withMessage('Debe confirmar el reset enviando confirmReset: true')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.resetLineMetrics(req, res)
);

/**
 * @route GET /api/admin/production-lines/:id/performance-report
 * @desc Generar reporte de rendimiento de línea
 * @access Admin
 */
router.get('/production-lines/:id/performance-report',
    productionLineValidators.lineId,
    [
        query('startDate')
            .optional()
            .isISO8601()
            .withMessage('Fecha inicio debe ser formato ISO8601'),
        query('endDate')
            .optional()
            .isISO8601()
            .withMessage('Fecha fin debe ser formato ISO8601'),
        query('includeDetails')
            .optional()
            .isBoolean()
            .withMessage('Parámetro includeDetails debe ser booleano'),
        query('format')
            .optional()
            .isIn(['json', 'pdf', 'csv', 'excel'])
            .withMessage('Formato debe ser: json, pdf, csv o excel')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.generatePerformanceReport(req, res)
);

/**
 * @route POST /api/admin/production-lines/:id/validate-csv
 * @desc Validar configuración CSV de equipos de una línea
 * @access Admin
 */
router.post('/production-lines/:id/validate-csv',
    productionLineValidators.lineId,
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.validateCSVConfiguration(req, res)
);

/**
 * @route GET /api/admin/production-lines/:id/export
 * @desc Exportar configuración de línea
 * @access Admin
 */
router.get('/production-lines/:id/export',
    productionLineValidators.lineId,
    [
        query('format')
            .optional()
            .isIn(['json', 'csv', 'xml', 'yaml'])
            .withMessage('Formato debe ser: json, csv, xml o yaml')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.exportLineConfiguration(req, res)
);

/**
 * @route GET /api/admin/production-lines/:id/history
 * @desc Obtener historial de cambios de una línea
 * @access Admin
 */
router.get('/production-lines/:id/history',
    productionLineValidators.lineId,
    [
        query('limit')
            .optional()
            .isInt({ min: 1, max: 200 })
            .withMessage('Límite debe estar entre 1 y 200'),
        query('offset')
            .optional()
            .isInt({ min: 0 })
            .withMessage('Offset debe ser un número no negativo'),
        query('eventType')
            .optional()
            .isIn(['creation', 'update', 'status_change', 'deletion', 'configuration_change'])
            .withMessage('Tipo de evento inválido'),
        query('startDate')
            .optional()
            .isISO8601()
            .withMessage('Fecha inicio debe ser formato ISO8601'),
        query('endDate')
            .optional()
            .isISO8601()
            .withMessage('Fecha fin debe ser formato ISO8601')
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.shortTerm(180), // Cache 3 minutos
    (req, res) => productionLineController.getLineHistory(req, res)
);

// =============================================================================
// RUTAS DE PROCESOS
// =============================================================================

/**
 * @route GET /api/admin/processes
 * @desc Obtener todos los procesos (con filtros opcionales)
 * @access Admin
 */
router.get('/processes',
    [
        query('lineId')
            .optional()
            .isUUID()
            .withMessage('ID de línea debe ser un UUID válido'),
        query('active')
            .optional()
            .isBoolean()
            .withMessage('Parámetro active debe ser booleano'),
        ...productionLineValidators.query
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.mediumTerm(300),
    (req, res) => processController.getProcesses(req, res)
);

/**
 * @route POST /api/admin/processes
 * @desc Crear nuevo proceso
 * @access Admin
 */
router.post('/processes',
    [
        body('lineId')
            .isUUID()
            .withMessage('ID de línea es requerido y debe ser UUID válido'),
        body('name')
            .notEmpty()
            .withMessage('Nombre del proceso es requerido')
            .isLength({ min: 2, max: 100 })
            .withMessage('Nombre debe tener entre 2 y 100 caracteres'),
        body('sequence')
            .isInt({ min: 1 })
            .withMessage('Secuencia debe ser un número entero positivo'),
        body('designCycleTimeSeconds')
            .optional()
            .isFloat({ min: 1, max: 7200 })
            .withMessage('Tiempo de ciclo debe estar entre 1 y 7200 segundos')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => processController.createProcess(req, res)
);

/**
 * @route PUT /api/admin/processes/:id
 * @desc Actualizar proceso existente
 * @access Admin
 */
router.put('/processes/:id',
    [
        param('id')
            .isUUID()
            .withMessage('ID de proceso debe ser un UUID válido'),
        body('name')
            .optional()
            .isLength({ min: 2, max: 100 })
            .withMessage('Nombre debe tener entre 2 y 100 caracteres'),
        body('designCycleTimeSeconds')
            .optional()
            .isFloat({ min: 1, max: 7200 })
            .withMessage('Tiempo de ciclo debe estar entre 1 y 7200 segundos')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => processController.updateProcess(req, res)
);

/**
 * @route DELETE /api/admin/processes/:id
 * @desc Eliminar proceso
 * @access Admin
 */
router.delete('/processes/:id',
    [
        param('id')
            .isUUID()
            .withMessage('ID de proceso debe ser un UUID válido')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => processController.deleteProcess(req, res)
);

/**
 * @route POST /api/admin/processes/reorder
 * @desc Reordenar secuencia de procesos en una línea
 * @access Admin
 */
router.post('/processes/reorder',
    [
        body('lineId')
            .isUUID()
            .withMessage('ID de línea es requerido y debe ser UUID válido'),
        body('processSequences')
            .isArray({ min: 1 })
            .withMessage('Secuencias de procesos son requeridas'),
        body('processSequences.*.processId')
            .isUUID()
            .withMessage('ID de proceso debe ser UUID válido'),
        body('processSequences.*.newSequence')
            .isInt({ min: 1 })
            .withMessage('Nueva secuencia debe ser número entero positivo')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => processController.reorderProcesses(req, res)
);

// =============================================================================
// RUTAS DE EQUIPOS
// =============================================================================

/**
 * @route GET /api/admin/equipment
 * @desc Obtener todos los equipos
 * @access Admin
 */
router.get('/equipment',
    [
        query('processId')
            .optional()
            .isUUID()
            .withMessage('ID de proceso debe ser un UUID válido'),
        query('active')
            .optional()
            .isBoolean()
            .withMessage('Parámetro active debe ser booleano'),
        query('hasConnection')
            .optional()
            .isBoolean()
            .withMessage('Parámetro hasConnection debe ser booleano'),
        ...productionLineValidators.query
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.shortTerm(120),
    (req, res) => equipmentController.getEquipment(req, res)
);

/**
 * @route POST /api/admin/equipment
 * @desc Crear nuevo equipo
 * @access Admin
 */
router.post('/equipment',
    [
        body('processId')
            .isUUID()
            .withMessage('ID de proceso es requerido y debe ser UUID válido'),
        body('name')
            .notEmpty()
            .withMessage('Nombre del equipo es requerido')
            .isLength({ min: 2, max: 100 })
            .withMessage('Nombre debe tener entre 2 y 100 caracteres'),
        body('code')
            .notEmpty()
            .withMessage('Código del equipo es requerido')
            .isLength({ max: 20 })
            .withMessage('Código no puede exceder 20 caracteres'),
        body('csvUrl')
            .optional()
            .isURL()
            .withMessage('URL CSV debe ser una URL válida'),
        body('type')
            .optional()
            .isIn(['serial', 'parallel'])
            .withMessage('Tipo debe ser serial o parallel')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => equipmentController.createEquipment(req, res)
);

/**
 * @route PUT /api/admin/equipment/:id
 * @desc Actualizar equipo existente
 * @access Admin
 */
router.put('/equipment/:id',
    [
        param('id')
            .isUUID()
            .withMessage('ID de equipo debe ser un UUID válido'),
        body('name')
            .optional()
            .isLength({ min: 2, max: 100 })
            .withMessage('Nombre debe tener entre 2 y 100 caracteres'),
        body('csvUrl')
            .optional()
            .isURL()
            .withMessage('URL CSV debe ser una URL válida')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => equipmentController.updateEquipment(req, res)
);

/**
 * @route DELETE /api/admin/equipment/:id
 * @desc Eliminar equipo
 * @access Admin
 */
router.delete('/equipment/:id',
    [
        param('id')
            .isUUID()
            .withMessage('ID de equipo debe ser un UUID válido')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => equipmentController.deleteEquipment(req, res)
);

/**
 * @route POST /api/admin/equipment/:id/test-connection
 * @desc Probar conexión de un equipo
 * @access Admin
 */
router.post('/equipment/:id/test-connection',
    rateLimitMiddleware.createLimiter(30, 5), // 30 tests por 5 minutos
    [
        param('id')
            .isUUID()
            .withMessage('ID de equipo debe ser un UUID válido')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => equipmentController.testEquipmentConnection(req, res)
);

// =============================================================================
// RUTAS DE CONFIGURACIÓN Y UTILIDADES
// =============================================================================

/**
 * @route GET /api/admin/system/health
 * @desc Verificar estado del sistema
 * @access Admin
 */
router.get('/system/health',
    cacheMiddleware.shortTerm(30),
    (req, res) => {
        // TODO: Implementar HealthController
        res.json({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            version: process.env.npm_package_version || '1.0.0',
            environment: process.env.NODE_ENV,
            uptime: process.uptime()
        });
    }
);

/**
 * @route POST /api/admin/system/maintenance
 * @desc Activar/desactivar modo mantenimiento
 * @access Admin
 */
router.post('/system/maintenance',
    rateLimitMiddleware.createLimiter(5, 60), // 5 cambios por hora
    [
        body('enabled')
            .isBoolean()
            .withMessage('Estado de mantenimiento debe ser booleano'),
        body('reason')
            .optional()
            .isLength({ max: 200 })
            .withMessage('Razón no puede exceder 200 caracteres')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar MaintenanceController
        res.json({
            success: true,
            message: 'Modo mantenimiento actualizado',
            maintenanceMode: req.body.enabled,
            reason: req.body.reason || 'No especificada'
        });
    }
);

// =============================================================================