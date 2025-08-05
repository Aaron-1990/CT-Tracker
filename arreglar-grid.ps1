# =============================================================================
# SCRIPT ARREGLAR GRID DE METRICAS - LAYOUT CORRECTO
# Corregir el layout que se sale de las cajas
# =============================================================================

param(
    [string]$ProjectPath = "C:\Aplicaciones\mi-servidor-web",
    [switch]$DryRun = $false
)

Write-Host "=============================================================================="
Write-Host "ARREGLAR GRID DE METRICAS - LAYOUT CORRECTO"
Write-Host "=============================================================================="

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $ProjectPath "backups\grid-fix-$timestamp"

Write-Host "Proyecto: $ProjectPath"
Write-Host "Modo: $(if($DryRun) {'DRY RUN'} else {'CORRECCION REAL'})"

Write-Host ""
Write-Host "PROBLEMA DETECTADO:"
Write-Host "El archivo process-cards.css tiene .metrics-grid configurado para solo 2 columnas"
Write-Host "pero ahora necesitamos 5 metricas (Diseno, CT Equipo, CT Proceso, Promedio 1h, OEE)"
Write-Host ""
Write-Host "SOLUCION:"
Write-Host "Reconfigurar .metrics-grid para layout responsive con 5 metricas"
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
    "public\dashboard\css\process-cards.css"
)

Write-Host "PASO 1: Backup del archivo CSS..."

if (-not $DryRun) {
    New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
    $cssFile = Join-Path $ProjectPath "public\dashboard\css\process-cards.css"
    if (Test-Path $cssFile) {
        $destPath = Join-Path $backupPath "process-cards.css"
        Copy-Item $cssFile $destPath -Force
        Write-Host "  Backup creado: process-cards.css"
    }
}

# =============================================================================
# ANALIZAR EL PROBLEMA
# =============================================================================

Write-Host ""
Write-Host "PASO 2: Analizando el problema actual..."

$cssFile = Join-Path $ProjectPath "public\dashboard\css\process-cards.css"

if (Test-Path $cssFile) {
    $content = Get-Content $cssFile -Raw -Encoding UTF8
    
    # Buscar la configuracion actual del grid
    if ($content -match "\.metrics-grid\s*\{[^}]*grid-template-columns:\s*1fr\s+1fr[^}]*\}") {
        Write-Host "  PROBLEMA CONFIRMADO: .metrics-grid configurado para 2 columnas (1fr 1fr)"
        Write-Host "  Esto causa que las 5 metricas se salgan de la caja"
    } elseif ($content -match "\.metrics-grid\s*\{[^}]*grid-template-columns:\s*repeat\(5,\s*1fr\)[^}]*\}") {
        Write-Host "  Grid ya esta configurado para 5 columnas, pero puede necesitar ajustes de spacing"
    } else {
        Write-Host "  Configuracion de grid no encontrada o es diferente"
        Write-Host "  Necesitamos agregar configuracion correcta"
    }
    
    # Verificar si tiene responsive design
    if ($content -match "@media.*max-width.*768px") {
        Write-Host "  Responsive design: PRESENTE"
    } else {
        Write-Host "  Responsive design: FALTANTE (necesario para mobile)"
    }
} else {
    Write-Host "  ERROR: Archivo process-cards.css no encontrado"
    exit 1
}

# =============================================================================
# APLICAR CORRECCION
# =============================================================================

Write-Host ""
Write-Host "PASO 3: Aplicando correccion del layout..."

if (-not $DryRun) {
    # Nueva configuracion CSS optimizada para 5 metricas
    $newMetricsGridCSS = @"

/* =============================================================================
 * CORRECCION LAYOUT METRICAS - $timestamp
 * Grid optimizado para 5 metricas (Diseno, CT Equipo, CT Proceso, Promedio 1h, OEE)
 * ============================================================================= */

.metrics-grid {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: 0.8rem;
    margin-bottom: 1.5rem;
    padding: 0.5rem;
}

/* Ajustar items para que se vean bien en 5 columnas */
.metric-item {
    text-align: center;
    padding: 0.6rem 0.4rem;
    background: var(--light-bg);
    border-radius: 6px;
    border-left: 3px solid var(--primary-blue);
    min-height: 60px;
    display: flex;
    flex-direction: column;
    justify-content: center;
}

.metric-value {
    font-size: 1.2rem;
    font-weight: bold;
    color: var(--dark-bg);
    display: block;
    margin-bottom: 0.2rem;
    line-height: 1.1;
}

.metric-label {
    font-size: 0.7rem;
    color: var(--text-light);
    text-transform: uppercase;
    letter-spacing: 0.3px;
    line-height: 1;
}

/* Responsive: 3 columnas en tablets */
@media (max-width: 1200px) {
    .metrics-grid {
        grid-template-columns: repeat(3, 1fr);
        gap: 0.6rem;
    }
    
    .metric-item {
        padding: 0.8rem 0.5rem;
        min-height: 65px;
    }
    
    .metric-value {
        font-size: 1.3rem;
    }
    
    .metric-label {
        font-size: 0.75rem;
    }
}

/* Responsive: 2 columnas en mobile */
@media (max-width: 768px) {
    .metrics-grid {
        grid-template-columns: repeat(2, 1fr);
        gap: 0.5rem;
    }
    
    .metric-item {
        padding: 1rem 0.6rem;
        min-height: 70px;
    }
    
    .metric-value {
        font-size: 1.4rem;
    }
    
    .metric-label {
        font-size: 0.8rem;
    }
}

/* Ajustar el contenedor de la process-card para acomodar mejor las metricas */
.process-card {
    background: white;
    border-radius: var(--border-radius);
    box-shadow: var(--shadow);
    padding: 1.8rem;
    min-width: 380px;
    max-width: 420px;
    text-align: center;
    border: 3px solid var(--primary-blue);
    position: relative;
    transition: all 0.3s ease;
}

/* Responsive para process cards */
@media (max-width: 1200px) {
    .process-card {
        min-width: 350px;
        max-width: 380px;
        padding: 1.6rem;
    }
}

@media (max-width: 768px) {
    .process-card {
        min-width: 320px;
        max-width: 350px;
        padding: 1.4rem;
    }
}

@media (max-width: 480px) {
    .process-card {
        min-width: 280px;
        max-width: 320px;
        padding: 1.2rem;
    }
}
"@

    # Leer contenido actual
    $content = Get-Content $cssFile -Raw -Encoding UTF8
    
    # Remover configuraciones antiguas de .metrics-grid
    $content = $content -replace "\.metrics-grid\s*\{[^}]*\}", ""
    $content = $content -replace "\.metric-item\s*\{[^}]*\}", ""
    $content = $content -replace "\.metric-value\s*\{[^}]*\}", ""
    $content = $content -replace "\.metric-label\s*\{[^}]*\}", ""
    
    # Remover responsive anterior para process-card si existe
    $content = $content -replace "@media\s*\([^)]*max-width:\s*768px[^)]*\)\s*\{[^}]*\.process-card[^}]*\}", ""
    
    # Agregar nueva configuracion
    $content += $newMetricsGridCSS
    
    # Guardar archivo
    [System.IO.File]::WriteAllText($cssFile, $content, [System.Text.Encoding]::UTF8)
    
    Write-Host "  Configuracion CSS actualizada:"
    Write-Host "    - Grid optimizado para 5 metricas"
    Write-Host "    - Responsive design mejorado"
    Write-Host "    - Tamaños de fuente ajustados"
    Write-Host "    - Process-card redimensionada para acomodar mejor"
    
} else {
    Write-Host "  DRY RUN: Se aplicaria nueva configuracion CSS para 5 metricas"
    Write-Host "    - Grid: repeat(5, 1fr) en desktop"
    Write-Host "    - Grid: repeat(3, 1fr) en tablet"
    Write-Host "    - Grid: repeat(2, 1fr) en mobile"
    Write-Host "    - Process-card redimensionada"
}

# =============================================================================
# VERIFICACION FINAL
# =============================================================================

Write-Host ""
Write-Host "PASO 4: Verificacion..."

if (-not $DryRun) {
    $updatedContent = Get-Content $cssFile -Raw -Encoding UTF8
    
    if ($updatedContent -match "grid-template-columns:\s*repeat\(5,\s*1fr\)") {
        Write-Host "  VERIFICACION OK: Grid configurado para 5 columnas"
    }
    
    if ($updatedContent -match "@media.*max-width.*1200px.*grid-template-columns:\s*repeat\(3,\s*1fr\)") {
        Write-Host "  VERIFICACION OK: Responsive tablet (3 columnas)"
    }
    
    if ($updatedContent -match "@media.*max-width.*768px.*grid-template-columns:\s*repeat\(2,\s*1fr\)") {
        Write-Host "  VERIFICACION OK: Responsive mobile (2 columnas)"
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
    Write-Host "CAMBIOS APLICADOS:"
    Write-Host "  process-cards.css - Grid optimizado para 5 metricas"
    Write-Host "  Responsive design - 5/3/2 columnas segun pantalla"
    Write-Host "  Process-card - Redimensionada para mejor ajuste"
    Write-Host ""
    Write-Host "SIGUIENTE PASO:"
    Write-Host "  Restart-Service VSM-Dashboard-BorgWarner"
    Write-Host ""
    Write-Host "RESULTADO ESPERADO:"
    Write-Host "  Las 5 metricas ahora deben caber perfectamente en cada caja"
    Write-Host "  Desktop: 5 columnas"
    Write-Host "  Tablet: 3 columnas (2 filas)"
    Write-Host "  Mobile: 2 columnas (3 filas)"
    Write-Host ""
    Write-Host "BACKUP: $backupPath"
} else {
    Write-Host ""
    Write-Host "DRY RUN COMPLETADO"
    Write-Host "Para aplicar correccion:"
    Write-Host "  .\arreglar-grid.ps1 -ProjectPath `"$ProjectPath`""
}

Write-Host "=============================================================================="