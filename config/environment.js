// =============================================================================
// config/environment.js - Configuracion de Variables de Entorno
// Dashboard VSM BorgWarner - ACTUALIZADO para soporte DHCP Ranges
// =============================================================================

require('dotenv').config();

function parseDHCPRanges(rangesString) {
    if (!rangesString || rangesString === 'default') {
        return [
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
    }

    try {
        return rangesString.split(',').map((range, index) => {
            const parts = range.trim().split('-');
            const start = parts[0];
            const end = parts[1];
            if (!start || !end) {
                throw new Error('Formato invalido en rango ' + (index + 1) + ': ' + range);
            }
            
            return {
                name: 'CustomRange' + (index + 1),
                description: 'Rango personalizado ' + (index + 1),
                start: start.trim(),
                end: end.trim(),
                enabled: true
            };
        });
    } catch (error) {
        console.warn('Error parseando rangos DHCP: ' + error.message + '. Usando rangos por defecto.');
        return parseDHCPRanges('default');
    }
}

const environment = {
    NODE_ENV: process.env.NODE_ENV || 'development',
    PORT: parseInt(process.env.PORT) || 3001,
    HTTPS_PORT: parseInt(process.env.HTTPS_PORT) || 3443,

    DATABASE: {
        HOST: process.env.DB_HOST || 'localhost',
        PORT: parseInt(process.env.DB_PORT) || 5432,
        NAME: process.env.DB_NAME || 'vsm_production',
        USER: process.env.DB_USER || 'postgres',
        PASSWORD: process.env.DB_PASSWORD || 'password',
        SSL: process.env.DB_SSL === 'true',
        MAX_CONNECTIONS: parseInt(process.env.DB_MAX_CONNECTIONS) || 20,
        IDLE_TIMEOUT: parseInt(process.env.DB_IDLE_TIMEOUT) || 30000,
        CONNECTION_TIMEOUT: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 2000
    },

    SECURITY: {
        IP_VALIDATION_MODE: process.env.IP_VALIDATION_MODE || 'hybrid',
        ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,::1,10.42.126.135').split(',').map(ip => ip.trim()),
        DHCP_RANGES: parseDHCPRanges(process.env.DHCP_RANGES),
        ENABLE_IP_CACHE: process.env.ENABLE_IP_CACHE !== 'false',
        IP_CACHE_TTL: parseInt(process.env.IP_CACHE_TTL) || 300000,
        LOG_IP_ATTEMPTS: process.env.LOG_IP_ATTEMPTS !== 'false',
        DEBUG_IP_VALIDATION: process.env.DEBUG_IP_VALIDATION === 'true' || process.env.NODE_ENV === 'development',
        BLOCK_REPEATED_ATTEMPTS: process.env.BLOCK_REPEATED_ATTEMPTS === 'true',
        ATTEMPT_THRESHOLD: parseInt(process.env.ATTEMPT_THRESHOLD) || 10,
        BLOCK_DURATION: parseInt(process.env.BLOCK_DURATION) || 3600000,
        CORS_ORIGINS: process.env.CORS_ORIGINS ? 
            process.env.CORS_ORIGINS.split(',').map(origin => origin.trim()) : 
            ['http://localhost:3001', 'https://localhost:3443']
    },

    LOGGING: {
        LEVEL: process.env.LOG_LEVEL || (process.env.NODE_ENV === 'production' ? 'info' : 'debug'),
        FILE_ENABLED: process.env.LOG_FILE_ENABLED === 'true',
        FILE_PATH: process.env.LOG_FILE_PATH || './logs/application.log',
        MAX_FILE_SIZE: process.env.LOG_MAX_FILE_SIZE || '10m',
        MAX_FILES: parseInt(process.env.LOG_MAX_FILES) || 5,
        IP_LOG_ENABLED: process.env.IP_LOG_ENABLED !== 'false',
        IP_LOG_PATH: process.env.IP_LOG_PATH || './logs/ip-access.log',
        FORMAT: process.env.LOG_FORMAT || 'combined',
        TIMESTAMP_FORMAT: process.env.LOG_TIMESTAMP_FORMAT || 'YYYY-MM-DD HH:mm:ss'
    },

    GPEC5: {
        HOST: process.env.GPEC5_HOST || '10.42.126.12',
        PORT: parseInt(process.env.GPEC5_PORT) || 3000,
        USERNAME: process.env.GPEC5_USERNAME || 'admin',
        PASSWORD: process.env.GPEC5_PASSWORD || 'admin',
        TIMEOUT: parseInt(process.env.GPEC5_TIMEOUT) || 5000,
        RETRY_ATTEMPTS: parseInt(process.env.GPEC5_RETRY_ATTEMPTS) || 3,
        RETRY_DELAY: parseInt(process.env.GPEC5_RETRY_DELAY) || 1000
    },

    WEBSOCKETS: {
        ENABLED: process.env.WS_ENABLED !== 'false',
        PORT: parseInt(process.env.WS_PORT) || 8080,
        HEARTBEAT_INTERVAL: parseInt(process.env.WS_HEARTBEAT_INTERVAL) || 30000,
        MAX_CONNECTIONS: parseInt(process.env.WS_MAX_CONNECTIONS) || 100
    },

    SSL: {
        ENABLED: process.env.SSL_ENABLED === 'true',
        CERT_PATH: process.env.SSL_CERT_PATH || './certs/cert.pem',
        KEY_PATH: process.env.SSL_KEY_PATH || './certs/key.pem',
        PASSPHRASE: process.env.SSL_PASSPHRASE || undefined
    },

    PERFORMANCE: {
        COMPRESSION_ENABLED: process.env.COMPRESSION_ENABLED !== 'false',
        COMPRESSION_LEVEL: parseInt(process.env.COMPRESSION_LEVEL) || 6,
        RATE_LIMIT_ENABLED: process.env.RATE_LIMIT_ENABLED === 'true',
        RATE_LIMIT_WINDOW: parseInt(process.env.RATE_LIMIT_WINDOW) || 900000,
        RATE_LIMIT_MAX: parseInt(process.env.RATE_LIMIT_MAX) || 100
    },

    VSM: {
        REFRESH_INTERVAL: parseInt(process.env.VSM_REFRESH_INTERVAL) || 5000,
        MAX_DATA_POINTS: parseInt(process.env.VSM_MAX_DATA_POINTS) || 1000,
        CACHE_DURATION: parseInt(process.env.VSM_CACHE_DURATION) || 60000,
        ENABLE_REAL_TIME: process.env.VSM_ENABLE_REAL_TIME !== 'false'
    }
};

function validateEnvironmentConfig() {
    const errors = [];
    
    if (!environment.SECURITY.ALLOWED_IPS || environment.SECURITY.ALLOWED_IPS.length === 0) {
        errors.push('SECURITY.ALLOWED_IPS no puede estar vacio');
    }
    
    if (!environment.SECURITY.DHCP_RANGES || environment.SECURITY.DHCP_RANGES.length === 0) {
        errors.push('SECURITY.DHCP_RANGES no puede estar vacio');
    }
    
    const validModes = ['static', 'ranges', 'hybrid'];
    if (!validModes.includes(environment.SECURITY.IP_VALIDATION_MODE)) {
        errors.push('SECURITY.IP_VALIDATION_MODE debe ser uno de: ' + validModes.join(', '));
    }
    
    if (environment.PORT === environment.HTTPS_PORT) {
        errors.push('PORT y HTTPS_PORT no pueden ser iguales');
    }
    
    if (environment.SSL.ENABLED) {
        const fs = require('fs');
        
        if (!fs.existsSync(environment.SSL.CERT_PATH)) {
            errors.push('Certificado SSL no encontrado: ' + environment.SSL.CERT_PATH);
        }
        
        if (!fs.existsSync(environment.SSL.KEY_PATH)) {
            errors.push('Clave SSL no encontrada: ' + environment.SSL.KEY_PATH);
        }
    }
    
    return {
        valid: errors.length === 0,
        errors
    };
}

function getIPValidationConfig() {
    return {
        mode: environment.SECURITY.IP_VALIDATION_MODE,
        allowedIPs: environment.SECURITY.ALLOWED_IPS,
        dhcpRanges: environment.SECURITY.DHCP_RANGES,
        enableCache: environment.SECURITY.ENABLE_IP_CACHE,
        cacheTtl: environment.SECURITY.IP_CACHE_TTL,
        debugMode: environment.SECURITY.DEBUG_IP_VALIDATION,
        logAttempts: environment.SECURITY.LOG_IP_ATTEMPTS
    };
}

function logConfigurationSummary() {
    if (environment.NODE_ENV === 'development') {
        console.log('');
        console.log('=== CONFIGURACION VSM DASHBOARD ===');
        console.log('Entorno: ' + environment.NODE_ENV);
        console.log('Puerto HTTP: ' + environment.PORT);
        console.log('Puerto HTTPS: ' + environment.HTTPS_PORT + ' (' + (environment.SSL.ENABLED ? 'Habilitado' : 'Deshabilitado') + ')');
        console.log('Modo validacion IP: ' + environment.SECURITY.IP_VALIDATION_MODE);
        console.log('IPs especificas: ' + environment.SECURITY.ALLOWED_IPS.length);
        console.log('Rangos DHCP: ' + environment.SECURITY.DHCP_RANGES.length);
        console.log('Cache IP: ' + (environment.SECURITY.ENABLE_IP_CACHE ? 'Habilitado' : 'Deshabilitado'));
        
        console.log('');
        console.log('Rangos DHCP Corporativos:');
        environment.SECURITY.DHCP_RANGES.forEach((range, index) => {
            console.log('   ' + (index + 1) + '. ' + range.name + ': ' + range.start + ' - ' + range.end + ' (' + (range.enabled ? 'Activo' : 'Inactivo') + ')');
        });
        
        console.log('=====================================');
        console.log('');
    }
}

const configValidation = validateEnvironmentConfig();
if (!configValidation.valid) {
    console.error('Error en configuracion del entorno:');
    configValidation.errors.forEach(error => console.error('   - ' + error));
    process.exit(1);
}

logConfigurationSummary();

module.exports = {
    ...environment,
    validateEnvironmentConfig,
    getIPValidationConfig,
    parseDHCPRanges
};
