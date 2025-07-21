// config/logger.js
const winston = require('winston');
const path = require('path');

// Crear directorio de logs si no existe
const fs = require('fs');
const logDir = './logs';
if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
}

const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    transports: [
        new winston.transports.Console({
            format: winston.format.combine(
                winston.format.colorize(),
                winston.format.simple()
            )
        })
    ]
});

// Agregar archivo de log si está habilitado
if (process.env.LOG_FILE_ENABLED === 'true') {
    logger.add(new winston.transports.File({
        filename: process.env.LOG_FILE_PATH || './logs/app.log'
    }));
}

module.exports = logger;
