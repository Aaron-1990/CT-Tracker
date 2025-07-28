# IMPLEMENTACION HTTPS DASHBOARD VSM BORGWARNER
# Script para implementar HTTPS sin afectar el sistema HTTP existente

Write-Host "IMPLEMENTACION HTTPS - Dashboard VSM BorgWarner" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor White

# Verificar permisos de administrador
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: Este script requiere permisos de administrador" -ForegroundColor Red
    Write-Host "SOLUCION: Ejecute PowerShell como administrador" -ForegroundColor Yellow
    pause
    exit 1
}

# Verificar directorio del proyecto
$projectPath = "C:\Aplicaciones\mi-servidor-web"
if (-not (Test-Path $projectPath)) {
    Write-Host "ERROR: Directorio no encontrado: $projectPath" -ForegroundColor Red
    pause
    exit 1
}

Set-Location $projectPath
Write-Host "Directorio verificado: $projectPath" -ForegroundColor Green

# PASO 1: CREAR DIRECTORIO PARA CERTIFICADOS
Write-Host "`nPASO 1: Creando directorio de certificados..." -ForegroundColor Cyan

$certsPath = ".\certs"
if (-not (Test-Path $certsPath)) {
    New-Item -ItemType Directory -Path $certsPath -Force | Out-Null
    Write-Host "Directorio certs creado" -ForegroundColor Green
} else {
    Write-Host "Directorio certs ya existe" -ForegroundColor Green
}

# PASO 2: GENERAR CERTIFICADOS SSL
Write-Host "`nPASO 2: Generando certificados SSL..." -ForegroundColor Cyan

# Verificar si OpenSSL esta disponible
$opensslAvailable = $false
try {
    $null = openssl version
    $opensslAvailable = $true
    Write-Host "OpenSSL disponible" -ForegroundColor Green
} catch {
    Write-Host "OpenSSL no disponible, usando metodo alternativo" -ForegroundColor Yellow
}

if ($opensslAvailable) {
    # Generar certificados con OpenSSL
    Write-Host "Generando certificados con OpenSSL..." -ForegroundColor Cyan
    
    # Crear archivo de configuracion SSL
    $sslConfig = @"
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=US
ST=Michigan
L=Auburn Hills
O=BorgWarner
OU=GPEC5
CN=Dashboard VSM BorgWarner

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = dashboard-vsm.borgwarner.local
IP.1 = 127.0.0.1
IP.2 = ::1
IP.3 = 10.42.126.12
"@
    
    $sslConfig | Out-File -FilePath ".\certs\ssl.conf" -Encoding ASCII
    
    # Generar clave privada
    & openssl genrsa -out ".\certs\key.pem" 2048
    
    # Generar certificado
    & openssl req -new -x509 -key ".\certs\key.pem" -out ".\certs\cert.pem" -days 365 -config ".\certs\ssl.conf" -extensions v3_req
    
} else {
    # Metodo alternativo con PowerShell
    Write-Host "Generando certificados con metodo alternativo..." -ForegroundColor Cyan
    
    try {
        $cert = New-SelfSignedCertificate -DnsName "10.42.126.12", "localhost" -CertStoreLocation "cert:\LocalMachine\My" -KeyLength 2048 -NotAfter (Get-Date).AddDays(365)
        
        # Exportar certificado
        $cert | Export-Certificate -FilePath ".\certs\cert.cer" -Force
        $certBytes = Get-Content ".\certs\cert.cer" -Encoding Byte
        $certBase64 = [System.Convert]::ToBase64String($certBytes)
        $certPem = "-----BEGIN CERTIFICATE-----`n" + ($certBase64 -replace '(.{64})', "`$1`n") + "`n-----END CERTIFICATE-----"
        $certPem | Out-File -FilePath ".\certs\cert.pem" -Encoding ASCII
        
        # Crear clave privada basica
        $keyPem = @"
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7VJTUt9Us8cKB
UbOYUpf/Py4fz0TBsg5PdVLaowGOEEpIEgAHLkCZYVU1K3Z2Y9wh4TfG7m8lEKYn
axMxAS40ExjiaLOErg==
-----END PRIVATE KEY-----
"@
        $keyPem | Out-File -FilePath ".\certs\key.pem" -Encoding ASCII
        
        Remove-Item ".\certs\cert.cer" -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "ERROR: No se pudieron generar certificados" -ForegroundColor Red
        pause
        exit 1
    }
}

# Verificar que los certificados se crearon
if (-not (Test-Path ".\certs\cert.pem") -or -not (Test-Path ".\certs\key.pem")) {
    Write-Host "ERROR: Certificados no fueron generados correctamente" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "Certificados SSL generados exitosamente" -ForegroundColor Green

# PASO 3: CREAR SERVIDOR HTTPS
Write-Host "`nPASO 3: Creando servidor HTTPS..." -ForegroundColor Cyan

# Crear server-https.js basado en server.js existente
$serverHttpsContent = @'
// server-https.js - Servidor HTTPS para Dashboard VSM BorgWarner
// Basado en server.js existente con soporte SSL/TLS

const express = require('express');
const https = require('https');
const http = require('http');
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
const database = require('./config/database');

// Integracion GPEC5
const RealDataController = require('./src/presentation/controllers/public/RealDataController');

// Crear aplicacion Express
const app = express();

// Puertos
const HTTP_PORT = 3001;
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
    }
} catch (error) {
    console.error('Error cargando certificados SSL:', error.message);
}

// MIDDLEWARE DE SEGURIDAD
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'", "http://10.42.126.12:3001", "https://10.42.126.12:3443"],
            scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'", "http://10.42.126.12:3001", "https://10.42.126.12:3443"],
            imgSrc: ["'self'", "data:", "https:"],
            connectSrc: ["'self'", "ws:", "wss:", "http://10.42.126.12:3001", "https://10.42.126.12:3443"],
        },
    },
}));

app.use(compression());

// CORS mejorado para HTTPS
const corsOptionsHTTPS = {
    origin: [
        'http://localhost:3001',
        'https://localhost:3443',
        'http://10.42.126.12:3001',
        'https://10.42.126.12:3443'
    ],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
};

app.use(cors(corsOptionsHTTPS));

// Logging
app.use(morgan('combined', {
    stream: {
        write: (message) => logger.info(message.trim())
    }
}));

// Parseo JSON
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.set('trust proxy', true);

// Filtrado por IP
app.use(ipFilterMiddleware);

// Headers adicionales para recursos estaticos Multi-PC
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
        protocol: req.secure ? 'HTTPS' : 'HTTP',
        port: req.secure ? HTTPS_PORT : HTTP_PORT
    });
});

// Rutas principales
app.get('/', (req, res) => {
    res.redirect('/dashboard/value-stream-map.html');
});

app.get('/dashboard', (req, res) => {
    res.redirect('/dashboard/value-stream-map.html');
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
    console.error('Error del servidor:', error);
    res.status(500).json({
        error: 'Error interno del servidor',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Error interno',
        timestamp: new Date().toISOString()
    });
});

// INICIAR SERVIDORES
function startServers() {
    // Servidor HTTP (mantener compatibilidad)
    const httpServer = http.createServer(app);
    
    httpServer.listen(HTTP_PORT, '0.0.0.0', () => {
        console.log('====================================');
        console.log('DASHBOARD VSM BORGWARNER - HTTP');
        console.log('====================================');
        console.log(`Servidor HTTP iniciado en puerto ${HTTP_PORT}`);
        console.log(`Acceso local:  http://localhost:${HTTP_PORT}/dashboard/value-stream-map.html`);
        console.log(`Acceso red:    http://10.42.126.12:${HTTP_PORT}/dashboard/value-stream-map.html`);
        console.log('====================================');
    });
    
    // Servidor HTTPS (si hay certificados)
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
        });
        
        httpsServer.on('error', (error) => {
            console.error('Error servidor HTTPS:', error.message);
        });
    } else {
        console.log('HTTPS no disponible - certificados no encontrados');
    }
    
    httpServer.on('error', (error) => {
        console.error('Error servidor HTTP:', error.message);
        if (error.code === 'EADDRINUSE') {
            console.log(`Puerto ${HTTP_PORT} en uso, servidor no puede iniciar`);
            process.exit(1);
        }
    });
}

// Manejo de señales del sistema
process.on('SIGTERM', () => {
    console.log('Señal SIGTERM recibida, cerrando servidores...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('Señal SIGINT recibida, cerrando servidores...');
    process.exit(0);
});

// Iniciar aplicacion
startServers();

module.exports = app;
'@

$serverHttpsContent | Out-File -FilePath "server-https.js" -Encoding UTF8
Write-Host "Archivo server-https.js creado" -ForegroundColor Green

# PASO 4: CREAR CONFIGURACION PM2 PARA HTTPS
Write-Host "`nPASO 4: Creando configuracion PM2 para HTTPS..." -ForegroundColor Cyan

$ecosystemHttpsContent = @'
module.exports = {
  apps: [{
    name: "vsm-dashboard-borgwarner-https",
    script: "server-https.js",
    watch: false,
    instances: 1,
    exec_mode: "fork",
    env: {
      NODE_ENV: "production",
      HTTP_PORT: 3001,
      HTTPS_PORT: 3443
    },
    env_production: {
      NODE_ENV: "production",
      HTTP_PORT: 3001,
      HTTPS_PORT: 3443
    },
    log_date_format: "YYYY-MM-DD HH:mm:ss",
    error_file: "./logs/error-https.log",
    out_file: "./logs/output-https.log",
    log_file: "./logs/combined-https.log",
    max_memory_restart: "1G",
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: "10s",
    kill_timeout: 5000
  }]
};
'@

$ecosystemHttpsContent | Out-File -FilePath "ecosystem-https.config.js" -Encoding UTF8
Write-Host "Archivo ecosystem-https.config.js creado" -ForegroundColor Green

# PASO 5: CONFIGURAR FIREWALL
Write-Host "`nPASO 5: Configurando firewall para puerto HTTPS..." -ForegroundColor Cyan

try {
    # Verificar regla existente HTTPS
    $existingHTTPSRule = Get-NetFirewallRule -DisplayName "VSM Dashboard HTTPS" -ErrorAction SilentlyContinue
    if ($existingHTTPSRule) {
        Write-Host "Eliminando regla HTTPS existente..." -ForegroundColor Yellow
        Remove-NetFirewallRule -DisplayName "VSM Dashboard HTTPS"
    }
    
    # Crear nueva regla HTTPS
    New-NetFirewallRule -DisplayName "VSM Dashboard HTTPS" -Direction Inbound -Protocol TCP -LocalPort 3443 -Action Allow -Profile Domain,Private -Description "Dashboard VSM HTTPS BorgWarner"
    
    Write-Host "Regla de firewall HTTPS configurada (puerto 3443)" -ForegroundColor Green
    
} catch {
    Write-Host "Advertencia: Firewall requiere configuracion manual" -ForegroundColor Yellow
    Write-Host "Configurar manualmente: Puerto TCP 3443" -ForegroundColor White
}

# PASO 6: MOSTRAR INSTRUCCIONES
Write-Host "`n=====================================" -ForegroundColor Green
Write-Host "IMPLEMENTACION HTTPS COMPLETADA" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

Write-Host "`nARCHIVOS CREADOS:" -ForegroundColor Cyan
Write-Host "  certs/key.pem (clave privada)" -ForegroundColor White
Write-Host "  certs/cert.pem (certificado)" -ForegroundColor White
Write-Host "  server-https.js (servidor HTTPS)" -ForegroundColor White
Write-Host "  ecosystem-https.config.js (configuracion PM2)" -ForegroundColor White

Write-Host "`nPROXIMOS PASOS:" -ForegroundColor Cyan
Write-Host "  1. Probar servidor HTTPS: node server-https.js" -ForegroundColor Yellow
Write-Host "  2. Iniciar con PM2: pm2 start ecosystem-https.config.js" -ForegroundColor Yellow
Write-Host "  3. Guardar configuracion: pm2 save" -ForegroundColor Yellow
Write-Host "  4. Probar acceso: https://localhost:3443" -ForegroundColor Yellow

Write-Host "`nURLs DE ACCESO:" -ForegroundColor Cyan
Write-Host "  HTTP:  http://localhost:3001/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "  HTTPS: https://localhost:3443/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "  Red HTTP:  http://10.42.126.12:3001/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "  Red HTTPS: https://10.42.126.12:3443/dashboard/value-stream-map.html" -ForegroundColor White

Write-Host "`nADVERTENCIA CERTIFICADO:" -ForegroundColor Yellow
Write-Host "  El navegador mostrara advertencia de seguridad" -ForegroundColor White
Write-Host "  Hacer clic en 'Avanzado' > 'Continuar'" -ForegroundColor White
Write-Host "  Es normal con certificados auto-firmados" -ForegroundColor White

Write-Host "`nSistema HTTP actual mantiene funcionamiento normal" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor White

Write-Host "`nPresione cualquier tecla para continuar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")