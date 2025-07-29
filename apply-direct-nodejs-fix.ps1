# SOLUCION NODE.JS DIRECTO - Dashboard VSM BorgWarner
# Eliminar dependencia de PM2 y usar Node.js directamente en el servicio

Write-Host "APLICANDO SOLUCION NODE.JS DIRECTO" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor White

$projectPath = "C:\Aplicaciones\mi-servidor-web"
$serviceName = "VSM-Dashboard-BorgWarner"

# 1. DETENER Y LIMPIAR SERVICIO ACTUAL
Write-Host "`n1. DETENIENDO Y LIMPIANDO SERVICIO..." -ForegroundColor Cyan

# Detener servicio
try {
    net stop $serviceName 2>$null
    Write-Host "   Servicio detenido" -ForegroundColor Green
} catch {
    Write-Host "   Servicio ya estaba detenido" -ForegroundColor Yellow
}

# Limpiar procesos Node.js existentes
try {
    Get-Process | Where-Object {$_.ProcessName -eq "node"} | Stop-Process -Force
    Write-Host "   Procesos Node.js limpiados" -ForegroundColor Green
} catch {
    Write-Host "   No habia procesos Node.js ejecutandose" -ForegroundColor Yellow
}

# Limpiar PM2
try {
    pm2 kill > $null 2>&1
    Write-Host "   PM2 limpiado" -ForegroundColor Green
} catch {
    Write-Host "   PM2 no estaba ejecutandose" -ForegroundColor Yellow
}

Start-Sleep 5

# 2. ACTUALIZAR SCRIPT DE SERVICIO SIN PM2
Write-Host "`n2. ACTUALIZANDO SCRIPT DE SERVICIO (SIN PM2)..." -ForegroundColor Cyan

$directNodeScript = @"
@echo off
title Dashboard VSM BorgWarner - Servicio Directo Node.js
echo ================================================================
echo     DASHBOARD VSM BORGWARNER - SERVICIO DIRECTO NODE.JS
echo ================================================================
echo [%date% %time%] Iniciando como servicio del sistema...
echo.

REM Configurar directorio de trabajo
cd /d "$projectPath"
if errorlevel 1 (
    echo ERROR: No se puede acceder al directorio del proyecto
    exit /b 1
)

REM Configurar variables de entorno del servicio
set NODE_ENV=production
set PORT=3001
set HTTPS_PORT=3443
set HOST=0.0.0.0

REM Esperar estabilizacion del sistema
echo Esperando estabilizacion del sistema (30 segundos)...
timeout /t 30 /nobreak > nul

REM Verificar que Node.js este disponible
echo Verificando Node.js...
node --version > nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js no esta disponible en PATH del servicio
    echo PATH actual: %PATH%
    exit /b 1
)

echo Node.js detectado correctamente
echo Variables de entorno configuradas:
echo   NODE_ENV=%NODE_ENV%
echo   PORT=%PORT%
echo   HTTPS_PORT=%HTTPS_PORT%
echo   HOST=%HOST%

echo ================================================================
echo INICIANDO DASHBOARD VSM CON NODE.JS DIRECTO
echo ================================================================

REM Verificar archivos necesarios
if not exist "server.js" (
    echo ERROR: server.js no encontrado
    exit /b 1
)

echo Archivos verificados correctamente

REM Limpiar procesos Node.js existentes que puedan estar en conflicto
echo Limpiando procesos Node.js anteriores...
taskkill /f /im node.exe > nul 2>&1

REM Crear script de inicio para ambos servidores
echo Creando script de inicio dual...

REM Escribir script de inicio HTTP
echo @echo off > start-http.bat
echo title Dashboard HTTP - Puerto 3001 >> start-http.bat
echo cd /d "$projectPath" >> start-http.bat
echo set NODE_ENV=production >> start-http.bat
echo set PORT=3001 >> start-http.bat
echo set HOST=0.0.0.0 >> start-http.bat
echo echo [%%date%% %%time%%] Iniciando servidor HTTP en puerto 3001... >> start-http.bat
echo node server.js >> start-http.bat

REM Escribir script de inicio HTTPS si existen certificados
if exist "certs\cert.pem" (
    if exist "certs\key.pem" (
        echo @echo off > start-https.bat
        echo title Dashboard HTTPS - Puerto 3443 >> start-https.bat
        echo cd /d "$projectPath" >> start-https.bat
        echo set NODE_ENV=production >> start-https.bat
        echo set HTTPS_PORT=3443 >> start-https.bat
        echo set HOST=0.0.0.0 >> start-https.bat
        echo echo [%%date%% %%time%%] Iniciando servidor HTTPS en puerto 3443... >> start-https.bat
        echo node server-https.js >> start-https.bat
        echo Certificados SSL encontrados - HTTPS disponible
    ) else (
        echo ADVERTENCIA: certs/key.pem no encontrado - Solo HTTP
    )
) else (
    echo ADVERTENCIA: certs/cert.pem no encontrado - Solo HTTP
)

REM Iniciar servidor HTTP en background
echo Iniciando servidor HTTP (puerto 3001)...
start /b cmd /c "start-http.bat > logs\http-output.log 2>&1"

REM Esperar que HTTP se estabilice
timeout /t 10 /nobreak > nul

REM Iniciar servidor HTTPS si esta disponible
if exist "start-https.bat" (
    echo Iniciando servidor HTTPS (puerto 3443)...
    start /b cmd /c "start-https.bat > logs\https-output.log 2>&1"
    timeout /t 10 /nobreak > nul
)

echo ================================================================
echo VERIFICANDO ESTADO DE SERVIDORES
echo ================================================================

REM Verificar que los procesos Node.js esten ejecutandose
timeout /t 5 /nobreak > nul

REM Buscar procesos Node.js
for /f "tokens=2" %%i in ('tasklist /fi "imagename eq node.exe" ^| find "node.exe"') do (
    echo Proceso Node.js detectado: PID %%i
    set NODE_RUNNING=1
)

if not defined NODE_RUNNING (
    echo ERROR: No se detectaron procesos Node.js ejecutandose
    echo Intentando inicio directo...
    echo [%date% %time%] Inicio directo Node.js...
    start /b node server.js
    timeout /t 15 /nobreak > nul
)

echo ================================================================
echo DASHBOARD VSM INICIADO COMO SERVICIO
echo ================================================================
echo HTTP Local:   http://localhost:3001
echo HTTP Red:     http://10.42.126.12:3001
if exist "start-https.bat" (
    echo HTTPS Local:  https://localhost:3443
    echo HTTPS Red:    https://10.42.126.12:3443
)
echo VSM HTTP:     http://localhost:3001/dashboard/value-stream-map.html
if exist "start-https.bat" (
    echo VSM HTTPS:    https://localhost:3443/dashboard/value-stream-map.html
)
echo ================================================================

REM Mantener el servicio vivo con monitoreo
set COUNTER=0

:LOOP
timeout /t 60 /nobreak > nul

REM Verificar que al menos un proceso Node.js este ejecutandose
tasklist /fi "imagename eq node.exe" | find "node.exe" > nul
if errorlevel 1 (
    echo [%date% %time%] ALERTA: Procesos Node.js no detectados, reiniciando...
    
    REM Limpiar procesos zombi
    taskkill /f /im node.exe > nul 2>&1
    timeout /t 5 /nobreak > nul
    
    REM Reiniciar HTTP
    start /b cmd /c "start-http.bat > logs\http-output.log 2>&1"
    timeout /t 10 /nobreak > nul
    
    REM Reiniciar HTTPS si esta disponible
    if exist "start-https.bat" (
        start /b cmd /c "start-https.bat > logs\https-output.log 2>&1"
        timeout /t 10 /nobreak > nul
    )
    
    echo [%date% %time%] Servidores reiniciados
)

REM Verificar conectividad HTTP cada 10 minutos
set /a COUNTER+=1
if %COUNTER% GEQ 10 (
    set COUNTER=0
    
    REM Test conectividad basica (sin curl para evitar dependencias)
    echo [%date% %time%] Verificacion periodica de servicios...
    
    REM Verificar puerto 3001
    netstat -an | find ":3001" > nul
    if errorlevel 1 (
        echo [%date% %time%] Puerto 3001 no activo, reiniciando HTTP...
        taskkill /f /im node.exe > nul 2>&1
        timeout /t 5 /nobreak > nul
        start /b cmd /c "start-http.bat > logs\http-output.log 2>&1"
    ) else (
        echo [%date% %time%] Puerto 3001 activo - HTTP funcionando
    )
    
    REM Verificar puerto 3443 si HTTPS esta configurado
    if exist "start-https.bat" (
        netstat -an | find ":3443" > nul
        if errorlevel 1 (
            echo [%date% %time%] Puerto 3443 no activo, reiniciando HTTPS...
            start /b cmd /c "start-https.bat > logs\https-output.log 2>&1"
        ) else (
            echo [%date% %time%] Puerto 3443 activo - HTTPS funcionando
        )
    )
)

goto LOOP
"@

$serviceScriptPath = "$projectPath\vsm-service.bat"
$directNodeScript | Out-File -FilePath $serviceScriptPath -Encoding UTF8
Write-Host "   Script de servicio Node.js directo creado" -ForegroundColor Green

# 3. CREAR DIRECTORIO DE LOGS SI NO EXISTE
Write-Host "`n3. VERIFICANDO DIRECTORIO DE LOGS..." -ForegroundColor Cyan
$logsPath = "$projectPath\logs"
if (!(Test-Path $logsPath)) {
    New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
    Write-Host "   Directorio logs creado" -ForegroundColor Green
} else {
    Write-Host "   Directorio logs existe" -ForegroundColor Green
}

# 4. REINICIAR SERVICIO CON NUEVA CONFIGURACION
Write-Host "`n4. REINICIANDO SERVICIO CON NODE.JS DIRECTO..." -ForegroundColor Cyan
try {
    net start $serviceName
    Write-Host "   Servicio reiniciado exitosamente" -ForegroundColor Green
} catch {
    Write-Host "   Error reiniciando servicio: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. ESPERAR INICIALIZACION EXTENDIDA
Write-Host "`n5. ESPERANDO INICIALIZACION (120 segundos)..." -ForegroundColor Cyan
Write-Host "   Tiempo adicional para Node.js directo sin PM2" -ForegroundColor Gray

for ($i = 1; $i -le 12; $i++) {
    Start-Sleep 10
    Write-Host "   $($i * 10) segundos transcurridos..." -ForegroundColor Gray
    
    # Verificar puertos cada 30 segundos
    if ($i % 3 -eq 0) {
        $port3001 = netstat -ano | findstr ":3001"
        $port3443 = netstat -ano | findstr ":3443"
        
        if ($port3001) {
            Write-Host "   Puerto 3001 detectado!" -ForegroundColor Green
        }
        if ($port3443) {
            Write-Host "   Puerto 3443 detectado!" -ForegroundColor Green
        }
        
        if ($port3001 -or $port3443) {
            Write-Host "   Servidores iniciando correctamente!" -ForegroundColor Green
            break
        }
    }
}

# 6. VERIFICACION FINAL
Write-Host "`n6. VERIFICACION FINAL:" -ForegroundColor Cyan

# Estado del servicio
$serviceStatus = Get-Service $serviceName -ErrorAction SilentlyContinue
if ($serviceStatus) {
    Write-Host "   Servicio Windows: $($serviceStatus.Status)" -ForegroundColor $(if($serviceStatus.Status -eq "Running"){"Green"}else{"Red"})
}

# Estado NSSM
$nssmPath = "C:\Tools\nssm\nssm.exe"
if (Test-Path $nssmPath) {
    $nssmStatus = & $nssmPath status $serviceName 2>$null
    Write-Host "   Estado NSSM: $nssmStatus" -ForegroundColor $(if($nssmStatus -eq "SERVICE_RUNNING"){"Green"}else{"Yellow"})
}

# Procesos Node.js
$nodeProcesses = Get-Process | Where-Object {$_.ProcessName -eq "node"}
if ($nodeProcesses) {
    Write-Host "   Procesos Node.js: $($nodeProcesses.Count) ejecutandose" -ForegroundColor Green
    $nodeProcesses | ForEach-Object {
        Write-Host "     - PID $($_.Id) (Memoria: $([math]::Round($_.WorkingSet64/1MB, 2)) MB)" -ForegroundColor White
    }
} else {
    Write-Host "   Procesos Node.js: NO DETECTADOS" -ForegroundColor Red
}

# Puertos
$port3001 = netstat -ano | findstr ":3001"
$port3443 = netstat -ano | findstr ":3443"

if ($port3001) {
    Write-Host "   Puerto 3001 (HTTP): ACTIVO" -ForegroundColor Green
} else {
    Write-Host "   Puerto 3001 (HTTP): NO DETECTADO" -ForegroundColor Red
}

if ($port3443) {
    Write-Host "   Puerto 3443 (HTTPS): ACTIVO" -ForegroundColor Green
} else {
    Write-Host "   Puerto 3443 (HTTPS): NO DETECTADO" -ForegroundColor Yellow
}

# Test de conectividad
Write-Host "`n7. TEST DE CONECTIVIDAD:" -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest "http://localhost:3001" -UseBasicParsing -TimeoutSec 10
    Write-Host "   HTTP Test: EXITOSO (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "   HTTP Test: FALLO (aun inicializando)" -ForegroundColor Yellow
}

if (Test-Path "$projectPath\certs\cert.pem") {
    try {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $response = Invoke-WebRequest "https://localhost:3443" -UseBasicParsing -TimeoutSec 10
        Write-Host "   HTTPS Test: EXITOSO (Status: $($response.StatusCode))" -ForegroundColor Green
    } catch {
        Write-Host "   HTTPS Test: FALLO (aun inicializando)" -ForegroundColor Yellow
    }
}

Write-Host "`n===================================" -ForegroundColor White
Write-Host "SOLUCION NODE.JS DIRECTO APLICADA" -ForegroundColor Green
Write-Host "`nSi los puertos aun no estan activos:" -ForegroundColor Yellow
Write-Host "  1. Esperar 5 minutos adicionales" -ForegroundColor White
Write-Host "  2. Monitorear: Get-Content $projectPath\logs\service-output.log -Wait" -ForegroundColor White
Write-Host "  3. Verificar: .\verificacion-dual.ps1" -ForegroundColor White
Write-Host "===================================" -ForegroundColor White