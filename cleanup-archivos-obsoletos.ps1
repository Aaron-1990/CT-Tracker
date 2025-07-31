# =============================================================================
# SCRIPT DE LIMPIEZA - ARCHIVOS OBSOLETOS DEL PROYECTO VSM
# Dashboard VSM BorgWarner - Eliminar archivos innecesarios para escalabilidad
# VERSION CORREGIDA - Sin simbolos especiales
# =============================================================================

param(
    [switch]$DryRun = $false,  # Solo mostrar que se eliminaria
    [switch]$Backup = $true    # Crear backup antes de eliminar
)

Write-Host "=============================================" -ForegroundColor Green
Write-Host "LIMPIEZA DE ARCHIVOS OBSOLETOS VSM DASHBOARD" -ForegroundColor Green
Write-Host "BorgWarner - Preparacion para escalabilidad" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

$projectPath = "C:\Aplicaciones\mi-servidor-web"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Set-Location $projectPath
Write-Host "Directorio base: $projectPath" -ForegroundColor White

# =============================================================================
# ANALISIS DE ARCHIVOS OBSOLETOS
# =============================================================================

Write-Host "`nANALISIS DE ARCHIVOS OBSOLETOS:" -ForegroundColor Cyan
Write-Host "---------------------------------------" -ForegroundColor White

# ARCHIVOS COMPLETAMENTE OBSOLETOS (se pueden eliminar sin riesgo)
$archivosObsoletos = @(
    @{
        Archivo = "audit-ip-config.ps1"
        Razon = "Script de auditoria temporal - ya no necesario con rangos DHCP implementados"
        Categoria = "Scripts obsoletos"
    },
    @{
        Archivo = "enterprise-config.ps1" 
        Razon = "Script de configuracion PM2 - ahora usamos servicio Windows"
        Categoria = "Scripts obsoletos"
    },
    @{
        Archivo = "enterprise-config-final.ps1"
        Razon = "Script de configuracion PM2 - ahora usamos servicio Windows"
        Categoria = "Scripts obsoletos"
    },
    @{
        Archivo = "iniciar-sistema-https.ps1"
        Razon = "Script de inicio PM2 HTTPS - ahora usamos servicio Windows"
        Categoria = "Scripts obsoletos"
    },
    @{
        Archivo = "implementar-https.ps1"
        Razon = "Script de implementacion HTTPS - ya implementado"
        Categoria = "Scripts obsoletos"
    },
    @{
        Archivo = "update-dual-service.ps1"
        Razon = "Script de actualizacion dual - ya implementado"
        Categoria = "Scripts obsoletos"
    },
    @{
        Archivo = "diagnostico-avanzado.ps1"
        Razon = "Script de diagnostico temporal - sistema ya estable"
        Categoria = "Scripts obsoletos"
    },
    @{
        Archivo = "ecosystem.config.js"
        Razon = "Configuracion PM2 HTTP - ahora usamos servicio Windows"
        Categoria = "PM2 obsoleto"
    },
    @{
        Archivo = "ecosystem-https.config.js"
        Razon = "Configuracion PM2 HTTPS - ahora usamos servicio Windows"
        Categoria = "PM2 obsoleto"
    },
    @{
        Archivo = "ecosystem.config.js.backup"
        Razon = "Backup de configuracion PM2 - ya no relevante"
        Categoria = "Backups obsoletos"
    },
    @{
        Archivo = "server.js.backup-20250724-174944"
        Razon = "Backup muy antiguo de server.js - ya no relevante"
        Categoria = "Backups obsoletos"
    },
    @{
        Archivo = "monitor-continuo.bat"
        Razon = "Monitor para PM2 - ahora usamos servicio Windows"
        Categoria = "Scripts obsoletos"
    }
)

# ARCHIVOS DE TRANSICION (revisar antes de eliminar)
$archivosTransicion = @(
    @{
        Archivo = "server-https.js"
        Razon = "Servidor HTTPS separado - puede consolidarse en server.js principal"
        Categoria = "Consolidacion posible"
        Accion = "REVISAR - Se usa actualmente?"
    },
    @{
        Archivo = ".env.example"
        Razon = "Plantilla de variables - util mantener para documentacion"
        Categoria = "Documentacion"
        Accion = "MANTENER como referencia"
    }
)

# =============================================================================
# MOSTRAR ANALISIS
# =============================================================================

Write-Host "`nARCHIVOS IDENTIFICADOS PARA ELIMINACION:" -ForegroundColor Yellow

$totalSize = 0
$archivosEncontrados = @()

foreach ($item in $archivosObsoletos) {
    $archivo = $item.Archivo
    if (Test-Path $archivo) {
        $fileInfo = Get-Item $archivo
        $sizeKB = [math]::Round($fileInfo.Length / 1KB, 1)
        $totalSize += $sizeKB
        
        Write-Host "  [X] $archivo" -ForegroundColor Red
        Write-Host "      Razon: $($item.Razon)" -ForegroundColor Gray
        Write-Host "      Tamaño: $sizeKB KB" -ForegroundColor Gray
        
        $archivosEncontrados += $item
    } else {
        Write-Host "  [-] $archivo (no existe)" -ForegroundColor Gray
    }
}

Write-Host "`nARCHIVOS PARA REVISION:" -ForegroundColor Yellow
foreach ($item in $archivosTransicion) {
    $archivo = $item.Archivo
    if (Test-Path $archivo) {
        $fileInfo = Get-Item $archivo
        $sizeKB = [math]::Round($fileInfo.Length / 1KB, 1)
        
        Write-Host "  [?] $archivo" -ForegroundColor Yellow
        Write-Host "      Razon: $($item.Razon)" -ForegroundColor Gray
        Write-Host "      Accion: $($item.Accion)" -ForegroundColor Cyan
        Write-Host "      Tamaño: $sizeKB KB" -ForegroundColor Gray
    }
}

# Buscar directorios de backup antiguos
Write-Host "`nDIRECTORIOS DE BACKUP ANTIGUOS:" -ForegroundColor Yellow
$backupDirs = Get-ChildItem -Path "backups" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "dhcp-migration-*" }

if ($backupDirs) {
    foreach ($dir in $backupDirs) {
        $dirSizeMB = [math]::Round((Get-ChildItem -Path $dir.FullName -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
        Write-Host "  [DIR] $($dir.Name)" -ForegroundColor Cyan
        Write-Host "        Tamaño: $dirSizeMB MB" -ForegroundColor Gray
        
        # Mantener solo los 2 backups más recientes
        if ($backupDirs.Count -gt 2) {
            $sortedDirs = $backupDirs | Sort-Object CreationTime -Descending
            if ($dir -notin $sortedDirs[0..1]) {
                Write-Host "        Accion: ELIMINAR (mantener solo 2 mas recientes)" -ForegroundColor Red
            } else {
                Write-Host "        Accion: MANTENER (backup reciente)" -ForegroundColor Green
            }
        }
    }
}

# =============================================================================
# RESUMEN ANTES DE ELIMINACION
# =============================================================================

Write-Host "`nRESUMEN DE LIMPIEZA:" -ForegroundColor Cyan
Write-Host "-------------------" -ForegroundColor White
Write-Host "Archivos obsoletos encontrados: $($archivosEncontrados.Count)" -ForegroundColor White
Write-Host "Espacio a liberar: $totalSize KB" -ForegroundColor White
Write-Host "Backups de seguridad: $(if($Backup){'Si'}else{'No'})" -ForegroundColor White

if ($DryRun) {
    Write-Host "`nMODO DRY RUN - No se eliminaran archivos" -ForegroundColor Magenta
    Write-Host "Para aplicar cambios, ejecute sin -DryRun" -ForegroundColor Yellow
} else {
    Write-Host "`nProcediendo con la eliminacion..." -ForegroundColor Yellow
    
    # Confirmacion del usuario
    Write-Host "`nEsta accion eliminara permanentemente los archivos obsoletos." -ForegroundColor Red
    Write-Host "Desea continuar? (Y/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    
    if ($response -ne "Y" -and $response -ne "y") {
        Write-Host "Operacion cancelada por el usuario" -ForegroundColor Red
        exit 0
    }
}

# =============================================================================
# CREAR BACKUP FINAL (SI ESTA HABILITADO)
# =============================================================================

if ($Backup -and -not $DryRun) {
    Write-Host "`nCreando backup final antes de eliminacion..." -ForegroundColor Cyan
    
    $backupFinalDir = "backups/cleanup-backup-$timestamp"
    New-Item -ItemType Directory -Path $backupFinalDir -Force | Out-Null
    
    foreach ($item in $archivosEncontrados) {
        $archivo = $item.Archivo
        if (Test-Path $archivo) {
            try {
                Copy-Item $archivo "$backupFinalDir/" -Force
                Write-Host "  Backup: $archivo" -ForegroundColor Green
            } catch {
                Write-Host "  Error backup: $archivo" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host "Backup final creado en: $backupFinalDir" -ForegroundColor Cyan
}

# =============================================================================
# ELIMINACION DE ARCHIVOS
# =============================================================================

if (-not $DryRun) {
    Write-Host "`nEliminando archivos obsoletos..." -ForegroundColor Cyan
    
    $eliminados = 0
    $errores = 0
    
    foreach ($item in $archivosEncontrados) {
        $archivo = $item.Archivo
        if (Test-Path $archivo) {
            try {
                Remove-Item $archivo -Force
                Write-Host "  [OK] Eliminado: $archivo" -ForegroundColor Green
                $eliminados++
            } catch {
                Write-Host "  [ERROR] $archivo - $($_.Exception.Message)" -ForegroundColor Red
                $errores++
            }
        }
    }
    
    # Eliminar backups antiguos (mantener solo 2 más recientes)
    if ($backupDirs -and $backupDirs.Count -gt 2) {
        Write-Host "`nLimpiando backups antiguos..." -ForegroundColor Cyan
        
        $sortedDirs = $backupDirs | Sort-Object CreationTime -Descending
        $dirsToDelete = $sortedDirs[2..($sortedDirs.Count-1)]
        
        foreach ($dir in $dirsToDelete) {
            try {
                Remove-Item $dir.FullName -Recurse -Force
                Write-Host "  [OK] Eliminado directorio: $($dir.Name)" -ForegroundColor Green
                $eliminados++
            } catch {
                Write-Host "  [ERROR] Error eliminando directorio: $($dir.Name)" -ForegroundColor Red
                $errores++
            }
        }
    }
    
    Write-Host "`nResultados de limpieza:" -ForegroundColor Cyan
    Write-Host "  Archivos eliminados: $eliminados" -ForegroundColor Green
    Write-Host "  Errores: $errores" -ForegroundColor $(if($errores -gt 0){"Red"}else{"Green"})
    Write-Host "  Espacio liberado: ~$totalSize KB" -ForegroundColor Green
}

# =============================================================================
# ARCHIVOS PRINCIPALES PARA ESCALABILIDAD
# =============================================================================

Write-Host "`nARCHIVOS PRINCIPALES PARA ESCALABILIDAD:" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor White

$archivosPrincipales = @(
    @{
        Archivo = "server.js"
        Proposito = "Servidor principal consolidado (HTTP + HTTPS)"
        Importancia = "CRITICO"
    },
    @{
        Archivo = ".env"
        Proposito = "Variables de entorno con rangos DHCP"
        Importancia = "CRITICO"
    },
    @{
        Archivo = "config/ip-validator.js"
        Proposito = "Validacion de rangos DHCP corporativos"
        Importancia = "CRITICO"
    },
    @{
        Archivo = "config/environment.js"
        Proposito = "Procesamiento de configuracion"
        Importancia = "CRITICO"
    },
    @{
        Archivo = "config/security.js"
        Proposito = "Middleware de seguridad"
        Importancia = "CRITICO"
    },
    @{
        Archivo = "config/logger.js"
        Proposito = "Sistema de logging"
        Importancia = "IMPORTANTE"
    },
    @{
        Archivo = "config/database.js"
        Proposito = "Configuracion de base de datos"
        Importancia = "CRITICO para escalabilidad"
    },
    @{
        Archivo = "vsm-service.bat"
        Proposito = "Script de servicio Windows"
        Importancia = "CRITICO"
    },
    @{
        Archivo = "package.json"
        Proposito = "Dependencias del proyecto"
        Importancia = "CRITICO"
    },
    @{
        Archivo = "certs/"
        Proposito = "Certificados SSL para HTTPS"
        Importancia = "IMPORTANTE"
    },
    @{
        Archivo = "public/"
        Proposito = "Archivos estaticos del dashboard"
        Importancia = "CRITICO"
    },
    @{
        Archivo = "src/"
        Proposito = "Codigo fuente de la aplicacion"
        Importancia = "CRITICO"
    },
    @{
        Archivo = "logs/"
        Proposito = "Archivos de log del sistema"
        Importancia = "IMPORTANTE"
    }
)

foreach ($item in $archivosPrincipales) {
    $archivo = $item.Archivo
    $existe = Test-Path $archivo
    $status = if ($existe) { "[OK]" } else { "[NO]" }
    $color = if ($existe) { "Green" } else { "Red" }
    
    Write-Host "  $status $archivo" -ForegroundColor $color
    Write-Host "        $($item.Proposito)" -ForegroundColor Gray
    Write-Host "        Importancia: $($item.Importancia)" -ForegroundColor $(
        switch ($item.Importancia) {
            "CRITICO" { "Red" }
            "CRITICO para escalabilidad" { "Yellow" }
            "IMPORTANTE" { "Cyan" }
            default { "Gray" }
        }
    )
}

Write-Host "`nLIMPIEZA COMPLETADA" -ForegroundColor Green
Write-Host "===================" -ForegroundColor Green

if (-not $DryRun) {
    Write-Host "`nEl proyecto ahora contiene solo los archivos necesarios" -ForegroundColor White
    Write-Host "para escalabilidad y desarrollo futuro." -ForegroundColor White
    Write-Host "`nProximos pasos recomendados:" -ForegroundColor Cyan
    Write-Host "1. Verificar que el servicio sigue funcionando" -ForegroundColor White
    Write-Host "2. Implementar nuevas funcionalidades de base de datos" -ForegroundColor White
    Write-Host "3. Escalar el dashboard con nuevas caracteristicas" -ForegroundColor White
} else {
    Write-Host "`nPara aplicar la limpieza, ejecute:" -ForegroundColor Yellow
    Write-Host "  .\cleanup-archivos-obsoletos.ps1" -ForegroundColor White
}

Write-Host "`nPresione cualquier tecla para finalizar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")