# =============================================================================
# SCRIPT MINIMO - CORRECCION MULTI-PC
# Solo los cambios esenciales
# =============================================================================

Write-Host "Aplicando corrección Multi-PC mínima..." -ForegroundColor Cyan

# Verificar directorio
if (-not (Test-Path "server.js")) {
    Write-Host "ERROR: Ejecutar desde directorio del proyecto" -ForegroundColor Red
    exit 1
}

# PASO 1: Backup
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item "server.js" "server.js.backup-$timestamp"
Copy-Item "public\dashboard\value-stream-map.html" "value-stream-map.html.backup-$timestamp"
Write-Host "Backup creado" -ForegroundColor Green

# PASO 2: Actualizar HTML (solo rutas)
$htmlFile = "public\dashboard\value-stream-map.html"
$htmlContent = Get-Content $htmlFile -Raw

$htmlContent = $htmlContent -replace 'href="../shared/', 'href="http://10.42.126.12:3001/shared/'
$htmlContent = $htmlContent -replace 'href="css/', 'href="http://10.42.126.12:3001/dashboard/css/'
$htmlContent = $htmlContent -replace 'src="js/', 'src="http://10.42.126.12:3001/dashboard/js/'

$htmlContent | Out-File -FilePath $htmlFile -Encoding UTF8
Write-Host "HTML actualizado con rutas absolutas" -ForegroundColor Green

# PASO 3: Mostrar instrucciones para server.js
Write-Host "`nPASO MANUAL REQUERIDO:" -ForegroundColor Yellow
Write-Host "Agregar el código del middleware en server.js después de:" -ForegroundColor White
Write-Host "app.use(ipFilterMiddleware);" -ForegroundColor Gray
Write-Host "`nVer artifact 'server.js - Solo cambios mínimos necesarios'" -ForegroundColor White

# PASO 4: Reiniciar servidor
Write-Host "`nReiniciando servidor..." -ForegroundColor Yellow
pm2 restart vsm-dashboard-borgwarner

Write-Host "`nCORRECCION COMPLETADA" -ForegroundColor Green
Write-Host "Probar desde PC remota: http://10.42.126.12:3001/dashboard/value-stream-map.html" -ForegroundColor White