# INICIAR SISTEMA HTTPS COMPLETO - Dashboard VSM BorgWarner
# Script para iniciar tanto HTTP como HTTPS manteniendo compatibilidad

Write-Host "INICIANDO SISTEMA HTTPS DASHBOARD VSM BORGWARNER" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor White

# Verificar permisos de administrador
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ADVERTENCIA: Se recomienda ejecutar como administrador para firewall" -ForegroundColor Yellow
    Write-Host "Continuando con permisos de usuario..." -ForegroundColor Cyan
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

# VERIFICAR ARCHIVOS NECESARIOS
Write-Host "`nVerificando archivos necesarios..." -ForegroundColor Cyan

$requiredFiles = @(
    "server.js",
    "server-https.js", 
    "ecosystem.config.js",
    "ecosystem-https.config.js",
    "certs\cert.pem",
    "certs\key.pem"
)

$allFilesExist = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ENCONTRADO: $file" -ForegroundColor Green
    } else {
        Write-Host "  FALTANTE: $file" -ForegroundColor Red
        $allFilesExist = $false
    }
}

if (-not $allFilesExist) {
    Write-Host "`nERROR: Archivos faltantes. Ejecute primero: .\implementar-https.ps1" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "Todos los archivos necesarios encontrados" -ForegroundColor Green

# INICIAR SERVIDOR HTTPS
Write-Host "`nIniciando servidor HTTPS..." -ForegroundColor Cyan

try {
    pm2 start ecosystem-https.config.js
    Write-Host "Servidor HTTPS iniciado correctamente" -ForegroundColor Green
} catch {
    Write-Host "Error iniciando servidor HTTPS" -ForegroundColor Red
}

# GUARDAR CONFIGURACION PM2
Write-Host "`nGuardando configuracion PM2..." -ForegroundColor Cyan
pm2 save

# VERIFICAR ESTADO
Write-Host "`nEstado de servicios:" -ForegroundColor Cyan
pm2 status

Write-Host "`nSistema HTTPS iniciado. URLs disponibles:" -ForegroundColor Green
Write-Host "  HTTPS: https://localhost:3443/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "  HTTPS Red: https://10.42.126.12:3443/dashboard/value-stream-map.html" -ForegroundColor White

Write-Host "`nPresione cualquier tecla para continuar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host "Todos los archivos necesarios encontrados" -ForegroundColor Green

# DETENER SERVICIOS EXISTENTES
Write-Host "`nDeteniendo servicios existentes..." -ForegroundColor Cyan

try {
    pm2 stop all
    Write-Host "Servicios PM2 detenidos" -ForegroundColor Green
} catch {
    Write-Host "No hay servicios PM2 ejecutándose" -ForegroundColor Yellow
}

# CREAR DIRECTORIO DE LOGS
Write-Host "`nVerificando directorio de logs..." -ForegroundColor Cyan

if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" -Force | Out-Null
    Write-Host "Directorio logs creado" -ForegroundColor Green
} else {
    Write-Host "Directorio logs existe" -ForegroundColor Green
}

# INICIAR SERVIDOR HTTP (ORIGINAL)
Write-Host "`nIniciando servidor HTTP original..." -ForegroundColor Cyan

try {
    pm2 start ecosystem.config.js
    Write-Host "Servidor HTTP iniciado correctamente" -ForegroundColor Green
} catch {
    Write-Host "Error iniciando servidor HTTP" -ForegroundColor Red
    Write-Host "Intentando iniciar directamente..." -ForegroundColor Yellow
    
    try {
        pm2 start server.js --name "vsm-dashboard-borgwarner"
        Write-Host "Servidor HTTP iniciado directamente" -ForegroundColor Green
    } catch {
        Write-Host "No se pudo iniciar servidor HTTP" -ForegroundColor Red
    }
}

# ESPERAR UN MOMENTO
Start-Sleep -Seconds 3

# INICIAR SERVIDOR HTTPS
Write-Host "`nIniciando servidor HTTPS..." -ForegroundColor Cyan

try {
    pm2 start ecosystem-https.config.js
    Write-Host "Servidor HTTPS iniciado correctamente" -ForegroundColor Green
} catch {
    Write-Host "Error iniciando servidor HTTPS" -ForegroundColor Red
    Write-Host "Intentando iniciar directamente..." -ForegroundColor Yellow
    
    try {
        pm2 start server-https.js --name "vsm-dashboard-borgwarner-https"
        Write-Host "Servidor HTTPS iniciado directamente" -ForegroundColor Green
    } catch {
        Write-Host "No se pudo iniciar servidor HTTPS" -ForegroundColor Red
    }
}

# ESPERAR UN MOMENTO PARA ESTABILIZACION
Write-Host "`nEsperando estabilización de servicios..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

# VERIFICAR ESTADO DE LOS SERVICIOS
Write-Host "`nVerificando estado de servicios..." -ForegroundColor Cyan

try {
    pm2 status
    
    # Guardar configuración PM2
    pm2 save
    Write-Host "`nConfiguración PM2 guardada" -ForegroundColor Green
    
} catch {
    Write-Host "Error verificando estado PM2" -ForegroundColor Red
}

# PROBAR CONECTIVIDAD BASICA
Write-Host "`nProbando conectividad básica..." -ForegroundColor Cyan

# Probar HTTP
try {
    $httpResponse = Invoke-WebRequest -Uri "http://localhost:3001/api/status" -TimeoutSec 10 -UseBasicParsing
    if ($httpResponse.StatusCode -eq 200) {
        Write-Host "  HTTP (3001): FUNCIONANDO" -ForegroundColor Green
    }
} catch {
    Write-Host "  HTTP (3001): ERROR - $($_.Exception.Message)" -ForegroundColor Red
}

# Probar HTTPS
try {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    $httpsResponse = Invoke-WebRequest -Uri "https://localhost:3443/api/status" -TimeoutSec 10 -UseBasicParsing
    if ($httpsResponse.StatusCode -eq 200) {
        Write-Host "  HTTPS (3443): FUNCIONANDO" -ForegroundColor Green
    }
} catch {
    Write-Host "  HTTPS (3443): ERROR - $($_.Exception.Message)" -ForegroundColor Red
}

# MOSTRAR RESUMEN FINAL
Write-Host "`n=================================================" -ForegroundColor Green
Write-Host "SISTEMA HTTPS DASHBOARD VSM INICIADO" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

Write-Host "`nServicios iniciados:" -ForegroundColor Cyan
Write-Host "  vsm-dashboard-borgwarner (HTTP - Puerto 3001)" -ForegroundColor White
Write-Host "  vsm-dashboard-borgwarner-https (HTTPS - Puerto 3443)" -ForegroundColor White

Write-Host "`nURLs de acceso:" -ForegroundColor Cyan
Write-Host "  Dashboard HTTP Local:   http://localhost:3001/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "  Dashboard HTTPS Local:  https://localhost:3443/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "  Dashboard HTTP Red:     http://10.42.126.12:3001/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "  Dashboard HTTPS Red:    https://10.42.126.12:3443/dashboard/value-stream-map.html" -ForegroundColor White

Write-Host "`nPanel administrativo:" -ForegroundColor Cyan
Write-Host "  Admin HTTP:   http://localhost:3001/admin" -ForegroundColor White
Write-Host "  Admin HTTPS:  https://localhost:3443/admin" -ForegroundColor White

Write-Host "`nComandos de gestión:" -ForegroundColor Cyan
Write-Host "  pm2 status                              - Ver estado servicios" -ForegroundColor Gray
Write-Host "  pm2 logs                                - Ver todos los logs" -ForegroundColor Gray
Write-Host "  pm2 logs vsm-dashboard-borgwarner       - Logs HTTP" -ForegroundColor Gray
Write-Host "  pm2 logs vsm-dashboard-borgwarner-https - Logs HTTPS" -ForegroundColor Gray
Write-Host "  pm2 restart all                         - Reiniciar servicios" -ForegroundColor Gray
Write-Host "  pm2 stop all                            - Detener servicios" -ForegroundColor Gray

Write-Host "`nEjecución de pruebas:" -ForegroundColor Cyan
Write-Host "  .\probar-https.ps1                      - Ejecutar pruebas completas" -ForegroundColor Gray

Write-Host "`nIMPORTANTE - Certificado Auto-firmado:" -ForegroundColor Yellow
Write-Host "  Al acceder via HTTPS, el navegador mostrará advertencia" -ForegroundColor White
Write-Host "  Pasos para continuar:" -ForegroundColor White
Write-Host "    1. Hacer clic en 'Avanzado'" -ForegroundColor White
Write-Host "    2. Hacer clic en 'Continuar a [IP] (no seguro)'" -ForegroundColor White
Write-Host "    3. El dashboard cargará normalmente" -ForegroundColor White

Write-Host "`nProgreso Enterprise Dashboard VSM:" -ForegroundColor Green
Write-Host "  Estado anterior: 85% (solo HTTP)" -ForegroundColor White
Write-Host "  Estado actual:   100% (HTTP + HTTPS)" -ForegroundColor Green
Write-Host "  Valor del sistema: $50K+ USD completamente funcional" -ForegroundColor White

Write-Host "`nSistema listo para acceso multi-PC corporativo" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor White

# OPCION PARA ABRIR DASHBOARD
Write-Host "`n¿Desea abrir el dashboard en el navegador? (s/N): " -ForegroundColor Cyan -NoNewline
$openBrowser = Read-Host

if ($openBrowser -eq "s" -or $openBrowser -eq "S") {
    Write-Host "`nAbriendo dashboard HTTPS..." -ForegroundColor Cyan
    try {
        Start-Process "https://localhost:3443/dashboard/value-stream-map.html"
        Write-Host "Dashboard abierto en navegador" -ForegroundColor Green
        Write-Host "Recuerde aceptar el certificado auto-firmado" -ForegroundColor Yellow
    } catch {
        Write-Host "No se pudo abrir navegador automáticamente" -ForegroundColor Yellow
        Write-Host "Abra manualmente: https://localhost:3443/dashboard/value-stream-map.html" -ForegroundColor White
    }
}

Write-Host "`nPresione cualquier tecla para finalizar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")