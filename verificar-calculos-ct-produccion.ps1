# =============================================================================
# SCRIPT SIMPLE DE VERIFICACION - CT EQUIPO VS CT PROCESO
# Version limpia sin emojis para PowerShell
# =============================================================================

param(
    [string]$ProjectPath = "C:\Aplicaciones\mi-servidor-web"
)

Write-Host "=========================================="
Write-Host "VERIFICACION SIMPLE - CALCULOS CT"
Write-Host "=========================================="

Write-Host "Proyecto: $ProjectPath"
Write-Host "Fecha: $(Get-Date)"
Write-Host ""

# Verificar archivos principales
$realDataController = Join-Path $ProjectPath "src\presentation\controllers\public\RealDataController.js"
$dashboardRenderer = Join-Path $ProjectPath "public\dashboard\js\dashboard-renderer.js"

Write-Host "PASO 1: VERIFICANDO ARCHIVOS PRINCIPALES..."
Write-Host "-------------------------------------------"

if (Test-Path $realDataController) {
    Write-Host "OK - RealDataController.js encontrado"
} else {
    Write-Host "ERROR - RealDataController.js NO encontrado" -ForegroundColor Red
    exit 1
}

if (Test-Path $dashboardRenderer) {
    Write-Host "OK - dashboard-renderer.js encontrado"
} else {
    Write-Host "ERROR - dashboard-renderer.js NO encontrado" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "PASO 2: VERIFICANDO METODO CT PROCESO..."
Write-Host "----------------------------------------"

$controllerContent = Get-Content $realDataController -Raw -Encoding UTF8

$hasCalculateProcessCycleTime = $controllerContent -match "calculateProcessCycleTime"

if ($hasCalculateProcessCycleTime) {
    Write-Host "OK - Metodo calculateProcessCycleTime ENCONTRADO"
    
    # Verificar que tiene logica BCMP->BCMP
    if ($controllerContent -match "BCMP.*BCMP|startsWith.*BCMP") {
        Write-Host "OK - Logica BCMP->BCMP implementada"
    } else {
        Write-Host "WARNING - Logica BCMP->BCMP no clara" -ForegroundColor Yellow
    }
} else {
    Write-Host "ERROR - Metodo calculateProcessCycleTime NO ENCONTRADO" -ForegroundColor Red
    Write-Host ""
    Write-Host "SOLUCION:"
    Write-Host "  1. Ejecutar: .\implementar-ct-minimo.ps1 -ProjectPath '$ProjectPath'"
    Write-Host "  2. Reiniciar servidor"
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "PASO 3: VERIFICANDO DASHBOARD..."
Write-Host "--------------------------------"

$rendererContent = Get-Content $dashboardRenderer -Raw -Encoding UTF8

# Verificar etiquetas
$hasCTEquipo = $rendererContent -match "CT Equipo"
$hasCTProceso = $rendererContent -match "CT Proceso"

Write-Host "Etiqueta 'CT Equipo': $(if($hasCTEquipo) {'OK ENCONTRADA'} else {'ERROR FALTANTE'})"
Write-Host "Etiqueta 'CT Proceso': $(if($hasCTProceso) {'OK ENCONTRADA'} else {'ERROR FALTANTE'})"

if (!$hasCTEquipo) {
    Write-Host "WARNING - Dashboard aun puede decir 'Tiempo Real'" -ForegroundColor Yellow
}

if (!$hasCTProceso) {
    Write-Host "ERROR - Dashboard NO tiene campo CT Proceso" -ForegroundColor Red
    Write-Host "SOLUCION: Revisar implementacion de dashboard"
}

Write-Host ""
Write-Host "PASO 4: VERIFICANDO CSS GRID..."
Write-Host "-------------------------------"

$processCSS = Join-Path $ProjectPath "public\dashboard\css\process-cards.css"
if (Test-Path $processCSS) {
    $cssContent = Get-Content $processCSS -Raw -Encoding UTF8
    
    if ($cssContent -match "repeat\(5") {
        Write-Host "OK - CSS Grid configurado para 5 columnas"
    } else {
        Write-Host "WARNING - CSS Grid aun en 4 columnas" -ForegroundColor Yellow
        Write-Host "SOLUCION: Actualizar CSS para mostrar CT Proceso"
    }
} else {
    Write-Host "WARNING - process-cards.css no encontrado" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "PASO 5: VERIFICACION DE INTEGRACION..."
Write-Host "-------------------------------------"

# Verificar que el metodo se llama en el controlador
if ($controllerContent -match "\.calculateProcessCycleTime\(") {
    Write-Host "OK - Metodo calculateProcessCycleTime se INVOCA"
} else {
    Write-Host "WARNING - Metodo existe pero NO se invoca" -ForegroundColor Yellow
    Write-Host "PROBLEMA: El metodo no se esta usando en el flujo principal"
}

# Verificar que retorna processTime
if ($controllerContent -match "processTime") {
    Write-Host "OK - Variable processTime presente en el codigo"
} else {
    Write-Host "WARNING - No hay referencia a processTime" -ForegroundColor Yellow
    Write-Host "PROBLEMA: El valor calculado no se envia al frontend"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "DIAGNOSTICO FINAL"
Write-Host "=========================================="

Write-Host ""
Write-Host "ESTADO DEL METODO CT PROCESO:"
if ($hasCalculateProcessCycleTime) {
    if ($controllerContent -match "\.calculateProcessCycleTime\(" -and $controllerContent -match "processTime") {
        Write-Host "  STATUS: IMPLEMENTADO Y INTEGRADO" -ForegroundColor Green
    } elseif ($controllerContent -match "\.calculateProcessCycleTime\(") {
        Write-Host "  STATUS: IMPLEMENTADO PERO NO INTEGRADO" -ForegroundColor Yellow
    } else {
        Write-Host "  STATUS: IMPLEMENTADO PERO NO SE USA" -ForegroundColor Yellow
    }
} else {
    Write-Host "  STATUS: NO IMPLEMENTADO" -ForegroundColor Red
}

Write-Host ""
Write-Host "ESTADO DEL DASHBOARD:"
if ($hasCTEquipo -and $hasCTProceso) {
    Write-Host "  STATUS: LISTO PARA MOSTRAR AMBOS CAMPOS" -ForegroundColor Green
} elseif ($hasCTEquipo) {
    Write-Host "  STATUS: PARCIAL - FALTA CT PROCESO" -ForegroundColor Yellow
} else {
    Write-Host "  STATUS: NO ACTUALIZADO" -ForegroundColor Red
}

Write-Host ""
Write-Host "RESPUESTA A TU PREGUNTA:"
Write-Host "========================"

if (!$hasCalculateProcessCycleTime) {
    Write-Host "SI - AMBAS CAJAS MUESTRAN EL MISMO VALOR" -ForegroundColor Red
    Write-Host "RAZON: El metodo CT Proceso no existe aun"
    Write-Host "SOLUCION: Ejecutar implementar-ct-minimo.ps1"
} elseif (!$hasCTProceso) {
    Write-Host "PROBABLEMENTE SI - SOLO HAY UNA CAJA CT" -ForegroundColor Yellow
    Write-Host "RAZON: Dashboard no muestra CT Proceso"
    Write-Host "SOLUCION: Actualizar dashboard para mostrar ambos campos"
} elseif ($controllerContent -notmatch "\.calculateProcessCycleTime\(") {
    Write-Host "SI - AMBAS CAJAS USAN EL MISMO CALCULO" -ForegroundColor Yellow
    Write-Host "RAZON: Metodo existe pero no se invoca"
    Write-Host "SOLUCION: Integrar metodo en el flujo principal"
} else {
    Write-Host "POSIBLEMENTE NO - VERIFICAR DASHBOARD MANUALMENTE" -ForegroundColor Green
    Write-Host "RAZON: Todo parece estar implementado"
    Write-Host "ACCION: Revisar dashboard en http://localhost:3001"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "COMANDOS DE ACCION INMEDIATA"
Write-Host "=========================================="

Write-Host ""
Write-Host "# Verificar estado actual del dashboard:"
Write-Host "Start-Process 'http://localhost:3001'"
Write-Host ""

Write-Host "# Ver logs en tiempo real:"
Write-Host "Get-Content '$ProjectPath\logs\*.log' -Tail 20"
Write-Host ""

Write-Host "# Reiniciar servidor:"
Write-Host "Stop-Process -Name 'node' -Force -ErrorAction SilentlyContinue"
Write-Host "cd '$ProjectPath' && node server.js"
Write-Host ""

if (!$hasCalculateProcessCycleTime) {
    Write-Host "# CRITICO - Implementar metodo faltante:"
    Write-Host ".\implementar-ct-minimo.ps1 -ProjectPath '$ProjectPath'"
    Write-Host ""
}

Write-Host "VERIFICACION COMPLETADA - $(Get-Date -Format 'HH:mm:ss')"