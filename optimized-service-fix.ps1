# CORRECCION FINAL - Script de Servicio Optimizado
# Solucion definitiva para el problema de inicializacion

Write-Host "APLICANDO CORRECCION FINAL AL SERVICIO" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor White

$projectPath = "C:\Aplicaciones\mi-servidor-web"
$serviceName = "VSM-Dashboard-BorgWarner"

# 1. DETENER SERVICIO
Write-Host "`n1. DETENIENDO SERVICIO..." -ForegroundColor Cyan
try {
    net stop $serviceName
    Write-Host "   Servicio detenido" -ForegroundColor Green
    Start-Sleep 5
} catch {
    Write-Host "   Servicio ya estaba detenido" -ForegroundColor Yellow
}

# 2. CREAR SCRIPT DE SERVICIO SUPER SIMPLIFICADO
Write-Host "`n2. CREANDO SCRIPT OPTIMIZADO..." -ForegroundColor Cyan

$optimizedScript = @"
@echo off
title Dashboard VSM BorgWarner - Servicio Optimizado
echo ================================================================
echo        DASHBOARD VSM BORGWARNER - SERVICIO OPTIMIZADO
echo ================================================================
echo [%date% %time%] Iniciando servicio optimizado...

REM Configurar directorio y variables
cd /d "$projectPath"
set NODE_ENV=production
set PORT=3001
set HTTPS_PORT=3443
set HOST=0.0.0.0

echo Directorio: %CD%
echo Variables configuradas

REM Verificacion rapida de Node.js
node --version
if errorlevel 1 (
    echo ERROR: Node.js no disponible
    exit /b 1
)

echo Node.js disponible, continuando...

REM Limpiar procesos anteriores
echo Limpiando procesos anteriores...
taskkill /f /im node.exe > nul 2>&1

REM Esperar solo 10 segundos
echo Esperando 10 segundos...
timeout /t 10 /nobreak > nul

echo ================================================================
echo INICIANDO SERVIDOR HTTPS (PRIORITARIO)
echo ================================================================

REM Verificar certificados SSL primero
if not exist "certs\cert.pem" (
    echo ERROR: Certificado SSL no encontrado
    echo Fallback a HTTP...
    goto START_HTTP
)

if not exist "certs\key.pem" (
    echo ERROR: Clave privada SSL no encontrada
    echo Fallback a HTTP...
    goto START_HTTP
)

REM Verificar server-https.js
if not exist "server-https.js" (
    echo ERROR: server-https.js no encontrado
    echo Fallback a HTTP...
    goto START_HTTP
)

echo Certificados SSL y servidor HTTPS encontrados

REM Iniciar servidor HTTPS directamente (puerto 3443)
echo [%date% %time%] Iniciando servidor HTTPS en puerto 3443...
start /b /wait cmd /c "node server-https.js > logs\https-service.log 2>&1"

REM Si llegamos aqui, significa que Node.js termino inesperadamente
echo [%date% %time%] ALERTA: Servidor HTTPS termino, reintentando...

REM Loop de reinicio HTTPS
:RESTART_HTTPS_LOOP
echo [%date% %time%] Reiniciando servidor HTTPS...
timeout /t 5 /nobreak > nul

REM Verificar si el puerto esta libre
netstat -an | find ":3443" > nul
if not errorlevel 1 (
    echo Puerto 3443 aun ocupado, esperando...
    timeout /t 10 /nobreak > nul
)

REM Reiniciar servidor HTTPS
start /b cmd /c "node server-https.js > logs\https-service.log 2>&1"
timeout /t 30 /nobreak > nul

REM Verificar si esta funcionando
netstat -an | find ":3443" > nul
if errorlevel 1 (
    echo Servidor HTTPS no inicio correctamente, reintentando...
    goto RESTART_HTTPS_LOOP
)

echo [%date% %time%] Servidor HTTPS funcionando en puerto 3443
goto KEEP_ALIVE_HTTPS

REM Fallback a HTTP si HTTPS falla
:START_HTTP
echo ================================================================
echo INICIANDO SERVIDOR HTTP (FALLBACK)
echo ================================================================

REM Verificar server.js
if not exist "server.js" (
    echo ERROR: server.js no encontrado
    exit /b 1
)

echo Archivo server.js encontrado

REM Iniciar servidor HTTP directamente
echo [%date% %time%] Iniciando servidor HTTP en puerto 3001...
start /b /wait cmd /c "node server.js > logs\http-service.log 2>&1"

REM Si llegamos aqui, significa que Node.js termino inesperadamente
echo [%date% %time%] ALERTA: Servidor HTTP termino, reintentando...

REM Loop de reinicio HTTP
:RESTART_HTTP_LOOP
echo [%date% %time%] Reiniciando servidor HTTP...
timeout /t 5 /nobreak > nul

REM Verificar si el puerto esta libre
netstat -an | find ":3001" > nul
if not errorlevel 1 (
    echo Puerto 3001 aun ocupado, esperando...
    timeout /t 10 /nobreak > nul
)

REM Reiniciar servidor HTTP
start /b cmd /c "node server.js > logs\http-service.log 2>&1"
timeout /t 30 /nobreak > nul

REM Verificar si esta funcionando
netstat -an | find ":3001" > nul
if errorlevel 1 (
    echo Servidor HTTP no inicio correctamente, reintentando...
    goto RESTART_HTTP_LOOP
)

echo [%date% %time%] Servidor HTTP funcionando en puerto 3001
goto KEEP_ALIVE_HTTP

REM Mantener el servicio HTTPS vivo
:KEEP_ALIVE_HTTPS
timeout /t 60 /nobreak > nul

REM Verificar que el proceso sigue vivo
tasklist /fi "imagename eq node.exe" | find "node.exe" > nul
if errorlevel 1 (
    echo [%date% %time%] Proceso Node.js terminado, reiniciando HTTPS...
    goto RESTART_HTTPS_LOOP
)

REM Verificar puerto HTTPS especificamente
netstat -an | find ":3443" > nul
if errorlevel 1 (
    echo [%date% %time%] Puerto 3443 no activo, reiniciando...
    goto RESTART_HTTPS_LOOP
)

echo [%date% %time%] Servidor HTTPS funcionando correctamente
goto KEEP_ALIVE_HTTPS

REM Mantener el servicio HTTP vivo (fallback)
:KEEP_ALIVE_HTTP
timeout /t 60 /nobreak > nul

REM Verificar que el proceso sigue vivo
tasklist /fi "imagename eq node.exe" | find "node.exe" > nul
if errorlevel 1 (
    echo [%date% %time%] Proceso Node.js terminado, reiniciando HTTP...
    goto RESTART_HTTP_LOOP
)

REM Verificar puerto HTTP especificamente
netstat -an | find ":3001" > nul
if errorlevel 1 (
    echo [%date% %time%] Puerto 3001 no activo, reiniciando...
    goto RESTART_HTTP_LOOP
)

echo [%date% %time%] Servidor HTTP funcionando correctamente
goto KEEP_ALIVE_HTTP
"@

$serviceScriptPath = "$projectPath\vsm-service.bat"
$optimizedScript | Out-File -FilePath $serviceScriptPath -Encoding UTF8
Write-Host "   Script optimizado creado" -ForegroundColor Green

# 3. CREAR TAMBIEN UN SCRIPT DE INICIO SIMPLE PARA HTTPS
Write-Host "`n3. CREANDO SCRIPT HTTPS COMPLEMENTARIO..." -ForegroundColor Cyan

if (Test-Path "$projectPath\certs\cert.pem") {
    $httpsScript = @"
@echo off
title HTTPS Server - Puerto 3443
cd /d "$projectPath"
set NODE_ENV=production
set HTTPS_PORT=3443
set HOST=0.0.0.0

echo Iniciando servidor HTTPS en puerto 3443...
node server-https.js
"@
    
    $httpsScript | Out-File -FilePath "$projectPath\start-https-manual.bat" -Encoding UTF8
    Write-Host "   Script HTTPS manual creado" -ForegroundColor Green
} else {
    Write-Host "   Certificados SSL no encontrados - HTTPS omitido" -ForegroundColor Yellow
}

# 4. REINICIAR SERVICIO
Write-Host "`n4. REINICIANDO SERVICIO..." -ForegroundColor Cyan
try {
    net start $serviceName
    Write-Host "   Servicio reiniciado" -ForegroundColor Green
} catch {
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. MONITOREO INICIAL
Write-Host "`n5. MONITOREO INICIAL (60 segundos)..." -ForegroundColor Cyan

for ($i = 1; $i -le 6; $i++) {
    Start-Sleep 10
    Write-Host "   $($i * 10) segundos..." -ForegroundColor Gray
    
    # Verificar estado cada 20 segundos
    if ($i % 2 -eq 0) {
        $service = Get-Service $serviceName -ErrorAction SilentlyContinue
        $nodeProc = Get-Process | Where-Object {$_.ProcessName -eq "node"}
        $port3443 = netstat -ano | findstr ":3443"
        $port3001 = netstat -ano | findstr ":3001"
        
        Write-Host "     Servicio: $($service.Status)" -ForegroundColor $(if($service.Status -eq "Running"){"Green"}else{"Red"})
        Write-Host "     Node.js: $($nodeProc.Count) procesos" -ForegroundColor $(if($nodeProc.Count -gt 0){"Green"}else{"Red"})
        Write-Host "     Puerto 3443 (HTTPS): $(if($port3443){"ACTIVO"}else{"INACTIVO"})" -ForegroundColor $(if($port3443){"Green"}else{"Red"})
        Write-Host "     Puerto 3001 (HTTP): $(if($port3001){"ACTIVO"}else{"INACTIVO"})" -ForegroundColor $(if($port3001){"Yellow"}else{"Gray"})
        
        if ($port3443 -and $nodeProc.Count -gt 0) {
            Write-Host "     ¡SERVIDOR HTTPS FUNCIONANDO!" -ForegroundColor Green
            break
        } elseif ($port3001 -and $nodeProc.Count -gt 0) {
            Write-Host "     ¡SERVIDOR HTTP FUNCIONANDO (FALLBACK)!" -ForegroundColor Yellow
            break
        }
    }
}

# 6. VERIFICACION FINAL
Write-Host "`n6. VERIFICACION FINAL:" -ForegroundColor Cyan

$finalService = Get-Service $serviceName -ErrorAction SilentlyContinue
$finalNodes = Get-Process | Where-Object {$_.ProcessName -eq "node"}
$finalPortHTTPS = netstat -ano | findstr ":3443"
$finalPortHTTP = netstat -ano | findstr ":3001"

Write-Host "   Servicio: $($finalService.Status)" -ForegroundColor $(if($finalService.Status -eq "Running"){"Green"}else{"Red"})
Write-Host "   Procesos Node.js: $($finalNodes.Count)" -ForegroundColor $(if($finalNodes.Count -gt 0){"Green"}else{"Red"})
Write-Host "   Puerto 3443 (HTTPS): $(if($finalPortHTTPS){"ACTIVO"}else{"INACTIVO"})" -ForegroundColor $(if($finalPortHTTPS){"Green"}else{"Red"})
Write-Host "   Puerto 3001 (HTTP): $(if($finalPortHTTP){"ACTIVO"}else{"INACTIVO"})" -ForegroundColor $(if($finalPortHTTP){"Yellow"}else{"Gray"})

# Test HTTPS primero
try {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-WebRequest "https://localhost:3443/api/status" -UseBasicParsing -TimeoutSec 5
    Write-Host "   HTTPS Test: EXITOSO (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "   HTTPS Test: FALLO" -ForegroundColor Red
    # Probar HTTP como fallback
    try {
        $response = Invoke-WebRequest "http://localhost:3001/api/status" -UseBasicParsing -TimeoutSec 5
        Write-Host "   HTTP Test (Fallback): EXITOSO (Status: $($response.StatusCode))" -ForegroundColor Yellow
    } catch {
        Write-Host "   HTTP Test (Fallback): FALLO" -ForegroundColor Red
    }
}

Write-Host "`n======================================" -ForegroundColor White
if ($finalPortHTTPS -and $finalNodes.Count -gt 0) {
    Write-Host "CORRECCION EXITOSA - SERVIDOR HTTPS FUNCIONANDO" -ForegroundColor Green
    Write-Host "URL Primaria: https://localhost:3443/dashboard/value-stream-map.html" -ForegroundColor White
    Write-Host "URL Red: https://10.42.126.12:3443/dashboard/value-stream-map.html" -ForegroundColor White
    Write-Host "NOTA: Aceptar certificado auto-firmado en el navegador" -ForegroundColor Yellow
} elseif ($finalPortHTTP -and $finalNodes.Count -gt 0) {
    Write-Host "CORRECCION EXITOSA - SERVIDOR HTTP FUNCIONANDO (FALLBACK)" -ForegroundColor Yellow
    Write-Host "URL: http://localhost:3001/dashboard/value-stream-map.html" -ForegroundColor White
    Write-Host "URL Red: http://10.42.126.12:3001/dashboard/value-stream-map.html" -ForegroundColor White
    Write-Host "RECOMENDACION: Verificar certificados SSL para HTTPS" -ForegroundColor Yellow
} else {
    Write-Host "CORRECCION APLICADA - VERIFICAR LOGS" -ForegroundColor Yellow
    Write-Host "Comando HTTPS: Get-Content $projectPath\logs\https-service.log -Wait" -ForegroundColor White
    Write-Host "Comando HTTP: Get-Content $projectPath\logs\http-service.log -Wait" -ForegroundColor White
}
Write-Host "======================================" -ForegroundColor White