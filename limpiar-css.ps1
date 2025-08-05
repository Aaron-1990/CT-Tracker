# =============================================================================
# SCRIPT LIMPIAR Y CORREGIR CSS FINAL
# Limpiar duplicados y configurar layout correcto para 5 metricas
# =============================================================================

param(
    [string]$ProjectPath = "C:\Aplicaciones\mi-servidor-web",
    [switch]$DryRun = $false
)

Write-Host "=============================================================================="
Write-Host "LIMPIAR Y CORREGIR CSS FINAL - LAYOUT 5 METRICAS"
Write-Host "=============================================================================="

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $ProjectPath "backups\css-clean-$timestamp"

Write-Host "Proyecto: $ProjectPath"
Write-Host "Modo: $(if($DryRun) {'DRY RUN'} else {'CORRECCION FINAL'})"

Write-Host ""
Write-Host "PROBLEMAS DETECTADOS:"
Write-Host "1. CSS duplicado con configuraciones multiples"
Write-Host "2. Media queries vacias"
Write-Host "3. Ancho de cajas demasiado pequeno para 5 metricas"
Write-Host "4. Configuraciones conflictivas superpuestas"
Write-Host ""
Write-Host "SOLUCION:"
Write-Host "Limpiar todo y aplicar CSS limpio optimizado para 5 metricas"
Write-Host ""

# =============================================================================
# BACKUP
# =============================================================================

$cssFile = Join-Path $ProjectPath "public\dashboard\css\process-cards.css"

Write-Host "PASO 1: Backup del archivo CSS actual..."

if (-not $DryRun) {
    New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
    if (Test-Path $cssFile) {
        Copy-Item $cssFile (Join-Path $backupPath "process-cards.css") -Force
        Write-Host "  Backup creado"
    }
}

# =============================================================================
# CREAR CSS LIMPIO Y OPTIMIZADO
# =============================================================================

Write-Host ""
Write-Host "PASO 2: Creando CSS limpio optimizado para 5 metricas..."

$cleanCSS = @"
/* =============================================================================
 * PROCESS CARDS CSS - LIMPIO Y OPTIMIZADO PARA 5 METRICAS
 * Generado: $timestamp
 * ============================================================================= */

/* ===== PROCESS CARD PRINCIPAL ===== */
.process-card {
    background: white;
    border-radius: var(--border-radius);
    box-shadow: var(--shadow);
    padding: 1.8rem;
    min-width: 420px;
    max-width: 480px;
    text-align: center;
    border: 3px solid var(--primary-blue);
    position: relative;
    transition: all 0.3s ease;
    margin: 0.5rem;
}

.process-card:hover {
    transform: translateY(-5px);
    box-shadow: 0 8px 25px rgba(0,0,0,0.15);
}

/* ===== HEADER DEL PROCESO ===== */
.process-title {
    font-size: 1.4rem;
    font-weight: bold;
    color: var(--dark-bg);
    margin-bottom: 0.5rem;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
}

.equipment-info {
    font-size: 0.85rem;
    color: var(--text-light);
    margin-bottom: 1.2rem;
    padding: 0.5rem;
    background: var(--light-bg);
    border-radius: 6px;
    line-height: 1.3;
}

/* ===== GRID DE METRICAS - 5 COLUMNAS ===== */
.metrics-grid {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: 0.6rem;
    margin-bottom: 1.2rem;
    padding: 0.3rem;
}

.metric-item {
    text-align: center;
    padding: 0.5rem 0.3rem;
    background: var(--light-bg);
    border-radius: 5px;
    border-left: 3px solid var(--primary-blue);
    min-height: 55px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    overflow: hidden;
}

.metric-value {
    font-size: 1.1rem;
    font-weight: bold;
    color: var(--dark-bg);
    display: block;
    margin-bottom: 0.1rem;
    line-height: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.metric-label {
    font-size: 0.65rem;
    color: var(--text-light);
    text-transform: uppercase;
    letter-spacing: 0.2px;
    line-height: 1;
    font-weight: 600;
}

/* ===== BIG METRICS ===== */
.big-metrics {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.8rem;
    margin-top: 1rem;
}

.big-metric {
    background: linear-gradient(135deg, var(--primary-blue), #2980b9);
    color: white;
    padding: 0.8rem;
    border-radius: 6px;
    text-align: center;
}

.big-metric-value {
    font-size: 1.6rem;
    font-weight: bold;
    margin-bottom: 0.2rem;
    line-height: 1;
}

.big-metric-label {
    font-size: 0.8rem;
    opacity: 0.9;
    line-height: 1;
}

/* ===== INDICADOR TIEMPO REAL ===== */
.realtime-indicator {
    position: absolute;
    top: 12px;
    right: 12px;
    width: 10px;
    height: 10px;
    background: var(--success-green);
    border-radius: 50%;
    animation: pulse 1.5s infinite;
}

@keyframes pulse {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.6; transform: scale(1.1); }
}

/* ===== RESPONSIVE DESIGN ===== */

/* Tablets - 3 columnas en 2 filas */
@media (max-width: 1200px) {
    .process-card {
        min-width: 380px;
        max-width: 440px;
        padding: 1.6rem;
    }
    
    .metrics-grid {
        grid-template-columns: repeat(3, 1fr);
        gap: 0.5rem;
    }
    
    .metric-item {
        padding: 0.6rem 0.4rem;
        min-height: 60px;
    }
    
    .metric-value {
        font-size: 1.2rem;
    }
    
    .metric-label {
        font-size: 0.7rem;
    }
}

/* Mobile - 2 columnas en 3 filas */
@media (max-width: 768px) {
    .process-card {
        min-width: 340px;
        max-width: 380px;
        padding: 1.4rem;
        margin: 0.3rem;
    }
    
    .metrics-grid {
        grid-template-columns: repeat(2, 1fr);
        gap: 0.4rem;
    }
    
    .metric-item {
        padding: 0.7rem 0.5rem;
        min-height: 65px;
    }
    
    .metric-value {
        font-size: 1.3rem;
    }
    
    .metric-label {
        font-size: 0.75rem;
    }
    
    .big-metrics {
        gap: 0.6rem;
    }
    
    .big-metric {
        padding: 0.7rem;
    }
    
    .big-metric-value {
        font-size: 1.4rem;
    }
}

/* Mobile pequeno - Stack vertical */
@media (max-width: 480px) {
    .process-card {
        min-width: 300px;
        max-width: 340px;
        padding: 1.2rem;
    }
    
    .metrics-grid {
        grid-template-columns: 1fr;
        gap: 0.3rem;
    }
    
    .metric-item {
        padding: 0.8rem;
        min-height: 50px;
    }
    
    .metric-value {
        font-size: 1.4rem;
    }
    
    .metric-label {
        font-size: 0.8rem;
    }
}
"@

if (-not $DryRun) {
    # Reescribir completamente el archivo CSS
    [System.IO.File]::WriteAllText($cssFile, $cleanCSS, [System.Text.Encoding]::UTF8)
    
    Write-Host "  CSS completamente reescrito y optimizado"
    Write-Host "  Configuraciones duplicadas eliminadas"
    Write-Host "  Layout optimizado para 5 metricas"
    Write-Host "  Anchos de caja incrementados (420-480px)"
    Write-Host "  Responsive design limpio"
    
} else {
    Write-Host "  DRY RUN: Se reescribiria completamente process-cards.css"
    Write-Host "    - Eliminar configuraciones duplicadas"
    Write-Host "    - Incrementar ancho de cajas (420-480px)"
    Write-Host "    - Grid optimizado para 5 metricas"
    Write-Host "    - Responsive limpio (5/3/2/1 columnas)"
}

# =============================================================================
# VERIFICACION
# =============================================================================

Write-Host ""
Write-Host "PASO 3: Verificacion del archivo..."

if (-not $DryRun) {
    $newContent = Get-Content $cssFile -Raw -Encoding UTF8
    
    # Verificar elementos clave
    $checks = @{
        "Grid 5 columnas" = $newContent -match "grid-template-columns:\s*repeat\(5,\s*1fr\)"
        "Ancho incrementado" = $newContent -match "min-width:\s*420px"
        "Responsive tablet" = $newContent -match "repeat\(3,\s*1fr\)"
        "Responsive mobile" = $newContent -match "repeat\(2,\s*1fr\)"
        "Sin duplicados" = ($newContent -split "\.metrics-grid").Count -eq 2  # Solo debe aparecer 1 vez la definicion
    }
    
    foreach ($check in $checks.GetEnumerator()) {
        $status = if ($check.Value) { "OK" } else { "FALTA" }
        Write-Host "  $($check.Key): $status"
    }
}

# =============================================================================
# INSTRUCCIONES FINALES
# =============================================================================

Write-Host ""
Write-Host "=============================================================================="
Write-Host "CORRECCION CSS FINAL"
Write-Host "=============================================================================="

if (-not $DryRun) {
    Write-Host ""
    Write-Host "CSS COMPLETAMENTE LIMPIO Y OPTIMIZADO:"
    Write-Host "  - Configuraciones duplicadas eliminadas"
    Write-Host "  - Ancho de cajas incrementado (420-480px)"
    Write-Host "  - Grid responsive: 5/3/2/1 columnas segun pantalla"
    Write-Host "  - Padding y spacing optimizado"
    Write-Host ""
    Write-Host "SIGUIENTE PASO:"
    Write-Host "  Restart-Service VSM-Dashboard-BorgWarner"
    Write-Host ""
    Write-Host "RESULTADO ESPERADO:"
    Write-Host "  Las 5 metricas ahora deben caber perfectamente sin salirse"
    Write-Host "  Cajas mas anchas para acomodar mejor las metricas"
    Write-Host ""
    Write-Host "BACKUP: $backupPath"
} else {
    Write-Host ""
    Write-Host "DRY RUN COMPLETADO"
    Write-Host "Para aplicar limpieza CSS:"
    Write-Host "  .\limpiar-css.ps1 -ProjectPath `"$ProjectPath`""
}

Write-Host "=============================================================================="