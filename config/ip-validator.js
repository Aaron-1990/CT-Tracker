// =============================================================================
// config/ip-validator.js - Modulo de Validacion IP con Soporte DHCP Ranges
// Dashboard VSM BorgWarner - Implementacion de Rangos Corporativos
// =============================================================================

const logger = require('./logger');

const CORPORATE_DHCP_RANGES = [
    {
        name: 'WorkstationsAreaA',
        description: 'Estaciones de trabajo - Area A',
        start: '10.41.126.1',
        end: '10.45.126.255',
        enabled: true
    },
    {
        name: 'WorkstationsAreaB', 
        description: 'Estaciones de trabajo - Area B',
        start: '10.50.126.1',
        end: '10.51.126.255',
        enabled: true
    },
    {
        name: 'MobileSpecialDevices',
        description: 'Dispositivos moviles y especiales',
        start: '10.92.48.1', 
        end: '10.92.52.255',
        enabled: true
    }
];

class IPValidationCache {
    constructor(ttlMs = 300000) {
        this.cache = new Map();
        this.ttl = ttlMs;
    }

    get(ip) {
        const entry = this.cache.get(ip);
        if (!entry) return null;

        if (Date.now() - entry.timestamp > this.ttl) {
            this.cache.delete(ip);
            return null;
        }

        return entry.result;
    }

    set(ip, result) {
        this.cache.set(ip, {
            result,
            timestamp: Date.now()
        });

        // Limpieza automatica del cache si crece mucho
        if (this.cache.size > 1000) {
            const entries = Array.from(this.cache.entries());
            const now = Date.now();
            
            entries.forEach(([key, value]) => {
                if (now - value.timestamp > this.ttl) {
                    this.cache.delete(key);
                }
            });
        }
    }

    clear() {
        this.cache.clear();
    }

    getStats() {
        return {
            size: this.cache.size,
            ttl: this.ttl
        };
    }
}

class IPValidator {
    constructor(options = {}) {
        this.cache = new IPValidationCache(options.cacheTtl);
        this.debugMode = options.debugMode || false;
        this.logAttempts = options.logAttempts || true;
        
        this.metrics = {
            totalRequests: 0,
            allowedRequests: 0,
            deniedRequests: 0,
            cacheHits: 0,
            rangeMatches: new Map(),
            staticMatches: 0
        };
    }

    ipToNumber(ip) {
        try {
            return ip.split('.')
                .reduce((acc, octet) => (acc << 8) + parseInt(octet, 10), 0) >>> 0;
        } catch (error) {
            logger.warn(`Error convirtiendo IP ${ip} a numero: ${error.message}`);
            return 0;
        }
    }

    isIPInRange(ip, rangeStart, rangeEnd) {
        try {
            const ipNum = this.ipToNumber(ip);
            const startNum = this.ipToNumber(rangeStart);
            const endNum = this.ipToNumber(rangeEnd);

            const inRange = ipNum >= startNum && ipNum <= endNum;

            if (this.debugMode) {
                logger.debug(`Range check: ${ip} (${ipNum}) in [${rangeStart} (${startNum}) - ${rangeEnd} (${endNum})] = ${inRange}`);
            }

            return inRange;
        } catch (error) {
            logger.error(`Error en validacion de rango: ${error.message}`);
            return false;
        }
    }

    validateStaticIPs(clientIP, allowedIPs) {
        const isAllowed = allowedIPs.includes(clientIP);
        
        if (isAllowed) {
            this.metrics.staticMatches++;
        }

        if (this.debugMode) {
            logger.debug(`Static IP validation: ${clientIP} in [${allowedIPs.join(', ')}] = ${isAllowed}`);
        }

        return {
            allowed: isAllowed,
            method: 'static',
            matchedRule: isAllowed ? 'static-ip-list' : null
        };
    }

    validateDHCPRanges(clientIP, ranges = CORPORATE_DHCP_RANGES) {
        for (const range of ranges) {
            if (!range.enabled) continue;

            if (this.isIPInRange(clientIP, range.start, range.end)) {
                const currentCount = this.metrics.rangeMatches.get(range.name) || 0;
                this.metrics.rangeMatches.set(range.name, currentCount + 1);

                if (this.debugMode) {
                    logger.debug(`IP ${clientIP} matched range: ${range.name} (${range.description})`);
                }

                return {
                    allowed: true,
                    method: 'dhcp-range',
                    matchedRule: range.name,
                    matchedRange: {
                        name: range.name,
                        description: range.description,
                        start: range.start,
                        end: range.end
                    }
                };
            }
        }

        if (this.debugMode) {
            logger.debug(`IP ${clientIP} no coincide con ningun rango DHCP corporativo`);
        }

        return {
            allowed: false,
            method: 'dhcp-range',
            matchedRule: null
        };
    }

    validateHybrid(clientIP, config) {
        // Primero verificar IPs estaticas (mayor prioridad)
        const staticResult = this.validateStaticIPs(clientIP, config.allowedIPs || []);
        if (staticResult.allowed) {
            return staticResult;
        }

        // Si no es IP estatica, verificar rangos DHCP
        const rangeResult = this.validateDHCPRanges(clientIP, config.dhcpRanges);
        return rangeResult;
    }

    validateIP(clientIP, config = {}) {
        try {
            this.metrics.totalRequests++;

            // Verificar cache primero
            const cachedResult = this.cache.get(clientIP);
            if (cachedResult) {
                this.metrics.cacheHits++;
                
                if (this.debugMode) {
                    logger.debug(`Cache hit para IP: ${clientIP}`);
                }
                
                return cachedResult;
            }

            let result;
            const mode = config.mode || 'hybrid';

            switch (mode) {
                case 'static':
                    result = this.validateStaticIPs(clientIP, config.allowedIPs || []);
                    break;
                
                case 'ranges':
                    result = this.validateDHCPRanges(clientIP, config.dhcpRanges);
                    break;
                    
                case 'hybrid':
                default:
                    result = this.validateHybrid(clientIP, config);
                    break;
            }

            // Agregar metadata al resultado
            result.clientIP = clientIP;
            result.timestamp = new Date().toISOString();
            result.mode = mode;

            // Actualizar metricas
            if (result.allowed) {
                this.metrics.allowedRequests++;
            } else {
                this.metrics.deniedRequests++;
            }

            // Guardar en cache
            this.cache.set(clientIP, result);

            // Log del resultado
            if (this.logAttempts) {
                const logLevel = result.allowed ? 'info' : 'warn';
                const action = result.allowed ? 'PERMITIDO' : 'DENEGADO';
                
                logger[logLevel](`[IP-VALIDATOR] ${action}: ${clientIP} | Metodo: ${result.method} | Regla: ${result.matchedRule || 'none'}`);
            }

            return result;

        } catch (error) {
            logger.error(`Error en validacion IP para ${clientIP}: ${error.message}`);
            
            return {
                allowed: false,
                method: 'error',
                matchedRule: null,
                error: error.message,
                clientIP,
                timestamp: new Date().toISOString()
            };
        }
    }

    getMetrics() {
        const rangeStats = {};
        this.metrics.rangeMatches.forEach((count, rangeName) => {
            rangeStats[rangeName] = count;
        });

        return {
            ...this.metrics,
            rangeMatches: rangeStats,
            cacheStats: this.cache.getStats(),
            uptime: process.uptime()
        };
    }

    resetMetrics() {
        this.metrics = {
            totalRequests: 0,
            allowedRequests: 0,
            deniedRequests: 0,
            cacheHits: 0,
            rangeMatches: new Map(),
            staticMatches: 0
        };
        this.cache.clear();
    }

    validateRangeConfiguration(ranges = CORPORATE_DHCP_RANGES) {
        const errors = [];
        
        ranges.forEach((range, index) => {
            if (!range.name || !range.start || !range.end) {
                errors.push(`Rango ${index}: Faltan propiedades requeridas (name, start, end)`);
                return;
            }

            const startNum = this.ipToNumber(range.start);
            const endNum = this.ipToNumber(range.end);
            
            if (startNum >= endNum) {
                errors.push(`Rango ${range.name}: IP inicial (${range.start}) debe ser menor que IP final (${range.end})`);
            }

            const ipRegex = /^(\d{1,3}\.){3}\d{1,3}$/;
            if (!ipRegex.test(range.start)) {
                errors.push(`Rango ${range.name}: IP inicial invalida (${range.start})`);
            }
            if (!ipRegex.test(range.end)) {
                errors.push(`Rango ${range.name}: IP final invalida (${range.end})`);
            }
        });

        return {
            valid: errors.length === 0,
            errors
        };
    }
}

// Instancia global del validador
const globalValidator = new IPValidator({
    cacheTtl: 300000, // 5 minutos
    debugMode: process.env.NODE_ENV !== 'production',
    logAttempts: true
});

// Funcion publica para validacion simple
function validateClientIP(clientIP, config = {}) {
    return globalValidator.validateIP(clientIP, config);
}

// Middleware para Express.js
function createIPFilterMiddleware(config = {}) {
    return (req, res, next) => {
        const clientIP = (req.ip || 
                         req.connection.remoteAddress || 
                         req.socket.remoteAddress ||
                         req.headers['x-forwarded-for'] ||
                         req.headers['x-real-ip'] ||
                         '').replace(/^::ffff:/, '');

        const result = globalValidator.validateIP(clientIP, config);

        if (result.allowed) {
            req.ipValidation = result;
            next();
        } else {
            res.status(403).json({
                error: 'Acceso denegado. IP no autorizada.',
                details: {
                    ip: clientIP,
                    method: result.method,
                    timestamp: result.timestamp
                }
            });
        }
    };
}

module.exports = {
    IPValidator,
    validateClientIP,
    createIPFilterMiddleware,
    CORPORATE_DHCP_RANGES,
    globalValidator
};
