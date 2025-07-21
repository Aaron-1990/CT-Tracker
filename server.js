// =============================================================================
// server.js - Servidor principal VSM (Value Stream Map)
// =============================================================================

const express = require('express');
const path = require('path');
const morgan = require('morgan');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const http = require('http');
const WebSocket = require('ws');

// Configuración
const environment = require('./config/environment');
const logger = require('./config/logger');
const { ipFilterMiddleware, corsOptions } = require('./config/security');
const database = require('./config/database');

// Crear aplicación Express
const app = express();
const server = http.createServer(app);

// =============================================================================
// MIDDLEWARE DE SEGURIDAD Y CONFIGURACIÓN
// =============================================================================

// Helmet para headers de seguridad
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
            imgSrc: ["'self'", "data:", "https:"],
            connectSrc: ["'self'", "ws:", "wss:"],
        },
    },
}));

// Compresión
app.use(compression());

// CORS
app.use(cors(corsOptions));

// Logging de requests
app.use(morgan('combined', {
    stream: {
        write: (message) => logger.info(message.trim())
    }
}));

// Parseo de JSON y formularios
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Configurar IP del cliente
app.set('trust proxy', true);

// Middleware de filtrado por IP
app.use(ipFilterMiddleware);

// Servir archivos estáticos
app.use(express.static(path.join(__dirname, 'public')));

// =============================================================================
// WEBSOCKET PARA TIEMPO REAL
// =============================================================================

let wss = null;
if (environment.WEBSOCKET.ENABLED) {
    wss = new WebSocket.Server({ 
        server, 
        path: '/ws'
    });

    wss.on('connection', (ws, req) => {
        const clientIP = req.socket.remoteAddress?.replace(/^::ffff:/, '');
        logger.info(`WebSocket conectado desde: ${clientIP}`);

        ws.on('message', (message) => {
            try {
                const data = JSON.parse(message);
                logger.debug('WebSocket mensaje recibido:', data);
                
                // Aquí se puede manejar diferentes tipos de mensajes
                switch (data.type) {
                    case 'subscribe':
                        ws.subscriptions = data.channels || [];
                        ws.send(JSON.stringify({
                            type: 'subscribed',
                            channels: ws.subscriptions
                        }));
                        break;
                    case 'ping':
                        ws.send(JSON.stringify({ type: 'pong' }));
                        break;
                }
            } catch (error) {
                logger.error('Error procesando mensaje WebSocket:', error);
            }
        });

        ws.on('close', () => {
            logger.info(`WebSocket desconectado: ${clientIP}`);
        });

        ws.on('error', (error) => {
            logger.error('Error en WebSocket:', error);
        });

        // Enviar mensaje de bienvenida
        ws.send(JSON.stringify({
            type: 'welcome',
            server: 'VSM Production Monitoring',
            timestamp: new Date().toISOString()
        }));
    });

    // Función para broadcast a todos los clientes conectados
    global.broadcastToClients = (data) => {
        if (!wss) return;
        
        wss.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify(data));
            }
        });
    };

    logger.info('✅ WebSocket Server iniciado en /ws');
}

// =============================================================================
// RUTAS DE LA API
// =============================================================================

// Rutas de salud del sistema
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: process.env.npm_package_version || '2.0.0',
        environment: environment.NODE_ENV,
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        websocket: environment.WEBSOCKET.ENABLED ? 'enabled' : 'disabled'
    });
});

// API de estado del servidor
app.get('/api/status', (req, res) => {
    res.json({
        status: 'online',
        timestamp: new Date(),
        server: require('os').hostname(),
        nodejs: process.version,
        environment: environment.NODE_ENV,
        database: 'connected', // TODO: verificar conexión real
        clients: wss ? wss.clients.size : 0
    });
});

// =============================================================================
// RUTAS PRINCIPALES
// =============================================================================

// Ruta principal - Dashboard VSM
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'dashboard', 'index.html'));
});

// Panel de administración
app.get('/admin', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'admin', 'index.html'));
});

// Constructor de líneas de producción
app.get('/admin/line-builder', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'admin', 'line-builder.html'));
});

// Vista específica de Value Stream Map
app.get('/vsm/:lineCode', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'dashboard', 'value-stream-map.html'));
});

// =============================================================================
// RUTAS DE LA API REST
// =============================================================================

// TODO: Implementar controladores de la API
// app.use('/api/admin', require('./src/presentation/routes/admin'));
// app.use('/api/public', require('./src/presentation/routes/public'));

// Placeholder para las rutas principales de la API
app.get('/api/production-lines', (req, res) => {
    res.json({
        message: 'API de líneas de producción - Pendiente de implementar',
        timestamp: new Date().toISOString()
    });
});

app.get('/api/vsm/:lineCode', (req, res) => {
    const { lineCode } = req.params;
    res.json({
        message: `VSM para línea ${lineCode} - Pendiente de implementar`,
        lineCode,
        timestamp: new Date().toISOString()
    });
});

// =============================================================================
// MANEJO DE ERRORES
// =============================================================================

// Middleware para rutas no encontradas
app.use((req, res) => {
    res.status(404).json({
        error: 'Ruta no encontrada',
        path: req.path,
        method: req.method,
        timestamp: new Date().toISOString()
    });
});

// Middleware de manejo de errores
app.use((err, req, res, next) => {
    logger.error('Error no manejado:', {
        error: err.message,
        stack: err.stack,
        url: req.url,
        method: req.method,
        ip: req.ip
    });

    res.status(err.status || 500).json({
        error: environment.NODE_ENV === 'production' 
            ? 'Error interno del servidor' 
            : err.message,
        timestamp: new Date().toISOString()
    });
});

// =============================================================================
// INICIO DEL SERVIDOR
// =============================================================================

// Verificar conexión a la base de datos
async function checkDatabaseConnection() {
    try {
        await database.query('SELECT NOW()');
        logger.info('✅ Conexión a PostgreSQL verificada');
        return true;
    } catch (error) {
        logger.error('❌ Error conectando a PostgreSQL:', error.message);
        return false;
    }
}

// Iniciar servidor
async function startServer() {
    try {
        // Verificar base de datos
        const dbConnected = await checkDatabaseConnection();
        if (!dbConnected && environment.NODE_ENV === 'production') {
            logger.error('💥 No se puede iniciar sin conexión a la base de datos');
            process.exit(1);
        }

        // Iniciar servidor HTTP
        server.listen(environment.PORT, '0.0.0.0', () => {
            logger.info(`🚀 Servidor VSM iniciado en puerto ${environment.PORT}`);
            logger.info(`🌍 Entorno: ${environment.NODE_ENV}`);
            
            // Mostrar IPs de acceso
            const interfaces = require('os').networkInterfaces();
            const addresses = [];
            for (const networkInterface of Object.values(interfaces)) {
                for (const iface of networkInterface) {
                    if (iface.family === 'IPv4' && !iface.internal) {
                        addresses.push(iface.address);
                    }
                }
            }
            
            if (addresses.length > 0) {
                logger.info(`🔗 Acceso desde red local: http://${addresses[0]}:${environment.PORT}`);
            }
            
            logger.info(`🔒 IPs permitidas: ${environment.SECURITY.ALLOWED_IPS.join(', ')}`);
            
            if (environment.WEBSOCKET.ENABLED) {
                logger.info(`⚡ WebSocket habilitado en ws://localhost:${environment.PORT}/ws`);
            }
        });

    } catch (error) {
        logger.error('💥 Error iniciando servidor:', error);
        process.exit(1);
    }
}

// Manejo de señales del sistema
process.on('SIGTERM', () => {
    logger.info('🛑 SIGTERM recibido, cerrando servidor...');
    server.close(() => {
        logger.info('✅ Servidor cerrado correctamente');
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    logger.info('🛑 SIGINT recibido, cerrando servidor...');
    server.close(() => {
        logger.info('✅ Servidor cerrado correctamente');
        process.exit(0);
    });
});

// Manejo de errores no capturados
process.on('uncaughtException', (error) => {
    logger.error('💥 Excepción no capturada:', error);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    logger.error('💥 Promise rechazada no manejada:', { reason, promise });
    process.exit(1);
});

// Iniciar el servidor
startServer();

module.exports = { app, server, wss };