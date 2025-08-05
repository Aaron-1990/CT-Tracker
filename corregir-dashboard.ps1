# =============================================================================
# SCRIPT DE CORRECCION - PROBLEMAS DASHBOARD CT
# Arreglar caracteres raros y agregar CT Proceso faltante
# =============================================================================

param(
    [string]$ProjectPath = "C:\Aplicaciones\mi-servidor-web",
    [switch]$DryRun = $false
)

Write-Host "=============================================================================="
Write-Host "CORRECCION DE PROBLEMAS DASHBOARD CT"
Write-Host "=============================================================================="

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $ProjectPath "backups\dashboard-fix-$timestamp"

Write-Host "Proyecto: $ProjectPath"
Write-Host "Modo: $(if($DryRun) {'DRY RUN'} else {'CORRECCION REAL'})"

Write-Host ""
Write-Host "PROBLEMAS A CORREGIR:"
Write-Host "1. Caracteres raros en CSS (simbolos de flecha mal codificados)"
Write-Host "2. Falta campo CT Proceso en dashboard-renderer.js"
Write-Host "3. Falta referencia CT Proceso en gpec5-data-processor.js"
Write-Host "4. Verificar encoding UTF-8 en archivos"
Write-Host ""

# Verificar proyecto
if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Proyecto no encontrado"
    exit 1
}

# =============================================================================
# CREAR BACKUP
# =============================================================================

$filesToBackup = @(
    "public\dashboard\js\dashboard-renderer.js",
    "public\dashboard\js\gpec5-data-processor.js",
    "public\dashboard\css\process-cards.css",
    "public\dashboard\css\dynamic-dashboard.css"
)

Write-Host "PASO 1: Backup de archivos a corregir..."

if (-not $DryRun) {
    New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
    foreach ($file in $filesToBackup) {
        $sourcePath = Join-Path $ProjectPath $file
        if (Test-Path $sourcePath) {
            $destPath = Join-Path $backupPath $file
            $destDir = Split-Path $destPath -Parent
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            Copy-Item $sourcePath $destPath -Force
            Write-Host "  Backup: $file"
        }
    }
    Write-Host "Backup completado"
}

# =============================================================================
# CORRECCION 1: LIMPIAR CARACTERES RAROS EN CSS
# =============================================================================

Write-Host ""
Write-Host "PASO 2: Limpiando caracteres raros en CSS..."

$cssFiles = @(
    "public\dashboard\css\dynamic-dashboard.css",
    "public\dashboard\css\process-cards.css"
)

foreach ($cssFile in $cssFiles) {
    $filePath = Join-Path $ProjectPath $cssFile
    if (Test-Path $filePath) {
        $content = Get-Content $filePath -Raw -Encoding UTF8
        
        # Buscar caracteres raros
        $hasWeirdChars = $content -match "[^\x00-\x7F]" -and $content -match "â|†|'"
        
        if ($hasWeirdChars) {
            Write-Host "  Limpiando $cssFile..."
            
            if (-not $DryRun) {
                # Limpiar caracteres raros comunes
                $content = $content -replace "â†'", "→"  # Flecha derecha
                $content = $content -replace "â†", "→"   # Flecha derecha
                $content = $content -replace "â€", "'"   # Comilla
                $content = $content -replace "â", ""      # Otros caracteres raros
                
                # Guardar con encoding UTF-8 correcto
                [System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::UTF8)
                Write-Host "    Caracteres limpiados y archivo guardado con UTF-8"
            } else {
                Write-Host "    DRY RUN: Se limpiarian caracteres raros"
            }
        } else {
            Write-Host "  $cssFile - No hay caracteres raros"
        }
    }
}

# =============================================================================
# CORRECCION 2: AGREGAR CT PROCESO A dashboard-renderer.js
# =============================================================================

Write-Host ""
Write-Host "PASO 3: Verificando y corrigiendo dashboard-renderer.js..."

$rendererFile = Join-Path $ProjectPath "public\dashboard\js\dashboard-renderer.js"

if (Test-Path $rendererFile) {
    $content = Get-Content $rendererFile -Raw -Encoding UTF8
    
    # Verificar si ya tiene CT Proceso
    if ($content -match "CT Proceso" -and $content -match "process-ct") {
        Write-Host "  Ya tiene CT Proceso implementado correctamente"
    } else {
        Write-Host "  Agregando CT Proceso a createMetricsGrid..."
        
        if (-not $DryRun) {
            # Buscar el patron de metricas existente y agregar CT Proceso
            $originalPattern = @"
                <div class="metric-item">
                    <span class="metric-value" id="`${processName}-equipment-ct">
                        `${this.formatMetricValue(metrics.realTime, 's')}
                    </span>
                    <span class="metric-label">CT Equipo</span>
                </div>
"@

            $newPattern = @"
                <div class="metric-item">
                    <span class="metric-value" id="`${processName}-equipment-ct">
                        `${this.formatMetricValue(metrics.realTime, 's')}
                    </span>
                    <span class="metric-label">CT Equipo</span>
                </div>
                <div class="metric-item">
                    <span class="metric-value" id="`${processName}-process-ct">
                        `${this.formatMetricValue(metrics.processTime || metrics.realTime, 's')}
                    </span>
                    <span class="metric-label">CT Proceso</span>
                </div>
"@

            # Si no encuentra el patron exacto, buscar patron alternativo
            if ($content -notmatch [regex]::Escape($originalPattern)) {
                # Buscar patron mas simple
                $simplePattern = "CT Equipo</span>"
                $simpleReplacement = @"
CT Equipo</span>
                </div>
                <div class="metric-item">
                    <span class="metric-value" id="`${processName}-process-ct">
                        `${this.formatMetricValue(metrics.processTime || metrics.realTime, 's')}
                    </span>
                    <span class="metric-label">CT Proceso</span>
"@
                
                if ($content -match $simplePattern) {
                    $content = $content -replace $simplePattern, $simpleReplacement
                    Write-Host "    CT Proceso agregado usando patron simple"
                } else {
                    Write-Host "    ADVERTENCIA: No se encontro patron para agregar CT Proceso"
                    Write-Host "    Sera necesario agregar manualmente"
                }
            } else {
                $content = $content -replace [regex]::Escape($originalPattern), $newPattern
                Write-Host "    CT Proceso agregado usando patron completo"
            }
            
            # Guardar archivo
            [System.IO.File]::WriteAllText($rendererFile, $content, [System.Text.Encoding]::UTF8)
            Write-Host "    dashboard-renderer.js actualizado"
        } else {
            Write-Host "    DRY RUN: Se agregaria CT Proceso a createMetricsGrid"
        }
    }
}

# =============================================================================
# CORRECCION 3: AGREGAR CT PROCESO A gpec5-data-processor.js
# =============================================================================

Write-Host ""
Write-Host "PASO 4: Verificando y corrigiendo gpec5-data-processor.js..."

$processorFile = Join-Path $ProjectPath "public\dashboard\js\gpec5-data-processor.js"

if (Test-Path $processorFile) {
    $content = Get-Content $processorFile -Raw -Encoding UTF8
    
    # Verificar si ya tiene referencia a process-ct
    if ($content -match "process-ct") {
        Write-Host "  Ya tiene referencias CT Proceso"
    } else {
        Write-Host "  Agregando referencia CT Proceso..."
        
        if (-not $DryRun) {
            # Buscar donde esta equipment-ct y agregar process-ct despues
            $equipmentCtPattern = "this\.updateMetricWithAnimation\(`\$\{prefix\}-equipment-ct`, `\$\{metrics\.realTime\}s`\);"
            $processCtAddition = @"
this.updateMetricWithAnimation(`${prefix}-equipment-ct`, `${metrics.realTime}s`);
        
        // CT Proceso (usar processTime si existe, sino realTime como fallback)
        const processTime = metrics.processTime || metrics.realTime;
        this.updateMetricWithAnimation(`${prefix}-process-ct`, `${processTime}s`);
"@
            
            if ($content -match $equipmentCtPattern) {
                $content = $content -replace $equipmentCtPattern, $processCtAddition
                Write-Host "    Referencia CT Proceso agregada"
            } else {
                Write-Host "    ADVERTENCIA: No se encontro patron equipment-ct para agregar process-ct"
            }
            
            # Guardar archivo
            [System.IO.File]::WriteAllText($processorFile, $content, [System.Text.Encoding]::UTF8)
            Write-Host "    gpec5-data-processor.js actualizado"
        } else {
            Write-Host "    DRY RUN: Se agregaria referencia CT Proceso"
        }
    }
}

# =============================================================================
# CORRECCION 4: VERIFICAR GRID CSS
# =============================================================================

Write-Host ""
Write-Host "PASO 5: Verificando grid CSS para 5 metricas..."

$cssFile = Join-Path $ProjectPath "public\dashboard\css\process-cards.css"

if (Test-Path $cssFile) {
    $content = Get-Content $cssFile -Raw -Encoding UTF8
    
    if ($content -match "grid-template-columns:\s*repeat\(5,\s*1fr\)") {
        Write-Host "  Grid CSS ya configurado para 5 metricas"
    } else {
        Write-Host "  Configurando grid CSS para 5 metricas..."
        
        if (-not $DryRun) {
            # Agregar estilos para 5 metricas
            $cssAddition = @"

/* Grid para 5 metricas CT - $timestamp */
.metrics-grid {
    display: grid;
    grid-template-columns: repeat(5, 1fr) !important;
    gap: 12px;
}

@media (max-width: 1200px) {
    .metrics-grid {
        grid-template-columns: repeat(3, 1fr) !important;
    }
}

@media (max-width: 768px) {
    .metrics-grid {
        grid-template-columns: repeat(2, 1fr) !important;
    }
}
"@
            
            $content += $cssAddition
            [System.IO.File]::WriteAllText($cssFile, $content, [System.Text.Encoding]::UTF8)
            Write-Host "    Grid CSS actualizado para 5 metricas"
        } else {
            Write-Host "    DRY RUN: Se actualizaria grid CSS"
        }
    }
}

# =============================================================================
# VERIFICACION FINAL
# =============================================================================

Write-Host ""
Write-Host "PASO 6: Verificacion de archivos corregidos..."

if (-not $DryRun) {
    Write-Host ""
    Write-Host "ARCHIVOS CORREGIDOS:"
    
    # Verificar que los archivos tienen los cambios
    $rendererContent = Get-Content (Join-Path $ProjectPath "public\dashboard\js\dashboard-renderer.js") -Raw
    $processorContent = Get-Content (Join-Path $ProjectPath "public\dashboard\js\gpec5-data-processor.js") -Raw
    $cssContent = Get-Content (Join-Path $ProjectPath "public\dashboard\css\process-cards.css") -Raw
    
    if ($rendererContent -match "CT Proceso") {
        Write-Host "  dashboard-renderer.js - CT Proceso: OK"
    } else {
        Write-Host "  dashboard-renderer.js - CT Proceso: FALTA"
    }
    
    if ($processorContent -match "process-ct") {
        Write-Host "  gpec5-data-processor.js - Referencias CT: OK"
    } else {
        Write-Host "  gpec5-data-processor.js - Referencias CT: FALTA"
    }
    
    if ($cssContent -match "repeat\(5") {
        Write-Host "  process-cards.css - Grid 5 metricas: OK"
    } else {
        Write-Host "  process-cards.css - Grid 5 metricas: FALTA"
    }
}

# =============================================================================
# INSTRUCCIONES FINALES
# =============================================================================

Write-Host ""
Write-Host "=============================================================================="
Write-Host "CORRECCION COMPLETADA"
Write-Host "=============================================================================="

if (-not $DryRun) {
    Write-Host ""
    Write-Host "SIGUIENTES PASOS:"
    Write-Host "1. Reiniciar servicio: Restart-Service VSM-Dashboard-BorgWarner"
    Write-Host "2. Abrir dashboard y verificar:"
    Write-Host "   - No hay simbolos raros"
    Write-Host "   - Aparece CT Equipo (antes Tiempo Real)"
    Write-Host "   - Aparece CT Proceso (nueva metrica)"
    Write-Host "   - Layout se ve bien con 5 metricas"
    Write-Host ""
    Write-Host "SI AUN HAY PROBLEMAS:"
    Write-Host "   Backup disponible en: $backupPath"
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "DRY RUN COMPLETADO"
    Write-Host "Para aplicar correcciones:"
    Write-Host "  .\script-correccion.ps1 -ProjectPath `"$ProjectPath`""
}

Write-Host "=============================================================================="