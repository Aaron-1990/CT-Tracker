# SCRIPT DE PRUEBAS HTTPS - Dashboard VSM BorgWarner
# Verifica conectividad HTTP y HTTPS

Write-Host "VERIFICACION CONECTIVIDAD DASHBOARD VSM" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor White

$projectPath = "C:\Aplicaciones\mi-servidor-web"
Set-Location $projectPath

# VERIFICAR ESTADO PM2
Write-Host "`nVerificando estado PM2..." -ForegroundColor Cyan

try {
    $pm2Status = pm2 jlist | ConvertFrom-Json
    
    # Verificar HTTP
    $httpApp = $pm2Status | Where-Object { $_.name -eq "vsm-dashboard-borgwarner" }
    if ($httpApp -and $httpApp.pm2_env.status -eq "online") {
        Write-Host "HTTP Dashboard: FUNCIONANDO" -ForegroundColor Green
    } else {
        Write-Host "HTTP Dashboard: OFFLINE" -ForegroundColor Red
    }
    
    # Verificar HTTPS
    $httpsApp = $pm2Status | Where-Object { $_.name -eq "vsm-dashboard-borgwarner-https" }
    if ($httpsApp -and $httpsApp.pm2_env.status -eq "online") {
        Write-Host "HTTPS Dashboard: FUNCIONANDO" -ForegroundColor Green
    } else {
        Write-Host "HTTPS Dashboard: OFFLINE" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Error verificando PM2" -ForegroundColor Red
}

# PROBAR CONECTIVIDAD
Write-Host "`nProbando conectividad..." -ForegroundColor Cyan

$urls = @(
    @{ Name = "HTTP Local"; URL = "http://localhost:3001/api/status" },
    @{ Name = "HTTPS Local"; URL = "https://localhost:3443/api/status" },
    @{ Name = "HTTP Red"; URL = "http://10.42.126.12:3001/api/status" },
    @{ Name = "HTTPS Red"; URL = "https://10.42.126.12:3443/api/status" }
)

foreach ($test in $urls) {
    Write-Host "Probando $($test.Name)..." -ForegroundColor White
    
    try {
        # Para HTTPS, ignorar errores de certificado en pruebas
        if ($test.URL.StartsWith("https")) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        }
        
        $response = Invoke-WebRequest -Uri $test.URL -TimeoutSec 10 -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Write-Host "  EXITO: $($test.Name)" -ForegroundColor Green
        } else {
            Write-Host "  ERROR: $($test.Name) - Codigo $($response.StatusCode)" -ForegroundColor Red
        }
    } catch {
        Write-Host "  FALLO: $($test.Name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# MOSTRAR INFORMACION FINAL
Write-Host "`n=======================================" -ForegroundColor Green
Write-Host "RESUMEN DE ACCESO AL DASHBOARD" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green

Write-Host "`nURLs disponibles:" -ForegroundColor Cyan
Write-Host "HTTP Local:   http://localhost:3001/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "HTTPS Local:  https://localhost:3443/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "HTTP Red:     http://10.42.126.12:3001/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "HTTPS Red:    https://10.42.126.12:3443/dashboard/value-stream-map.html" -ForegroundColor White

Write-Host "`nComandos utiles:" -ForegroundColor Cyan
Write-Host "pm2 status                           - Ver estado servicios" -ForegroundColor Gray
Write-Host "pm2 logs vsm-dashboard-borgwarner    - Logs HTTP" -ForegroundColor Gray
Write-Host "pm2 logs vsm-dashboard-borgwarner-https - Logs HTTPS" -ForegroundColor Gray
Write-Host "pm2 restart all                      - Reiniciar servicios" -ForegroundColor Gray

Write-Host "`nNota importante:" -ForegroundColor Yellow
Write-Host "Para HTTPS, el navegador mostrara advertencia de seguridad" -ForegroundColor White
Write-Host "Hacer clic en 'Avanzado' > 'Continuar a 10.42.126.12 (no seguro)'" -ForegroundColor White

Write-Host "`n=======================================" -ForegroundColor White