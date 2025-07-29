# MONITOR DE IMPLEMENTACION - Dashboard VSM BorgWarner
# Script para monitorear el progreso de la implementacion mejorada

Write-Host "MONITOR DE IMPLEMENTACION - ARQUITECTURA MEJORADA" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor White

$projectPath = "C:\Aplicaciones\mi-servidor-web"
$serviceName = "VSM-Dashboard-BorgWarner"

Write-Host "`nARQUITECTURA OBJETIVO:" -ForegroundColor Cyan
Write-Host "Windows Boot → Servicios → NSSM → Node.js Directo → Dashboard 24/7" -ForegroundColor White

# Monitorear en tiempo real durante la implementacion
Write-Host "`nINICIANDO MONITOREO DE IMPLEMENTACION..." -ForegroundColor Cyan
Write-Host "Presiona Ctrl+C para detener el monitoreo" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor White

$iteration = 0
while ($true) {
    $iteration++
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    Clear-Host
    Write-Host "MONITOR DE IMPLEMENTACION - DASHBOARD VSM BORGWARNER" -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor White
    Write-Host "Iteracion: $iteration | Hora: $timestamp" -ForegroundColor Gray
    
    # 1. Estado del servicio Windows
    Write-Host "`n1. SERVICIO WINDOWS:" -ForegroundColor Cyan
    try {
        $service = Get-Service $serviceName -ErrorAction Stop
        $serviceColor = switch ($service.Status) {
            "Running" { "Green" }
            "Paused" { "Yellow" }
            "Stopped" { "Red" }
            default { "Gray" }
        }
        Write-Host "   Estado: $($service.Status)" -ForegroundColor $serviceColor
    } catch {
        Write-Host "   ERROR: Servicio no encontrado" -ForegroundColor Red
    }
    
    # 2. Estado NSSM
    Write-Host "`n2. ESTADO NSSM:" -ForegroundColor Cyan
    $nssmPath = "C:\Tools\nssm\nssm.exe"
    if (Test-Path $nssmPath) {
        try {
            $nssmStatus = & $nssmPath status $serviceName 2>$null
            $nssmColor = if ($nssmStatus -eq "SERVICE_RUNNING") {"Green"} else {"Yellow"}
            Write-Host "   Status: $nssmStatus" -ForegroundColor $nssmColor
        } catch {
            Write-Host "   ERROR: No se puede verificar NSSM" -ForegroundColor Red
        }
    } else {
        Write-Host "   ERROR: NSSM no encontrado" -ForegroundColor Red
    }
    
    # 3. Procesos Node.js
    Write-Host "`n3. PROCESOS NODE.JS:" -ForegroundColor Cyan
    $nodeProcesses = Get-Process | Where-Object {$_.ProcessName -eq "node"}
    if ($nodeProcesses) {
        Write-Host "   Procesos activos: $($nodeProcesses.Count)" -ForegroundColor Green
        foreach ($proc in $nodeProcesses) {
            $memoryMB = [math]::Round($proc.WorkingSet64/1MB, 1)
            Write-Host "   - PID $($proc.Id): $memoryMB MB" -ForegroundColor White
        }
    } else {
        Write-Host "   No hay procesos Node.js ejecutandose" -ForegroundColor Red
    }
    
    # 4. Estados de puertos
    Write-Host "`n4. PUERTOS:" -ForegroundColor Cyan
    $port3001 = netstat -ano | findstr ":3001" | findstr "LISTENING"
    $port3443 = netstat -ano | findstr ":3443" | findstr "LISTENING"
    
    if ($port3001) {
        Write-Host "   Puerto 3001 (HTTP):  ACTIVO" -ForegroundColor Green
    } else {
        Write-Host "   Puerto 3001 (HTTP):  NO ACTIVO" -ForegroundColor Red
    }
    
    if ($port3443) {
        Write-Host "   Puerto 3443 (HTTPS): ACTIVO" -ForegroundColor Green
    } else {
        Write-Host "   Puerto 3443 (HTTPS): NO ACTIVO" -ForegroundColor Yellow
    }
    
    # 5. Test de conectividad
    Write-Host "`n5. CONECTIVIDAD:" -ForegroundColor Cyan
    
    # Test HTTP
    try {
        $httpResponse = Invoke-WebRequest "http://localhost:3001/api/status" -UseBasicParsing -TimeoutSec 3
        Write-Host "   HTTP (3001):  RESPONDIENDO ($($httpResponse.StatusCode))" -ForegroundColor Green
    } catch {
        Write-Host "   HTTP (3001):  NO RESPONDE" -ForegroundColor Red
    }
    
    # Test HTTPS
    try {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $httpsResponse = Invoke-WebRequest "https://localhost:3443/api/status" -UseBasicParsing -TimeoutSec 3
        Write-Host "   HTTPS (3443): RESPONDIENDO ($($httpsResponse.StatusCode))" -ForegroundColor Green
    } catch {
        Write-Host "   HTTPS (3443): NO RESPONDE" -ForegroundColor Red
    }
    
    # 6. Logs recientes
    Write-Host "`n6. LOGS RECIENTES:" -ForegroundColor Cyan
    $serviceLog = "$projectPath\logs\service-output.log"
    if (Test-Path $serviceLog) {
        $lastLines = Get-Content $serviceLog -Tail 3 -ErrorAction SilentlyContinue
        foreach ($line in $lastLines) {
            if ($line.Length -gt 0) {
                $shortLine = if ($line.Length -gt 70) { $line.Substring(0, 70) + "..." } else { $line }
                Write-Host "   $shortLine" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "   Archivo de log no encontrado" -ForegroundColor Yellow
    }
    
    # 7. URLs operativas
    Write-Host "`n7. URLS DISPONIBLES:" -ForegroundColor Cyan
    if ($port3001) {
        Write-Host "   ✅ http://localhost:3001/dashboard/value-stream-map.html" -ForegroundColor Green
        Write-Host "   ✅ http://10.42.126.12:3001/dashboard/value-stream-map.html" -ForegroundColor Green
    } else {
        Write-Host "   ❌ HTTP URLs no disponibles" -ForegroundColor Red
    }
    
    if ($port3443) {
        Write-Host "   ✅ https://localhost:3443/dashboard/value-stream-map.html" -ForegroundColor Green
        Write-Host "   ✅ https://10.42.126.12:3443/dashboard/value-stream-map.html" -ForegroundColor Green
    } else {
        Write-Host "   ❌ HTTPS URLs no disponibles" -ForegroundColor Yellow
    }
    
    # 8. Estado de implementacion
    Write-Host "`n8. ESTADO DE IMPLEMENTACION:" -ForegroundColor Cyan
    $score = 0
    $maxScore = 4
    
    if ($service -and $service.Status -eq "Running") { $score++ }
    if ($nodeProcesses.Count -gt 0) { $score++ }
    if ($port3001) { $score++ }
    if ($port3443) { $score++ }
    
    $percentage = [math]::Round(($score / $maxScore) * 100)
    $statusColor = if ($percentage -ge 100) {"Green"} elseif ($percentage -ge 75) {"Yellow"} else {"Red"}
    
    Write-Host "   Progreso: $score/$maxScore ($percentage%)" -ForegroundColor $statusColor
    
    if ($percentage -eq 100) {
        Write-Host "   STATUS: IMPLEMENTACION COMPLETADA ✅" -ForegroundColor Green
        Write-Host "   Dashboard operativo 24/7 sin dependencias de login" -ForegroundColor Green
    } elseif ($percentage -ge 75) {
        Write-Host "   STATUS: IMPLEMENTACION EN PROGRESO ⏳" -ForegroundColor Yellow
    } else {
        Write-Host "   STATUS: IMPLEMENTACION INICIANDO 🔄" -ForegroundColor Red
    }
    
    Write-Host "`n====================================================" -ForegroundColor White
    Write-Host "Actualizando en 10 segundos... (Ctrl+C para salir)" -ForegroundColor Gray
    
    Start-Sleep 10
}