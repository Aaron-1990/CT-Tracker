# =============================================================================
# SCRIPT MINIMO - SOLO INTEGRATION DE processTime
# La caja CT Proceso ya existe, solo falta conectar el dato
# =============================================================================

param(
    [string]$ProjectPath = "C:\Aplicaciones\mi-servidor-web",
    [switch]$DryRun = $false
)

Write-Host "=============================================================================="
Write-Host "INTEGRACION MINIMA - CONECTAR processTime A LA CAJA EXISTENTE"
Write-Host "=============================================================================="

Write-Host "PROBLEMA: La caja CT Proceso ya existe pero usa metrics.realTime como fallback"
Write-Host "SOLUCION: Generar metrics.processTime para que la caja muestre valor diferente"
Write-Host ""

$controllerFile = Join-Path $ProjectPath "src\presentation\controllers\public\RealDataController.js"

if (!(Test-Path $controllerFile)) {
    Write-Host "ERROR: RealDataController.js no encontrado" -ForegroundColor Red
    exit 1
}

# =============================================================================
# PASO 1: VERIFICAR ESTADO ACTUAL
# =============================================================================

Write-Host "PASO 1: Verificando estado actual..."

$content = Get-Content $controllerFile -Raw -Encoding UTF8

$hasCalculateProcessCycleTime = $content -match "calculateProcessCycleTime"
$hasProcessTimeReturn = $content -match "processTime:"

Write-Host "  calculateProcessCycleTime: $(if($hasCalculateProcessCycleTime) {'EXISTE'} else {'FALTA'})"
Write-Host "  processTime en return: $(if($hasProcessTimeReturn) {'EXISTE'} else {'FALTA'})"

if (!$hasCalculateProcessCycleTime) {
    Write-Host ""
    Write-Host "ERROR: Primero debe agregar el metodo calculateProcessCycleTime" -ForegroundColor Red
    Write-Host "Ejecute primero: .\agregar-metodo-ct-proceso.ps1"
    exit 1
}

if ($hasProcessTimeReturn) {
    Write-Host ""
    Write-Host "OK: processTime ya esta integrado en el return" -ForegroundColor Green
    Write-Host "La integracion ya esta completa."
    exit 0
}

# =============================================================================
# PASO 2: ENCONTRAR DONDE AGREGAR LA INVOCACION
# =============================================================================

Write-Host ""
Write-Host "PASO 2: Buscando donde generar processTime..."

# Buscar el patron donde se retornan las metricas
$metricsReturnPattern = "return\s*\{\s*realTime:[\s\S]*?\};"

if ($content -match $metricsReturnPattern) {
    Write-Host "  ENCONTRADO: Patron de return de metricas"
} else {
    Write-Host "  ERROR: No se encontro patron de return de metricas" -ForegroundColor Red
    Write-Host "  Sera necesario integracion manual"
}

# =============================================================================
# PASO 3: INTEGRATION MINIMA - SOLO AGREGAR processTime
# =============================================================================

Write-Host ""
Write-Host "PASO 3: $(if($DryRun) {'SIMULANDO'} else {'APLICANDO'}) integracion minima..."

if ($DryRun) {
    Write-Host "DRY RUN - Cambios que se aplicarian:"
    Write-Host "  1. Agregar invocacion: const processTime = this.calculateProcessCycleTime(...)"
    Write-Host "  2. Agregar al return: processTime: processTime"
    Write-Host "  3. La caja CT Proceso usara metrics.processTime en lugar de metrics.realTime"
} else {
    # Crear backup
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $ProjectPath "backups"
    if (!(Test-Path $backupPath)) {
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    }
    $backupFile = Join-Path $backupPath "RealDataController-integration-$timestamp.js"
    Copy-Item $controllerFile $backupFile -Force
    Write-Host "  BACKUP: $backupFile"
    
    try {
        # CAMBIO 1: Buscar donde se calcula realTime y agregar processTime
        $realTimePattern = "(const realTime = recentCycles\.reduce[\s\S]*?recentCycles\.length;)"
        $processTimeAddition = "`$1`n`n        // NUEVO: Calcular CT Proceso (BCMP->BCMP rate real)`n        const processTime = this.calculateProcessCycleTime(allCycleTimes, 'PROCESS_AGGREGATE');"
        
        if ($content -match $realTimePattern) {
            $content = $content -replace $realTimePattern, $processTimeAddition
            Write-Host "    Invocacion calculateProcessCycleTime agregada"
        } else {
            Write-Host "    ADVERTENCIA: Patron realTime no encontrado, usando metodo alternativo"
            
            # Plan B: Agregar antes del return
            $beforeReturnPattern = "(\s+)(return\s*\{)"
            $beforeReturnAddition = "`$1// NUEVO: Calcular CT Proceso (BCMP->BCMP rate real)`n`$1const processTime = this.calculateProcessCycleTime(allCycleTimes, 'PROCESS_AGGREGATE');`n`n`$1`$2"
            
            if ($content -match $beforeReturnPattern) {
                $content = $content -replace $beforeReturnPattern, $beforeReturnAddition
                Write-Host "    Invocacion agregada antes del return (Plan B)"
            }
        }
        
        # CAMBIO 2: Agregar processTime al objeto de return
        $returnPattern = "(return\s*\{\s*realTime:\s*[^,}]+),"
        $returnReplacement = "`$1,`n            processTime: processTime,"
        
        if ($content -match $returnPattern) {
            $content = $content -replace $returnPattern, $returnReplacement
            Write-Host "    processTime agregado al return"
        } else {
            Write-Host "    ERROR: No se pudo agregar processTime al return" -ForegroundColor Red
        }
        
        # Guardar cambios
        Set-Content $controllerFile $content -Encoding UTF8
        Write-Host "  OK: Cambios aplicados exitosamente" -ForegroundColor Green
        
        # Verificacion
        $verification = Get-Content $controllerFile -Raw -Encoding UTF8
        if ($verification -match "processTime:" -and $verification -match "calculateProcessCycleTime\(allCycleTimes") {
            Write-Host "  VERIFICACION: processTime integrado correctamente" -ForegroundColor Green
        } else {
            Write-Host "  WARNING: Verificacion no paso completamente" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        
        # Restaurar backup
        if (Test-Path $backupFile) {
            Copy-Item $backupFile $controllerFile -Force
            Write-Host "  Archivo restaurado desde backup"
        }
    }
}

# =============================================================================
# PASO 4: VERIFICAR FRONTEND YA EXISTE
# =============================================================================

Write-Host ""
Write-Host "PASO 4: Verificando frontend (deberia estar listo)..."

$rendererFile = Join-Path $ProjectPath "public\dashboard\js\dashboard-renderer.js"
if (Test-Path $rendererFile) {
    $rendererContent = Get-Content $rendererFile -Raw -Encoding UTF8
    
    if ($rendererContent -match "metrics\.processTime.*metrics\.realTime") {
        Write-Host "  OK: dashboard-renderer.js tiene fallback processTime || realTime" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: dashboard-renderer.js NO tiene referencia a processTime" -ForegroundColor Yellow
        Write-Host "  SOLUCION: Ejecutar corregir-dashboard.ps1"
    }
}

# =============================================================================
# RESULTADO ESPERADO
# =============================================================================

Write-Host ""
Write-Host "=============================================================================="
Write-Host "$(if($DryRun) {'SIMULACION'} else {'INTEGRACION'}) COMPLETADA"
Write-Host "=============================================================================="

if (!$DryRun) {
    Write-Host ""
    Write-Host "FLUJO DESPUES DE LA INTEGRACION:"
    Write-Host "  1. Backend calcula: metrics.realTime (BREQ->BCMP, CT Equipo)"
    Write-Host "  2. Backend calcula: metrics.processTime (BCMP->BCMP, CT Proceso)"  
    Write-Host "  3. Dashboard muestra: CT Equipo = metrics.realTime"
    Write-Host "  4. Dashboard muestra: CT Proceso = metrics.processTime"
    Write-Host ""
    Write-Host "RESULTADO ESPERADO:"
    Write-Host "  - Continuity Test: CT Equipo (~25s) != CT Proceso (~22s)"
    Write-Host "  - Wave Solder: CT Equipo (~45s) = CT Proceso (~45s)"
    Write-Host ""
    Write-Host "SIGUIENTES PASOS:"
    Write-Host "1. Reiniciar servidor: node server.js"
    Write-Host "2. Abrir dashboard: http://localhost:3001"
    Write-Host "3. Verificar Continuity Test muestra valores diferentes"
    Write-Host ""
    Write-Host "SI LAS CAJAS AUN SON IGUALES:"
    Write-Host "  - Revisar logs del servidor para errores"
    Write-Host "  - Ejecutar: Select-String -Path '$controllerFile' -Pattern 'processTime'"
    Write-Host ""
    Write-Host "BACKUP DISPONIBLE:"
    Write-Host "  $backupFile"
}

Write-Host ""
Write-Host "=============================================================================="