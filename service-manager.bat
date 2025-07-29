@echo off
title Gestor de Servicio VSM Dashboard
color 0A

:MENU
cls
echo ================================================================
echo           GESTOR SERVICIO VSM DASHBOARD BORGWARNER
echo ================================================================
echo.
echo [1] Ver estado del servicio
echo [2] Iniciar servicio  
echo [3] Detener servicio
echo [4] Reiniciar servicio
echo [5] Ver logs del servicio
echo [6] Probar conectividad
echo [7] Abrir Services.msc
echo [8] Salir
echo.
set /p choice=Seleccione una opcion (1-8): 

if "%choice%"=="1" goto STATUS
if "%choice%"=="2" goto START
if "%choice%"=="3" goto STOP  
if "%choice%"=="4" goto RESTART
if "%choice%"=="5" goto LOGS
if "%choice%"=="6" goto TEST
if "%choice%"=="7" goto SERVICES
if "%choice%"=="8" goto EXIT
goto MENU

:STATUS
echo.
echo Estado del servicio:
sc query VSM-Dashboard-BorgWarner
echo.
echo Estado detallado NSSM:
C:\Tools\nssm\nssm.exe status VSM-Dashboard-BorgWarner
pause
goto MENU

:START
echo.
echo Iniciando servicio...
net start VSM-Dashboard-BorgWarner
pause
goto MENU

:STOP
echo.
echo Deteniendo servicio...
net stop VSM-Dashboard-BorgWarner
pause
goto MENU

:RESTART
echo.
echo Reiniciando servicio...
net stop VSM-Dashboard-BorgWarner
timeout /t 5 /nobreak
net start VSM-Dashboard-BorgWarner
pause
goto MENU

:LOGS
echo.
echo Logs del servicio (ultimas 50 lineas):
if exist "C:\Aplicaciones\mi-servidor-web\logs\service-output.log" (
    powershell "Get-Content 'C:\Aplicaciones\mi-servidor-web\logs\service-output.log' -Tail 50"
) else (
    echo No hay logs disponibles
)
pause
goto MENU

:TEST
echo.
echo Probando conectividad...
curl -s http://localhost:3001/api/status
if errorlevel 1 (
    echo ERROR: Dashboard no responde
) else (
    echo OK: Dashboard respondiendo
)
echo.
echo Probando acceso web...
curl -s -o nul -w "HTTP Status: %%{http_code}" http://localhost:3001
echo.
pause
goto MENU

:SERVICES
echo.
echo Abriendo administrador de servicios...
services.msc
goto MENU

:EXIT
exit

