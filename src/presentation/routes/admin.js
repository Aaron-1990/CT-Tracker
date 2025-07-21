// =============================================================================
// src/presentation/routes/admin.js
// Rutas de administración para el sistema VSM - VERSIÓN COMPLETA Y CORREGIDA
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
 * 
 * @param {Object} dependencies - Objeto con todas las dependencias necesarias
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
    // configurationController = new ConfigurationController(dependencies);
    // lineBuilderController = new LineBuilderController(dependencies);
    // analyticsController = new AnalyticsController(dependencies);
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
            .withMessage('Nombre de línea es requerido')
            .isLength({ min: 3, max: 100 })
            .withMessage('Nombre debe tener entre 3 y 100 caracteres')
            .trim(),
        body('code')
            .optional()
            .isLength({ max: 20 })
            .withMessage('Código no puede exceder 20 caracteres')
            .matches(/^[A-Z0-9_-]+$/)
            .withMessage('Código solo puede contener letras mayúsculas, números, guiones y guiones bajos'),
        body('description')
            .optional()
            .isLength({ max: 500 })
            .withMessage('Descripción no puede exceder 500 caracteres'),
        body('targetOeePercentage')
            .optional()
            .isFloat({ min: 1, max: 100 })
            .withMessage('OEE objetivo debe estar entre 1% y 100%'),
        body('status')
            .optional()
            .isIn(['draft', 'active', 'inactive', 'maintenance'])
            .withMessage('Estado debe ser: draft, active, inactive o maintenance')
    ],

    // Validadores para procesos dentro de líneas
    processes: [
        body('processes')
            .optional()
            .isArray({ max: 50 })
            .withMessage('Una línea no puede tener más de 50 procesos'),
        body('processes.*.name')
            .if(body('processes').exists())
            .notEmpty()
            .withMessage('Nombre del proceso es requerido'),
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

const processValidators = {
    create: [
        body('name')
            .notEmpty()
            .withMessage('Nombre del proceso es requerido')
            .isLength({ min: 2, max: 100 })
            .withMessage('Nombre debe tener entre 2 y 100 caracteres'),
        body('sequence')
            .isInt({ min: 1 })
            .withMessage('Secuencia debe ser un número entero positivo'),
        body('lineId')
            .isUUID()
            .withMessage('ID de línea debe ser un UUID válido'),
        body('designCycleTimeSeconds')
            .optional()
            .isFloat({ min: 1, max: 7200 })
            .withMessage('Tiempo de ciclo debe estar entre 1 y 7200 segundos'),
        body('designProcessTimeSeconds')
            .optional()
            .isFloat({ min: 1, max: 7200 })
            .withMessage('Tiempo de proceso debe estar entre 1 y 7200 segundos')
    ],

    processId: [
        param('id')
            .isUUID()
            .withMessage('ID de proceso debe ser un UUID válido')
    ]
};

const equipmentValidators = {
    create: [
        body('name')
            .notEmpty()
            .withMessage('Nombre del equipo es requerido')
            .isLength({ min: 2, max: 100 })
            .withMessage('Nombre debe tener entre 2 y 100 caracteres'),
        body('type')
            .isIn(['sensor', 'actuator', 'plc', 'hmi', 'robot', 'conveyor', 'other'])
            .withMessage('Tipo de equipo inválido'),
        body('connectionType')
            .isIn(['tcp', 'serial', 'modbus', 'opcua', 'mqtt', 'http'])
            .withMessage('Tipo de conexión inválido'),
        body('ipAddress')
            .optional()
            .isIP()
            .withMessage('Dirección IP inválida'),
        body('port')
            .optional()
            .isInt({ min: 1, max: 65535 })
            .withMessage('Puerto debe estar entre 1 y 65535')
    ],

    equipmentId: [
        param('id')
            .isUUID()
            .withMessage('ID de equipo debe ser un UUID válido')
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
 * @desc Reiniciar métricas de una línea
 * @access Admin
 */
router.post('/production-lines/:id/reset-metrics',
    rateLimitMiddleware.createLimiter(10, 60), // 10 reinicios por hora
    productionLineValidators.lineId,
    [
        body('confirmation')
            .equals('RESET_METRICS')
            .withMessage('Confirmación requerida: RESET_METRICS')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.resetLineMetrics(req, res)
);

/**
 * @route GET /api/admin/production-lines/:id/history
 * @desc Obtener historial de una línea
 * @access Admin
 */
router.get('/production-lines/:id/history',
    productionLineValidators.lineId,
    [
        query('startDate')
            .optional()
            .isISO8601()
            .withMessage('Fecha de inicio debe ser válida'),
        query('endDate')
            .optional()
            .isISO8601()
            .withMessage('Fecha de fin debe ser válida'),
        query('events')
            .optional()
            .isBoolean()
            .withMessage('Parámetro events debe ser booleano')
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.shortTerm(180), // Cache 3 minutos
    (req, res) => productionLineController.getLineHistory(req, res)
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
            .isIn(['json', 'csv', 'xlsx'])
            .withMessage('Formato debe ser json, csv o xlsx'),
        query('includeMetrics')
            .optional()
            .isBoolean()
            .withMessage('Parámetro includeMetrics debe ser booleano')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => productionLineController.exportLineConfiguration(req, res)
);

// =============================================================================
// RUTAS DE PROCESOS
// =============================================================================

/**
 * @route GET /api/admin/processes
 * @desc Obtener todos los procesos
 * @access Admin
 */
router.get('/processes',
    [
        query('lineId')
            .optional()
            .isUUID()
            .withMessage('ID de línea debe ser un UUID válido'),
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
    processValidators.create,
    validationMiddleware.handleValidationErrors,
    (req, res) => processController.createProcess(req, res)
);

/**
 * @route GET /api/admin/processes/:id
 * @desc Obtener detalle de un proceso específico
 * @access Admin
 */
router.get('/processes/:id',
    processValidators.processId,
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.shortTerm(120),
    (req, res) => processController.getProcessDetail(req, res)
);

/**
 * @route PUT /api/admin/processes/:id
 * @desc Actualizar proceso existente
 * @access Admin
 */
router.put('/processes/:id',
    processValidators.processId,
    processValidators.create,
    validationMiddleware.handleValidationErrors,
    (req, res) => processController.updateProcess(req, res)
);

/**
 * @route DELETE /api/admin/processes/:id
 * @desc Eliminar proceso
 * @access Admin
 */
router.delete('/processes/:id',
    rateLimitMiddleware.createLimiter(30, 60), // 30 eliminaciones por hora
    processValidators.processId,
    validationMiddleware.handleValidationErrors,
    (req, res) => processController.deleteProcess(req, res)
);

/**
 * @route POST /api/admin/processes/reorder
 * @desc Reordenar procesos en una línea
 * @access Admin
 */
router.post('/processes/reorder',
    [
        body('lineId')
            .isUUID()
            .withMessage('ID de línea debe ser un UUID válido'),
        body('processOrder')
            .isArray({ min: 1 })
            .withMessage('Orden de procesos debe ser un array con al menos un elemento'),
        body('processOrder.*')
            .isUUID()
            .withMessage('Cada ID de proceso debe ser un UUID válido')
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
        query('type')
            .optional()
            .isIn(['sensor', 'actuator', 'plc', 'hmi', 'robot', 'conveyor', 'other'])
            .withMessage('Tipo de equipo inválido'),
        query('status')
            .optional()
            .isIn(['connected', 'disconnected', 'error', 'maintenance'])
            .withMessage('Estado de equipo inválido'),
        ...productionLineValidators.query
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.mediumTerm(300),
    (req, res) => equipmentController.getEquipment(req, res)
);

/**
 * @route POST /api/admin/equipment
 * @desc Crear nuevo equipo
 * @access Admin
 */
router.post('/equipment',
    equipmentValidators.create,
    validationMiddleware.handleValidationErrors,
    (req, res) => equipmentController.createEquipment(req, res)
);

/**
 * @route GET /api/admin/equipment/:id
 * @desc Obtener detalle de un equipo específico
 * @access Admin
 */
router.get('/equipment/:id',
    equipmentValidators.equipmentId,
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.shortTerm(120),
    (req, res) => equipmentController.getEquipmentDetail(req, res)
);

/**
 * @route PUT /api/admin/equipment/:id
 * @desc Actualizar equipo existente
 * @access Admin
 */
router.put('/equipment/:id',
    equipmentValidators.equipmentId,
    equipmentValidators.create,
    validationMiddleware.handleValidationErrors,
    (req, res) => equipmentController.updateEquipment(req, res)
);

/**
 * @route DELETE /api/admin/equipment/:id
 * @desc Eliminar equipo
 * @access Admin
 */
router.delete('/equipment/:id',
    rateLimitMiddleware.createLimiter(20, 60), // 20 eliminaciones por hora
    equipmentValidators.equipmentId,
    validationMiddleware.handleValidationErrors,
    (req, res) => equipmentController.deleteEquipment(req, res)
);

/**
 * @route POST /api/admin/equipment/:id/test-connection
 * @desc Probar conexión con equipo
 * @access Admin
 */
router.post('/equipment/:id/test-connection',
    rateLimitMiddleware.createLimiter(50, 60), // 50 pruebas por hora
    equipmentValidators.equipmentId,
    validationMiddleware.handleValidationErrors,
    (req, res) => equipmentController.testEquipmentConnection(req, res)
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
            .isIn(['day', 'week', 'month', 'quarter', 'year'])
            .withMessage('Período debe ser: day, week, month, quarter o year'),
        query('startDate')
            .optional()
            .isISO8601()
            .withMessage('Fecha de inicio debe ser válida'),
        query('endDate')
            .optional()
            .isISO8601()
            .withMessage('Fecha de fin debe ser válida')
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
 * @route POST /api/admin/analytics/reports/generate
 * @desc Generar reporte personalizado
 * @access Admin
 */
router.post('/analytics/reports/generate',
    rateLimitMiddleware.createLimiter(10, 60), // 10 reportes por hora
    [
        body('type')
            .isIn(['performance', 'oee', 'downtime', 'productivity'])
            .withMessage('Tipo de reporte inválido'),
        body('format')
            .optional()
            .isIn(['pdf', 'xlsx', 'csv'])
            .withMessage('Formato debe ser pdf, xlsx o csv'),
        body('lineIds')
            .optional()
            .isArray()
            .withMessage('IDs de líneas debe ser un array'),
        body('lineIds.*')
            .if(body('lineIds').exists())
            .isUUID()
            .withMessage('Cada ID de línea debe ser un UUID válido')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar analyticsController.generateReport
        res.json({
            message: 'Report generation - Pendiente implementación',
            timestamp: new Date().toISOString()
        });
    }
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
        res.json({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            version: process.env.npm_package_version || '1.0.0',
            environment: process.env.NODE_ENV,
            uptime: process.uptime(),
            memory: {
                used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + 'MB',
                total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + 'MB'
            }
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
            reason: req.body.reason || 'No especificada',
            timestamp: new Date().toISOString()
        });
    }
);

/**
 * @route GET /api/admin/system/logs
 * @desc Obtener logs del sistema
 * @access Admin
 */
router.get('/system/logs',
    [
        query('level')
            .optional()
            .isIn(['error', 'warn', 'info', 'debug'])
            .withMessage('Nivel de log inválido'),
        query('limit')
            .optional()
            .isInt({ min: 1, max: 1000 })
            .withMessage('Límite debe estar entre 1 y 1000'),
        query('startDate')
            .optional()
            .isISO8601()
            .withMessage('Fecha de inicio debe ser válida')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar LogController
        res.json({
            message: 'System logs - Pendiente implementación',
            timestamp: new Date().toISOString()
        });
    }
);

// =============================================================================
// RUTAS DE HERRAMIENTAS Y UTILIDADES
// =============================================================================

/**
 * @route POST /api/admin/tools/backup
 * @desc Crear backup del sistema
 * @access Admin
 */
router.post('/tools/backup',
    rateLimitMiddleware.createLimiter(3, 60), // 3 backups por hora
    [
        body('includeMetrics')
            .optional()
            .isBoolean()
            .withMessage('Parámetro includeMetrics debe ser booleano'),
        body('includeHistory')
            .optional()
            .isBoolean()
            .withMessage('Parámetro includeHistory debe ser booleano'),
        body('description')
            .optional()
            .isLength({ max: 200 })
            .withMessage('Descripción no puede exceder 200 caracteres')
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
 * @route GET /api/admin/tools/backups
 * @desc Listar backups disponibles
 * @access Admin
 */
router.get('/tools/backups',
    productionLineValidators.query,
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.shortTerm(60),
    (req, res) => {
        // TODO: Implementar backupController.listBackups
        res.json({
            message: 'Backup listing - Pendiente implementación',
            timestamp: new Date().toISOString()
        });
    }
);

/**
 * @route POST /api/admin/tools/backups/:id/restore
 * @desc Restaurar backup específico
 * @access Admin
 */
router.post('/tools/backups/:id/restore',
    rateLimitMiddleware.createLimiter(2, 60), // 2 restauraciones por hora
    [
        param('id')
            .isUUID()
            .withMessage('ID de backup debe ser un UUID válido'),
        body('confirmation')
            .equals('RESTORE_BACKUP')
            .withMessage('Confirmación requerida: RESTORE_BACKUP')
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

/**
 * @route POST /api/admin/tools/csv/validate
 * @desc Validar archivo CSV para importación
 * @access Admin
 */
router.post('/tools/csv/validate',
    rateLimitMiddleware.createLimiter(50, 60), // 50 validaciones por hora
    [
        body('csvData')
            .notEmpty()
            .withMessage('Datos CSV son requeridos'),
        body('type')
            .isIn(['production-lines', 'processes', 'equipment'])
            .withMessage('Tipo debe ser: production-lines, processes o equipment')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar csvController.validateCSV
        res.json({
            message: 'CSV validation - Pendiente implementación',
            timestamp: new Date().toISOString()
        });
    }
);

/**
 * @route GET /api/admin/tools/csv/template/:type
 * @desc Descargar plantilla CSV
 * @access Admin
 */
router.get('/tools/csv/template/:type',
    [
        param('type')
            .isIn(['production-lines', 'processes', 'equipment'])
            .withMessage('Tipo debe ser: production-lines, processes o equipment')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar csvController.downloadTemplate
        res.json({
            message: 'CSV template download - Pendiente implementación',
            type: req.params.type,
            timestamp: new Date().toISOString()
        });
    }
);

// =============================================================================
// RUTAS DE CONFIGURACIÓN
// =============================================================================

/**
 * @route GET /api/admin/config/settings
 * @desc Obtener configuración del sistema
 * @access Admin
 */
router.get('/config/settings',
    cacheMiddleware.mediumTerm(300),
    (req, res) => {
        // TODO: Implementar configController.getSettings
        res.json({
            message: 'System settings - Pendiente implementación',
            timestamp: new Date().toISOString()
        });
    }
);

/**
 * @route PUT /api/admin/config/settings
 * @desc Actualizar configuración del sistema
 * @access Admin
 */
router.put('/config/settings',
    rateLimitMiddleware.createLimiter(10, 60), // 10 actualizaciones por hora
    [
        body('settings')
            .isObject()
            .withMessage('Configuración debe ser un objeto'),
        body('settings.maxProcessesPerLine')
            .optional()
            .isInt({ min: 1, max: 100 })
            .withMessage('Máximo procesos por línea debe estar entre 1 y 100'),
        body('settings.defaultCacheTimeout')
            .optional()
            .isInt({ min: 30, max: 3600 })
            .withMessage('Timeout de cache debe estar entre 30 y 3600 segundos'),
        body('settings.enableNotifications')
            .optional()
            .isBoolean()
            .withMessage('Habilitación de notificaciones debe ser booleano')
    ],
    validationMiddleware.handleValidationErrors,
    (req, res) => {
        // TODO: Implementar configController.updateSettings
        res.json({
            message: 'Settings update - Pendiente implementación',
            timestamp: new Date().toISOString()
        });
    }
);

/**
 * @route GET /api/admin/config/audit-log
 * @desc Obtener log de auditoría
 * @access Admin
 */
router.get('/config/audit-log',
    [
        query('action')
            .optional()
            .isIn(['create', 'update', 'delete', 'login', 'logout'])
            .withMessage('Acción inválida'),
        query('userId')
            .optional()
            .isUUID()
            .withMessage('ID de usuario debe ser un UUID válido'),
        ...productionLineValidators.query
    ],
    validationMiddleware.handleValidationErrors,
    cacheMiddleware.shortTerm(120),
    (req, res) => {
        // TODO: Implementar auditController.getAuditLog
        res.json({
            message: 'Audit log - Pendiente implementación',
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
    // Log del error con contexto completo
    console.error('Error en rutas admin:', {
        error: err.message,
        stack: err.stack,
        url: req.originalUrl,
        method: req.method,
        body: req.body,
        params: req.params,
        query: req.query,
        user: req.user?.username || 'unknown',
        timestamp: new Date().toISOString()
    });

    // Determinar código de estado HTTP
    const statusCode = err.statusCode || err.status || 500;
    
    // Respuesta de error estructurada
    const errorResponse = {
        success: false,
        message: err.message || 'Error interno en administración',
        errorCode: err.code || 'ADMIN_ERROR',
        timestamp: new Date().toISOString()
    };

    // En desarrollo, incluir información adicional para debugging
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

    // Responder con el error estructurado
    res.status(statusCode).json(errorResponse);
});

// =============================================================================
// EXPORTACIONES
// =============================================================================

module.exports = {
    router,
    initializeControllers
};