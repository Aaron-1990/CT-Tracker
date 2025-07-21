// config/security.js
const environment = require('./environment');

// Middleware de filtrado por IP
const ipFilterMiddleware = (req, res, next) => {
    const clientIP = (req.ip || req.connection.remoteAddress || '').replace(/^::ffff:/, '');
    const allowedIPs = environment.SECURITY.ALLOWED_IPS;

    if (allowedIPs.includes(clientIP)) {
        next();
    } else {
        console.log(`[${new Date().toISOString()}] Acceso denegado desde IP: ${clientIP}`);
        res.status(403).json({
            error: 'Acceso denegado. IP no autorizada.',
            timestamp: new Date().toISOString()
        });
    }
};

// Configuración de CORS
const corsOptions = {
    origin: function (origin, callback) {
        if (!origin) return callback(null, true);

        const allowedOrigins = [
            'http://localhost:3000',
            'http://127.0.0.1:3000',
            ...environment.SECURITY.ALLOWED_IPS.map(ip => `http://${ip}:3000`)
        ];

        if (allowedOrigins.includes(origin)) {
            callback(null, true);
        } else {
            callback(new Error('No permitido por CORS'));
        }
    },
    credentials: true
};

module.exports = {
    ipFilterMiddleware,
    corsOptions
};
