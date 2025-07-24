# =============================================================================
# PASO 1: CONFIGURACION PM2 Y GESTION DE PROCESOS
# Dashboard BorgWarner - Configuracion de PM2 para Produccion
# Nombre del archivo: pm2-setup.ps1
# =============================================================================

Write-Host "Configurando PM2 para Dashboard VSM BorgWarner..." -ForegroundColor Green

# 1. INSTALAR PM2 Y DEPENDENCIAS
Write-Host "Instalando PM2 y dependencias de produccion..." -ForegroundColor Cyan

npm install pm2 -g
npm install pm2-windows-startup -g
npm install pm2-logrotate -g

# 2. CREAR ARCHIVO DE CONFIGURACION PM2
Write-Host "Creando configuracion PM2..." -ForegroundColor Cyan

$pm2ConfigContent = @'
module.exports = {
  apps: [{
    name: 'vsm-dashboard-borgwarner',
    script: 'server.js',
    instances: 1,
    exec_mode: 'fork',
    watch: false,
    max_memory_restart: '500M',
    
    env: {
      NODE_ENV: 'production',
      PORT: 3001,
      HOST: '0.0.0.0'
    },
    
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    error_file: './logs/error.log',
    out_file: './logs/output.log',
    log_file: './logs/combined.log',
    merge_logs: true,
    
    autorestart: true,
    restart_delay: 5000,
    max_restarts: 10,
    min_uptime: '10s',
    
    kill_timeout: 5000,
    listen_timeout: 10000,
    shutdown_with_message: true
  }]
};
'@

$pm2ConfigContent | Out-File -FilePath "ecosystem.config.js" -Encoding UTF8

# 3. CREAR SCRIPTS DE GESTION
Write-Host "Creando scripts de gestion..." -ForegroundColor Cyan

# Script de inicio
$startScriptContent = @'
@echo off
echo Iniciando Servidor VSM BorgWarner...
cd /d "%~dp0"
pm2 start ecosystem.config.js
pm2 save
echo Servidor iniciado como servicio
echo Dashboard disponible en: http://10.42.126.12:3001
pause
'@
$startScriptContent | Out-File -FilePath "start-server.bat" -Encoding UTF8

# Script de detener
$stopScriptContent = @'
@echo off
echo Deteniendo Servidor VSM BorgWarner...
pm2 stop vsm-dashboard-borgwarner
echo Servidor detenido
pause
'@
$stopScriptContent | Out-File -FilePath "stop-server.bat" -Encoding UTF8

# Script de reiniciar
$restartScriptContent = @'
@echo off
echo Reiniciando Servidor VSM BorgWarner...
pm2 restart vsm-dashboard-borgwarner
echo Servidor reiniciado
echo Dashboard disponible en: http://10.42.126.12:3001
pause
'@
$restartScriptContent | Out-File -FilePath "restart-server.bat" -Encoding UTF8

# Script de logs
$logsScriptContent = @'
@echo off
echo Mostrando logs del Servidor VSM...
pm2 logs vsm-dashboard-borgwarner --lines 50
pause
'@
$logsScriptContent | Out-File -FilePath "view-logs.bat" -Encoding UTF8

# Script de estado
$statusScriptContent = @'
@echo off
echo Estado del Servidor VSM BorgWarner:
echo.
pm2 status
echo.
pm2 info vsm-dashboard-borgwarner
pause
'@
$statusScriptContent | Out-File -FilePath "server-status.bat" -Encoding UTF8

# 4. CONFIGURAR INICIO AUTOMATICO CON WINDOWS
Write-Host "Configurando inicio automatico con Windows..." -ForegroundColor Yellow

pm2-startup install

Write-Host "IMPORTANTE: Se requiere configuracion adicional de startup" -ForegroundColor Yellow
Write-Host "Ejecuta despues: pm2 start ecosystem.config.js && pm2 save" -ForegroundColor Gray

# 5. CONFIGURAR LOGS AUTOMATICOS
Write-Host "Configurando rotacion de logs..." -ForegroundColor Cyan

pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7
pm2 set pm2-logrotate:compress true

# 6. CREAR DIRECTORIO DE LOGS
if (!(Test-Path "logs")) {
    New-Item -ItemType Directory -Name "logs"
    Write-Host "Directorio de logs creado" -ForegroundColor Green
}

Write-Host "CONFIGURACION COMPLETADA" -ForegroundColor Green
Write-Host "PROXIMOS PASOS:" -ForegroundColor White
Write-Host "1. Ejecutar: pm2 start ecosystem.config.js" -ForegroundColor Gray
Write-Host "2. Ejecutar: pm2 save" -ForegroundColor Gray
Write-Host "3. Reiniciar la PC para probar inicio automatico" -ForegroundColor Gray
Write-Host "COMANDOS DISPONIBLES:" -ForegroundColor White
Write-Host "start-server.bat    - Iniciar servidor" -ForegroundColor Gray
Write-Host "stop-server.bat     - Detener servidor" -ForegroundColor Gray
Write-Host "restart-server.bat  - Reiniciar servidor" -ForegroundColor Gray
Write-Host "view-logs.bat       - Ver logs" -ForegroundColor Gray
Write-Host "server-status.bat   - Ver estado" -ForegroundColor Gray