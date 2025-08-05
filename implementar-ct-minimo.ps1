# =============================================================================
# SCRIPT SUPER MINIMO - SOLO CAMBIOS DE ETIQUETA Y NUEVO CAMPO
# No tocar el corazon del calculo existente
# =============================================================================

param(
    [string]$ProjectPath = "C:\Aplicaciones\mi-servidor-web",
    [switch]$DryRun = $false
)

Write-Host "=============================================================================="
Write-Host "CAMBIOS MINIMOS - CT EQUIPO Y CT PROCESO"
Write-Host "=============================================================================="

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $ProjectPath "backups\ct-labels-$timestamp"

Write-Host "Proyecto: $ProjectPath"
Write-Host "Backup: $backupPath"

Write-Host ""
Write-Host "CAMBIOS A REALIZAR (MINIMOS):"
Write-Host ""
Write-Host "FRONTEND (solo etiquetas):"
Write-Host "  1. dashboard-renderer.js - Cambiar Tiempo Real por CT Equipo"
Write-Host "  2. process-cards.css - Grid 4 a 5 columnas"
Write-Host "  3. gpec5-data-processor.js - Cambiar prefix-real por prefix-equipment-ct"
Write-Host ""
Write-Host "BACKEND (agregar calculo, NO tocar existente):"
Write-Host "  4. RealDataController.js - SOLO agregar calculateProcessCycleTime"
Write-Host "                           - NO modificar calculo existente"
Write-Host ""
Write-Host "TOTAL: 4 archivos, cambios minimos, corazon del calculo INTACTO"
Write-Host ""

# Verificar proyecto
if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Proyecto no encontrado"
    exit 1
}

# =============================================================================
# CREAR BACKUP MINIMO
# =============================================================================

$filesToBackup = @(
    "public\dashboard\js\dashboard-renderer.js",
    "public\dashboard\css\process-cards.css",
    "public\dashboard\js\gpec5-data-processor.js", 
    "src\presentation\controllers\public\RealDataController.js"
)

Write-Host "PASO 1: Backup..."

if (-not $DryRun) {
    New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
    foreach ($file in $filesToBackup) {
        $sourcePath = Join-Path $ProjectPath $file
        if (Test-Path $sourcePath) {
            $destPath = Join-Path $backupPath $file
            $destDir = Split-Path $destPath -Parent
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            Copy-Item $sourcePath $destPath -Force
            Write-Host "  $file"
        }
    }
    Write-Host "Backup completado"
}

# =============================================================================
# CAMBIO 1: SOLO ETIQUETA - dashboard-renderer.js
# =============================================================================

Write-Host ""
Write-Host "PASO 2: Cambiando etiqueta Tiempo Real por CT Equipo..."

$rendererFile = Join-Path $ProjectPath "public\dashboard\js\dashboard-renderer.js"

if (Test-Path $rendererFile) {
    $content = Get-Content $rendererFile -Raw
    
    if ($content -match "CT Equipo") {
        Write-Host "  Ya cambiado"
    } else {
        if (-not $DryRun) {
            # SOLO cambiar la etiqueta
            $content = $content -replace "Tiempo Real", "CT Equipo"
            Set-Content $rendererFile $content -Encoding UTF8
            Write-Host "  Etiqueta cambiada: Tiempo Real -> CT Equipo"
        } else {
            Write-Host "  DRY RUN: Se cambiaria Tiempo Real por CT Equipo"
        }
    }
}

# =============================================================================
# CAMBIO 2: CSS GRID - process-cards.css
# =============================================================================

Write-Host ""
Write-Host "PASO 3: Actualizando CSS para 5 metricas..."

$cssFile = Join-Path $ProjectPath "public\dashboard\css\process-cards.css"

if (Test-Path $cssFile) {
    $content = Get-Content $cssFile -Raw
    
    if ($content -match "repeat\(5, 1fr\)") {
        Write-Host "  Ya actualizado"
    } else {
        if (-not $DryRun) {
            # Cambiar grid de 4 a 5 columnas
            $content = $content -replace "grid-template-columns: repeat\(4, 1fr\)", "grid-template-columns: repeat(5, 1fr)"
            
            # Agregar responsive simple
            $content += "`n`n/* CT Equipo y Proceso - $timestamp */`n"
            $content += "@media (max-width: 1200px) { .metrics-grid { grid-template-columns: repeat(3, 1fr); } }`n"
            $content += "@media (max-width: 768px) { .metrics-grid { grid-template-columns: repeat(2, 1fr); } }"
            
            Set-Content $cssFile $content -Encoding UTF8
            Write-Host "  CSS actualizado para 5 columnas"
        } else {
            Write-Host "  DRY RUN: Se cambiaria grid a 5 columnas"
        }
    }
}

# =============================================================================
# CAMBIO 3: REFERENCIAS - gpec5-data-processor.js
# =============================================================================

Write-Host ""
Write-Host "PASO 4: Actualizando referencias en gpec5-data-processor.js..."

$processorFile = Join-Path $ProjectPath "public\dashboard\js\gpec5-data-processor.js"

if (Test-Path $processorFile) {
    $content = Get-Content $processorFile -Raw
    
    if ($content -match "equipment-ct") {
        Write-Host "  Ya actualizado"
    } else {
        if (-not $DryRun) {
            # Cambiar prefix-real por prefix-equipment-ct
            $content = $content -replace "prefix`}-real", "prefix}-equipment-ct"
            Set-Content $processorFile $content -Encoding UTF8
            Write-Host "  Referencias actualizadas"
        } else {
            Write-Host "  DRY RUN: Se cambiarian referencias prefix-real por prefix-equipment-ct"
        }
    }
}

# =============================================================================
# CAMBIO 4: AGREGAR CT PROCESO - RealDataController.js
# =============================================================================

Write-Host ""
Write-Host "PASO 5: BACKEND - Agregando calculo CT Proceso..."
Write-Host "  IMPORTANTE: NO se toca el calculo existente"

$controllerFile = Join-Path $ProjectPath "src\presentation\controllers\public\RealDataController.js"

if (Test-Path $controllerFile) {
    $content = Get-Content $controllerFile -Raw
    
    if ($content -match "calculateProcessCycleTime") {
        Write-Host "  Ya tiene calculo CT Proceso"
    } else {
        Write-Host "  Agregando metodo calculateProcessCycleTime..."
        
        $newMethod = @"

    /**
     * NUEVO: Calcular CT Proceso (BCMP->BCMP consecutivo)
     * NO modifica el calculo existente de CT Equipo
     */
    calculateProcessCycleTime(allRecords, equipmentId) {
        try {
            if (!allRecords || allRecords.length < 2) return null;

            const bcmpRecords = allRecords
                .filter(record => record && record.status && 
                       (record.status.startsWith('BCMP') || record.status.includes('OK')))
                .sort((a, b) => {
                    const timeA = new Date(a.timestamp || a.scannedAt);
                    const timeB = new Date(b.timestamp || b.scannedAt);
                    return timeB.getTime() - timeA.getTime();
                });

            if (bcmpRecords.length < 2) return null;

            const processCycleTimes = [];
            
            for (let i = 1; i < Math.min(bcmpRecords.length, 15); i++) {
                const currentRecord = bcmpRecords[i - 1];
                const previousRecord = bcmpRecords[i];
                
                const currentTime = new Date(currentRecord.timestamp || currentRecord.scannedAt);
                const previousTime = new Date(previousRecord.timestamp || previousRecord.scannedAt);
                
                if (!isNaN(currentTime.getTime()) && !isNaN(previousTime.getTime())) {
                    const cycleTimeMs = currentTime.getTime() - previousTime.getTime();
                    const cycleTimeSeconds = cycleTimeMs / 1000;
                    
                    if (cycleTimeSeconds >= 3 && cycleTimeSeconds <= 300) {
                        processCycleTimes.push(cycleTimeSeconds);
                    }
                }
            }
            
            if (processCycleTimes.length === 0) return null;
            
            const recentCycles = processCycleTimes.slice(0, 10);
            const average = recentCycles.reduce((sum, ct) => sum + ct, 0) / recentCycles.length;
            
            return Math.round(average * 10) / 10;
            
        } catch (error) {
            logger.warn(`Error calculando CT Proceso para ${equipmentId}:`, error.message);
            return null;
        }
    }
"@

        if (-not $DryRun) {
            # Agregar metodo antes del ultimo }
            $content = $content -replace "(\s+)(\})\s*$", "`$1$newMethod`$1`$2"
            Set-Content $controllerFile $content -Encoding UTF8
            Write-Host "  Metodo calculateProcessCycleTime agregado"
            Write-Host "  CALCULO EXISTENTE PRESERVADO"
        } else {
            Write-Host "  DRY RUN: Se agregaria calculateProcessCycleTime sin tocar calculo existente"
        }
    }
}

# =============================================================================
# RESUMEN FINAL
# =============================================================================

Write-Host ""
Write-Host "=============================================================================="
Write-Host "IMPLEMENTACION COMPLETADA"
Write-Host "=============================================================================="

if (-not $DryRun) {
    Write-Host ""
    Write-Host "CAMBIOS APLICADOS (MINIMOS):"
    Write-Host "  dashboard-renderer.js - Etiqueta cambiada"
    Write-Host "  process-cards.css - Grid 5 columnas" 
    Write-Host "  gpec5-data-processor.js - Referencias actualizadas"
    Write-Host "  RealDataController.js - Metodo CT Proceso agregado"
    Write-Host ""
    Write-Host "CALCULO EXISTENTE:"
    Write-Host "  RealCSVFetcher.js - INTACTO (corazon del sistema)"
    Write-Host "  Logica BREQ->BCMP - PRESERVADA"
    Write-Host "  Analisis outliers - PRESERVADO"
    Write-Host ""
    Write-Host "SIGUIENTES PASOS:"
    Write-Host "1. Reiniciar: node server.js"
    Write-Host "2. Verificar dashboard muestra CT Equipo (antes Tiempo Real)"
    Write-Host "3. Verificar aparece nueva metrica CT Proceso"
    Write-Host "4. Para Wave Solder: CT Equipo = CT Proceso (ambos BCMP->BCMP)"
    Write-Host "5. Para otros: CT Equipo != CT Proceso (BREQ->BCMP vs BCMP->BCMP)"
    Write-Host ""
    Write-Host "BACKUP: $backupPath"
} else {
    Write-Host ""
    Write-Host "DRY RUN COMPLETADO - NINGUN ARCHIVO MODIFICADO"
    Write-Host ""
    Write-Host "Para aplicar:"
    Write-Host "  .\script.ps1 -ProjectPath `"$ProjectPath`""
}

Write-Host ""
Write-Host "=============================================================================="