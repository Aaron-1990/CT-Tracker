# ============================================================================
# VERIFICACION POST-CONVERSION - DASHBOARD VSM BORGWARNER
# Ejecutar estos comandos para confirmar que la conversion fue exitosa
# ============================================================================

Write-Host "VERIFICACION DEL SERVICIO DASHBOARD VSM BORGWARNER" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor White

# 1. VERIFICAR ESTADO DEL SERVICIO WINDOWS
Write-Host "`n1. ESTADO DEL SERVICIO WINDOWS:" -ForegroundColor Cyan
try {
    $service = Get-Service "VSM-Dashboard-BorgWarner" -ErrorAction Stop
    Write-Host "   Nombre: $($service.Name)" -ForegroundColor White
    Write-Host "   Estado: $($service.Status)" -ForegroundColor $(if($service.Status -eq "Running"){"Green"}else{"Red"})
    Write-Host "   Inicio: $($service.StartType)" -ForegroundColor White
} catch {
    Write-Host "   ERROR: Servicio no encontrado" -ForegroundColor Red
}

# 2. VERIFICAR NSSM STATUS
Write-Host "`n2. ESTADO DETALLADO NSSM:" -ForegroundColor Cyan
$nssmPath = "C:\Tools\nssm\nssm.exe"
if (Test-Path $nssmPath) {
    & $nssmPath status "VSM-Dashboard-BorgWarner"
} else {
    Write-Host "   NSSM no encontrado en la ruta esperada" -ForegroundColor Red
}

# 3. VERIFICAR CONECTIVIDAD HTTP
Write-Host "`n3. PRUEBA DE CONECTIVIDAD HTTP:" -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3001/api/status" -UseBasicParsing -TimeoutSec 10
    Write-Host "   Status Code: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   Dashboard: RESPONDIENDO" -ForegroundColor Green
} catch {
    Write-Host "   ERROR: Dashboard no responde aun" -ForegroundColor Yellow
    Write-Host "   Detalle: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host "   NOTA: Es normal durante los primeros minutos tras conversion" -ForegroundColor Yellow
}

# 4. VERIFICAR PUERTO 3001
Write-Host "`n4. VERIFICACION DE PUERTO 3001:" -ForegroundColor Cyan
$port3001 = netstat -ano | findstr ":3001"
if ($port3001) {
    Write-Host "   Puerto 3001: ACTIVO" -ForegroundColor Green
    Write-Host "   Detalles:" -ForegroundColor Gray
    $port3001 | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
} else {
    Write-Host "   Puerto 3001: NO DETECTADO" -ForegroundColor Red
}

# 5. VERIFICAR LOGS DEL SERVICIO
Write-Host "`n5. LOGS DEL SERVICIO (ULTIMAS 10 LINEAS):" -ForegroundColor Cyan
$serviceLogPath = "C:\Aplicaciones\mi-servidor-web\logs\service-output.log"
if (Test-Path $serviceLogPath) {
    Write-Host "   Archivo de log encontrado" -ForegroundColor Green
    try {
        $lastLines = Get-Content $serviceLogPath -Tail 10 -ErrorAction Stop
        foreach ($line in $lastLines) {
            Write-Host "   $line" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   No se pudo leer el archivo de log" -ForegroundColor Yellow
    }
} else {
    Write-Host "   Archivo de log aun no creado (normal durante inicio)" -ForegroundColor Yellow
}

# 6. VERIFICAR ARCHIVOS CREADOS
Write-Host "`n6. ARCHIVOS Y HERRAMIENTAS CREADAS:" -ForegroundColor Cyan
$files = @(
    "C:\Aplicaciones\mi-servidor-web\vsm-service.bat",
    "C:\Aplicaciones\mi-servidor-web\service-manager.bat", 
    "C:\Aplicaciones\mi-servidor-web\rotate-logs.bat",
    "C:\Tools\nssm\nssm.exe"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "   OK $file" -ForegroundColor Green
    } else {
        Write-Host "   ERROR $file" -ForegroundColor Red
    }
}

# 7. VERIFICAR TAREA PROGRAMADA DE LOGS
Write-Host "`n7. TAREA PROGRAMADA DE ROTACION DE LOGS:" -ForegroundColor Cyan
try {
    $task = Get-ScheduledTask -TaskName "VSM Dashboard Log Rotation" -ErrorAction Stop
    Write-Host "   Estado: $($task.State)" -ForegroundColor Green
    Write-Host "   Proxima ejecucion: $($task.NextRunTime)" -ForegroundColor White
} catch {
    Write-Host "   Tarea programada no encontrada" -ForegroundColor Yellow
}

# 8. COMANDO PARA ABRIR GESTOR VISUAL
Write-Host "`n8. HERRAMIENTAS DE GESTION DISPONIBLES:" -ForegroundColor Cyan
Write-Host "   • Gestor visual: .\service-manager.bat" -ForegroundColor White
Write-Host "   • Services Windows: services.msc" -ForegroundColor White
Write-Host "   • Estado servicio: Get-Service VSM-Dashboard-BorgWarner" -ForegroundColor White
Write-Host "   • Iniciar servicio: net start VSM-Dashboard-BorgWarner" -ForegroundColor White
Write-Host "   • Detener servicio: net stop VSM-Dashboard-BorgWarner" -ForegroundColor White

# RESUMEN FINAL
Write-Host "`n===================================================" -ForegroundColor White
Write-Host "RESUMEN DE VERIFICACION:" -ForegroundColor Green

# Calcular puntuacion de exito
$successScore = 0
$totalChecks = 8

# Check 1: Servicio existe
if ((Get-Service "VSM-Dashboard-BorgWarner" -ErrorAction SilentlyContinue)) { $successScore++ }

# Check 2: NSSM existe
if (Test-Path "C:\Tools\nssm\nssm.exe") { $successScore++ }

# Check 3: Puerto activo
if ((netstat -ano | findstr ":3001")) { $successScore++ }

# Check 4: Archivos creados
$filesExist = $files | Where-Object { Test-Path $_ }
if ($filesExist.Count -eq $files.Count) { $successScore++ }

# Check 5-8: Componentes adicionales
if (Test-Path "C:\Aplicaciones\mi-servidor-web\logs") { $successScore++ }
if (Get-ScheduledTask -TaskName "VSM Dashboard Log Rotation" -ErrorAction SilentlyContinue) { $successScore++ }
if (Test-Path "C:\Aplicaciones\mi-servidor-web\service-manager.bat") { $successScore++ }
if (Test-Path "C:\Aplicaciones\mi-servidor-web\vsm-service.bat") { $successScore++ }

$percentage = [math]::Round(($successScore / $totalChecks) * 100, 0)

Write-Host "Puntuacion de exito: $successScore/$totalChecks ($percentage porciento)" -ForegroundColor $(if($percentage -ge 90){"Green"}elseif($percentage -ge 70){"Yellow"}else{"Red"})

if ($percentage -ge 90) {
    Write-Host "STATUS: CONVERSION EXITOSA - SISTEMA OPERATIVO" -ForegroundColor Green
    Write-Host "SIGUIENTE PASO: Reiniciar PC para probar auto-inicio completo" -ForegroundColor White
} elseif ($percentage -ge 70) {
    Write-Host "STATUS: CONVERSION PARCIAL - REVISAR ELEMENTOS FALTANTES" -ForegroundColor Yellow
    Write-Host "ACCION: Verificar logs y ejecutar comandos de troubleshooting" -ForegroundColor White
} else {
    Write-Host "STATUS: CONVERSION INCOMPLETA - REQUIERE ATENCION" -ForegroundColor Red
    Write-Host "ACCION: Revisar errores y considerar re-ejecutar conversion" -ForegroundColor White
}

Write-Host "===================================================" -ForegroundColor White