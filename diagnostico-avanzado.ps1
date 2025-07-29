# DIAGNOSTICO AVANZADO - Dashboard VSM BorgWarner
# Script para identificar y solucionar problemas de inicio

Write-Host "DIAGNOSTICO AVANZADO - DASHBOARD VSM BORGWARNER" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor White

$projectPath = "C:\Aplicaciones\mi-servidor-web"
$serviceName = "VSM-Dashboard-BorgWarner"

# 1. VERIFICAR ESTADO DEL SERVICIO
Write-Host "`n1. ESTADO DEL SERVICIO:" -ForegroundColor Cyan
$service = Get-Service $serviceName -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "   Estado: $($service.Status)" -ForegroundColor $(if($service.Status -eq "Running"){"Green"}else{"Red"})
    Write-Host "   Inicio: $($service.StartType)" -ForegroundColor White
} else {
    Write-Host "   ERROR: Servicio no encontrado" -ForegroundColor Red
}

# 2. VERIFICAR LOGS DEL SERVICIO
Write-Host "`n2. LOGS DEL SERVICIO (ULTIMAS 15 LINEAS):" -ForegroundColor Cyan
$serviceLog = "$projectPath\logs\service-output.log"
if (Test-Path $serviceLog) {
    Write-Host "   Archivo encontrado: $serviceLog" -ForegroundColor Green
    $logLines = Get-Content $serviceLog -Tail 15
    foreach ($line in $logLines) {
        if ($line -like "*ERROR*" -or $line -like "*ALERTA*") {
            Write-Host "   $line" -ForegroundColor Red
        } elseif ($line -like "*OK*" -or $line -like "*online*") {
            Write-Host "   $line" -ForegroundColor Green
        } else {
            Write-Host "   $line" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "   ERROR: Archivo de log no encontrado" -ForegroundColor Red
}

# 3. VERIFICAR LOGS DE ERROR
Write-Host "`n3. LOGS DE ERROR:" -ForegroundColor Cyan
$errorLog = "$projectPath\logs\service-error.log"
if (Test-Path $errorLog) {
    $errorLines = Get-Content $errorLog -Tail 10
    if ($errorLines) {
        foreach ($line in $errorLines) {
            Write-Host "   $line" -ForegroundColor Red
        }
    } else {
        Write-Host "   No hay errores recientes" -ForegroundColor Green
    }
} else {
    Write-Host "   Archivo de error no encontrado" -ForegroundColor Yellow
}

# 4. VERIFICAR PROCESOS NODE.JS
Write-Host "`n4. PROCESOS NODE.JS/PM2:" -ForegroundColor Cyan
$nodeProcesses = Get-Process | Where-Object { $_.ProcessName -like "*node*" -or $_.ProcessName -like "*pm2*" }
if ($nodeProcesses) {
    Write-Host "   Procesos encontrados:" -ForegroundColor Green
    $nodeProcesses | ForEach-Object {
        Write-Host "   - $($_.ProcessName) (PID: $($_.Id), Memoria: $([math]::Round($_.WorkingSet64/1MB, 2)) MB)" -ForegroundColor White
    }
} else {
    Write-Host "   NO HAY PROCESOS NODE.JS/PM2 EJECUTANDOSE" -ForegroundColor Red
    Write-Host "   Esto confirma que PM2 no esta iniciando" -ForegroundColor Yellow
}

# 5. VERIFICAR PM2 MANUALMENTE
Write-Host "`n5. VERIFICACION PM2 MANUAL:" -ForegroundColor Cyan
try {
    Set-Location $projectPath
    $pm2Status = pm2 status 2>&1
    if ($pm2Status -like "*error*" -or $pm2Status -like "*daemon*") {
        Write-Host "   PM2 daemon no esta ejecutandose" -ForegroundColor Red
    } else {
        Write-Host "   PM2 Status:" -ForegroundColor Green
        pm2 status
    }
} catch {
    Write-Host "   ERROR ejecutando PM2: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. VERIFICAR VARIABLES DE ENTORNO
Write-Host "`n6. VARIABLES DE ENTORNO:" -ForegroundColor Cyan
Write-Host "   NODE_ENV: $($env:NODE_ENV)" -ForegroundColor White
Write-Host "   PATH contiene Node.js: $(if($env:PATH -like '*nodejs*'){'SI'}else{'NO'})" -ForegroundColor $(if($env:PATH -like '*nodejs*'){"Green"}else{"Red"})

# Verificar Node.js disponible
try {
    $nodeVersion = node --version 2>$null
    Write-Host "   Node.js version: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "   Node.js: NO DISPONIBLE EN PATH" -ForegroundColor Red
}

# Verificar PM2 disponible
try {
    $pm2Version = pm2 --version 2>$null
    Write-Host "   PM2 version: $pm2Version" -ForegroundColor Green
} catch {
    Write-Host "   PM2: NO DISPONIBLE EN PATH" -ForegroundColor Red
}

# 7. PRUEBA DE INICIO MANUAL
Write-Host "`n7. PRUEBA DE INICIO MANUAL:" -ForegroundColor Cyan
Write-Host "   Intentando iniciar PM2 manualmente..." -ForegroundColor Yellow

try {
    # Limpiar PM2
    pm2 kill > $null 2>&1
    Start-Sleep 3
    
    # Intentar iniciar HTTP
    pm2 start ecosystem.config.js --env production
    Start-Sleep 5
    
    # Verificar estado
    $pm2List = pm2 list 2>$null
    Write-Host "   Estado tras inicio manual:" -ForegroundColor White
    pm2 status
    
} catch {
    Write-Host "   ERROR en inicio manual: $($_.Exception.Message)" -ForegroundColor Red
}

# 8. VERIFICAR ARCHIVOS DE CONFIGURACION
Write-Host "`n8. VERIFICACION DE ARCHIVOS:" -ForegroundColor Cyan
$configFiles = @(
    "ecosystem.config.js",
    "ecosystem-https.config.js", 
    "server.js",
    "server-https.js"
)

foreach ($file in $configFiles) {
    $filePath = "$projectPath\$file"
    if (Test-Path $filePath) {
        $fileSize = (Get-Item $filePath).Length
        Write-Host "   $file : OK ($fileSize bytes)" -ForegroundColor Green
    } else {
        Write-Host "   $file : FALTANTE" -ForegroundColor Red
    }
}

# 9. SOLUCION PROPUESTA
Write-Host "`n9. SOLUCION PROPUESTA:" -ForegroundColor Cyan

if (-not $nodeProcesses) {
    Write-Host "   PROBLEMA IDENTIFICADO: PM2 no esta iniciando en el servicio" -ForegroundColor Red
    Write-Host "   SOLUCION SUGERIDA:" -ForegroundColor Yellow
    Write-Host "     1. Reiniciar servicio manualmente" -ForegroundColor White
    Write-Host "     2. Modificar script de servicio para mejor compatibilidad" -ForegroundColor White
    Write-Host "     3. Usar alternativa de inicio directo Node.js" -ForegroundColor White
}

# 10. COMANDOS DE RECUPERACION
Write-Host "`n10. COMANDOS DE RECUPERACION:" -ForegroundColor Cyan
Write-Host "    # Reiniciar servicio:" -ForegroundColor White
Write-Host "    net stop $serviceName" -ForegroundColor Gray
Write-Host "    net start $serviceName" -ForegroundColor Gray
Write-Host ""
Write-Host "    # Inicio manual para pruebas:" -ForegroundColor White
Write-Host "    pm2 kill" -ForegroundColor Gray
Write-Host "    pm2 start ecosystem.config.js" -ForegroundColor Gray
Write-Host "    pm2 start ecosystem-https.config.js" -ForegroundColor Gray
Write-Host ""
Write-Host "    # Monitorear logs:" -ForegroundColor White
Write-Host "    Get-Content $projectPath\logs\service-output.log -Wait" -ForegroundColor Gray

Write-Host "`n===============================================" -ForegroundColor White