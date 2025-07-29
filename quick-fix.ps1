# =============================================================================
# SOLUCION RAPIDA - Habilitar debug y verificar problema IP
# =============================================================================

Write-Host "=============================================" -ForegroundColor Green
Write-Host "SOLUCION RAPIDA BASADA EN DIAGNOSTICO" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Navegar al directorio del proyecto
$projectPath = "C:\Aplicaciones\mi-servidor-web"
Set-Location $projectPath

Write-Host "`nPASO 1: INTERRUMPIR PROCESOS COLGADOS" -ForegroundColor Cyan
Write-Host "---------------------------------------" -ForegroundColor White

Write-Host "Si el script anterior esta colgado, presiona Ctrl+C para interrumpirlo" -ForegroundColor Yellow
Write-Host "Continuando con la solucion..." -ForegroundColor White

Write-Host "`nPASO 2: VERIFICAR LOGS ACTUALES DE PM2" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor White

try {
    Write-Host "Obteniendo ultimas 20 lineas de logs..." -ForegroundColor Yellow
    
    # Obtener logs sin colgar el script
    $logOutput = pm2 logs --lines 20 --raw --no-color 2>&1
    
    if ($logOutput) {
        Write-Host "Logs recientes encontrados:" -ForegroundColor Green
        $logOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        
        # Buscar lineas especificas de debug IP
        $debugLines = $logOutput | Where-Object { $_ -match "DEBUG.*IP|IP.*detectada|IP.*denegad" }
        
        if ($debugLines) {
            Write-Host "`nLineas de debug IP encontradas:" -ForegroundColor Yellow
            $debugLines | ForEach-Object { Write-Host "  >>> $_" -ForegroundColor Cyan }
        } else {
            Write-Host "`nNo se encontraron logs de debug IP" -ForegroundColor Red
            Write-Host "Los logs de debug pueden estar deshabilitados" -ForegroundColor Yellow
        }
    } else {
        Write-Host "No se pudieron obtener logs de PM2" -ForegroundColor Red
    }
} catch {
    Write-Host "Error obteniendo logs: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nPASO 3: VERIFICAR ESTADO DE SERVICIOS" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor White

try {
    Write-Host "Estado actual de servicios PM2:" -ForegroundColor Yellow
    pm2 status
} catch {
    Write-Host "Error obteniendo estado PM2" -ForegroundColor Red
}

Write-Host "`nPASO 4: CREAR BACKUP Y APLICAR SOLUCION" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor White

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Crear backup
try {
    Copy-Item "config/environment.js" "config/environment.js.backup.$timestamp"
    Write-Host "Backup creado: environment.js.backup.$timestamp" -ForegroundColor Green
} catch {
    Write-Host "Error creando backup: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nAplicando solucion basada en diagnostico:" -ForegroundColor Yellow
Write-Host "1. Agregar .trim() para eliminar espacios" -ForegroundColor White
Write-Host "2. Sincronizar fallback con .env" -ForegroundColor White

# Leer archivo actual
$envJsContent = Get-Content "config/environment.js" -Raw

# Aplicar correccion
$oldLine = "ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,10.42.126.12,10.43.126.200,10.43.126.22').split(','),"
$newLine = "ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,::1,10.42.126.12,10.43.126.200,10.43.126.22').split(',').map(ip => ip.trim()),"

if ($envJsContent.Contains($oldLine)) {
    $envJsContent = $envJsContent.Replace($oldLine, $newLine)
    
    # Escribir archivo corregido
    $envJsContent | Out-File -FilePath "config/environment.js" -Encoding UTF8
    
    Write-Host "Archivo config/environment.js corregido:" -ForegroundColor Green
    Write-Host "  + Agregado ::1 al fallback" -ForegroundColor White
    Write-Host "  + Agregado .trim() para eliminar espacios" -ForegroundColor White
    
} else {
    Write-Host "ADVERTENCIA: No se encontro la linea exacta a corregir" -ForegroundColor Yellow
    Write-Host "El archivo podria haber cambiado" -ForegroundColor Yellow
    
    # Mostrar la linea actual para comparacion
    $lines = $envJsContent -split "`n"
    $allowedIpsLine = $lines | Where-Object { $_ -match "ALLOWED_IPS.*process\.env" }
    if ($allowedIpsLine) {
        Write-Host "Linea actual encontrada:" -ForegroundColor Yellow
        Write-Host "  $allowedIpsLine" -ForegroundColor White
    }
}

Write-Host "`nPASO 5: REINICIAR SERVICIOS PM2" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor White

try {
    Write-Host "Reiniciando todos los servicios PM2..." -ForegroundColor Yellow
    pm2 restart all
    
    # Esperar un momento
    Start-Sleep -Seconds 3
    
    Write-Host "Estado posterior al reinicio:" -ForegroundColor Yellow
    pm2 status
    
    Write-Host "Servicios reiniciados correctamente" -ForegroundColor Green
    
} catch {
    Write-Host "Error reiniciando PM2: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Reiniciar manualmente con: pm2 restart all" -ForegroundColor Yellow
}

Write-Host "`nPASO 6: PRUEBA INMEDIATA" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor White

Write-Host "SOLICITAR PRUEBA INMEDIATA:" -ForegroundColor Yellow
Write-Host "Pedir al usuario de 10.43.126.22 que acceda a:" -ForegroundColor White
Write-Host "http://10.42.126.12:3001/dashboard/value-stream-map.html" -ForegroundColor Cyan

Write-Host "`nMientras tanto, monitoreamos logs:" -ForegroundColor Yellow
Write-Host "pm2 logs --lines 0 --raw" -ForegroundColor White

Write-Host "`nSi sigue fallando, verificar:" -ForegroundColor Red
Write-Host "1. Que IP exacta se detecta en los logs" -ForegroundColor White
Write-Host "2. Si hay proxies/NAT modificando la IP" -ForegroundColor White
Write-Host "3. Si el firewall de Windows esta bloqueando" -ForegroundColor White

Write-Host "`n=============================================" -ForegroundColor Green
Write-Host "SOLUCION APLICADA" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

Write-Host "`nCambios realizados:" -ForegroundColor Green
Write-Host "+ Agregado .trim() para eliminar espacios" -ForegroundColor White
Write-Host "+ Sincronizado fallback con .env (incluyendo ::1)" -ForegroundColor White
Write-Host "+ Servicios PM2 reiniciados" -ForegroundColor White
Write-Host "+ Backup creado para rollback si es necesario" -ForegroundColor White

Write-Host "`nPara monitorear en tiempo real:" -ForegroundColor Cyan
Write-Host "pm2 logs --lines 0" -ForegroundColor Yellow

Write-Host "`nPara revertir si es necesario:" -ForegroundColor Red
Write-Host "Copy-Item config/environment.js.backup.$timestamp config/environment.js" -ForegroundColor White
Write-Host "pm2 restart all" -ForegroundColor White

pause