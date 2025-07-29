# =============================================================================
# DIAGNOSTICO ESPECIFICO - Problema IP 10.43.126.22
# Basado en resultados de auditoria
# =============================================================================

Write-Host "=============================================" -ForegroundColor Green
Write-Host "DIAGNOSTICO ESPECIFICO DEL PROBLEMA IP" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Navegar al directorio del proyecto
$projectPath = "C:\Aplicaciones\mi-servidor-web"
Set-Location $projectPath

Write-Host "PROBLEMA IDENTIFICADO: INCONSISTENCIA EN FALLBACK" -ForegroundColor Red
Write-Host "================================================" -ForegroundColor White

Write-Host "`n1. VERIFICANDO CARGA DEL ARCHIVO .ENV" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor White

# Simular la carga de .env como lo hace Node.js
try {
    $envContent = Get-Content ".env" -Raw
    $envLines = $envContent -split "`n"
    $allowedIpsFromEnv = ""
    
    foreach ($line in $envLines) {
        $line = $line.Trim()
        if ($line -match "^ALLOWED_IPS=(.+)$") {
            $allowedIpsFromEnv = $Matches[1]
            break
        }
    }
    
    if ($allowedIpsFromEnv) {
        Write-Host "Valor en .env: $allowedIpsFromEnv" -ForegroundColor Green
        
        # Convertir a array como lo hace JavaScript
        $ipsFromEnv = $allowedIpsFromEnv -split "," | ForEach-Object { $_.Trim() }
        Write-Host "IPs procesadas desde .env:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $ipsFromEnv.Length; $i++) {
            $ip = $ipsFromEnv[$i]
            Write-Host "  [$i] '$ip'" -ForegroundColor White
            if ($ip -eq "10.43.126.22") {
                Write-Host "      ^^ IP OBJETIVO ENCONTRADA" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "ERROR: No se pudo extraer ALLOWED_IPS del .env" -ForegroundColor Red
    }
} catch {
    Write-Host "ERROR leyendo .env: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n2. VERIFICANDO FALLBACK EN ENVIRONMENT.JS" -ForegroundColor Cyan
Write-Host "-------------------------------------------" -ForegroundColor White

try {
    $envJsContent = Get-Content "config/environment.js" -Raw
    if ($envJsContent -match "ALLOWED_IPS: \(process\.env\.ALLOWED_IPS \|\| '([^']+)'\)") {
        $fallbackValue = $Matches[1]
        Write-Host "Valor fallback en environment.js: $fallbackValue" -ForegroundColor Yellow
        
        # Convertir fallback a array
        $ipsFromFallback = $fallbackValue -split "," | ForEach-Object { $_.Trim() }
        Write-Host "IPs en fallback:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $ipsFromFallback.Length; $i++) {
            $ip = $ipsFromFallback[$i]
            Write-Host "  [$i] '$ip'" -ForegroundColor White
            if ($ip -eq "10.43.126.22") {
                Write-Host "      ^^ IP OBJETIVO ENCONTRADA" -ForegroundColor Green
            }
        }
        
        # Comparar diferencias
        Write-Host "`nCOMPARACION .env vs fallback:" -ForegroundColor Red
        $onlyInEnv = $ipsFromEnv | Where-Object { $_ -notin $ipsFromFallback }
        $onlyInFallback = $ipsFromFallback | Where-Object { $_ -notin $ipsFromEnv }
        
        if ($onlyInEnv) {
            Write-Host "Solo en .env: $($onlyInEnv -join ', ')" -ForegroundColor Red
        }
        if ($onlyInFallback) {
            Write-Host "Solo en fallback: $($onlyInFallback -join ', ')" -ForegroundColor Red
        }
        if (-not $onlyInEnv -and -not $onlyInFallback) {
            Write-Host "CONFIGURACIONES IDENTICAS" -ForegroundColor Green
        }
        
    } else {
        Write-Host "ERROR: No se pudo extraer fallback de environment.js" -ForegroundColor Red
    }
} catch {
    Write-Host "ERROR leyendo environment.js: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n3. SIMULANDO CARGA DE CONFIGURACION COMO NODE.JS" -ForegroundColor Cyan
Write-Host "------------------------------------------------" -ForegroundColor White

# Simular el proceso exact de Node.js
Write-Host "Simulando: require('dotenv').config()" -ForegroundColor Yellow

# En este punto, process.env.ALLOWED_IPS tendria el valor del .env
$simulatedProcessEnv = $allowedIpsFromEnv

if ($simulatedProcessEnv) {
    Write-Host "process.env.ALLOWED_IPS = '$simulatedProcessEnv'" -ForegroundColor Green
    
    # Simular la logica de environment.js
    $finalValue = $simulatedProcessEnv # Usa .env, no fallback
    $finalIPs = $finalValue -split "," | ForEach-Object { $_.Trim() }
    
    Write-Host "Valor final que usaria Node.js: $finalValue" -ForegroundColor Green
    Write-Host "Array final de IPs autorizadas:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $finalIPs.Length; $i++) {
        $ip = $finalIPs[$i]
        Write-Host "  [$i] '$ip'" -ForegroundColor White
        if ($ip -eq "10.43.126.22") {
            Write-Host "      ^^ IP 10.43.126.22 ESTARIA AUTORIZADA" -ForegroundColor Green
        }
    }
} else {
    Write-Host "process.env.ALLOWED_IPS = undefined (usaria fallback)" -ForegroundColor Red
    Write-Host "Esto indicaria que .env no se cargo correctamente" -ForegroundColor Red
}

Write-Host "`n4. VERIFICANDO LOGS EN TIEMPO REAL" -ForegroundColor Cyan
Write-Host "-----------------------------------" -ForegroundColor White

Write-Host "Verificando logs de PM2 para debug de IPs..." -ForegroundColor Yellow

try {
    # Obtener logs recientes que muestren debug de IPs
    $recentLogs = pm2 logs --lines 100 --raw 2>$null
    
    if ($recentLogs) {
        $debugLines = $recentLogs | Where-Object { $_ -match "DEBUG.*IP|IP.*detectada|IPs.*permitidas" }
        
        if ($debugLines) {
            Write-Host "Logs de debug encontrados:" -ForegroundColor Green
            $debugLines | Select-Object -Last 10 | ForEach-Object {
                Write-Host "  $_" -ForegroundColor Cyan
            }
        } else {
            Write-Host "No se encontraron logs de debug de IPs" -ForegroundColor Yellow
            Write-Host "Los logs de debug podrian estar deshabilitados" -ForegroundColor Yellow
        }
    } else {
        Write-Host "No se pudieron obtener logs de PM2" -ForegroundColor Red
    }
} catch {
    Write-Host "Error obteniendo logs: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n5. PRUEBA DE CONECTIVIDAD DESDE LA IP PROBLEMATICA" -ForegroundColor Cyan
Write-Host "--------------------------------------------------" -ForegroundColor White

# Verificar si hay intentos de conexion desde la IP
$connections = Get-NetTCPConnection | Where-Object { 
    $_.RemoteAddress -eq "10.43.126.22" -or $_.RemoteAddress -eq "::ffff:10.43.126.22" 
}

if ($connections) {
    Write-Host "Conexiones detectadas desde 10.43.126.22:" -ForegroundColor Green
    $connections | ForEach-Object {
        Write-Host "  Puerto: $($_.LocalPort), Estado: $($_.State), IP: $($_.RemoteAddress)" -ForegroundColor White
    }
} else {
    Write-Host "No hay conexiones activas desde 10.43.126.22" -ForegroundColor Yellow
    Write-Host "Esto puede indicar que:" -ForegroundColor Yellow
    Write-Host "  1. La IP no esta intentando conectar ahora" -ForegroundColor White
    Write-Host "  2. Las conexiones son rechazadas antes de establecerse" -ForegroundColor White
    Write-Host "  3. La IP real del cliente es diferente" -ForegroundColor White
}

Write-Host "`n=============================================" -ForegroundColor Green
Write-Host "CONCLUSION DEL DIAGNOSTICO" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

Write-Host "`nBASADO EN LA AUDITORIA:" -ForegroundColor Cyan
Write-Host "1. El archivo .env CONTIENE correctamente 10.43.126.22" -ForegroundColor Green
Write-Host "2. El fallback en environment.js TAMBIEN la contiene" -ForegroundColor Green
Write-Host "3. Los puertos 3001 y 3443 estan activos" -ForegroundColor Green
Write-Host "4. El middleware de seguridad esta implementado" -ForegroundColor Green

Write-Host "`nPOSIBLES CAUSAS DEL PROBLEMA:" -ForegroundColor Red
Write-Host "A. Inconsistencia menor: ::1 falta en fallback" -ForegroundColor Yellow
Write-Host "B. Espacios en blanco no removidos con .trim()" -ForegroundColor Yellow
Write-Host "C. El archivo .env no se carga correctamente" -ForegroundColor Yellow
Write-Host "D. La IP real del cliente es diferente a 10.43.126.22" -ForegroundColor Yellow
Write-Host "E. Problema de cache - servicios no reiniciados" -ForegroundColor Yellow

Write-Host "`nSOLUCION RECOMENDADA:" -ForegroundColor Green
Write-Host "1. Agregar .trim() a environment.js (solucion conservadora)" -ForegroundColor White
Write-Host "2. Habilitar logs de debug temporalmente" -ForegroundColor White
Write-Host "3. Probar acceso y verificar IP exacta detectada" -ForegroundColor White
Write-Host "4. Ajustar segun IP real detectada" -ForegroundColor White

pause