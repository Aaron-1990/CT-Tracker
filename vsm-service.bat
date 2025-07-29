@echo off
title Dashboard VSM BorgWarner - Servicio Optimizado
echo ================================================================
echo        DASHBOARD VSM BORGWARNER - SERVICIO OPTIMIZADO
echo ================================================================
echo [%date% %time%] Iniciando servicio optimizado...

REM Configurar directorio y variables
cd /d "C:\Aplicaciones\mi-servidor-web"
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
