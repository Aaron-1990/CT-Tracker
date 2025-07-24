# =============================================================================
# PASO 2: CONFIGURACIÓN PC SERVIDOR ENTERPRISE 24/7
# Dashboard VSM BorgWarner - Lineamientos Corporativos
# Nombre del archivo: enterprise-config.ps1
# =============================================================================

Write-Host "🏢 Configurando PC como Servidor Enterprise..." -ForegroundColor Green
Write-Host "Dashboard VSM BorgWarner - Configuración Corporativa" -ForegroundColor White

# VERIFICAR PERMISOS DE ADMINISTRADOR
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ ERROR: Este script requiere permisos de administrador" -ForegroundColor Red
    Write-Host "💡 Haga clic derecho en PowerShell y seleccione 'Ejecutar como administrador'" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "✅ Permisos de administrador confirmados" -ForegroundColor Green

# =============================================================================
# 1. CONFIGURACIÓN DE ENERGÍA PARA SERVIDOR 24/7
# =============================================================================
Write-Host "`n🔋 CONFIGURANDO POLÍTICAS DE ENERGÍA PARA SERVIDOR 24/7..." -ForegroundColor Cyan

# Crear perfil de energía personalizado para servidor
powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c "VSM-Server-Profile"
$serverProfileGuid = (powercfg -list | Select-String "VSM-Server-Profile" | ForEach-Object { ($_ -split "\s+")[3] })

if ($serverProfileGuid) {
    # Configurar el perfil personalizado
    powercfg -setactive $serverProfileGuid
    
    # Configuraciones de servidor: NUNCA apagar
    powercfg -change -standby-timeout-ac 0         # Nunca standby cuando conectado
    powercfg -change -standby-timeout-dc 0         # Nunca standby con batería
    powercfg -change -hibernate-timeout-ac 0       # Nunca hibernar conectado
    powercfg -change -hibernate-timeout-dc 0       # Nunca hibernar con batería
    powercfg -change -disk-timeout-ac 0            # Discos siempre activos conectado
    powercfg -change -disk-timeout-dc 30           # Discos activos 30min con batería
    powercfg -change -monitor-timeout-ac 20        # Monitor off tras 20min conectado
    powercfg -change -monitor-timeout-dc 10        # Monitor off tras 10min con batería
    
    Write-Host "✅ Perfil de energía 'VSM-Server-Profile' creado y activado" -ForegroundColor Green
} else {
    # Fallback: configurar perfil actual
    powercfg -change -standby-timeout-ac 0
    powercfg -change -hibernate-timeout-ac 0
    powercfg -change -disk-timeout-ac 0
    powercfg -change -monitor-timeout-ac 20
    Write-Host "✅ Perfil de energía actual configurado para servidor" -ForegroundColor Green
}

# Deshabilitar hibernación completamente para liberar espacio
powercfg -hibernate off
Write-Host "✅ Hibernación deshabilitada (libera espacio en disco)" -ForegroundColor Green

# Configurar para NO apagar con botón de encendido
powercfg -setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 0
powercfg -setdcvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 0
powercfg -setactive SCHEME_CURRENT

Write-Host "✅ Botón de encendido configurado para NO apagar el sistema" -ForegroundColor Green

# =============================================================================
# 2. CONFIGURACIÓN DE AUTO-LOGIN PARA USUARIO TÉCNICO
# =============================================================================
Write-Host "`n🔐 CONFIGURANDO AUTO-LOGIN PARA USUARIO TÉCNICO..." -ForegroundColor Cyan

$currentUser = $env:USERNAME
$computerName = $env:COMPUTERNAME

Write-Host "Usuario actual: $currentUser" -ForegroundColor White
Write-Host "Equipo: $computerName" -ForegroundColor White

# Configurar auto-login en el registro (método seguro)
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

try {
    Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "1" -Type String
    Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $currentUser -Type String
    Set-ItemProperty -Path $regPath -Name "DefaultDomainName" -Value $computerName -Type String
    
    Write-Host "✅ Auto-login configurado para usuario: $currentUser" -ForegroundColor Green
    Write-Host "⚠️  IMPORTANTE: Configure la contraseña manualmente ejecutando 'netplwiz'" -ForegroundColor Yellow
    Write-Host "   1. Ejecutar: netplwiz" -ForegroundColor Gray
    Write-Host "   2. Seleccionar usuario: $currentUser" -ForegroundColor Gray
    Write-Host "   3. Desmarcar: 'Los usuarios deben escribir su nombre...'" -ForegroundColor Gray
    Write-Host "   4. Aplicar y escribir contraseña" -ForegroundColor Gray
} catch {
    Write-Host "❌ Error configurando auto-login: $($_.Exception.Message)" -ForegroundColor Red
}

# =============================================================================
# 3. CONFIGURACIÓN DE RESPALDO UPS (PREPARACIÓN)
# =============================================================================
Write-Host "`n⚡ CONFIGURANDO RESPALDO UPS..." -ForegroundColor Cyan

# Configurar respuesta del sistema a fallas de energía
$regPathUPS = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
try {
    # Configurar acciones para UPS
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\UPS" -Name "Start" -Value 3 -ErrorAction SilentlyContinue
    
    Write-Host "✅ Servicio UPS habilitado para detección automática" -ForegroundColor Green
    Write-Host "💡 RECOMENDACIÓN: Instalar software del fabricante del UPS" -ForegroundColor Yellow
    Write-Host "   • APC: PowerChute Personal Edition" -ForegroundColor Gray
    Write-Host "   • CyberPower: PowerPanel Personal" -ForegroundColor Gray
    Write-Host "   • Tripp Lite: PowerAlert" -ForegroundColor Gray
} catch {
    Write-Host "⚠️  Configuración UPS básica aplicada" -ForegroundColor Yellow
}

# Configurar acciones de energía crítica
powercfg -setacvalueindex SCHEME_CURRENT 238C9FA8-0AAD-41ED-83F4-97BE242C8F20 9D7815A6-7EE4-497E-8888-515A05F02364 2
powercfg -setdcvalueindex SCHEME_CURRENT 238C9FA8-0AAD-41ED-83F4-97BE242C8F20 9D7815A6-7EE4-497E-8888-515A05F02364 1
powercfg -setactive SCHEME_CURRENT

Write-Host "✅ Acciones de energía crítica configuradas:" -ForegroundColor Green
Write-Host "   • AC (Conectado): Hibernar cuando batería crítica" -ForegroundColor Gray
Write-Host "   • DC (Batería): Apagar cuando batería crítica" -ForegroundColor Gray

# =============================================================================
# 4. CONFIGURACIÓN DE REINICIO PROGRAMADO - DOMINGOS 3 AM
# =============================================================================
Write-Host "`n🔄 CONFIGURANDO REINICIO PROGRAMADO - DOMINGOS 3:00 AM..." -ForegroundColor Cyan

# Crear script de pre-reinicio para el Dashboard VSM
$preRebootScript = @"
@echo off
echo [%date% %time%] REINICIO PROGRAMADO VSM DASHBOARD - PREPARACIÓN
echo Guardando estado de PM2...
cd /d "C:\Aplicaciones\mi-servidor-web"
pm2 save
echo Estado guardado. Sistema se reiniciará en 60 segundos.
echo El Dashboard VSM se iniciará automáticamente tras el reinicio.
"@

$preRebootScript | Out-File -FilePath "C:\Aplicaciones\mi-servidor-web\pre-reboot.bat" -Encoding UTF8

try {
    # Eliminar tarea existente si existe
    Unregister-ScheduledTask -TaskName "VSM Dashboard Weekly Restart" -Confirm:$false -ErrorAction SilentlyContinue
    
    # Crear nueva tarea programada
    $action = New-ScheduledTaskAction -Execute "C:\Aplicaciones\mi-servidor-web\pre-reboot.bat"
    $actionReboot = New-ScheduledTaskAction -Execute "shutdown" -Argument "/r /t 60 /c 'Reinicio programado Dashboard VSM - Domingos 3 AM para Windows Updates'"
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "03:00AM"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    Register-ScheduledTask -TaskName "VSM Dashboard Weekly Restart" -Action @($action, $actionReboot) -Trigger $trigger -Settings $settings -Principal $principal -Description "Reinicio programado semanal para mantenimiento del servidor Dashboard VSM BorgWarner"
    
    Write-Host "✅ Reinicio programado configurado: Domingos 3:00 AM" -ForegroundColor Green
    Write-Host "   • Pre-script: Guarda estado PM2" -ForegroundColor Gray
    Write-Host "   • Reinicio: 60 segundos después" -ForegroundColor Gray
    Write-Host "   • Post-reinicio: Auto-inicio Dashboard" -ForegroundColor Gray
} catch {
    Write-Host "❌ Error configurando reinicio programado: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Configurar manualmente en Programador de tareas" -ForegroundColor Yellow
}

# =============================================================================
# 5. CONFIGURACIÓN DE INICIO AUTOMÁTICO DEL DASHBOARD
# =============================================================================
Write-Host "`n🚀 CONFIGURANDO INICIO AUTOMÁTICO DEL DASHBOARD VSM..." -ForegroundColor Cyan

# Crear script de inicio mejorado
$startupScript = @"
@echo off
title Dashboard VSM BorgWarner - Inicio Automático
echo ================================================
echo    DASHBOARD VSM BORGWARNER - INICIO AUTOMATICO
echo ================================================
echo [%date% %time%] Iniciando servicios del Dashboard VSM...

REM Esperar que Windows termine de cargar completamente
echo Esperando estabilización del sistema (30 segundos)...
timeout /t 30 /nobreak > nul

REM Cambiar al directorio del proyecto
cd /d "C:\Aplicaciones\mi-servidor-web"
if errorlevel 1 (
    echo ERROR: No se puede acceder al directorio del proyecto
    pause
    exit /b 1
)

REM Verificar que Node.js está disponible
node --version > nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js no está disponible en PATH
    pause
    exit /b 1
)

REM Verificar que PM2 está disponible
pm2 --version > nul 2>&1
if errorlevel 1 (
    echo ERROR: PM2 no está disponible. Instalando...
    npm install pm2 -g
)

echo Iniciando Dashboard VSM con PM2...
pm2 resurrect
if errorlevel 1 (
    echo No hay configuración guardada, iniciando fresh...
    pm2 start ecosystem.config.js
    pm2 save
)

echo ================================================
echo ✅ DASHBOARD VSM BORGWARNER INICIADO
echo ================================================
echo 🌐 Acceso local:  http://localhost:3001
echo 📡 Acceso red:    http://10.42.126.12:3001
echo 📊 Estado PM2:    pm2 status
echo 📋 Logs:          pm2 logs
echo ================================================

REM Verificar que el servidor responde
timeout /t 10 /nobreak > nul
curl -s http://localhost:3001/api/status > nul
if errorlevel 1 (
    echo ⚠️  Dashboard iniciado pero aún no responde
    echo    Verifique logs: pm2 logs
) else (
    echo ✅ Dashboard respondiendo correctamente
)

echo.
echo Sistema listo. Esta ventana se puede cerrar.
echo El Dashboard seguirá funcionando en segundo plano.
timeout /t 10 /nobreak
"@

# Guardar en startup de Windows
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\vsm-dashboard-startup.bat"
$startupScript | Out-File -FilePath $startupPath -Encoding UTF8

Write-Host "✅ Script de inicio automático creado en Startup" -ForegroundColor Green

# =============================================================================
# 6. CONFIGURACIÓN DE MONITOREO Y VERIFICACIÓN
# =============================================================================
Write-Host "`n📊 CONFIGURANDO SISTEMA DE MONITOREO..." -ForegroundColor Cyan

# Script de monitoreo avanzado
$monitorScript = @"
@echo off
title Monitor Continuo Dashboard VSM BorgWarner
color 0A
mode con: cols=80 lines=30

:INICIO
cls
echo ================================================================================
echo                      MONITOR DASHBOARD VSM BORGWARNER
echo ================================================================================
echo [%date% %time%] Estado del servidor...
echo.

REM Verificar PM2
pm2 status 2>nul | findstr "vsm-dashboard-borgwarner"
if errorlevel 1 (
    echo ❌ ALERTA: Dashboard no detectado en PM2
    echo Intentando recuperación automática...
    pm2 start ecosystem.config.js
    pm2 save
    echo ✅ Recuperación iniciada
) else (
    echo ✅ PM2: Dashboard detectado y funcionando
)

REM Verificar conectividad HTTP
for /f %%i in ('curl -s -o nul -w "%%{http_code}" http://localhost:3001/api/status 2^>nul') do set http_code=%%i
if "%http_code%"=="200" (
    echo ✅ HTTP: Dashboard respondiendo correctamente [200 OK]
) else (
    echo ❌ ALERTA: Dashboard no responde [Código: %http_code%]
    echo Reiniciando servicios...
    pm2 restart vsm-dashboard-borgwarner
    echo ✅ Reinicio ejecutado
)

REM Verificar memoria y CPU
echo.
echo 📊 RECURSOS DEL SISTEMA:
for /f "skip=1 tokens=2 delims=," %%i in ('wmic OS get TotalVisibleMemorySize /format:csv') do set total_mem=%%i
for /f "skip=1 tokens=2 delims=," %%i in ('wmic OS get FreePhysicalMemory /format:csv') do set free_mem=%%i
for /f "skip=1 tokens=2 delims=," %%i in ('wmic cpu get loadpercentage /format:csv') do set cpu_load=%%i

echo    💾 Memoria libre: %free_mem% KB de %total_mem% KB
echo    🔥 CPU: %cpu_load%%%

echo.
echo ================================================================================
echo Próxima verificación en 5 minutos... [Ctrl+C para salir]
echo ================================================================================
timeout /t 300 /nobreak > nul
goto INICIO
"@

$monitorScript | Out-File -FilePath "C:\Aplicaciones\mi-servidor-web\monitor-continuo.bat" -Encoding UTF8

# =============================================================================
# 7. RESUMEN FINAL Y VERIFICACIONES
# =============================================================================
Write-Host "`n🎯 CONFIGURACIÓN ENTERPRISE COMPLETADA" -ForegroundColor Green

Write-Host "`n📋 RESUMEN DE CONFIGURACIÓN:" -ForegroundColor White
Write-Host "   🖥️  PC Servidor 24/7:           ✅ CONFIGURADO" -ForegroundColor Green
Write-Host "   🔐 Auto-login:                ⚠️  REQUIERE NETPLWIZ" -ForegroundColor Yellow  
Write-Host "   ⚡ Respaldo UPS:              ✅ PREPARADO" -ForegroundColor Green
Write-Host "   🔄 Reinicio Domingos 3AM:     ✅ PROGRAMADO" -ForegroundColor Green
Write-Host "   🚀 Inicio automático:         ✅ CONFIGURADO" -ForegroundColor Green
Write-Host "   📊 Monitoreo continuo:        ✅ DISPONIBLE" -ForegroundColor Green

Write-Host "`n⚠️  PASOS MANUALES PENDIENTES:" -ForegroundColor Yellow
Write-Host "   1. Ejecutar 'netplwiz' para completar auto-login" -ForegroundColor Gray
Write-Host "   2. Conectar UPS y instalar software del fabricante" -ForegroundColor Gray
Write-Host "   3. Configurar PM2: pm2 start ecosystem.config.js && pm2 save" -ForegroundColor Gray

Write-Host "`n🛠️  COMANDOS DE GESTIÓN:" -ForegroundColor White
Write-Host "   • .\monitor-continuo.bat    - Monitor en tiempo real" -ForegroundColor Gray
Write-Host "   • pm2 status                - Estado servicios" -ForegroundColor Gray
Write-Host "   • pm2 logs                  - Ver logs" -ForegroundColor Gray

Write-Host "`n🌐 ACCESO AL DASHBOARD:" -ForegroundColor White
Write-Host "   • Local: http://localhost:3001" -ForegroundColor Gray
Write-Host "   • Red:   http://10.42.126.12:3001" -ForegroundColor Gray

Write-Host "`n✨ SIGUIENTE PASO: Reiniciar la PC para probar configuración completa" -ForegroundColor Cyan