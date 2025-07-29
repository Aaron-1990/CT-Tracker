# =============================================================================
# CORRECCION DIRECTA - Sin verificar logs PM2
# Solucion inmediata basada en diagnostico
# =============================================================================

Write-Host "=============================================" -ForegroundColor Green
Write-Host "CORRECCION DIRECTA - PROBLEMA IP 10.43.126.22" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Navegar al directorio del proyecto
$projectPath = "C:\Aplicaciones\mi-servidor-web"
Set-Location $projectPath

Write-Host "`nBASADO EN DIAGNOSTICO ANTERIOR:" -ForegroundColor Cyan
Write-Host "- IP 10.43.126.22 esta en .env correctamente" -ForegroundColor Green
Write-Host "- Falta .trim() para eliminar espacios" -ForegroundColor Yellow
Write-Host "- Falta ::1 en fallback de environment.js" -ForegroundColor Yellow

Write-Host "`nPASO 1: CREAR BACKUP DE SEGURIDAD" -ForegroundColor Cyan
Write-Host "-----------------------------------" -ForegroundColor White

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = "config/environment.js.backup.$timestamp"

try {
    Copy-Item "config/environment.js" $backupFile
    Write-Host "Backup creado: $backupFile" -ForegroundColor Green
} catch {
    Write-Host "ERROR creando backup: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nPASO 2: MOSTRAR CAMBIO A REALIZAR" -ForegroundColor Cyan
Write-Host "----------------------------------" -ForegroundColor White

Write-Host "CAMBIO EN config/environment.js:" -ForegroundColor Yellow
Write-Host "`nDESDE:" -ForegroundColor Red
Write-Host "ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,10.42.126.12,10.43.126.200,10.43.126.22').split(',')," -ForegroundColor Red

Write-Host "`nHACIA:" -ForegroundColor Green
Write-Host "ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,::1,10.42.126.12,10.43.126.200,10.43.126.22').split(',').map(ip => ip.trim())," -ForegroundColor Green

Write-Host "`nBENEFICIOS:" -ForegroundColor Yellow
Write-Host "1. Agregado ::1 (localhost IPv6) al fallback" -ForegroundColor White
Write-Host "2. Agregado .trim() para eliminar espacios en blanco" -ForegroundColor White
Write-Host "3. Mantiene toda la configuracion existente" -ForegroundColor White

$response = Read-Host "`nAplicar correccion? (Y/N)"

if ($response -eq "Y" -or $response -eq "y") {
    
    Write-Host "`nPASO 3: APLICAR CORRECCION" -ForegroundColor Cyan
    Write-Host "---------------------------" -ForegroundColor White
    
    try {
        # Leer archivo actual
        $content = Get-Content "config/environment.js" -Raw
        
        # Definir patrones de busqueda y reemplazo
        $oldPattern = "ALLOWED_IPS: \(process\.env\.ALLOWED_IPS \|\| '127\.0\.0\.1,10\.42\.126\.12,10\.43\.126\.200,10\.43\.126\.22'\)\.split\(','\),"
        $newPattern = "ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,::1,10.42.126.12,10.43.126.200,10.43.126.22').split(',').map(ip => ip.trim()),"
        
        # Verificar que el patron existe
        if ($content -match [regex]::Escape("ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,10.42.126.12,10.43.126.200,10.43.126.22').split(','),")) {
            # Aplicar reemplazo
            $newContent = $content -replace [regex]::Escape("ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,10.42.126.12,10.43.126.200,10.43.126.22').split(','),"), $newPattern
            
            # Escribir archivo corregido
            $newContent | Out-File -FilePath "config/environment.js" -Encoding UTF8
            
            Write-Host "Archivo corregido exitosamente" -ForegroundColor Green
            
            # Verificar el cambio
            $updatedContent = Get-Content "config/environment.js" -Raw
            if ($updatedContent -match "\.trim\(\)" -and $updatedContent -match "::1") {
                Write-Host "Verificacion exitosa: .trim() y ::1 agregados" -ForegroundColor Green
            } else {
                Write-Host "ADVERTENCIA: Verificacion fallida" -ForegroundColor Yellow
            }
            
        } else {
            Write-Host "ERROR: Patron no encontrado en el archivo" -ForegroundColor Red
            Write-Host "El archivo podria haber cambiado" -ForegroundColor Yellow
            
            # Mostrar lineas relevantes para debug
            $lines = $content -split "`n"
            $relevantLine = $lines | Where-Object { $_ -match "ALLOWED_IPS.*process\.env" }
            if ($relevantLine) {
                Write-Host "Linea actual encontrada:" -ForegroundColor Yellow
                Write-Host "$relevantLine" -ForegroundColor White
            }
            exit 1
        }
        
    } catch {
        Write-Host "ERROR aplicando correccion: $($_.Exception.Message)" -ForegroundColor Red
        
        # Restaurar backup
        Write-Host "Restaurando backup..." -ForegroundColor Yellow
        try {
            Copy-Item $backupFile "config/environment.js"
            Write-Host "Backup restaurado" -ForegroundColor Green
        } catch {
            Write-Host "ERROR restaurando backup" -ForegroundColor Red
        }
        exit 1
    }
    
    Write-Host "`nPASO 4: REINICIAR SERVICIOS PM2" -ForegroundColor Cyan
    Write-Host "--------------------------------" -ForegroundColor White
    
    try {
        Write-Host "Obteniendo estado actual..." -ForegroundColor Yellow
        pm2 status
        
        Write-Host "`nReiniciando todos los servicios..." -ForegroundColor Yellow
        pm2 restart all
        
        # Esperar reinicio
        Start-Sleep -Seconds 5
        
        Write-Host "`nEstado posterior al reinicio:" -ForegroundColor Yellow
        pm2 status
        
        Write-Host "Servicios reiniciados correctamente" -ForegroundColor Green
        
    } catch {
        Write-Host "ERROR reiniciando PM2: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "SOLUCION: Reiniciar manualmente con 'pm2 restart all'" -ForegroundColor Yellow
    }
    
    Write-Host "`n=============================================" -ForegroundColor Green
    Write-Host "CORRECCION COMPLETADA" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    
    Write-Host "`nCambios aplicados:" -ForegroundColor Green
    Write-Host "1. Agregado .trim() para eliminar espacios" -ForegroundColor White
    Write-Host "2. Agregado ::1 al fallback" -ForegroundColor White
    Write-Host "3. Servicios PM2 reiniciados" -ForegroundColor White
    Write-Host "4. Backup disponible: $backupFile" -ForegroundColor White
    
    Write-Host "`nPRUEBA INMEDIATA:" -ForegroundColor Cyan
    Write-Host "Solicitar al usuario de 10.43.126.22 que acceda a:" -ForegroundColor Yellow
    Write-Host "http://10.42.126.12:3001/dashboard/value-stream-map.html" -ForegroundColor White
    
    Write-Host "`nPARA MONITOREAR RESULTADOS:" -ForegroundColor Cyan
    Write-Host "1. Abrir una nueva ventana PowerShell" -ForegroundColor White
    Write-Host "2. Ejecutar: pm2 logs --lines 0" -ForegroundColor Yellow
    Write-Host "3. Observar logs mientras el usuario accede" -ForegroundColor White
    
    Write-Host "`nSI SIGUE FALLANDO:" -ForegroundColor Red
    Write-Host "- Verificar IP exacta detectada en logs" -ForegroundColor White
    Write-Host "- Puede ser problema de NAT/Proxy" -ForegroundColor White
    Write-Host "- La IP real podria ser diferente a 10.43.126.22" -ForegroundColor White
    
    Write-Host "`nPARA REVERTIR:" -ForegroundColor Yellow
    Write-Host "Copy-Item $backupFile config/environment.js" -ForegroundColor White
    Write-Host "pm2 restart all" -ForegroundColor White
    
} else {
    Write-Host "`nOperacion cancelada por el usuario" -ForegroundColor Yellow
    Write-Host "No se realizaron cambios" -ForegroundColor White
    Write-Host "Backup disponible: $backupFile" -ForegroundColor White
}

Write-Host "`nPresiona Enter para continuar..." -ForegroundColor Gray
Read-Host