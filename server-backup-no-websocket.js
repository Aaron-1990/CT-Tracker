// =============================================================================
// server.js - Servidor principal VSM (Value Stream Map) - CON INTEGRACIÓN GPEC5
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

// ===== INTEGRACIÓN GPEC5 =====
const RealDataController = require('./src/presentation/controllers/public/RealDataController');

// Crear aplicación Express
const app = express();
const server = http.createServer(app);

// Inicializar controlador de datos reales GPEC5
const realDataController = new RealDataController();

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
        websocket: environment.WEBSOCKET.ENABLED ? 'enabled' : 'disabled',
        gpec5: {
            polling: realDataController.isPolling || false,
            connectedClients: realDataController.connectedClients?.size || 0
        }
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
        clients: wss ? wss.clients.size : 0,
        gpec5: {
            active: true,
            polling: realDataController.isPolling || false,
            clients: realDataController.connectedClients?.size || 0
        }
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

// Dashboard VSM GPEC5
app.get('/gpec5', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'dashboard', 'value-stream-map.html'));
});

// =============================================================================
// RUTAS DE LA API REST
// =============================================================================

// ===== RUTAS API GPEC5 - DATOS REALES =====
// Configuración de equipos y procesos GPEC5
app.get('/api/gpec5/configuration', realDataController.getConfiguration.bind(realDataController));

// Datos en tiempo real de toda la línea GPEC5
app.get('/api/gpec5/data/live', realDataController.getLiveData.bind(realDataController));

// Datos de proceso específico
app.get('/api/gpec5/process/:processName', realDataController.getProcessData.bind(realDataController));

// Control de polling
app.post('/api/gpec5/polling/start', realDataController.startPolling.bind(realDataController));
app.post('/api/gpec5/polling/stop', realDataController.stopPolling.bind(realDataController));

// Estadísticas del sistema
app.get('/api/gpec5/stats', realDataController.getSystemStats.bind(realDataController));

// ===== RUTAS API GENERALES (EXISTENTES) =====
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

// =============================================================================
// WEBSOCKET GPEC5 Y INICIALIZACIÓN AUTOMÁTICA
// =============================================================================

// Crear servidor WebSocket adicional para GPEC5
let wssGPEC5 = null;
try {
    wssGPEC5 = new WebSocket.Server({ 
        port: parseInt(process.env.WEBSOCKET_PORT_GPEC5) || 3002,
        path: '/gpec5-realtime'
    });

    wssGPEC5.on('connection', (ws) => {
        realDataController.handleWebSocketConnection(ws);
    });

    logger.info(`🌐 WebSocket GPEC5 disponible en: ws://localhost:${parseInt(process.env.WEBSOCKET_PORT_GPEC5) || 3002}/gpec5-realtime`);
} catch (error) {
    logger.error('❌ Error iniciando WebSocket GPEC5:', error.message);
}

// Inicializar GPEC5 automáticamente después del arranque
setTimeout(async () => {
    try {
        logger.info('🚀 Iniciando polling automático GPEC5...');
        await realDataController.startPolling({ body: {} }, {
            json: (response) => {
                if (response && response.success) {
                    logger.info('✅ Polling GPEC5 iniciado automáticamente');
                } else {
                    logger.error('❌ Error iniciando polling:', response?.error || 'Error desconocido');
                }
            }
        });
    } catch (error) {
        logger.error('❌ Error en inicialización automática GPEC5:', error.message);
    }
}, 5000); // Esperar 5 segundos después del inicio del servidor

// Log de rutas GPEC5 configuradas
logger.info('🔗 Rutas GPEC5 configuradas:');
logger.info('   GET  /api/gpec5/configuration');
logger.info('   GET  /api/gpec5/data/live');
logger.info('   GET  /api/gpec5/process/:processName');
logger.info('   POST /api/gpec5/polling/start');
logger.info('   POST /api/gpec5/polling/stop');
logger.info('   GET  /api/gpec5/stats');

// =============================================================================
// MANEJO DE SEÑALES DEL SISTEMA
// =============================================================================

// Manejo de señales del sistema
process.on('SIGTERM', () => {
    logger.info('🛑 SIGTERM recibido, cerrando servidor...');
    realDataController.cleanup();
    if (wssGPEC5) wssGPEC5.close();
    server.close(() => {
        logger.info('✅ Servidor cerrado correctamente');
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    logger.info('🛑 SIGINT recibido, cerrando servidor...');
    realDataController.cleanup();
    if (wssGPEC5) wssGPEC5.close();
    server.close(() => {
        logger.info('✅ Servidor cerrado correctamente');
        process.exit(0);
    });
});

// Manejo de errores no capturados
process.on('uncaughtException', (error) => {
    logger.error('💥 Excepción no capturada:', error);
    realDataController.cleanup();
    if (wssGPEC5) wssGPEC5.close();
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    logger.error('💥 Promise rechazada no manejada:', { reason, promise });
    realDataController.cleanup();
    if (wssGPEC5) wssGPEC5.close();
    process.exit(1);
});

// Iniciar el servidor
startServer();

module.exports = { app, server, wss, realDataController, wssGPEC5 };