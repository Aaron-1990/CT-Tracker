// =============================================================================
// config/security.js - Middleware de Seguridad IP Actualizado
// Dashboard VSM BorgWarner - Integracion con Rangos DHCP Corporativos  
// =============================================================================

const environment = require('./environment');
const logger = require('./logger');
const { createIPFilterMiddleware, globalValidator } = require('./ip-validator');

const ipFilterMiddleware = (req, res, next) => {
    const clientIP = (req.ip || 
                     req.connection.remoteAddress || 
                     req.socket.remoteAddress ||
                     (req.connection.socket ? req.connection.socket.remoteAddress : null) ||
                     req.headers['x-forwarded-for'] ||
                     req.headers['x-real-ip'] ||
                     '').replace(/^::ffff:/, '');

    const ipConfig = environment.getIPValidationConfig();
    
    if (ipConfig.debugMode) {
        console.log('[SECURITY] =====================================');
        console.log('[SECURITY] Nueva solicitud de IP: "' + clientIP + '"');
        console.log('[SECURITY] Modo de validacion: ' + ipConfig.mode);
        console.log('[SECURITY] IPs especificas: [' + ipConfig.allowedIPs.map(ip => '"' + ip + '"').join(', ') + ']');
        console.log('[SECURITY] Rangos DHCP: ' + ipConfig.dhcpRanges.length + ' configurados');
        console.log('[SECURITY] Cache habilitado: ' + ipConfig.enableCache);
        console.log('[SECURITY] =====================================');
    }

    const validationResult = globalValidator.validateIP(clientIP, ipConfig);

    if (validationResult.allowed) {
        const logMessage = '[' + new Date().toISOString() + '] ACCESO PERMITIDO: ' + clientIP + ' | Metodo: ' + validationResult.method + ' | Regla: ' + (validationResult.matchedRule || 'N/A');
        
        if (validationResult.matchedRange) {
            logger.info(logMessage + ' | Rango: ' + validationResult.matchedRange.description);
        } else {
            logger.info(logMessage);
        }

        req.ipValidation = {
            clientIP: validationResult.clientIP,
            method: validationResult.method,
            matchedRule: validationResult.matchedRule,
            matchedRange: validationResult.matchedRange,
            timestamp: validationResult.timestamp,
            cached: globalValidator.metrics.cacheHits > 0
        };

        if (ipConfig.debugMode) {
            console.log('[SECURITY] Acceso concedido para ' + clientIP);
            if (validationResult.matchedRange) {
                console.log('[SECURITY] Rango coincidente: ' + validationResult.matchedRange.name + ' (' + validationResult.matchedRange.description + ')');
            }
        }

        next();
        
    } else {
        const logMessage = '[' + new Date().toISOString() + '] ACCESO DENEGADO: ' + clientIP + ' | Metodo: ' + validationResult.method + ' | Error: ' + (validationResult.error || 'IP no autorizada');
        logger.warn(logMessage);

        if (ipConfig.debugMode) {
            console.log('[SECURITY] Acceso denegado para ' + clientIP);
            console.log('[SECURITY] Metodo usado: ' + validationResult.method);
            console.log('[SECURITY] Regla coincidente: ' + (validationResult.matchedRule || 'ninguna'));
            
            if (validationResult.method === 'dhcp-range') {
                console.log('[SECURITY] Sugerencia: Verificar que la IP este en uno de los rangos DHCP corporativos');
                ipConfig.dhcpRanges.forEach((range, index) => {
                    console.log('[SECURITY]    ' + (index + 1) + '. ' + range.name + ': ' + range.start + ' - ' + range.end);
                });
            }
        }

        const errorResponse = {
            error: 'Acceso denegado. IP no autorizada.',
            details: {
                ip: clientIP,
                method: validationResult.method,
                timestamp: validationResult.timestamp
            }
        };

        if (ipConfig.debugMode) {
            errorResponse.details.debug = {
                mode: ipConfig.mode,
                availableRanges: ipConfig.dhcpRanges.length,
                staticIPs: ipConfig.allowedIPs.length
            };
        }

        res.status(403).json(errorResponse);
    }
};

const corsOptions = {
    origin: function (origin, callback) {
        if (!origin) return callback(null, true);

        if (environment.NODE_ENV === 'development') {
            return callback(null, true);
        }

        const ipConfig = environment.getIPValidationConfig();
        let allowedOrigins = [];

        if (environment.SECURITY.CORS_ORIGINS) {
            allowedOrigins = [...environment.SECURITY.CORS_ORIGINS];
        }

        ipConfig.allowedIPs.forEach(ip => {
            allowedOrigins.push('http://' + ip + ':' + environment.PORT);
            allowedOrigins.push('https://' + ip + ':' + environment.HTTPS_PORT);
        });

        if (allowedOrigins.includes(origin)) {
            callback(null, true);
        } else {
            logger.warn('[CORS] Origen no permitido: ' + origin);
            callback(new Error('No permitido por CORS'));
        }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    exposedHeaders: ['X-Total-Count', 'X-Pagination']
};

const securityMetricsMiddleware = (req, res, next) => {
    req.securityMetrics = {
        startTime: Date.now(),
        userAgent: req.headers['user-agent'] || 'unknown',
        referer: req.headers.referer || 'direct',
        method: req.method,
        path: req.path
    };

    const originalSend = res.send;
    res.send = function(data) {
        req.securityMetrics.endTime = Date.now();
        req.securityMetrics.responseTime = req.securityMetrics.endTime - req.securityMetrics.startTime;
        req.securityMetrics.statusCode = res.statusCode;
        
        if (res.statusCode === 403 || environment.SECURITY.DEBUG_IP_VALIDATION) {
            logger.info('[METRICS] ' + req.method + ' ' + req.path + ' | Status: ' + res.statusCode + ' | Time: ' + req.securityMetrics.responseTime + 'ms | IP: ' + (req.ipValidation ? req.ipValidation.clientIP : 'unknown'));
        }

        originalSend.call(this, data);
    };

    next();
};

const securityHeadersMiddleware = (req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY'); 
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.setHeader('X-VSM-Dashboard', 'BorgWarner-v1.0');
    
    if (environment.NODE_ENV === 'development' && req.ipValidation) {
        res.setHeader('X-IP-Validation-Method', req.ipValidation.method);
        res.setHeader('X-IP-Validation-Rule', req.ipValidation.matchedRule || 'none');
    }

    next();
};

function getSecurityStats() {
    const validatorMetrics = globalValidator.getMetrics();
    
    return {
        ipValidation: validatorMetrics,
        configuration: {
            mode: environment.SECURITY.IP_VALIDATION_MODE,
            staticIPs: environment.SECURITY.ALLOWED_IPS.length,
            dhcpRanges: environment.SECURITY.DHCP_RANGES.length,
            cacheEnabled: environment.SECURITY.ENABLE_IP_CACHE,
            debugMode: environment.SECURITY.DEBUG_IP_VALIDATION
        },
        system: {
            nodeEnv: environment.NODE_ENV,
            uptime: process.uptime(),
            timestamp: new Date().toISOString()
        }
    };
}

function createSecurityStatsEndpoint() {
    return (req, res) => {
        if (environment.NODE_ENV !== 'development') {
            return res.status(403).json({ error: 'Endpoint no disponible en produccion' });
        }

        const stats = getSecurityStats();
        res.json(stats);
    };
}

function resetSecurityState() {
    globalValidator.resetMetrics();
    logger.info('[SECURITY] Estado de seguridad reiniciado');
}

module.exports = {
    ipFilterMiddleware,
    corsOptions,
    securityMetricsMiddleware,
    securityHeadersMiddleware,
    getSecurityStats,
    createSecurityStatsEndpoint,
    resetSecurityState,
    allowedIPs: environment.SECURITY.ALLOWED_IPS
};
