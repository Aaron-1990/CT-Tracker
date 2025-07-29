# TROUBLESHOOTING Y MONITOREO - DASHBOARD VSM BORGWARNER
# Comandos para diagnosticar y monitorear el proceso de inicializacion

Write-Host "TROUBLESHOOTING DASHBOARD VSM BORGWARNER" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor White

# 1. MONITOREAR LOGS EN TIEMPO REAL
Write-Host "`n1. MONITOREAR LOGS EN TIEMPO REAL (Ctrl+C para salir):" -ForegroundColor Cyan
Write-Host "Get-Content C:\Aplicaciones\mi-servidor-web\logs\service-output.log -Wait -Tail 10" -ForegroundColor Yellow

# 2. VERIFICAR PROCESO DE INICIALIZACION
Write-Host "`n2. VERIFICAR ESTADO ACTUAL DEL SCRIPT DE SERVICIO:" -ForegroundColor Cyan

$logPath = "C:\Aplicaciones\mi-servidor-web\logs\service-output.log"
if (Test-Path $logPath) {
    $lastLines = Get-Content $logPath -Tail 20
    
    # Buscar indicadores de progreso
    $foundStabilization = $lastLines | Where-Object { $_ -like "*estabilizacion*" }
    $foundPM2Start = $lastLines | Where-Object { $_ -like "*pm2 start*" }
    $foundOnline = $lastLines | Where-Object { $_ -like "*online*" }
    $foundError = $lastLines | Where-Object { $_ -like "*ERROR*" -or $_ -like "*error*" }
    
    Write-Host "Indicadores encontrados en los logs:" -ForegroundColor White
    if ($foundStabilization) {
        Write-Host "   - Fase de estabilizacion: DETECTADA" -ForegroundColor Yellow
    }
    if ($foundPM2Start) {
        Write-Host "   - Inicio PM2: DETECTADO" -ForegroundColor Green
    }
    if ($foundOnline) {
        Write-Host "   - Dashboard online: DETECTADO" -ForegroundColor Green
    }
    if ($foundError) {
        Write-Host "   - Errores: DETECTADOS" -ForegroundColor Red
        $foundError | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
    }
    
    Write-Host "`nUltimas 10 lineas del log:" -ForegroundColor Gray
    $lastLines[-10..-1] | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
}

# 3. FORZAR VERIFICACION DE CONECTIVIDAD CON REINTENTOS
Write-Host "`n3. VERIFICACION DE CONECTIVIDAD CON REINTENTOS:" -ForegroundColor Cyan

for ($i = 1; $i -le 5; $i++) {
    Write-Host "   Intento $i/5..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-WebRequest "http://localhost:3001/api/status" -UseBasicParsing -TimeoutSec 5
        Write-Host "   EXITO: Dashboard respondiendo (Status: $($response.StatusCode))" -ForegroundColor Green
        break
    } catch {
        Write-Host "   Fallo: $($_.Exception.Message)" -ForegroundColor Red
        
        # Verificar si el puerto esta activo
        $portCheck = netstat -ano | findstr ":3001"
        if ($portCheck) {
            Write-Host "   Puerto 3001 detectado - Dashboard iniciando..." -ForegroundColor Yellow
        } else {
            Write-Host "   Puerto 3001 no detectado - Aun inicializando..." -ForegroundColor Yellow
        }
        
        if ($i -lt 5) {
            Write-Host "   Esperando 30 segundos antes del siguiente intento..." -ForegroundColor Gray
            Start-Sleep 30
        }
    }
}

# 4. VERIFICAR PROCESOS NODE.JS Y PM2
Write-Host "`n4. PROCESOS RELACIONADOS:" -ForegroundColor Cyan
$nodeProcesses = Get-Process | Where-Object { $_.ProcessName -like "*node*" -or $_.ProcessName -like "*pm2*" }

if ($nodeProcesses) {
    Write-Host "   Procesos Node.js/PM2 detectados:" -ForegroundColor Green
    $nodeProcesses | ForEach-Object {
        Write-Host "   - $($_.ProcessName) (PID: $($_.Id), CPU: $($_.CPU), Memoria: $([math]::Round($_.WorkingSet64/1MB, 2)) MB)" -ForegroundColor White
    }
} else {
    Write-Host "   No se detectaron procesos Node.js/PM2" -ForegroundColor Yellow
    Write-Host "   Esto puede indicar que el servicio aun no ha llegado a la fase PM2" -ForegroundColor Yellow
}

# 5. COMANDOS DE DIAGNOSTICO AVANZADO
Write-Host "`n5. COMANDOS DE DIAGNOSTICO ADICIONAL:" -ForegroundColor Cyan
Write-Host "   # Ver todos los logs del servicio:" -ForegroundColor White
Write-Host "   Get-Content C:\Aplicaciones\mi-servidor-web\logs\service-output.log" -ForegroundColor Gray
Write-Host "   
   # Ver logs de error del servicio:" -ForegroundColor White
Write-Host "   Get-Content C:\Aplicaciones\mi-servidor-web\logs\service-error.log" -ForegroundColor Gray
Write-Host "   
   # Reiniciar el servicio manualmente:" -ForegroundColor White
Write-Host "   net stop VSM-Dashboard-BorgWarner" -ForegroundColor Gray
Write-Host "   Start-Sleep 10" -ForegroundColor Gray
Write-Host "   net start VSM-Dashboard-BorgWarner" -ForegroundColor Gray
Write-Host "   
   # Ver estado detallado del servicio:" -ForegroundColor White
Write-Host "   C:\Tools\nssm\nssm.exe status VSM-Dashboard-BorgWarner" -ForegroundColor Gray

# 6. ESTIMACION DE TIEMPO DE INICIALIZACION
Write-Host "`n6. ESTIMACION DE TIEMPO:" -ForegroundColor Cyan
Write-Host "   Tiempo total estimado de inicializacion: 3-5 minutos" -ForegroundColor White
Write-Host "   - Estabilizacion del sistema: 45 segundos" -ForegroundColor Gray
Write-Host "   - Limpieza PM2: 5 segundos" -ForegroundColor Gray
Write-Host "   - Inicio PM2 y Node.js: 15-30 segundos" -ForegroundColor Gray
Write-Host "   - Verificacion de servicios: 15 segundos" -ForegroundColor Gray
Write-Host "   - Disponibilidad HTTP: 30-60 segundos adicionales" -ForegroundColor Gray

Write-Host "`n=========================================" -ForegroundColor White
Write-Host "RECOMENDACION: Esperar 2-3 minutos mas y volver a verificar" -ForegroundColor Yellow
Write-Host "Si persiste el problema, ejecutar reinicio manual del servicio" -ForegroundColor Yellow