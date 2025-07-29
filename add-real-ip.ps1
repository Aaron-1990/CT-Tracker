# =============================================================================
# SOLUCION DEFINITIVA - Agregar IP real detectada: 10.42.126.135
# =============================================================================

Write-Host "=============================================" -ForegroundColor Green
Write-Host "SOLUCION: AGREGAR IP REAL 10.42.126.135" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Navegar al directorio del proyecto
$projectPath = "C:\Aplicaciones\mi-servidor-web"
Set-Location $projectPath

Write-Host "`nPROBLEMA IDENTIFICADO:" -ForegroundColor Red
Write-Host "IP esperada: 10.43.126.22" -ForegroundColor Yellow
Write-Host "IP real detectada: 10.42.126.135" -ForegroundColor Cyan
Write-Host "Causa: NAT/Proxy corporativo o configuracion de red" -ForegroundColor White

Write-Host "`nPASO 1: CREAR BACKUP DE ARCHIVOS" -ForegroundColor Cyan
Write-Host "---------------------------------" -ForegroundColor White

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Backup .env
try {
    Copy-Item ".env" ".env.backup.$timestamp"
    Write-Host "Backup .env creado: .env.backup.$timestamp" -ForegroundColor Green
} catch {
    Write-Host "ERROR creando backup .env: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Backup environment.js
try {
    Copy-Item "config/environment.js" "config/environment.js.backup.$timestamp"
    Write-Host "Backup environment.js creado: config/environment.js.backup.$timestamp" -ForegroundColor Green
} catch {
    Write-Host "ERROR creando backup environment.js: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nPASO 2: MOSTRAR CAMBIOS A REALIZAR" -ForegroundColor Cyan
Write-Host "-----------------------------------" -ForegroundColor White

Write-Host "CAMBIO 1 - Archivo .env:" -ForegroundColor Yellow
Write-Host "DESDE:" -ForegroundColor Red
Write-Host "ALLOWED_IPS=127.0.0.1,::1,10.42.126.12,10.43.126.200,10.43.126.22" -ForegroundColor Red

Write-Host "`nHACIA:" -ForegroundColor Green
Write-Host "ALLOWED_IPS=127.0.0.1,::1,10.42.126.12,10.43.126.200,10.43.126.22,10.42.126.135" -ForegroundColor Green

Write-Host "`nCAMBIO 2 - Archivo config/environment.js:" -ForegroundColor Yellow
Write-Host "DESDE:" -ForegroundColor Red
Write-Host "ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,::1,10.42.126.12,10.43.126.200,10.43.126.22').split(',').map(ip => ip.trim())," -ForegroundColor Red

Write-Host "`nHACIA:" -ForegroundColor Green
Write-Host "ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,::1,10.42.126.12,10.43.126.200,10.43.126.22,10.42.126.135').split(',').map(ip => ip.trim())," -ForegroundColor Green

$response = Read-Host "`nAplicar correcion agregando IP 10.42.126.135? (Y/N)"

if ($response -eq "Y" -or $response -eq "y") {
    
    Write-Host "`nPASO 3: ACTUALIZAR ARCHIVO .ENV" -ForegroundColor Cyan
    Write-Host "--------------------------------" -ForegroundColor White
    
    try {
        # Leer archivo .env
        $envContent = Get-Content ".env" -Raw
        
        # Buscar y reemplazar la linea ALLOWED_IPS
        $oldEnvLine = "ALLOWED_IPS=127.0.0.1,::1,10.42.126.12,10.43.126.200,10.43.126.22"
        $newEnvLine = "ALLOWED_IPS=127.0.0.1,::1,10.42.126.12,10.43.126.200,10.43.126.22,10.42.126.135"
        
        if ($envContent.Contains($oldEnvLine)) {
            $envContent = $envContent.Replace($oldEnvLine, $newEnvLine)
            $envContent | Out-File -FilePath ".env" -Encoding UTF8
            Write-Host "Archivo .env actualizado correctamente" -ForegroundColor Green
        } else {
            Write-Host "ADVERTENCIA: Linea exacta no encontrada en .env" -ForegroundColor Yellow
            Write-Host "Verificar manualmente el archivo .env" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "ERROR actualizando .env: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "`nPASO 4: ACTUALIZAR CONFIG/ENVIRONMENT.JS" -ForegroundColor Cyan
    Write-Host "-----------------------------------------" -ForegroundColor White
    
    try {
        # Leer archivo environment.js
        $envJsContent = Get-Content "config/environment.js" -Raw
        
        # Buscar y reemplazar la linea ALLOWED_IPS
        $oldJsLine = "ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,::1,10.42.126.12,10.43.126.200,10.43.126.22').split(',').map(ip => ip.trim()),"
        $newJsLine = "ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,::1,10.42.126.12,10.43.126.200,10.43.126.22,10.42.126.135').split(',').map(ip => ip.trim()),"
        
        if ($envJsContent.Contains($oldJsLine)) {
            $envJsContent = $envJsContent.Replace($oldJsLine, $newJsLine)
            $envJsContent | Out-File -FilePath "config/environment.js" -Encoding UTF8
            Write-Host "Archivo config/environment.js actualizado correctamente" -ForegroundColor Green
        } else {
            Write-Host "ADVERTENCIA: Linea exacta no encontrada en environment.js" -ForegroundColor Yellow
            Write-Host "Verificar manualmente el archivo" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "ERROR actualizando environment.js: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "`nPASO 5: VERIFICAR CAMBIOS APLICADOS" -ForegroundColor Cyan
    Write-Host "------------------------------------" -ForegroundColor White
    
    # Verificar .env
    $envCheck = Get-Content ".env" | Where-Object { $_ -match "ALLOWED_IPS" }
    Write-Host "Contenido .env:" -ForegroundColor Yellow
    Write-Host "  $envCheck" -ForegroundColor White
    
    # Verificar environment.js
    $envJsCheck = Get-Content "config/environment.js" | Where-Object { $_ -match "ALLOWED_IPS.*process.env" }
    Write-Host "Contenido environment.js:" -ForegroundColor Yellow
    Write-Host "  $envJsCheck" -ForegroundColor White
    
    Write-Host "`nPASO 6: REINICIAR SERVICIOS PM2" -ForegroundColor Cyan
    Write-Host "--------------------------------" -ForegroundColor White
    
    try {
        Write-Host "Reiniciando todos los servicios PM2..." -ForegroundColor Yellow
        pm2 restart all
        
        Start-Sleep -Seconds 5
        
        Write-Host "Estado de servicios:" -ForegroundColor Yellow
        pm2 status
        
        Write-Host "Servicios reiniciados correctamente" -ForegroundColor Green
        
    } catch {
        Write-Host "ERROR reiniciando PM2: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "SOLUCION: Ejecutar manualmente 'pm2 restart all'" -ForegroundColor Yellow
    }
    
    Write-Host "`n=============================================" -ForegroundColor Green
    Write-Host "SOLUCION APLICADA EXITOSAMENTE" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    
    Write-Host "`nIP AGREGADA: 10.42.126.135" -ForegroundColor Cyan
    Write-Host "Archivos modificados:" -ForegroundColor Yellow
    Write-Host "1. .env - IP agregada a ALLOWED_IPS" -ForegroundColor White
    Write-Host "2. config/environment.js - IP agregada al fallback" -ForegroundColor White
    Write-Host "3. Servicios PM2 reiniciados" -ForegroundColor White
    
    Write-Host "`nPRUEBA INMEDIATA:" -ForegroundColor Cyan
    Write-Host "El usuario debe probar AHORA:" -ForegroundColor Yellow
    Write-Host "HTTP:  http://10.42.126.12:3001/dashboard/value-stream-map.html" -ForegroundColor White
    Write-Host "HTTPS: https://10.42.126.12:3443/dashboard/value-stream-map.html" -ForegroundColor White
    
    Write-Host "`nRESULTADO ESPERADO:" -ForegroundColor Green
    Write-Host "El dashboard deberia cargar correctamente en ambos puertos" -ForegroundColor White
    
    Write-Host "`nSI AUN HAY PROBLEMAS:" -ForegroundColor Red
    Write-Host "- Verificar que la IP sigue siendo 10.42.126.135 en los logs" -ForegroundColor White
    Write-Host "- La IP podria cambiar dinamicamente (DHCP)" -ForegroundColor White
    
    Write-Host "`nPARA REVERTIR SI ES NECESARIO:" -ForegroundColor Yellow
    Write-Host "Copy-Item .env.backup.$timestamp .env" -ForegroundColor White
    Write-Host "Copy-Item config/environment.js.backup.$timestamp config/environment.js" -ForegroundColor White
    Write-Host "pm2 restart all" -ForegroundColor White
    
    Write-Host "`nBACKUPS CREADOS:" -ForegroundColor Cyan
    Write-Host "- .env.backup.$timestamp" -ForegroundColor White
    Write-Host "- config/environment.js.backup.$timestamp" -ForegroundColor White
    
} else {
    Write-Host "`nOperacion cancelada por el usuario" -ForegroundColor Yellow
    Write-Host "La IP 10.42.126.135 NO fue agregada" -ForegroundColor White
    Write-Host "El acceso seguira siendo denegado" -ForegroundColor Red
}

Write-Host "`nPresiona Enter para continuar..." -ForegroundColor Gray
Read-Host