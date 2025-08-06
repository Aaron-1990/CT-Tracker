# =============================================================================
# SCRIPT VSM LINEAL - VERSION LIMPIA SIN SIMBOLOS
# Layout horizontal con scroll para Value Stream Map
# =============================================================================

param(
    [string]$ProjectPath = "C:\Aplicaciones\mi-servidor-web",
    [switch]$DryRun = $false
)

Write-Host "=============================================================================="
Write-Host "VSM LAYOUT LINEAL - FLOW HORIZONTAL CON SCROLL"
Write-Host "=============================================================================="

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $ProjectPath "backups\vsm-linear-$timestamp"

Write-Host "Proyecto: $ProjectPath"
if ($DryRun) {
    Write-Host "Modo: DRY RUN"
} else {
    Write-Host "Modo: IMPLEMENTACION REAL"
}

Write-Host ""
Write-Host "OBJETIVO:"
Write-Host "Convertir dashboard a Value Stream Map lineal horizontal"
Write-Host "- Procesos en secuencia horizontal"
Write-Host "- Scroll horizontal si no caben"
Write-Host "- Controles de zoom"
Write-Host ""

# Verificar proyecto
if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Proyecto no encontrado"
    exit 1
}

# =============================================================================
# BACKUP
# =============================================================================

$filesToBackup = @(
    "public\dashboard\css\vsm-dashboard.css",
    "public\dashboard\value-stream-map.html"
)

Write-Host "PASO 1: Backup de archivos..."

if (-not $DryRun) {
    New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
    foreach ($file in $filesToBackup) {
        $sourcePath = Join-Path $ProjectPath $file
        if (Test-Path $sourcePath) {
            $destName = Split-Path $file -Leaf
            $destPath = Join-Path $backupPath $destName
            Copy-Item $sourcePath $destPath -Force
            Write-Host "  Backup: $destName"
        }
    }
    Write-Host "Backup completado"
}

# =============================================================================
# CREAR CSS PARA VSM LINEAL
# =============================================================================

Write-Host ""
Write-Host "PASO 2: Aplicando CSS VSM lineal..."

if (-not $DryRun) {
    $vsmDashboardFile = Join-Path $ProjectPath "public\dashboard\css\vsm-dashboard.css"
    
    if (Test-Path $vsmDashboardFile) {
        $existingCSS = Get-Content $vsmDashboardFile -Raw -Encoding UTF8
        
        # CSS para VSM lineal limpio
        $vsmLinearCSS = @"

/* VSM LINEAR LAYOUT - $timestamp */
.vsm-flow {
    display: flex;
    align-items: center;
    justify-content: flex-start;
    gap: 1.5rem;
    margin: 2rem 0;
    padding: 2rem 1rem;
    min-height: 400px;
    overflow-x: auto;
    overflow-y: hidden;
    scrollbar-width: thin;
    scrollbar-color: var(--primary-blue) #f1f1f1;
}

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
    background: var(--secondary-blue);
    transform: translateY(-2px);
}

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

@media (max-width: 768px) {
    .vsm-flow {
        gap: 1rem;
        padding: 1rem 0.5rem;
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
        
        # Remover configuraciones VSM antiguas
        $cleanCSS = $existingCSS -replace "\/\* VSM Flow \*\/.*?(?=\/\*|\z)", ""
        $cleanCSS = $cleanCSS -replace "\.vsm-flow\s*\{[^}]*\}", ""
        $cleanCSS = $cleanCSS -replace "\.flow-arrow\s*\{[^}]*\}", ""
        
        # Agregar nueva configuracion
        $newCSS = $cleanCSS + $vsmLinearCSS
        
        [System.IO.File]::WriteAllText($vsmDashboardFile, $newCSS, [System.Text.Encoding]::UTF8)
        Write-Host "  CSS VSM lineal aplicado"
    }
}

# =============================================================================
# CREAR JAVASCRIPT
# =============================================================================

Write-Host ""
Write-Host "PASO 3: Creando funcionalidad JavaScript..."

if (-not $DryRun) {
    $jsContent = @"
// VSM Linear Controller - Clean Version
class VSMLinearController {
    constructor() {
        this.currentZoom = 1;
        this.init();
    }
    
    init() {
        this.addControls();
        this.addSequenceNumbers();
    }
    
    addControls() {
        var vsmFlow = document.querySelector('.vsm-flow');
        if (!vsmFlow) return;
        
        var controls = document.createElement('div');
        controls.className = 'vsm-controls';
        controls.innerHTML = 
            '<div style="color: #666; font-size: 0.9rem;">Value Stream Map - Linea GPEC5</div>' +
            '<div style="color: #999; font-size: 0.8rem;">Deslizar para navegar</div>' +
            '<button class="zoom-btn" onclick="vsmController.zoomOut()">- Zoom Out</button>' +
            '<button class="zoom-btn" onclick="vsmController.zoomIn()">+ Zoom In</button>' +
            '<button class="zoom-btn" onclick="vsmController.resetZoom()">Reset</button>';
        
        vsmFlow.parentNode.insertBefore(controls, vsmFlow);
    }
    
    addSequenceNumbers() {
        var processCards = document.querySelectorAll('.process-card');
        for (var i = 0; i < processCards.length; i++) {
            var card = processCards[i];
            var sequence = document.createElement('div');
            sequence.className = 'process-sequence';
            sequence.textContent = i + 1;
            card.style.position = 'relative';
            card.appendChild(sequence);
        }
    }
    
    zoomOut() {
        if (this.currentZoom > 0.5) {
            this.currentZoom -= 0.1;
            this.applyZoom();
        }
    }
    
    zoomIn() {
        if (this.currentZoom < 1) {
            this.currentZoom += 0.1;
            this.applyZoom();
        }
    }
    
    resetZoom() {
        this.currentZoom = 1;
        this.applyZoom();
    }
    
    applyZoom() {
        var container = document.querySelector('.vsm-flow');
        if (container) {
            container.style.transform = 'scale(' + this.currentZoom + ')';
            container.style.transformOrigin = 'left top';
            console.log('Zoom: ' + Math.round(this.currentZoom * 100) + '%');
        }
    }
}

// Inicializar
document.addEventListener('DOMContentLoaded', function() {
    if (document.querySelector('.vsm-flow')) {
        window.vsmController = new VSMLinearController();
        console.log('VSM Controller inicializado');
    }
});
"@
    
    $jsFile = Join-Path $ProjectPath "public\dashboard\js\vsm-linear-controller.js"
    [System.IO.File]::WriteAllText($jsFile, $jsContent, [System.Text.Encoding]::UTF8)
    Write-Host "  JavaScript creado"
    
    # Agregar script al HTML
    $htmlFile = Join-Path $ProjectPath "public\dashboard\value-stream-map.html"
    if (Test-Path $htmlFile) {
        $htmlContent = Get-Content $htmlFile -Raw -Encoding UTF8
        
        if ($htmlContent -notmatch "vsm-linear-controller\.js") {
            $scriptTag = '    <script src="/dashboard/js/vsm-linear-controller.js"></script>'
            $htmlContent = $htmlContent -replace "(<\/body>)", "$scriptTag`n`$1"
            
            [System.IO.File]::WriteAllText($htmlFile, $htmlContent, [System.Text.Encoding]::UTF8)
            Write-Host "  Script agregado al HTML"
        }
    }
} else {
    Write-Host "  DRY RUN: Se crearia JavaScript y se actualizaria HTML"
}

# =============================================================================
# INSTRUCCIONES FINALES
# =============================================================================

Write-Host ""
Write-Host "=============================================================================="
Write-Host "VSM LINEAL COMPLETADO"
Write-Host "=============================================================================="

if (-not $DryRun) {
    Write-Host ""
    Write-Host "CAMBIOS APLICADOS:"
    Write-Host "  - Layout horizontal con scroll"
    Write-Host "  - Flechas animadas entre procesos"
    Write-Host "  - Controles de zoom funcionales"
    Write-Host "  - Numeracion de procesos secuencial"
    Write-Host ""
    Write-Host "FUNCIONALIDADES:"
    Write-Host "  - VSM real horizontal"
    Write-Host "  - Scroll horizontal suave"
    Write-Host "  - Zoom: 50% - 100%"
    Write-Host "  - Responsive mobile"
    Write-Host ""
    Write-Host "SIGUIENTE PASO:"
    Write-Host "  Restart-Service VSM-Dashboard-BorgWarner"
    Write-Host ""
    Write-Host "BACKUP: $backupPath"
} else {
    Write-Host ""
    Write-Host "DRY RUN COMPLETADO"
    Write-Host "Para aplicar VSM lineal:"
    Write-Host "  .\vsm-lineal.ps1"
}

Write-Host "=============================================================================="