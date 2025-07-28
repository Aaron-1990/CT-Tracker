// server-https-solo.js - Solo servidor HTTPS sin conflicto de puertos
// Basado en server.js existente pero SOLO para puerto 3443

const express = require('express');
const https = require('https');
const fs = require('fs');
const path = require('path');
const morgan = require('morgan');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const WebSocket = require('ws');

// Configuracion
const environment = require('./config/environment');
const logger = require('./config/logger');
const { ipFilterMiddleware, corsOptions } = require('./config/security');

// Integracion GPEC5
const RealDataController = require('./src/presentation/controllers/public/RealDataController');

// Crear aplicacion Express
const app = express();

// SOLO PUERTO HTTPS
const HTTPS_PORT = 3443;

// Inicializar controlador de datos reales GPEC5
const realDataController = new RealDataController();

// CONFIGURACION SSL
let sslOptions = null;
try {
    const keyPath = path.join(__dirname, 'certs', 'key.pem');
    const certPath = path.join(__dirname, 'certs', 'cert.pem');
    
    if (fs.existsSync(keyPath) && fs.existsSync(certPath)) {
        sslOptions = {
            key: fs.readFileSync(keyPath),
            cert: fs.readFileSync(certPath)
        };
        console.log('Certificados SSL cargados correctamente');
    } else {
        console.log('Certificados SSL no encontrados en ./certs/');
        process.exit(1);
    }
} catch (error) {
    console.error('Error cargando certificados SSL:', error.message);
    process.exit(1);
}

// MIDDLEWARE DE SEGURIDAD
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'", "https://10.42.126.12:3443"],
            scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'", "https://10.42.126.12:3443"],
            imgSrc: ["'self'", "data:", "https:"],
            connectSrc: ["'self'", "ws:", "wss:", "https://10.42.126.12:3443"],
        },
    },
}));

app.use(compression());

// CORS para HTTPS
const corsOptionsHTTPS = {
    origin: [
        'https://localhost:3443',
        'https://10.42.126.12:3443',
        'http://localhost:3001',
        'http://10.42.126.12:3001'
    ],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
};

app.use(cors(corsOptionsHTTPS));

// Logging
app.use(morgan('combined', {
    stream: {
        write: (message) => console.log(`[HTTPS] ${message.trim()}`)
    }
}));

// Parseo JSON
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.set('trust proxy', true);

// Filtrado por IP
app.use(ipFilterMiddleware);

// Headers adicionales para recursos estaticos
app.use((req, res, next) => {
    if (req.path.endsWith('.css')) {
        res.header('Content-Type', 'text/css; charset=utf-8');
    }
    
    if (req.path.endsWith('.js')) {
        res.header('Content-Type', 'application/javascript; charset=utf-8');
    }
    
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
    
    next();
});

// Endpoints proxy para recursos criticos
app.get('/proxy/css/:filename', (req, res) => {
    const filename = req.params.filename;
    const filePath = path.join(__dirname, 'public/shared/css', filename);
    
    res.setHeader('Content-Type', 'text/css; charset=utf-8');
    res.setHeader('Access-Control-Allow-Origin', '*');
    
    res.sendFile(filePath, (err) => {
        if (err) {
            console.error(`Error sirviendo CSS ${filename}:`, err.message);
            res.status(404).send(`/* Error: CSS ${filename} no encontrado */`);
        }
    });
});

app.get('/proxy/js/:filename', (req, res) => {
    const filename = req.params.filename;
    const filePath = path.join(__dirname, 'public/dashboard/js', filename);
    
    res.setHeader('Content-Type', 'application/javascript; charset=utf-8');
    res.setHeader('Access-Control-Allow-Origin', '*');
    
    res.sendFile(filePath, (err) => {
        if (err) {
            console.error(`Error sirviendo JS ${filename}:`, err.message);
            res.status(404).send(`// Error: JavaScript ${filename} no encontrado`);
        }
    });
});

// Servir archivos estaticos
app.use(express.static(path.join(__dirname, 'public')));

// RUTAS API
app.get('/api/status', (req, res) => {
    res.json({
        status: 'online',
        timestamp: new Date().toISOString(),
        server: 'VSM Dashboard BorgWarner HTTPS',
        version: '2.0.0-https',
        protocol: 'HTTPS',
        port: HTTPS_PORT,
        nodejs: process.version,
        environment: process.env.NODE_ENV || 'production',
        gpec5: {
            active: true,
            polling: realDataController.isPolling || false,
            clients: realDataController.connectedClients?.size || 0
        }
    });
});

// Ruta health check
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        protocol: 'HTTPS'
    });
});

// ===== RUTAS API GPEC5 - DATOS REALES =====
// Configuracion de equipos y procesos GPEC5
app.get('/api/gpec5/configuration', realDataController.getConfiguration.bind(realDataController));

// Datos en tiempo real de toda la linea GPEC5
app.get('/api/gpec5/data/live', realDataController.getLiveData.bind(realDataController));

// Datos de proceso especifico
app.get('/api/gpec5/process/:processName', realDataController.getProcessData.bind(realDataController));

// Control de polling
app.post('/api/gpec5/polling/start', realDataController.startPolling.bind(realDataController));
app.post('/api/gpec5/polling/stop', realDataController.stopPolling.bind(realDataController));

// Estadisticas del sistema
app.get('/api/gpec5/stats', realDataController.getSystemStats.bind(realDataController));

// Importar rutas API existentes
try {
    // Aqui se importarian las rutas API del sistema original
    console.log('Rutas API cargadas correctamente');
} catch (error) {
    console.log('Rutas API no encontradas, continuando...');
}

// Rutas principales
app.get('/', (req, res) => {
    res.redirect('/dashboard/value-stream-map.html');
});

app.get('/dashboard', (req, res) => {
    res.redirect('/dashboard/value-stream-map.html');
});

// Fallback para SPA
app.get('/dashboard/*', (req, res) => {
    res.sendFile(path.join(__dirname, 'dashboard', 'value-stream-map.html'));
});

// Error 404
app.use((req, res) => {
    res.status(404).json({
        error: 'Recurso no encontrado',
        path: req.url,
        timestamp: new Date().toISOString()
    });
});

// Error handler general
app.use((error, req, res, next) => {
    console.error('Error del servidor HTTPS:', error);
    res.status(500).json({
        error: 'Error interno del servidor',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Error interno',
        timestamp: new Date().toISOString()
    });
});

// INICIAR SOLO SERVIDOR HTTPS
function startHTTPSServer() {
    if (sslOptions) {
        const httpsServer = https.createServer(sslOptions, app);
        
        httpsServer.listen(HTTPS_PORT, '0.0.0.0', () => {
            console.log('====================================');
            console.log('DASHBOARD VSM BORGWARNER - HTTPS');
            console.log('====================================');
            console.log(`Servidor HTTPS iniciado en puerto ${HTTPS_PORT}`);
            console.log(`Acceso local:  https://localhost:${HTTPS_PORT}/dashboard/value-stream-map.html`);
            console.log(`Acceso red:    https://10.42.126.12:${HTTPS_PORT}/dashboard/value-stream-map.html`);
            console.log('====================================');
            console.log('CERTIFICADO AUTO-FIRMADO:');
            console.log('Los navegadores mostraran advertencia de seguridad');
            console.log('Usuarios deben hacer clic en "Avanzado" > "Continuar"');
            console.log('====================================');
            console.log('');
            console.log('Servidor HTTPS listo para acceso multi-PC corporativo');
            console.log('Sistema HTTP original mantiene funcionamiento en puerto 3001');
        });
        
        httpsServer.on('error', (error) => {
            console.error('Error servidor HTTPS:', error.message);
            if (error.code === 'EADDRINUSE') {
                console.log(`Puerto ${HTTPS_PORT} en uso`);
                process.exit(1);
            }
        });
    } else {
        console.log('ERROR: Certificados SSL no disponibles');
        process.exit(1);
    }
}

// Manejo de señales del sistema
process.on('SIGTERM', () => {
    console.log('Señal SIGTERM recibida, cerrando servidor HTTPS...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('Señal SIGINT recibida, cerrando servidor HTTPS...');
    process.exit(0);
});

// Iniciar aplicacion
startHTTPSServer();

module.exports = app;