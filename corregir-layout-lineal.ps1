# =============================================================================
# SCRIPT CORRECCION LAYOUT LINEAL VSM
# Eliminar propiedades CSS que mantengan las cajas centradas
# =============================================================================

param(
    [string]$ProjectPath = "C:\Aplicaciones\mi-servidor-web",
    [switch]$DryRun = $false
)

Write-Host "=============================================================================="
Write-Host "CORRECCION LAYOUT LINEAL VSM - ELIMINAR CENTRADO"
Write-Host "=============================================================================="

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $ProjectPath "backups\layout-fix-$timestamp"

Write-Host "Proyecto: $ProjectPath"
Write-Host "Modo: $(if($DryRun) {'DRY RUN'} else {'CORRECCION REAL'})"

Write-Host ""
Write-Host "PROBLEMA DETECTADO:"
Write-Host "Las cajas de proceso se mantienen centradas en lugar de layout lineal horizontal"
Write-Host ""
Write-Host "POSIBLES CAUSAS:"
Write-Host "1. .vsm-flow con justify-content: center o flex-wrap: wrap"
Write-Host "2. .process-card con propiedades de centrado"  
Write-Host "3. Conflictos entre CSS files diferentes"
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
    "public\dashboard\css\vsm-dashboard.css",
    "public\dashboard\css\dynamic-dashboard.css",
    "public\dashboard\css\process-cards.css"
)

Write-Host "PASO 1: Backup de archivos CSS..."

if (-not $DryRun) {
    New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
    
    foreach ($file in $filesToBackup) {
        $fullPath = Join-Path $ProjectPath $file
        if (Test-Path $fullPath) {
            $fileName = Split-Path $file -Leaf
            $destPath = Join-Path $backupPath $fileName
            Copy-Item $fullPath $destPath -Force
            Write-Host "  Backup: $fileName"
        }
    }
}

# =============================================================================
# ANALIZAR ARCHIVOS CSS
# =============================================================================

Write-Host ""
Write-Host "PASO 2: Analizando configuracion actual..."

$vsmDashboardCSS = Join-Path $ProjectPath "public\dashboard\css\vsm-dashboard.css"
$dynamicDashboardCSS = Join-Path $ProjectPath "public\dashboard\css\dynamic-dashboard.css"

if (Test-Path $vsmDashboardCSS) {
    $content = Get-Content $vsmDashboardCSS -Raw -Encoding UTF8
    
    if ($content -match "justify-content:\s*flex-start") {
        Write-Host "  vsm-dashboard.css: justify-content flex-start OK"
    } elseif ($content -match "justify-content:\s*center") {
        Write-Host "  vsm-dashboard.css: PROBLEMA - justify-content center encontrado"
    }
    
    if ($content -match "flex-wrap:\s*wrap") {
        Write-Host "  vsm-dashboard.css: PROBLEMA - flex-wrap wrap encontrado"
    }
}

if (Test-Path $dynamicDashboardCSS) {
    $content = Get-Content $dynamicDashboardCSS -Raw -Encoding UTF8
    
    if ($content -match "justify-content:\s*center") {
        Write-Host "  dynamic-dashboard.css: PROBLEMA - justify-content center encontrado"
    }
    
    if ($content -match "flex-wrap:\s*wrap") {
        Write-Host "  dynamic-dashboard.css: PROBLEMA - flex-wrap wrap encontrado"  
    }
}

# =============================================================================
# APLICAR CORRECCIONES
# =============================================================================

Write-Host ""
Write-Host "PASO 3: Aplicando correcciones CSS..."

if (-not $DryRun) {
    
    # 1. Corregir vsm-dashboard.css
    if (Test-Path $vsmDashboardCSS) {
        $content = Get-Content $vsmDashboardCSS -Raw -Encoding UTF8
        
        # Asegurar configuracion lineal correcta
        $linearFlowCSS = @"

/* =============================================================================
 * VSM LINEAR LAYOUT - CORRECCION $timestamp
 * Layout horizontal verdadero sin centrado
 * ============================================================================= */

.vsm-flow {
    display: flex;
    align-items: center;
    justify-content: flex-start !important;
    flex-wrap: nowrap !important;
    gap: 2rem;
    margin: 2rem 0;
    padding: 2rem 1rem;
    min-height: 400px;
    overflow-x: auto;
    overflow-y: hidden;
    scrollbar-width: thin;
    scrollbar-color: var(--primary-blue) #f1f1f1;
    
    /* Eliminar cualquier centrado */
    text-align: left;
    width: 100%;
    box-sizing: border-box;
}

/* Webkit scrollbar para mejor UX */
.vsm-flow::-webkit-scrollbar {
    height: 12px;
}

.vsm-flow::-webkit-scrollbar-track {
    background: #f1f1f1;
    border-radius: 6px;
}

.vsm-flow::-webkit-scrollbar-thumb {
    background: var(--primary-blue);
    border-radius: 6px;
}

/* Flechas de flujo */
.flow-arrow {
    font-size: 2.5rem;
    color: var(--primary-blue);
    font-weight: bold;
    min-width: 40px;
    text-align: center;
    animation: flowPulse 3s ease-in-out infinite;
    user-select: none;
    flex-shrink: 0;
}

@keyframes flowPulse {
    0%, 100% { 
        transform: scale(1); 
        opacity: 0.7; 
    }
    50% { 
        transform: scale(1.15); 
        opacity: 1;
    }
}

/* Controles VSM */
.vsm-controls {
    position: sticky;
    top: 0;
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(10px);
    padding: 1rem;
    margin-bottom: 1rem;
    border-radius: 10px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    z-index: 100;
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 1rem;
    flex-wrap: wrap;
}

.zoom-btn {
    padding: 0.5rem 1rem;
    background: var(--primary-blue);
    color: white;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    font-size: 0.9rem;
    transition: all 0.3s ease;
}

.zoom-btn:hover {
    background: var(--primary-blue-dark);
    transform: translateY(-2px);
}

/* Numeros de secuencia */
.process-sequence {
    position: absolute;
    top: -15px;
    left: 50%;
    transform: translateX(-50%);
    background: var(--primary-blue);
    color: white;
    width: 30px;
    height: 30px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    font-size: 0.9rem;
    box-shadow: 0 2px 5px rgba(0,0,0,0.2);
}

/* Responsive pero manteniendo layout lineal */
@media (max-width: 768px) {
    .vsm-flow {
        gap: 1rem;
        padding: 1rem 0.5rem;
        /* Mantener scroll horizontal en mobile */
        justify-content: flex-start !important;
        flex-wrap: nowrap !important;
    }
    
    .flow-arrow {
        font-size: 2rem;
        min-width: 30px;
    }
    
    .vsm-controls {
        padding: 0.8rem;
        flex-direction: column;
        gap: 0.5rem;
    }
}

"@

        # Remover cualquier CSS vsm-flow existente y agregar el nuevo
        $content = $content -replace '(?s)\/\* VSM LINEAR LAYOUT.*?\*\/.*?@media \(max-width: 768px\) \{[^}]*\}[^}]*\}[^}]*\}', ''
        $content += $linearFlowCSS
        
        [System.IO.File]::WriteAllText($vsmDashboardCSS, $content, [System.Text.Encoding]::UTF8)
        Write-Host "  vsm-dashboard.css: Layout lineal aplicado"
    }
    
    # 2. Corregir dynamic-dashboard.css
    if (Test-Path $dynamicDashboardCSS) {
        $content = Get-Content $dynamicDashboardCSS -Raw -Encoding UTF8
        
        # Remover cualquier configuracion que centre el .vsm-flow
        $content = $content -replace '\.vsm-flow\s*\{[^}]*justify-content:\s*center[^}]*\}', ''
        $content = $content -replace '\.vsm-flow\s*\{[^}]*flex-wrap:\s*wrap[^}]*\}', ''
        
        # Asegurar que no interfiera con el layout lineal
        $fixCSS = @"

/* =============================================================================
 * DYNAMIC DASHBOARD - NO INTERFERIR CON VSM LINEAR
 * ============================================================================= */

/* Asegurar que .vsm-flow mantenga su layout lineal */
.vsm-flow {
    /* NO sobrescribir las propiedades del layout lineal */
    /* Estas propiedades se manejan en vsm-dashboard.css */
}

/* Process cards - sin centrado forzado */
.process-card {
    /* Mantener flex-shrink: 0 para layout lineal */
    flex-shrink: 0;
}

"@
        $content += $fixCSS
        
        [System.IO.File]::WriteAllText($dynamicDashboardCSS, $content, [System.Text.Encoding]::UTF8)
        Write-Host "  dynamic-dashboard.css: Conflictos removidos"
    }
    
    # 3. Verificar process-cards.css
    $processCardsCSS = Join-Path $ProjectPath "public\dashboard\css\process-cards.css"
    if (Test-Path $processCardsCSS) {
        $content = Get-Content $processCardsCSS -Raw -Encoding UTF8
        
        # Asegurar que process-card sea compatible con flex layout
        if ($content -notmatch "flex-shrink:\s*0") {
            $content += @"

/* =============================================================================
 * PROCESS CARDS - COMPATIBLE CON LAYOUT LINEAL
 * ============================================================================= */

.process-card {
    /* Evitar que se encojan en el layout flex */
    flex-shrink: 0;
    /* Mantener ancho fijo para layout horizontal */
    width: auto;
    min-width: 420px;
    max-width: 480px;
}

"@
            [System.IO.File]::WriteAllText($processCardsCSS, $content, [System.Text.Encoding]::UTF8)
            Write-Host "  process-cards.css: Compatibilidad flex agregada"
        }
    }

} else {
    Write-Host "  DRY RUN: Se aplicarian correcciones CSS"
}

# =============================================================================
# VERIFICACION
# =============================================================================

Write-Host ""
Write-Host "PASO 4: Verificando configuracion final..."

if (-not $DryRun) {
    if (Test-Path $vsmDashboardCSS) {
        $content = Get-Content $vsmDashboardCSS -Raw -Encoding UTF8
        
        if ($content -match "justify-content:\s*flex-start.*!important") {
            Write-Host "  vsm-flow justify-content: flex-start !important - OK"
        }
        
        if ($content -match "flex-wrap:\s*nowrap.*!important") {
            Write-Host "  vsm-flow flex-wrap: nowrap !important - OK"
        }
        
        if ($content -match "overflow-x:\s*auto") {
            Write-Host "  vsm-flow overflow-x: auto - OK"
        }
    }
}

# =============================================================================
# INSTRUCCIONES FINALES
# =============================================================================

Write-Host ""
Write-Host "=============================================================================="
Write-Host "CORRECCION LAYOUT LINEAL COMPLETADA"
Write-Host "=============================================================================="

if (-not $DryRun) {
    Write-Host ""
    Write-Host "CAMBIOS APLICADOS:"
    Write-Host "1. .vsm-flow configurado para layout horizontal estricto"
    Write-Host "2. justify-content: flex-start !important"
    Write-Host "3. flex-wrap: nowrap !important"
    Write-Host "4. overflow-x: auto para scroll horizontal"
    Write-Host "5. Eliminados conflictos CSS de centrado"
    Write-Host ""
    Write-Host "SIGUIENTES PASOS:"
    Write-Host "1. Reiniciar servicio: Restart-Service VSM-Dashboard-BorgWarner"
    Write-Host "2. Verificar en navegador que las cajas se muestren en linea horizontal"
    Write-Host "3. Probar scroll horizontal con varias cajas de proceso"
    Write-Host ""
    Write-Host "BACKUP CREADO EN: $backupPath"
} else {
    Write-Host ""
    Write-Host "PARA APLICAR CAMBIOS:"
    Write-Host "Ejecutar: .\corregir-layout-lineal.ps1 -ProjectPath 'C:\Aplicaciones\mi-servidor-web'"
}

Write-Host ""