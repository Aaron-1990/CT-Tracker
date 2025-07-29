# ACTUALIZACION A SERVICIO DUAL HTTP/HTTPS - Dashboard VSM BorgWarner
# Corregir servicio para soportar tanto HTTP (3001) como HTTPS (3443)

Write-Host "ACTUALIZACION A SERVICIO DUAL HTTP/HTTPS" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor White

$projectPath = "C:\Aplicaciones\mi-servidor-web"
$serviceName = "VSM-Dashboard-BorgWarner"

# 1. VERIFICAR ESTADO ACTUAL
Write-Host "`n1. VERIFICANDO CONFIGURACION ACTUAL..." -ForegroundColor Cyan

# Verificar archivos necesarios
$requiredFiles = @(
    "$projectPath\ecosystem.config.js",
    "$projectPath\ecosystem-https.config.js", 
    "$projectPath\server.js",
    "$projectPath\server-https.js",
    "$projectPath\certs\cert.pem",
    "$projectPath\certs\key.pem"
)

$httpsAvailable = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "   ENCONTRADO: $file" -ForegroundColor Green
    } else {
        Write-Host "   FALTANTE: $file" -ForegroundColor Red
        if ($file -like "*https*" -or $file -like "*certs*") {
            $httpsAvailable = $false
        }
    }
}

if ($httpsAvailable) {
    Write-Host "   STATUS: Configuracion DUAL HTTP/HTTPS disponible" -ForegroundColor Green
} else {
    Write-Host "   STATUS: Solo HTTP disponible (HTTPS requiere certificados)" -ForegroundColor Yellow
}

# 2. DETENER SERVICIO ACTUAL
Write-Host "`n2. DETENIENDO SERVICIO ACTUAL..." -ForegroundColor Cyan
try {
    net stop $serviceName
    Write-Host "   Servicio detenido exitosamente" -ForegroundColor Green
    Start-Sleep 5
} catch {
    Write-Host "   Servicio ya estaba detenido" -ForegroundColor Yellow
}

# 3. ACTUALIZAR SCRIPT DE SERVICIO DUAL
Write-Host "`n3. ACTUALIZANDO SCRIPT DE SERVICIO DUAL..." -ForegroundColor Cyan

$dualServiceScript = @"
@echo off
title Dashboard VSM BorgWarner - Servicio Dual HTTP/HTTPS
echo ================================================================
echo     DASHBOARD VSM BORGWARNER - SERVICIO DUAL HTTP/HTTPS
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

REM Esperar estabilizacion del sistema (solo para servicios)
echo Esperando estabilizacion del sistema (30 segundos)...
timeout /t 30 /nobreak > nul

REM Limpiar procesos PM2 existentes
echo Limpiando procesos anteriores...
pm2 kill > nul 2>&1
timeout /t 5 /nobreak > nul

REM Verificar que PM2 daemon este disponible
echo Iniciando PM2 daemon...
pm2 ping > nul 2>&1
if errorlevel 1 (
    echo PM2 daemon no responde, iniciando...
    pm2 status > nul 2>&1
)

echo ================================================================
echo INICIANDO SERVIDORES DUAL HTTP/HTTPS
echo ================================================================

REM Iniciar servidor HTTP (puerto 3001)
echo Iniciando servidor HTTP en puerto 3001...
pm2 start ecosystem.config.js --env production
if errorlevel 1 (
    echo ERROR: No se pudo iniciar servidor HTTP
    echo Intentando con server.js directamente...
    pm2 start server.js --name "vsm-dashboard-borgwarner" --env production
)

REM Esperar que HTTP se estabilice
timeout /t 10 /nobreak > nul

REM Verificar certificados SSL para HTTPS
echo Verificando certificados SSL...
if exist "certs\cert.pem" (
    if exist "certs\key.pem" (
        echo Certificados SSL encontrados, iniciando servidor HTTPS...
        
        REM Iniciar servidor HTTPS (puerto 3443)
        echo Iniciando servidor HTTPS en puerto 3443...
        pm2 start ecosystem-https.config.js --env production
        if errorlevel 1 (
            echo ERROR: No se pudo iniciar servidor HTTPS
            echo Intentando con server-https.js directamente...
            pm2 start server-https.js --name "vsm-dashboard-borgwarner-https" --env production
        )
        
        timeout /t 10 /nobreak > nul
    ) else (
        echo ADVERTENCIA: certs/key.pem no encontrado - HTTPS no disponible
    )
) else (
    echo ADVERTENCIA: certs/cert.pem no encontrado - HTTPS no disponible
)

REM Verificar estado de servicios iniciados
echo ================================================================
echo VERIFICANDO ESTADO DE SERVICIOS
echo ================================================================

pm2 status | findstr "online"
if errorlevel 1 (
    echo ERROR: Ningun servicio se inicio correctamente
    echo Intentando recuperacion...
    pm2 start server.js --name "vsm-dashboard-borgwarner-backup" --env production
)

REM Guardar configuracion PM2
echo Guardando configuracion PM2...
pm2 save > nul 2>&1

echo ================================================================
echo DASHBOARD VSM INICIADO COMO SERVICIO DUAL
echo ================================================================
echo HTTP Local:   http://localhost:3001
echo HTTP Red:     http://10.42.126.12:3001
echo HTTPS Local:  https://localhost:3443
echo HTTPS Red:    https://10.42.126.12:3443
echo VSM HTTP:     http://localhost:3001/dashboard/value-stream-map.html
echo VSM HTTPS:    https://localhost:3443/dashboard/value-stream-map.html
echo ================================================================

REM Mantener el servicio vivo con monitoreo dual
set HTTP_COUNTER=0
set HTTPS_COUNTER=0

:LOOP
timeout /t 30 /nobreak > nul

REM Verificar que PM2 daemon este vivo
pm2 ping > nul 2>&1
if errorlevel 1 (
    echo [%date% %time%] ALERTA: PM2 daemon no responde, reiniciando...
    pm2 kill > nul 2>&1
    timeout /t 5 /nobreak > nul
    pm2 start ecosystem.config.js --env production
    if exist "certs\cert.pem" (
        pm2 start ecosystem-https.config.js --env production
    )
    pm2 save > nul 2>&1
    echo [%date% %time%] PM2 y servicios reiniciados
)

REM Verificar que los servicios esten online
pm2 status | findstr "online" > nul
if errorlevel 1 (
    echo [%date% %time%] ALERTA: Servicios no online, reiniciando...
    pm2 restart all > nul 2>&1
    echo [%date% %time%] Servicios reiniciados
)

REM Verificar conectividad HTTP cada 5 minutos (contador 10 = 5 minutos)
set /a HTTP_COUNTER+=1
if %HTTP_COUNTER% GEQ 10 (
    set HTTP_COUNTER=0
    
    REM Test HTTP puerto 3001
    curl -s -m 5 http://localhost:3001/api/status > nul 2>&1
    if errorlevel 1 (
        echo [%date% %time%] ALERTA: HTTP 3001 no responde, reiniciando...
        pm2 restart vsm-dashboard-borgwarner > nul 2>&1
    ) else (
        echo [%date% %time%] OK: HTTP 3001 respondiendo correctamente
    )
)

REM Verificar conectividad HTTPS cada 5 minutos
set /a HTTPS_COUNTER+=1
if %HTTPS_COUNTER% GEQ 10 (
    set HTTPS_COUNTER=0
    
    if exist "certs\cert.pem" (
        REM Test HTTPS puerto 3443 (usando curl con -k para certificados auto-firmados)
        curl -s -k -m 5 https://localhost:3443/api/status > nul 2>&1
        if errorlevel 1 (
            echo [%date% %time%] ALERTA: HTTPS 3443 no responde, reiniciando...
            pm2 restart vsm-dashboard-borgwarner-https > nul 2>&1
        ) else (
            echo [%date% %time%] OK: HTTPS 3443 respondiendo correctamente
        )
    )
)

goto LOOP
"@

$serviceScriptPath = "$projectPath\vsm-service.bat"
$dualServiceScript | Out-File -FilePath $serviceScriptPath -Encoding UTF8
Write-Host "   Script de servicio dual actualizado" -ForegroundColor Green

# 4. ACTUALIZAR SCRIPT DE VERIFICACION
Write-Host "`n4. ACTUALIZANDO SCRIPT DE VERIFICACION..." -ForegroundColor Cyan

$updatedVerificationScript = @"
# VERIFICACION DUAL HTTP/HTTPS - Dashboard VSM BorgWarner

Write-Host "VERIFICACION DUAL HTTP/HTTPS - DASHBOARD VSM" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor White

# 1. Estado del servicio Windows
Write-Host "`n1. SERVICIO WINDOWS:" -ForegroundColor Cyan
Get-Service VSM-Dashboard-BorgWarner

# 2. Verificacion HTTP (Puerto 3001)
Write-Host "`n2. VERIFICACION HTTP (Puerto 3001):" -ForegroundColor Cyan
try {
    `$response = Invoke-WebRequest "http://localhost:3001/api/status" -UseBasicParsing -TimeoutSec 10
    Write-Host "   HTTP Status: `$(`$response.StatusCode)" -ForegroundColor Green
    Write-Host "   HTTP: RESPONDIENDO" -ForegroundColor Green
} catch {
    Write-Host "   HTTP Error: `$(`$_.Exception.Message)" -ForegroundColor Red
}

# 3. Verificacion HTTPS (Puerto 3443)  
Write-Host "`n3. VERIFICACION HTTPS (Puerto 3443):" -ForegroundColor Cyan
try {
    # Ignore SSL certificate errors for self-signed certificates
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {`$true}
    `$response = Invoke-WebRequest "https://localhost:3443/api/status" -UseBasicParsing -TimeoutSec 10
    Write-Host "   HTTPS Status: `$(`$response.StatusCode)" -ForegroundColor Green
    Write-Host "   HTTPS: RESPONDIENDO" -ForegroundColor Green
} catch {
    Write-Host "   HTTPS Error: `$(`$_.Exception.Message)" -ForegroundColor Red
    if (Test-Path "C:\Aplicaciones\mi-servidor-web\certs\cert.pem") {
        Write-Host "   Certificados SSL encontrados - verificar logs" -ForegroundColor Yellow
    } else {
        Write-Host "   Certificados SSL no encontrados" -ForegroundColor Red
    }
}

# 4. Verificacion de puertos
Write-Host "`n4. PUERTOS ACTIVOS:" -ForegroundColor Cyan
`$port3001 = netstat -ano | findstr ":3001"
`$port3443 = netstat -ano | findstr ":3443"

if (`$port3001) {
    Write-Host "   Puerto 3001 (HTTP): ACTIVO" -ForegroundColor Green
} else {
    Write-Host "   Puerto 3001 (HTTP): NO DETECTADO" -ForegroundColor Red
}

if (`$port3443) {
    Write-Host "   Puerto 3443 (HTTPS): ACTIVO" -ForegroundColor Green
} else {
    Write-Host "   Puerto 3443 (HTTPS): NO DETECTADO" -ForegroundColor Red
}

# 5. URLs disponibles
Write-Host "`n5. URLS DISPONIBLES:" -ForegroundColor Cyan
Write-Host "   HTTP Local:   http://localhost:3001/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "   HTTP Red:     http://10.42.126.12:3001/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "   HTTPS Local:  https://localhost:3443/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "   HTTPS Red:    https://10.42.126.12:3443/dashboard/value-stream-map.html" -ForegroundColor White

Write-Host "`n=============================================" -ForegroundColor White
"@

$verificationScriptPath = "$projectPath\verificacion-dual.ps1"
$updatedVerificationScript | Out-File -FilePath $verificationScriptPath -Encoding UTF8
Write-Host "   Script de verificacion dual creado" -ForegroundColor Green

# 5. REINICIAR SERVICIO CON CONFIGURACION DUAL
Write-Host "`n5. REINICIANDO SERVICIO CON CONFIGURACION DUAL..." -ForegroundColor Cyan
try {
    net start $serviceName
    Write-Host "   Servicio reiniciado exitosamente" -ForegroundColor Green
} catch {
    Write-Host "   Error reiniciando servicio: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. ESPERAR INICIALIZACION
Write-Host "`n6. ESPERANDO INICIALIZACION DUAL (90 segundos)..." -ForegroundColor Cyan
Write-Host "   Tiempo adicional necesario para inicio de ambos servidores" -ForegroundColor Gray
Start-Sleep 90

# 7. VERIFICACION FINAL DUAL
Write-Host "`n7. VERIFICACION FINAL DUAL:" -ForegroundColor Cyan

# Estado del servicio
$serviceStatus = Get-Service $serviceName -ErrorAction SilentlyContinue
if ($serviceStatus) {
    Write-Host "   Servicio Windows: $($serviceStatus.Status)" -ForegroundColor $(if($serviceStatus.Status -eq "Running"){"Green"}else{"Red"})
}

# Puerto 3001 (HTTP)
$port3001 = netstat -ano | findstr ":3001"
if ($port3001) {
    Write-Host "   Puerto 3001 (HTTP): ACTIVO" -ForegroundColor Green
} else {
    Write-Host "   Puerto 3001 (HTTP): NO DETECTADO" -ForegroundColor Red
}

# Puerto 3443 (HTTPS) 
$port3443 = netstat -ano | findstr ":3443"
if ($port3443) {
    Write-Host "   Puerto 3443 (HTTPS): ACTIVO" -ForegroundColor Green
} else {
    Write-Host "   Puerto 3443 (HTTPS): NO DETECTADO (verificar certificados)" -ForegroundColor Yellow
}

# Test HTTP
try {
    $response = Invoke-WebRequest "http://localhost:3001/api/status" -UseBasicParsing -TimeoutSec 10
    Write-Host "   HTTP Test: EXITOSO (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "   HTTP Test: FALLO" -ForegroundColor Red
}

# Test HTTPS (si certificados existen)
if (Test-Path "$projectPath\certs\cert.pem") {
    try {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $response = Invoke-WebRequest "https://localhost:3443/api/status" -UseBasicParsing -TimeoutSec 10
        Write-Host "   HTTPS Test: EXITOSO (Status: $($response.StatusCode))" -ForegroundColor Green
    } catch {
        Write-Host "   HTTPS Test: FALLO (aun inicializando o problema certificados)" -ForegroundColor Yellow
    }
} else {
    Write-Host "   HTTPS Test: OMITIDO (certificados no encontrados)" -ForegroundColor Gray
}

Write-Host "`n=========================================" -ForegroundColor White
Write-Host "ACTUALIZACION A SERVICIO DUAL COMPLETADA" -ForegroundColor Green
Write-Host "`nCOMandos utiles:" -ForegroundColor White
Write-Host "   .\verificacion-dual.ps1  - Verificacion completa dual" -ForegroundColor Gray
Write-Host "   Get-Content $projectPath\logs\service-output.log -Wait  - Monitorear logs" -ForegroundColor Gray
Write-Host "=========================================" -ForegroundColor White