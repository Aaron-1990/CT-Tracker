# =============================================================================
# CONFIGURACION ENTERPRISE - Dashboard VSM BorgWarner
# Servidor 24/7 - Version limpia sin caracteres especiales
# =============================================================================

Write-Host "CONFIGURACION ENTERPRISE - Dashboard VSM BorgWarner" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor White

# VERIFICAR PERMISOS DE ADMINISTRADOR
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: Este script requiere permisos de administrador" -ForegroundColor Red
    Write-Host "SOLUCION: Ejecute PowerShell como administrador" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "OK: Permisos de administrador confirmados" -ForegroundColor Green

# =============================================================================
# 1. VERIFICAR DIRECTORIO DEL PROYECTO
# =============================================================================
Write-Host "`nVERIFICANDO DIRECTORIO DEL PROYECTO..." -ForegroundColor Cyan

$projectPath = "C:\Aplicaciones\mi-servidor-web"

if (-not (Test-Path $projectPath)) {
    Write-Host "ERROR: Directorio no encontrado: $projectPath" -ForegroundColor Red
    pause
    exit 1
}

Set-Location $projectPath
Write-Host "OK: Directorio verificado: $projectPath" -ForegroundColor Green

# =============================================================================
# 2. CONFIGURAR ECOSYSTEM.CONFIG.JS PARA PUERTO 3001
# =============================================================================
Write-Host "`nCONFIGURANDO ECOSYSTEM.CONFIG.JS..." -ForegroundColor Cyan

# Backup del archivo existente
if (Test-Path "ecosystem.config.js") {
    Copy-Item "ecosystem.config.js" "ecosystem.config.js.backup"
    Write-Host "OK: Backup creado: ecosystem.config.js.backup" -ForegroundColor Green
}

# Crear nuevo ecosystem.config.js
$ecosystemConfig = @"
module.exports = {
  apps: [{
    name: "vsm-dashboard-borgwarner",
    script: "server.js",
    watch: false,
    instances: 1,
    exec_mode: "fork",
    env: {
      NODE_ENV: "production",
      PORT: 3001
    },
    env_production: {
      NODE_ENV: "production",
      PORT: 3001
    },
    log_date_format: "YYYY-MM-DD HH:mm:ss",
    error_file: "./logs/error.log",
    out_file: "./logs/output.log",
    log_file: "./logs/combined.log",
    max_memory_restart: "1G",
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: "10s",
    kill_timeout: 5000
  }]
};
"@

$ecosystemConfig | Out-File -FilePath "ecosystem.config.js" -Encoding UTF8
Write-Host "OK: ecosystem.config.js actualizado para puerto 3001" -ForegroundColor Green

# =============================================================================
# 3. CREAR DIRECTORIO DE LOGS
# =============================================================================
Write-Host "`nCONFIGURANDO LOGS..." -ForegroundColor Cyan

if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" -Force | Out-Null
    Write-Host "OK: Directorio logs creado" -ForegroundColor Green
} else {
    Write-Host "OK: Directorio logs ya existe" -ForegroundColor Green
}

# =============================================================================
# 4. CONFIGURAR POLITICAS DE ENERGIA
# =============================================================================
Write-Host "`nCONFIGURANDO POLITICAS DE ENERGIA..." -ForegroundColor Cyan

try {
    # Establecer perfil de alto rendimiento
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    
    # Configuraciones para servidor 24/7
    powercfg -change -standby-timeout-ac 0
    powercfg -change -hibernate-timeout-ac 0
    powercfg -change -disk-timeout-ac 0
    powercfg -change -monitor-timeout-ac 30
    
    # Deshabilitar hibernacion
    powercfg -hibernate off
    
    Write-Host "OK: Politicas de energia configuradas para servidor 24/7" -ForegroundColor Green
} catch {
    Write-Host "ADVERTENCIA: Error al configurar energia: $($_.Exception.Message)" -ForegroundColor Yellow
}

# =============================================================================
# 5. CONFIGURAR AUTO-LOGIN
# =============================================================================
Write-Host "`nCONFIGURANDO AUTO-LOGIN..." -ForegroundColor Cyan

$currentUser = $env:USERNAME
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

try {
    Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "1" -Type String
    Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $currentUser -Type String
    
    Write-Host "OK: Auto-login configurado para: $currentUser" -ForegroundColor Green
    Write-Host "PENDIENTE: Ejecute netplwiz para completar" -ForegroundColor Yellow
} catch {
    Write-Host "ERROR: No se pudo configurar auto-login: $($_.Exception.Message)" -ForegroundColor Red
}

# =============================================================================
# 6. CONFIGURAR FIREWALL
# =============================================================================
Write-Host "`nCONFIGURANDO FIREWALL..." -ForegroundColor Cyan

try {
    # Eliminar regla existente si existe
    Remove-NetFirewallRule -DisplayName "Dashboard VSM Puerto 3001" -ErrorAction SilentlyContinue
    
    # Crear nueva regla
    New-NetFirewallRule -DisplayName "Dashboard VSM Puerto 3001" -Direction Inbound -Protocol TCP -LocalPort 3001 -Action Allow -Profile Domain,Private,Public
    
    Write-Host "OK: Firewall configurado para puerto 3001" -ForegroundColor Green
} catch {
    Write-Host "ERROR: No se pudo configurar firewall: $($_.Exception.Message)" -ForegroundColor Red
}

# =============================================================================
# 7. CREAR SCRIPT DE INICIO AUTOMATICO
# =============================================================================
Write-Host "`nCONFIGURANDO INICIO AUTOMATICO..." -ForegroundColor Cyan

$startupScript = @"
@echo off
title Dashboard VSM BorgWarner - Inicio Automatico
color 0A

echo ================================================================
echo           DASHBOARD VSM BORGWARNER - INICIO AUTOMATICO
echo ================================================================
echo Fecha: %date% %time%
echo.

echo Esperando estabilizacion del sistema (30 segundos)...
timeout /t 30 /nobreak > nul

echo Cambiando al directorio del proyecto...
cd /d "C:\Aplicaciones\mi-servidor-web"
if errorlevel 1 (
    echo ERROR: No se puede acceder al directorio del proyecto
    pause
    exit /b 1
)

echo Verificando Node.js...
node --version > nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js no disponible
    pause
    exit /b 1
)

echo Verificando PM2...
pm2 --version > nul 2>&1
if errorlevel 1 (
    echo Instalando PM2...
    npm install pm2 -g
)

echo Deteniendo instancias previas...
pm2 delete vsm-dashboard-borgwarner > nul 2>&1

echo Iniciando Dashboard VSM...
pm2 start ecosystem.config.js --env production

echo Guardando configuracion PM2...
pm2 save

echo.
echo ================================================================
echo                 DASHBOARD VSM INICIADO
echo ================================================================
echo Local:  http://localhost:3001
echo Red:    http://10.42.126.12:3001
echo VSM:    http://localhost:3001/dashboard/value-stream-map.html
echo Admin:  http://localhost:3001/admin
echo ================================================================

timeout /t 10
"@

$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\vsm-dashboard-startup.bat"
$startupScript | Out-File -FilePath $startupPath -Encoding UTF8
Write-Host "OK: Script de inicio automatico creado" -ForegroundColor Green

# =============================================================================
# 8. CONFIGURAR REINICIO PROGRAMADO
# =============================================================================
Write-Host "`nCONFIGURANDO REINICIO PROGRAMADO..." -ForegroundColor Cyan

try {
    # Eliminar tarea existente
    Unregister-ScheduledTask -TaskName "VSM Dashboard Weekly Restart" -Confirm:$false -ErrorAction SilentlyContinue
    
    # Crear script de pre-reinicio
    $preRebootScript = @"
@echo off
echo Guardando configuracion PM2...
cd /d "C:\Aplicaciones\mi-servidor-web"
pm2 save
echo Configuracion guardada. Reinicio en 60 segundos...
"@
    
    $preRebootScript | Out-File -FilePath "$projectPath\pre-reboot.bat" -Encoding UTF8
    
    # Crear tarea programada
    $action1 = New-ScheduledTaskAction -Execute "$projectPath\pre-reboot.bat"
    $action2 = New-ScheduledTaskAction -Execute "shutdown" -Argument "/r /t 60 /c `"Mantenimiento Dashboard VSM`""
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "03:00AM"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    Register-ScheduledTask -TaskName "VSM Dashboard Weekly Restart" -Action @($action1, $action2) -Trigger $trigger -Settings $settings -Principal $principal -Description "Reinicio semanal Dashboard VSM"
    
    Write-Host "OK: Reinicio programado configurado para domingos 3:00 AM" -ForegroundColor Green
} catch {
    Write-Host "ERROR: No se pudo configurar reinicio programado: $($_.Exception.Message)" -ForegroundColor Red
}

# =============================================================================
# 9. CREAR SCRIPT DE MONITOREO
# =============================================================================
Write-Host "`nCREANDO SCRIPT DE MONITOREO..." -ForegroundColor Cyan

$monitorScript = @"
@echo off
title Monitor Dashboard VSM
color 0A

:LOOP
cls
echo ================================================================
echo              MONITOR DASHBOARD VSM BORGWARNER
echo ================================================================
echo Fecha: %date% %time%
echo.

echo Verificando PM2...
pm2 status | findstr "vsm-dashboard-borgwarner"
if errorlevel 1 (
    echo ALERTA: Dashboard no detectado en PM2
    echo Iniciando recuperacion...
    cd /d "C:\Aplicaciones\mi-servidor-web"
    pm2 start ecosystem.config.js --env production
    pm2 save
) else (
    echo OK: Dashboard funcionando en PM2
)

echo.
echo Verificando conectividad HTTP...
curl -s -o nul -w "%%{http_code}" http://localhost:3001/api/status > temp.txt 2>nul
set /p HTTP_CODE=<temp.txt
del temp.txt > nul 2>&1

if "%HTTP_CODE%"=="200" (
    echo OK: HTTP Status %HTTP_CODE% - Servidor respondiendo
) else (
    echo ALERTA: HTTP Status %HTTP_CODE% - Problema detectado
)

echo.
echo URLs disponibles:
echo  - http://localhost:3001
echo  - http://localhost:3001/dashboard/value-stream-map.html
echo  - http://localhost:3001/admin
echo.
echo Proxima verificacion en 5 minutos...
echo Presione Ctrl+C para salir
echo ================================================================

timeout /t 300 /nobreak > nul
goto LOOP
"@

$monitorScript | Out-File -FilePath "$projectPath\monitor-dashboard.bat" -Encoding UTF8
Write-Host "OK: Script de monitoreo creado - monitor-dashboard.bat" -ForegroundColor Green

# =============================================================================
# 10. RESUMEN FINAL
# =============================================================================
Write-Host "`nCONFIGURACION ENTERPRISE COMPLETADA" -ForegroundColor Green

Write-Host "`nRESUMEN DE CONFIGURACION:" -ForegroundColor White
Write-Host "   OK: ecosystem.config.js actualizado (puerto 3001)" -ForegroundColor Green
Write-Host "   OK: Politicas de energia 24/7 configuradas" -ForegroundColor Green
Write-Host "   PENDIENTE: Auto-login preparado (requiere netplwiz)" -ForegroundColor Yellow
Write-Host "   OK: Firewall configurado para puerto 3001" -ForegroundColor Green
Write-Host "   OK: Script de inicio automatico creado" -ForegroundColor Green
Write-Host "   OK: Reinicio programado domingos 3AM" -ForegroundColor Green
Write-Host "   OK: Script de monitoreo disponible" -ForegroundColor Green

Write-Host "`nPASOS MANUALES PENDIENTES:" -ForegroundColor Yellow
Write-Host "   1. Ejecutar: netplwiz" -ForegroundColor Gray
Write-Host "   2. Ejecutar: pm2 start ecosystem.config.js" -ForegroundColor Gray
Write-Host "   3. Ejecutar: pm2 save" -ForegroundColor Gray
Write-Host "   4. Probar reinicio de PC" -ForegroundColor Gray

Write-Host "`nCOMANDOS UTILES:" -ForegroundColor White
Write-Host "   pm2 start ecosystem.config.js  - Iniciar dashboard" -ForegroundColor Gray
Write-Host "   pm2 status                     - Ver estado" -ForegroundColor Gray
Write-Host "   pm2 logs                       - Ver logs" -ForegroundColor Gray
Write-Host "   .\monitor-dashboard.bat        - Monitor en tiempo real" -ForegroundColor Gray

Write-Host "`nURLS DE ACCESO:" -ForegroundColor White
Write-Host "   Local: http://localhost:3001" -ForegroundColor Gray
Write-Host "   Red:   http://10.42.126.12:3001" -ForegroundColor Gray

Write-Host "`nPROXIMO PASO: Ejecutar pm2 start ecosystem.config.js" -ForegroundColor Cyan

pause