# VERIFICACION DUAL HTTP/HTTPS - Dashboard VSM BorgWarner

Write-Host "VERIFICACION DUAL HTTP/HTTPS - DASHBOARD VSM" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor White

# 1. Estado del servicio Windows
Write-Host "
1. SERVICIO WINDOWS:" -ForegroundColor Cyan
Get-Service VSM-Dashboard-BorgWarner

# 2. Verificacion HTTP (Puerto 3001)
Write-Host "
2. VERIFICACION HTTP (Puerto 3001):" -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest "http://localhost:3001/api/status" -UseBasicParsing -TimeoutSec 10
    Write-Host "   HTTP Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   HTTP: RESPONDIENDO" -ForegroundColor Green
} catch {
    Write-Host "   HTTP Error: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Verificacion HTTPS (Puerto 3443)  
Write-Host "
3. VERIFICACION HTTPS (Puerto 3443):" -ForegroundColor Cyan
try {
    # Ignore SSL certificate errors for self-signed certificates
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-WebRequest "https://localhost:3443/api/status" -UseBasicParsing -TimeoutSec 10
    Write-Host "   HTTPS Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   HTTPS: RESPONDIENDO" -ForegroundColor Green
} catch {
    Write-Host "   HTTPS Error: $($_.Exception.Message)" -ForegroundColor Red
    if (Test-Path "C:\Aplicaciones\mi-servidor-web\certs\cert.pem") {
        Write-Host "   Certificados SSL encontrados - verificar logs" -ForegroundColor Yellow
    } else {
        Write-Host "   Certificados SSL no encontrados" -ForegroundColor Red
    }
}

# 4. Verificacion de puertos
Write-Host "
4. PUERTOS ACTIVOS:" -ForegroundColor Cyan
$port3001 = netstat -ano | findstr ":3001"
$port3443 = netstat -ano | findstr ":3443"

if ($port3001) {
    Write-Host "   Puerto 3001 (HTTP): ACTIVO" -ForegroundColor Green
} else {
    Write-Host "   Puerto 3001 (HTTP): NO DETECTADO" -ForegroundColor Red
}

if ($port3443) {
    Write-Host "   Puerto 3443 (HTTPS): ACTIVO" -ForegroundColor Green
} else {
    Write-Host "   Puerto 3443 (HTTPS): NO DETECTADO" -ForegroundColor Red
}

# 5. URLs disponibles
Write-Host "
5. URLS DISPONIBLES:" -ForegroundColor Cyan
Write-Host "   HTTP Local:   http://localhost:3001/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "   HTTP Red:     http://10.42.126.12:3001/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "   HTTPS Local:  https://localhost:3443/dashboard/value-stream-map.html" -ForegroundColor White
Write-Host "   HTTPS Red:    https://10.42.126.12:3443/dashboard/value-stream-map.html" -ForegroundColor White

Write-Host "
=============================================" -ForegroundColor White
