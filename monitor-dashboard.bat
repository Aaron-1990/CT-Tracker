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
