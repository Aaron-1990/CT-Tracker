# Script Ultra-Simplificado para Separar Tiempo de Ciclo
param([switch]$TestMode = $false)

$PROJECT_ROOT = "C:\Aplicaciones\mi-servidor-web"

Write-Host "=== INICIANDO IMPLEMENTACION ===" -ForegroundColor Green
Write-Host "Proyecto: $PROJECT_ROOT"
Write-Host "Modo Test: $TestMode"

# Verificar prerequisitos
if (!(Test-Path "$PROJECT_ROOT\server.js")) {
    Write-Host "ERROR: No se encontro server.js en $PROJECT_ROOT" -ForegroundColor Red
    exit 1
}

Write-Host "Prerequisitos OK" -ForegroundColor Green

# Crear backup si no es modo test
if (!$TestMode) {
    $BACKUP_DIR = "$PROJECT_ROOT\backups\backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $BACKUP_DIR -Force | Out-Null
    Write-Host "Backup directory creado: $BACKUP_DIR" -ForegroundColor Yellow
}

# CAMBIO 1: RealDataController.js
$file1 = "$PROJECT_ROOT\src\presentation\controllers\public\RealDataController.js"
Write-Host "Procesando RealDataController..."

if (Test-Path $file1) {
    if ($TestMode) {
        Write-Host "MODO TEST: Simulando cambios en RealDataController.js" -ForegroundColor Yellow
    } else {
        try {
            $backupFile = "$BACKUP_DIR\RealDataController.js.backup"
            Copy-Item $file1 $backupFile -Force
            Write-Host "Backup creado: RealDataController.js" -ForegroundColor Green
            
            $content = Get-Content $file1 -Raw -Encoding UTF8
            $oldPattern = "const cycleTimes = [];"
            $newPattern = "const equipmentCycleTimes = []; // Tiempos BREQ/BCMP`r`nconst processCycleTimes = []; // Tiempos timestamps consecutivos"
            
            if ($content -match [regex]::Escape($oldPattern)) {
                $content = $content -replace [regex]::Escape($oldPattern), $newPattern
                Set-Content $file1 -Value $content -Encoding UTF8
                Write-Host "RealDataController actualizado" -ForegroundColor Green
            } else {
                Write-Host "Patron no encontrado en RealDataController" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "ERROR en RealDataController: $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "RealDataController.js no encontrado" -ForegroundColor Yellow
}

# CAMBIO 2: dashboard-renderer.js
$file2 = "$PROJECT_ROOT\public\dashboard\js\dashboard-renderer.js"
Write-Host "Procesando dashboard-renderer..."

if (Test-Path $file2) {
    if ($TestMode) {
        Write-Host "MODO TEST: Simulando cambios en dashboard-renderer.js" -ForegroundColor Yellow
    } else {
        try {
            $backupFile = "$BACKUP_DIR\dashboard-renderer.js.backup"
            Copy-Item $file2 $backupFile -Force
            Write-Host "Backup creado: dashboard-renderer.js" -ForegroundColor Green
            
            $content = Get-Content $file2 -Raw -Encoding UTF8
            $oldPattern = "Tiempo Real"
            $newPattern = "T.C. Proceso"
            
            if ($content -match $oldPattern) {
                $content = $content -replace $oldPattern, $newPattern
                Set-Content $file2 -Value $content -Encoding UTF8
                Write-Host "dashboard-renderer actualizado" -ForegroundColor Green
            } else {
                Write-Host "Patron no encontrado en dashboard-renderer" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "ERROR en dashboard-renderer: $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "dashboard-renderer.js no encontrado" -ForegroundColor Yellow
}

# RESULTADOS
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IMPLEMENTACION COMPLETADA" -ForegroundColor Green
Write-Host ""
Write-Host "PROXIMOS PASOS:" -ForegroundColor Green
Write-Host "1. Reiniciar servidor: node server.js"
Write-Host "2. Abrir dashboard: http://localhost:3001"
Write-Host "3. Verificar nueva etiqueta: T.C. Proceso"
Write-Host "========================================" -ForegroundColor Cyan
