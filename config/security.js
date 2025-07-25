// config/security.js
const environment = require('./environment');

// Middleware de filtrado por IP
const ipFilterMiddleware = (req, res, next) => {
    const clientIP = (req.ip || req.connection.remoteAddress || '').replace(/^::ffff:/, '');
    const allowedIPs = environment.SECURITY.ALLOWED_IPS;

    // TEMPORAL: Debug para ver qué IP llega y qué IPs están permitidas
    console.log(`DEBUG: IP detectada: "${clientIP}"`);
    console.log(`DEBUG: IPs permitidas: [${allowedIPs.map(ip => `"${ip}"`).join(', ')}]`);
    console.log(`DEBUG: Coincidencia: ${allowedIPs.includes(clientIP)}`);

    if (allowedIPs.includes(clientIP)) {
        console.log(`[${new Date().toISOString()}] Acceso permitido desde IP: ${clientIP}`);
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
            'http://localhost:3001',
            'http://127.0.0.1:3001',
            'http://10.42.126.12:3001',
            ...environment.SECURITY.ALLOWED_IPS.map(ip => `http://${ip}:3001`)
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
