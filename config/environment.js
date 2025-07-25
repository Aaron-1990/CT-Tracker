// config/environment.js - Variables de entorno
require('dotenv').config();

const environment = {
    // Servidor
    NODE_ENV: process.env.NODE_ENV || 'development',
    PORT: parseInt(process.env.PORT) || 3000,
    
    // Base de datos
    DATABASE: {
        HOST: process.env.DB_HOST || 'localhost',
        PORT: parseInt(process.env.DB_PORT) || 5432,
        NAME: process.env.DB_NAME || 'vsm_production',
        USER: process.env.DB_USER || 'postgres',
        PASSWORD: process.env.DB_PASSWORD || 'password',
        SSL: process.env.DB_SSL === 'true'
    },
    
    // Seguridad
    SECURITY: {
        ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,10.42.126.12,10.43.126.200').split(','),
        SESSION_SECRET: process.env.SESSION_SECRET || 'vsm-secret-key-change-in-production'
    },

    // VSM Settings
    VSM: {
        OUTLIER_DETECTION: {
            STANDARD_DEVIATION_MULTIPLIER: parseFloat(process.env.OUTLIER_STD_MULTIPLIER) || 2.0,
            MINIMUM_SAMPLE_SIZE: parseInt(process.env.OUTLIER_MIN_SAMPLES) || 5,
            MAX_OUTLIER_PERCENTAGE: parseFloat(process.env.OUTLIER_MAX_PERCENTAGE) || 25
        },
        CSV_POLLING: {
            DEFAULT_INTERVAL_SECONDS: parseInt(process.env.CSV_POLLING_INTERVAL) || 30,
            TIMEOUT_SECONDS: parseInt(process.env.CSV_TIMEOUT) || 10,
            MAX_RETRIES: parseInt(process.env.CSV_MAX_RETRIES) || 3
        },
        CALCULATIONS: {
            HOURLY_CALCULATION_CRON: process.env.HOURLY_CALC_CRON || '0 * * * *',
            STATISTICAL_UPDATE_CRON: process.env.STATS_UPDATE_CRON || '*/5 * * * *',
            MAINTENANCE_CRON: process.env.MAINTENANCE_CRON || '0 2 * * *'
        }
    },

    // Logging
    LOGGING: {
        LEVEL: process.env.LOG_LEVEL || 'info',
        FILE_ENABLED: process.env.LOG_FILE_ENABLED === 'true',
        FILE_PATH: process.env.LOG_FILE_PATH || './logs/app.log'
    },

    // WebSocket
    WEBSOCKET: {
        ENABLED: process.env.WEBSOCKET_ENABLED !== 'false',
        PORT: parseInt(process.env.WEBSOCKET_PORT) || 3001
    }
};

module.exports = environment;
