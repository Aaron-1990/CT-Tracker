# =============================================================================
# SCRIPT CORREGIDO - AGREGAR METODO calculateProcessCycleTime
# Manejo correcto del codigo JavaScript en PowerShell
# =============================================================================

param(
    [string]$ProjectPath = "C:\Aplicaciones\mi-servidor-web",
    [switch]$DryRun = $false
)

Write-Host "=============================================================================="
Write-Host "AGREGAR METODO calculateProcessCycleTime - VERSION CORREGIDA"
Write-Host "=============================================================================="

Write-Host "Proyecto: $ProjectPath"
Write-Host "Modo: $(if($DryRun) {'DRY RUN'} else {'APLICAR CAMBIOS'})"

$controllerFile = Join-Path $ProjectPath "src\presentation\controllers\public\RealDataController.js"

# =============================================================================
# PASO 1: VERIFICAR ARCHIVO EXISTS
# =============================================================================

Write-Host ""
Write-Host "PASO 1: Verificando archivo..."

if (!(Test-Path $controllerFile)) {
    Write-Host "ERROR: RealDataController.js no encontrado" -ForegroundColor Red
    exit 1
}

# =============================================================================
# PASO 2: VERIFICAR QUE NO EXISTE EL METODO
# =============================================================================

Write-Host ""
Write-Host "PASO 2: Verificando que el metodo no existe..."

$content = Get-Content $controllerFile -Raw -Encoding UTF8

if ($content -match "calculateProcessCycleTime") {
    Write-Host "ADVERTENCIA: El metodo calculateProcessCycleTime YA EXISTE" -ForegroundColor Yellow
    Write-Host "No se realizaran cambios."
    exit 0
}

Write-Host "OK: El metodo no existe, se puede agregar"

# =============================================================================
# PASO 3: CREAR EL METODO COMO ARCHIVO TEMPORAL
# =============================================================================

Write-Host ""
Write-Host "PASO 3: Preparando metodo calculateProcessCycleTime..."

# Crear archivo temporal con el metodo
$tempMethodFile = Join-Path $env:TEMP "calculateProcessCycleTime.js"

$methodContent = @'

    /**
     * NUEVO: Calcular CT Proceso (BCMP->BCMP consecutivo)
     * Mide el rate real de produccion entre piezas completadas
     * NO modifica el calculo existente de CT Equipo (analyzeEquipmentRecords)
     */
    calculateProcessCycleTime(allRecords, equipmentId) {
        try {
            // Validar entrada
            if (!allRecords || !Array.isArray(allRecords) || allRecords.length < 2) {
                return null;
            }

            // Filtrar solo registros BCMP (piezas completadas)
            const bcmpRecords = allRecords
                .filter(record => {
                    if (!record || !record.status) return false;
                    // Incluir BCMP OK, BCMP NG, y variaciones
                    return record.status.startsWith('BCMP') || 
                           record.status.includes('OK') || 
                           record.status.includes('FAIL');
                })
                .sort((a, b) => {
                    // Ordenar por timestamp descendente (mas reciente primero)
                    const timeA = new Date(a.timestamp || a.scannedAt);
                    const timeB = new Date(b.timestamp || b.scannedAt);
                    return timeB.getTime() - timeA.getTime();
                });

            if (bcmpRecords.length < 2) {
                // No hay suficientes registros BCMP para calcular rate
                return null;
            }

            const processCycleTimes = [];
            
            // Calcular tiempos entre registros BCMP consecutivos
            for (let i = 1; i < Math.min(bcmpRecords.length, 15); i++) {
                const currentRecord = bcmpRecords[i - 1];  // Mas reciente
                const previousRecord = bcmpRecords[i];     // Anterior
                
                const currentTime = new Date(currentRecord.timestamp || currentRecord.scannedAt);
                const previousTime = new Date(previousRecord.timestamp || previousRecord.scannedAt);
                
                if (!isNaN(currentTime.getTime()) && !isNaN(previousTime.getTime())) {
                    const cycleTimeMs = currentTime.getTime() - previousTime.getTime();
                    const cycleTimeSeconds = cycleTimeMs / 1000;
                    
                    // Filtro de tiempos razonables para rate de produccion
                    // 3 segundos minimo, 5 minutos maximo
                    if (cycleTimeSeconds >= 3 && cycleTimeSeconds <= 300) {
                        processCycleTimes.push(cycleTimeSeconds);
                    }
                }
            }
            
            if (processCycleTimes.length === 0) {
                return null;
            }
            
            // Promediar ultimos 10 ciclos para estabilidad
            const recentCycles = processCycleTimes.slice(0, 10);
            const average = recentCycles.reduce((sum, ct) => sum + ct, 0) / recentCycles.length;
            
            return Math.round(average * 10) / 10;
            
        } catch (error) {
            // Usar logger si esta disponible, sino console
            if (typeof logger !== 'undefined') {
                logger.warn(`Error calculando CT Proceso para ${equipmentId}:`, error.message);
            } else {
                console.warn(`Error calculando CT Proceso para ${equipmentId}:`, error.message);
            }
            return null;
        }
    }
'@

$methodContent | Out-File -FilePath $tempMethodFile -Encoding UTF8
Write-Host "Metodo preparado en archivo temporal"

# =============================================================================
# PASO 4: ENCONTRAR LUGAR PARA INSERTAR
# =============================================================================

Write-Host ""
Write-Host "PASO 4: Buscando lugar para insertar..."

# Buscar el ultimo } del archivo
if ($content -match "(\s+)(\})\s*$") {
    Write-Host "OK: Encontrado lugar para insertar (antes del ultimo })"
} else {
    Write-Host "ERROR: No se encontro el patron de cierre del archivo" -ForegroundColor Red
    exit 1
}

# =============================================================================
# PASO 5: APLICAR CAMBIOS
# =============================================================================

Write-Host ""
Write-Host "PASO 5: $(if($DryRun) {'SIMULANDO'} else {'APLICANDO'}) cambios..."

if ($DryRun) {
    Write-Host "DRY RUN - No se modificara el archivo"
    Write-Host "Se agregaria el metodo calculateProcessCycleTime"
} else {
    # Crear backup
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $ProjectPath "backups"
    if (!(Test-Path $backupPath)) {
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    }
    $backupFile = Join-Path $backupPath "RealDataController-$timestamp.js"
    Copy-Item $controllerFile $backupFile -Force
    Write-Host "BACKUP creado: $backupFile"
    
    try {
        # Leer el metodo desde el archivo temporal
        $newMethod = Get-Content $tempMethodFile -Raw -Encoding UTF8
        
        # Aplicar el cambio usando regex simple
        $modifiedContent = $content -replace "(\s+)(\})\s*$", "`$1$newMethod`$1`$2"
        
        # Guardar archivo modificado
        $modifiedContent | Out-File -FilePath $controllerFile -Encoding UTF8
        
        Write-Host "OK: Metodo calculateProcessCycleTime agregado exitosamente" -ForegroundColor Green
        
        # Verificar que se aplico correctamente
        $verification = Get-Content $controllerFile -Raw -Encoding UTF8
        if ($verification -match "calculateProcessCycleTime") {
            Write-Host "VERIFICACION: Metodo encontrado en el archivo" -ForegroundColor Green
        } else {
            Write-Host "ERROR: Metodo NO se encontro despues de la modificacion" -ForegroundColor Red
            # Restaurar backup
            Copy-Item $backupFile $controllerFile -Force
            Write-Host "Archivo restaurado desde backup"
            exit 1
        }
        
    } catch {
        Write-Host "ERROR aplicando cambios: $($_.Exception.Message)" -ForegroundColor Red
        
        # Restaurar desde backup si fallo
        if (Test-Path $backupFile) {
            Copy-Item $backupFile $controllerFile -Force
            Write-Host "Archivo restaurado desde backup"
        }
        exit 1
    } finally {
        # Limpiar archivo temporal
        if (Test-Path $tempMethodFile) {
            Remove-Item $tempMethodFile -Force
        }
    }
}

# =============================================================================
# PASO 6: INSTRUCCIONES POST-IMPLEMENTACION
# =============================================================================

Write-Host ""
Write-Host "=============================================================================="
Write-Host "$(if($DryRun) {'SIMULACION COMPLETADA'} else {'IMPLEMENTACION COMPLETADA'})"
Write-Host "=============================================================================="

if (!$DryRun) {
    Write-Host ""
    Write-Host "CAMBIO APLICADO:"
    Write-Host "  + Metodo calculateProcessCycleTime agregado a RealDataController.js"
    Write-Host "  + Calcula rate real de produccion (BCMP->BCMP)"
    Write-Host "  + NO modifica calculos existentes"
    Write-Host ""
    Write-Host "IMPORTANTE - SIGUIENTE PASO:"
    Write-Host "El metodo existe pero necesita ser INTEGRADO al flujo principal."
    Write-Host ""
    Write-Host "EJECUTAR SIGUIENTE SCRIPT:"
    Write-Host "  .\integrar-processtime-minimo.ps1 -ProjectPath '$ProjectPath'"
    Write-Host ""
    Write-Host "VERIFICACION:"
    Write-Host "  Select-String -Path '$controllerFile' -Pattern 'calculateProcessCycleTime'"
    Write-Host ""
    Write-Host "BACKUP disponible:"
    Write-Host "  $backupFile"
}

Write-Host ""
Write-Host "=============================================================================="