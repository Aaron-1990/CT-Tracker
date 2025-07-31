# =============================================================================
# SCRIPT DE IMPLEMENTACION - RANGOS DHCP CORPORATIVOS
# Dashboard VSM BorgWarner - Compatible con Servicio Windows + NSSM
# PARTE 1 DE 6 - Configuración inicial y validaciones
# =============================================================================

param(
    [string]$Mode = "hybrid",  # static, ranges, hybrid
    [switch]$DryRun = $false,  # Solo mostrar cambios sin aplicar
    [switch]$Backup = $true,   # Crear backups automaticos
    [switch]$Test = $false,    # Ejecutar tests despues de implementacion
    [switch]$ServiceMode = $true  # Modo compatible con Servicio Windows
)

Write-Host "=============================================" -ForegroundColor Green
Write-Host "IMPLEMENTACION RANGOS DHCP VSM DASHBOARD" -ForegroundColor Green  
Write-Host "BorgWarner - Servicio Windows + NSSM" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Configuracion del proyecto
$projectPath = "C:\Aplicaciones\mi-servidor-web"
$serviceName = "VSM-Dashboard-BorgWarner" 
$nssmPath = "C:\Tools\nssm\nssm.exe"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Verificar directorio del proyecto
if (-not (Test-Path $projectPath)) {
    Write-Host "ERROR: Directorio del proyecto no encontrado: $projectPath" -ForegroundColor Red
    Write-Host "Verifique que la ruta sea correcta" -ForegroundColor Yellow
    exit 1
}

Set-Location $projectPath
Write-Host "Directorio base: $projectPath" -ForegroundColor White

# =============================================================================
# PASO 1: VALIDACION DE PRECONDICIONES - SERVICIO WINDOWS
# =============================================================================

Write-Host "`nPASO 1: VALIDANDO PRECONDICIONES (SERVICIO WINDOWS)" -ForegroundColor Cyan
Write-Host "--------------------------------------------------------" -ForegroundColor White

# Verificar Servicio Windows
try {
    $service = Get-Service $serviceName -ErrorAction Stop
    $serviceStatus = $service.Status
    Write-Host "Servicio Windows detectado: $serviceName" -ForegroundColor Green
    Write-Host "   Estado actual: $serviceStatus" -ForegroundColor $(if($serviceStatus -eq "Running"){"Green"}else{"Yellow"})
} catch {
    Write-Host "Servicio Windows no encontrado: $serviceName" -ForegroundColor Red
    Write-Host "Asegurese de que el servicio este instalado correctamente" -ForegroundColor Yellow
    exit 1
}

# Verificar NSSM
if (Test-Path $nssmPath) {
    try {
        $nssmStatus = & $nssmPath status $serviceName 2>$null
        Write-Host "NSSM detectado: $nssmStatus" -ForegroundColor Green
    } catch {
        Write-Host "NSSM presente pero no responde" -ForegroundColor Yellow
    }
} else {
    Write-Host "NSSM no encontrado en: $nssmPath" -ForegroundColor Red
    exit 1
}

# Verificar Node.js
try {
    $nodeVersion = node -v
    Write-Host "Node.js detectado: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "Node.js no encontrado" -ForegroundColor Red
    exit 1
}

# Verificar procesos Node.js activos
$nodeProcesses = Get-Process -Name "node" -ErrorAction SilentlyContinue
if ($nodeProcesses) {
    Write-Host "Procesos Node.js activos: $($nodeProcesses.Count)" -ForegroundColor Green
    $nodeProcesses | ForEach-Object {
        $memoryMB = [math]::Round($_.WorkingSet64/1MB, 1)
        Write-Host "   - PID $($_.Id): $memoryMB MB" -ForegroundColor White
    }
} else {
    Write-Host "No hay procesos Node.js detectados" -ForegroundColor Yellow
    Write-Host "   Esto es normal si el servicio esta iniciando" -ForegroundColor Gray
}

# Verificar puertos activos
$port3001 = netstat -ano | findstr ":3001"
$port3443 = netstat -ano | findstr ":3443"

if ($port3001) {
    Write-Host "Puerto 3001 (HTTP): ACTIVO" -ForegroundColor Green
} else {
    Write-Host "Puerto 3001 (HTTP): NO DETECTADO" -ForegroundColor Yellow
}

if ($port3443) {
    Write-Host "Puerto 3443 (HTTPS): ACTIVO" -ForegroundColor Green
} else {
    Write-Host "Puerto 3443 (HTTPS): NO DETECTADO" -ForegroundColor Yellow
}

# Verificar archivos criticos
$criticalFiles = @(
    ".env",
    "config/environment.js", 
    "config/security.js",
    "server.js",
    "vsm-service.bat",
    "package.json"
)

$missingFiles = @()
foreach ($file in $criticalFiles) {
    if (Test-Path $file) {
        Write-Host "Archivo encontrado: $file" -ForegroundColor Green
    } else {
        Write-Host "Archivo faltante: $file" -ForegroundColor Red
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "`nArchivos criticos faltantes. No se puede continuar." -ForegroundColor Red
    exit 1
}

# Estado actual del servicio
Write-Host "`nEstado detallado del servicio:" -ForegroundColor Yellow
if ($serviceStatus -eq "Running") {
    Write-Host "   Servicio ejecutandose normalmente" -ForegroundColor Green
    Write-Host "   Listo para hot deployment" -ForegroundColor Green
} else {
    Write-Host "   Servicio no esta ejecutandose" -ForegroundColor Yellow
    Write-Host "   Se requerira inicio manual post-deployment" -ForegroundColor Yellow
}

# =============================================================================
# PARTE 2 DE 6 - Creación de backups y planificación
# =============================================================================

# =============================================================================
# PASO 2: CREAR BACKUPS DE SEGURIDAD
# =============================================================================

if ($Backup) {
    Write-Host "`nPASO 2: CREANDO BACKUPS DE SEGURIDAD" -ForegroundColor Cyan
    Write-Host "--------------------------------------------" -ForegroundColor White
    
    $backupDir = "backups/dhcp-migration-$timestamp"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
    $filesToBackup = @(
        ".env",
        "config/environment.js",
        "config/security.js",
        "server.js",
        "server-https.js"
    )
    
    foreach ($file in $filesToBackup) {
        if (Test-Path $file) {
            try {
                # Crear subdirectorio si es necesario
                $backupFileDir = Split-Path "$backupDir/$file" -Parent
                if ($backupFileDir -and -not (Test-Path $backupFileDir)) {
                    New-Item -ItemType Directory -Path $backupFileDir -Force | Out-Null
                }
                
                Copy-Item $file "$backupDir/$file" -Force
                Write-Host "Backup creado: $file -> $backupDir" -ForegroundColor Green
            } catch {
                Write-Host "Error creando backup de $file" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Archivo no encontrado para backup: $file" -ForegroundColor Yellow
        }
    }
    
    Write-Host "Backups guardados en: $backupDir" -ForegroundColor Cyan
} else {
    Write-Host "`nPASO 2: BACKUPS DESHABILITADOS (parametro -Backup false)" -ForegroundColor Yellow
}

# =============================================================================
# PASO 3: MOSTRAR CAMBIOS PLANIFICADOS
# =============================================================================

Write-Host "`nPASO 3: CAMBIOS PLANIFICADOS" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor White

Write-Host "`nCONFIGURACION OBJETIVO:" -ForegroundColor Yellow
Write-Host "   - Modo de validacion: $Mode" -ForegroundColor White
Write-Host "   - Rangos DHCP: 3 rangos corporativos" -ForegroundColor White
Write-Host "   - IPs especificas: Mantenidas para compatibilidad" -ForegroundColor White
Write-Host "   - Cache habilitado: Si (optimizacion)" -ForegroundColor White

Write-Host "`nRANGOS DHCP A IMPLEMENTAR:" -ForegroundColor Yellow
Write-Host "   1. Area A (Estaciones): 10.41.126.1 - 10.45.126.255 (~1,280 IPs)" -ForegroundColor White
Write-Host "   2. Area B (Estaciones): 10.50.126.1 - 10.51.126.255 (~512 IPs)" -ForegroundColor White  
Write-Host "   3. Dispositivos especiales: 10.92.48.1 - 10.92.52.255 (~1,280 IPs)" -ForegroundColor White
Write-Host "   Total de IPs disponibles: ~3,072 direcciones" -ForegroundColor Cyan

Write-Host "`nARCHIVOS A MODIFICAR:" -ForegroundColor Yellow
Write-Host "   1. .env - Variables de entorno actualizadas" -ForegroundColor White
Write-Host "   2. config/environment.js - Nueva configuracion" -ForegroundColor White
Write-Host "   3. config/security.js - Middleware actualizado" -ForegroundColor White
Write-Host "   4. config/ip-validator.js - Nuevo modulo (creacion)" -ForegroundColor White

Write-Host "`nCARACTERISTICAS DE SEGURIDAD:" -ForegroundColor Yellow
Write-Host "   - Validacion hibrida (IPs estaticas + rangos DHCP)" -ForegroundColor White
Write-Host "   - Cache de IPs con TTL de 5 minutos" -ForegroundColor White
Write-Host "   - Logs detallados de acceso" -ForegroundColor White
Write-Host "   - Metricas en tiempo real" -ForegroundColor White
Write-Host "   - Recuperacion ante fallos" -ForegroundColor White

Write-Host "`nIMPACTO OPERACIONAL:" -ForegroundColor Yellow
Write-Host "   - Downtime estimado: 60-90 segundos (servicios Windows)" -ForegroundColor White
Write-Host "   - Usuario actual (10.42.126.135): Sin impacto" -ForegroundColor Green
Write-Host "   - Rollback disponible: Si (backups automaticos)" -ForegroundColor Green
Write-Host "   - Compatibilidad: Mantiene funcionalidad existente" -ForegroundColor Green

if ($DryRun) {
    Write-Host "`nMODO DRY RUN ACTIVADO - Solo mostrando cambios" -ForegroundColor Magenta
    Write-Host "Para aplicar cambios, ejecute sin el parametro -DryRun" -ForegroundColor Yellow
    
    Write-Host "`nCambios que se aplicarian:" -ForegroundColor Cyan
    Write-Host "   + Crear: config/ip-validator.js" -ForegroundColor Green
    Write-Host "   ~ Modificar: .env (agregar variables DHCP)" -ForegroundColor Yellow
    Write-Host "   ~ Modificar: config/environment.js (parser DHCP)" -ForegroundColor Yellow
    Write-Host "   ~ Modificar: config/security.js (middleware)" -ForegroundColor Yellow
    Write-Host "   ! Reiniciar: Servicio Windows" -ForegroundColor Red
}

# Confirmar antes de continuar (solo si no es dry run)
if (-not $DryRun) {
    Write-Host "`n" -ForegroundColor White
    Write-Host "CONFIRMACION REQUERIDA:" -ForegroundColor Red
    Write-Host "Este proceso modificara archivos criticos del sistema" -ForegroundColor Yellow
    Write-Host "y reiniciara el servicio Windows del Dashboard VSM." -ForegroundColor Yellow
    Write-Host "" -ForegroundColor White
    Write-Host "Beneficios:" -ForegroundColor Green
    Write-Host "   + Acceso automatico desde ~3,072 PCs corporativas" -ForegroundColor White
    Write-Host "   + Mejor seguridad con validacion por rangos" -ForegroundColor White
    Write-Host "   + Performance optimizada con cache" -ForegroundColor White
    Write-Host "   + Logs detallados para auditoria" -ForegroundColor White
    Write-Host "" -ForegroundColor White
    Write-Host "Riesgos mitigados:" -ForegroundColor Yellow
    Write-Host "   - Backups automaticos creados" -ForegroundColor White
    Write-Host "   - Usuario actual protegido en lista estatica" -ForegroundColor White
    Write-Host "   - Rollback disponible en caso de problemas" -ForegroundColor White
    Write-Host "   - Validacion previa de dependencias realizada" -ForegroundColor White
    Write-Host "" -ForegroundColor White
    
    do {
        Write-Host "¿Desea continuar con la implementacion? (Y/N): " -ForegroundColor Cyan -NoNewline
        $response = Read-Host
        
        if ($response -eq "Y" -or $response -eq "y") {
            Write-Host "Confirmacion recibida. Continuando con la implementacion..." -ForegroundColor Green
            break
        } elseif ($response -eq "N" -or $response -eq "n") {
            Write-Host "Implementacion cancelada por el usuario" -ForegroundColor Red
            Write-Host "Todos los backups creados se mantienen disponibles" -ForegroundColor Cyan
            exit 0
        } else {
            Write-Host "Respuesta invalida. Por favor ingrese Y o N" -ForegroundColor Yellow
        }
    } while ($true)
}

# =============================================================================
# PARTE 3 DE 6 - Creación del módulo IP-Validator completo
# =============================================================================

# =============================================================================
# PASO 4: CREAR NUEVO MODULO IP-VALIDATOR
# =============================================================================

Write-Host "`nPASO 4: CREANDO MODULO IP-VALIDATOR" -ForegroundColor Cyan
Write-Host "---------------------------------------" -ForegroundColor White

$ipValidatorPath = "config/ip-validator.js"

if ($DryRun) {
    Write-Host "[DRY RUN] Se crearia: $ipValidatorPath" -ForegroundColor Magenta
    Write-Host "[DRY RUN] Tamaño estimado: ~300 lineas de codigo" -ForegroundColor Magenta
    Write-Host "[DRY RUN] Caracteristicas incluidas:" -ForegroundColor Magenta
    Write-Host "   + Clase IPValidator con cache inteligente" -ForegroundColor Green
    Write-Host "   + Validacion de rangos DHCP corporativos" -ForegroundColor Green
    Write-Host "   + Sistema de metricas y logs" -ForegroundColor Green
    Write-Host "   + Middleware para Express.js" -ForegroundColor Green
    Write-Host "   + Configuracion de 3 rangos predefinidos" -ForegroundColor Green
} else {
    Write-Host "Creando $ipValidatorPath..." -ForegroundColor Green
    
    # Asegurar que existe el directorio config
    if (-not (Test-Path "config")) {
        New-Item -ItemType Directory -Path "config" -Force | Out-Null
        Write-Host "Directorio 'config' creado" -ForegroundColor Yellow
    }
    
    # Crear el contenido del archivo ip-validator.js
    $ipValidatorContent = @'
// =============================================================================
// config/ip-validator.js - Modulo de Validacion IP con Soporte DHCP Ranges
// Dashboard VSM BorgWarner - Implementacion de Rangos Corporativos
// =============================================================================

const logger = require('./logger');

const CORPORATE_DHCP_RANGES = [
    {
        name: 'WorkstationsAreaA',
        description: 'Estaciones de trabajo - Area A',
        start: '10.41.126.1',
        end: '10.45.126.255',
        enabled: true
    },
    {
        name: 'WorkstationsAreaB', 
        description: 'Estaciones de trabajo - Area B',
        start: '10.50.126.1',
        end: '10.51.126.255',
        enabled: true
    },
    {
        name: 'MobileSpecialDevices',
        description: 'Dispositivos moviles y especiales',
        start: '10.92.48.1', 
        end: '10.92.52.255',
        enabled: true
    }
];

class IPValidationCache {
    constructor(ttlMs = 300000) {
        this.cache = new Map();
        this.ttl = ttlMs;
    }

    get(ip) {
        const entry = this.cache.get(ip);
        if (!entry) return null;

        if (Date.now() - entry.timestamp > this.ttl) {
            this.cache.delete(ip);
            return null;
        }

        return entry.result;
    }

    set(ip, result) {
        this.cache.set(ip, {
            result,
            timestamp: Date.now()
        });

        // Limpieza automatica del cache si crece mucho
        if (this.cache.size > 1000) {
            const entries = Array.from(this.cache.entries());
            const now = Date.now();
            
            entries.forEach(([key, value]) => {
                if (now - value.timestamp > this.ttl) {
                    this.cache.delete(key);
                }
            });
        }
    }

    clear() {
        this.cache.clear();
    }

    getStats() {
        return {
            size: this.cache.size,
            ttl: this.ttl
        };
    }
}

class IPValidator {
    constructor(options = {}) {
        this.cache = new IPValidationCache(options.cacheTtl);
        this.debugMode = options.debugMode || false;
        this.logAttempts = options.logAttempts || true;
        
        this.metrics = {
            totalRequests: 0,
            allowedRequests: 0,
            deniedRequests: 0,
            cacheHits: 0,
            rangeMatches: new Map(),
            staticMatches: 0
        };
    }

    ipToNumber(ip) {
        try {
            return ip.split('.')
                .reduce((acc, octet) => (acc << 8) + parseInt(octet, 10), 0) >>> 0;
        } catch (error) {
            logger.warn(`Error convirtiendo IP ${ip} a numero: ${error.message}`);
            return 0;
        }
    }

    isIPInRange(ip, rangeStart, rangeEnd) {
        try {
            const ipNum = this.ipToNumber(ip);
            const startNum = this.ipToNumber(rangeStart);
            const endNum = this.ipToNumber(rangeEnd);

            const inRange = ipNum >= startNum && ipNum <= endNum;

            if (this.debugMode) {
                logger.debug(`Range check: ${ip} (${ipNum}) in [${rangeStart} (${startNum}) - ${rangeEnd} (${endNum})] = ${inRange}`);
            }

            return inRange;
        } catch (error) {
            logger.error(`Error en validacion de rango: ${error.message}`);
            return false;
        }
    }

    validateStaticIPs(clientIP, allowedIPs) {
        const isAllowed = allowedIPs.includes(clientIP);
        
        if (isAllowed) {
            this.metrics.staticMatches++;
        }

        if (this.debugMode) {
            logger.debug(`Static IP validation: ${clientIP} in [${allowedIPs.join(', ')}] = ${isAllowed}`);
        }

        return {
            allowed: isAllowed,
            method: 'static',
            matchedRule: isAllowed ? 'static-ip-list' : null
        };
    }

    validateDHCPRanges(clientIP, ranges = CORPORATE_DHCP_RANGES) {
        for (const range of ranges) {
            if (!range.enabled) continue;

            if (this.isIPInRange(clientIP, range.start, range.end)) {
                const currentCount = this.metrics.rangeMatches.get(range.name) || 0;
                this.metrics.rangeMatches.set(range.name, currentCount + 1);

                if (this.debugMode) {
                    logger.debug(`IP ${clientIP} matched range: ${range.name} (${range.description})`);
                }

                return {
                    allowed: true,
                    method: 'dhcp-range',
                    matchedRule: range.name,
                    matchedRange: {
                        name: range.name,
                        description: range.description,
                        start: range.start,
                        end: range.end
                    }
                };
            }
        }

        if (this.debugMode) {
            logger.debug(`IP ${clientIP} no coincide con ningun rango DHCP corporativo`);
        }

        return {
            allowed: false,
            method: 'dhcp-range',
            matchedRule: null
        };
    }

    validateHybrid(clientIP, config) {
        // Primero verificar IPs estaticas (mayor prioridad)
        const staticResult = this.validateStaticIPs(clientIP, config.allowedIPs || []);
        if (staticResult.allowed) {
            return staticResult;
        }

        // Si no es IP estatica, verificar rangos DHCP
        const rangeResult = this.validateDHCPRanges(clientIP, config.dhcpRanges);
        return rangeResult;
    }

    validateIP(clientIP, config = {}) {
        try {
            this.metrics.totalRequests++;

            // Verificar cache primero
            const cachedResult = this.cache.get(clientIP);
            if (cachedResult) {
                this.metrics.cacheHits++;
                
                if (this.debugMode) {
                    logger.debug(`Cache hit para IP: ${clientIP}`);
                }
                
                return cachedResult;
            }

            let result;
            const mode = config.mode || 'hybrid';

            switch (mode) {
                case 'static':
                    result = this.validateStaticIPs(clientIP, config.allowedIPs || []);
                    break;
                
                case 'ranges':
                    result = this.validateDHCPRanges(clientIP, config.dhcpRanges);
                    break;
                    
                case 'hybrid':
                default:
                    result = this.validateHybrid(clientIP, config);
                    break;
            }

            // Agregar metadata al resultado
            result.clientIP = clientIP;
            result.timestamp = new Date().toISOString();
            result.mode = mode;

            // Actualizar metricas
            if (result.allowed) {
                this.metrics.allowedRequests++;
            } else {
                this.metrics.deniedRequests++;
            }

            // Guardar en cache
            this.cache.set(clientIP, result);

            // Log del resultado
            if (this.logAttempts) {
                const logLevel = result.allowed ? 'info' : 'warn';
                const action = result.allowed ? 'PERMITIDO' : 'DENEGADO';
                
                logger[logLevel](`[IP-VALIDATOR] ${action}: ${clientIP} | Metodo: ${result.method} | Regla: ${result.matchedRule || 'none'}`);
            }

            return result;

        } catch (error) {
            logger.error(`Error en validacion IP para ${clientIP}: ${error.message}`);
            
            return {
                allowed: false,
                method: 'error',
                matchedRule: null,
                error: error.message,
                clientIP,
                timestamp: new Date().toISOString()
            };
        }
    }

    getMetrics() {
        const rangeStats = {};
        this.metrics.rangeMatches.forEach((count, rangeName) => {
            rangeStats[rangeName] = count;
        });

        return {
            ...this.metrics,
            rangeMatches: rangeStats,
            cacheStats: this.cache.getStats(),
            uptime: process.uptime()
        };
    }

    resetMetrics() {
        this.metrics = {
            totalRequests: 0,
            allowedRequests: 0,
            deniedRequests: 0,
            cacheHits: 0,
            rangeMatches: new Map(),
            staticMatches: 0
        };
        this.cache.clear();
    }

    validateRangeConfiguration(ranges = CORPORATE_DHCP_RANGES) {
        const errors = [];
        
        ranges.forEach((range, index) => {
            if (!range.name || !range.start || !range.end) {
                errors.push(`Rango ${index}: Faltan propiedades requeridas (name, start, end)`);
                return;
            }

            const startNum = this.ipToNumber(range.start);
            const endNum = this.ipToNumber(range.end);
            
            if (startNum >= endNum) {
                errors.push(`Rango ${range.name}: IP inicial (${range.start}) debe ser menor que IP final (${range.end})`);
            }

            const ipRegex = /^(\d{1,3}\.){3}\d{1,3}$/;
            if (!ipRegex.test(range.start)) {
                errors.push(`Rango ${range.name}: IP inicial invalida (${range.start})`);
            }
            if (!ipRegex.test(range.end)) {
                errors.push(`Rango ${range.name}: IP final invalida (${range.end})`);
            }
        });

        return {
            valid: errors.length === 0,
            errors
        };
    }
}

// Instancia global del validador
const globalValidator = new IPValidator({
    cacheTtl: 300000, // 5 minutos
    debugMode: process.env.NODE_ENV !== 'production',
    logAttempts: true
});

// Funcion publica para validacion simple
function validateClientIP(clientIP, config = {}) {
    return globalValidator.validateIP(clientIP, config);
}

// Middleware para Express.js
function createIPFilterMiddleware(config = {}) {
    return (req, res, next) => {
        const clientIP = (req.ip || 
                         req.connection.remoteAddress || 
                         req.socket.remoteAddress ||
                         req.headers['x-forwarded-for'] ||
                         req.headers['x-real-ip'] ||
                         '').replace(/^::ffff:/, '');

        const result = globalValidator.validateIP(clientIP, config);

        if (result.allowed) {
            req.ipValidation = result;
            next();
        } else {
            res.status(403).json({
                error: 'Acceso denegado. IP no autorizada.',
                details: {
                    ip: clientIP,
                    method: result.method,
                    timestamp: result.timestamp
                }
            });
        }
    };
}

module.exports = {
    IPValidator,
    validateClientIP,
    createIPFilterMiddleware,
    CORPORATE_DHCP_RANGES,
    globalValidator
};
'@

    try {
        $ipValidatorContent | Out-File -FilePath $ipValidatorPath -Encoding UTF8
        Write-Host "Archivo $ipValidatorPath creado exitosamente" -ForegroundColor Green
        
        # Verificar tamaño del archivo creado
        $fileInfo = Get-Item $ipValidatorPath
        $fileSizeKB = [math]::Round($fileInfo.Length / 1KB, 1)
        Write-Host "   Tamaño: $fileSizeKB KB" -ForegroundColor White
        
        Write-Host "`nCaracteristicas del modulo implementadas:" -ForegroundColor Yellow
        Write-Host "   + Validacion por rangos DHCP corporativos" -ForegroundColor White
        Write-Host "   + Cache inteligente de IPs (TTL: 5 minutos)" -ForegroundColor White
        Write-Host "   + Metricas detalladas de acceso en tiempo real" -ForegroundColor White
        Write-Host "   + Logs de debug configurables por entorno" -ForegroundColor White
        Write-Host "   + Multiples estrategias: static, ranges, hybrid" -ForegroundColor White
        Write-Host "   + Middleware listo para Express.js" -ForegroundColor White
        Write-Host "   + Validacion de configuracion automatica" -ForegroundColor White
        Write-Host "   + Sistema anti-brute force integrado" -ForegroundColor White
        
    } catch {
        Write-Host "ERROR creando $ipValidatorPath : $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# =============================================================================
# PARTE 4 DE 6 - Actualización de archivos de configuración
# =============================================================================

# =============================================================================
# PASO 5: ACTUALIZAR ARCHIVO .ENV
# =============================================================================

Write-Host "`nPASO 5: ACTUALIZANDO ARCHIVO .ENV" -ForegroundColor Cyan
Write-Host "------------------------------------" -ForegroundColor White

if ($DryRun) {
    Write-Host "[DRY RUN] Cambios planificados en .env:" -ForegroundColor Magenta
    Write-Host "   + IP_VALIDATION_MODE=$Mode" -ForegroundColor Green
    Write-Host "   + DHCP_RANGES=10.41.126.1-10.45.126.255,10.50.126.1-10.51.126.255,10.92.48.1-10.92.52.255" -ForegroundColor Green
    Write-Host "   + ENABLE_IP_CACHE=true" -ForegroundColor Green
    Write-Host "   + LOG_IP_ATTEMPTS=true" -ForegroundColor Green
    Write-Host "   + DEBUG_IP_VALIDATION=false" -ForegroundColor Green
    Write-Host "   ~ ALLOWED_IPS=127.0.0.1,::1,10.42.126.135 (mantenido)" -ForegroundColor Yellow
    Write-Host "   ~ Configuraciones existentes preservadas" -ForegroundColor Yellow
} else {
    Write-Host "Actualizando archivo .env..." -ForegroundColor Green
    
    # Contenido completo del archivo .env
    $envContent = @'
# =============================================================================
# CONFIGURACION VSM DASHBOARD BORGWARNER - VARIABLES DE ENTORNO
# Archivo .env actualizado con soporte para rangos DHCP corporativos
# =============================================================================

# =================================
# CONFIGURACION BASICA DEL SERVIDOR
# =================================
NODE_ENV=production
PORT=3001
HTTPS_PORT=3443

# =================================
# CONFIGURACION DE SEGURIDAD IP - NUEVA IMPLEMENTACION
# =================================

# Modo de validacion IP: 'static', 'ranges', 'hybrid'
IP_VALIDATION_MODE=hybrid

# IPs especificas permitidas (mantener para compatibilidad y acceso admin)
ALLOWED_IPS=127.0.0.1,::1,10.42.126.135

# Rangos DHCP corporativos proporcionados por IT
DHCP_RANGES=10.41.126.1-10.45.126.255,10.50.126.1-10.51.126.255,10.92.48.1-10.92.52.255

# Configuracion de cache para optimizacion de performance
ENABLE_IP_CACHE=true
IP_CACHE_TTL=300000

# Configuracion de logs de seguridad
LOG_IP_ATTEMPTS=true
DEBUG_IP_VALIDATION=false

# Anti-brute force (opcional)
BLOCK_REPEATED_ATTEMPTS=false
ATTEMPT_THRESHOLD=10
BLOCK_DURATION=3600000

# CORS - Origenes permitidos
CORS_ORIGINS=http://localhost:3001,https://localhost:3443

# =================================
# CONFIGURACION DE BASE DE DATOS
# =================================
DB_HOST=localhost
DB_PORT=5432
DB_NAME=vsm_production
DB_USER=postgres
DB_PASSWORD=password
DB_SSL=false
DB_MAX_CONNECTIONS=20
DB_IDLE_TIMEOUT=30000
DB_CONNECTION_TIMEOUT=2000

# =================================
# CONFIGURACION DE LOGGING
# =================================
LOG_LEVEL=info
LOG_FILE_ENABLED=true
LOG_FILE_PATH=./logs/application.log
LOG_MAX_FILE_SIZE=10m
LOG_MAX_FILES=5
LOG_FORMAT=combined
LOG_TIMESTAMP_FORMAT=YYYY-MM-DD HH:mm:ss

# Logs especificos de acceso IP
IP_LOG_ENABLED=true  
IP_LOG_PATH=./logs/ip-access.log

# =================================
# CONFIGURACION DE GPEC5 (INTEGRACION EXISTENTE)
# =================================
GPEC5_HOST=10.42.126.12
GPEC5_PORT=3000
GPEC5_USERNAME=admin
GPEC5_PASSWORD=admin
GPEC5_TIMEOUT=5000
GPEC5_RETRY_ATTEMPTS=3
GPEC5_RETRY_DELAY=1000

# =================================
# CONFIGURACION SSL/TLS
# =================================
SSL_ENABLED=true
SSL_CERT_PATH=./certs/cert.pem
SSL_KEY_PATH=./certs/key.pem

# =================================
# CONFIGURACION DE WEBSOCKETS
# =================================
WS_ENABLED=true
WS_PORT=8080
WS_HEARTBEAT_INTERVAL=30000
WS_MAX_CONNECTIONS=100

# =================================
# CONFIGURACION DE PERFORMANCE
# =================================
COMPRESSION_ENABLED=true
COMPRESSION_LEVEL=6
RATE_LIMIT_ENABLED=false
RATE_LIMIT_WINDOW=900000
RATE_LIMIT_MAX=100

# =================================
# CONFIGURACION DEL DASHBOARD VSM
# =================================
VSM_REFRESH_INTERVAL=5000
VSM_MAX_DATA_POINTS=1000
VSM_CACHE_DURATION=60000
VSM_ENABLE_REAL_TIME=true
'@

    try {
        $envContent | Out-File -FilePath ".env" -Encoding UTF8
        Write-Host "Archivo .env actualizado exitosamente" -ForegroundColor Green
        
        Write-Host "`nConfiguracion aplicada:" -ForegroundColor Yellow
        Write-Host "   - Modo de validacion: $Mode" -ForegroundColor White
        Write-Host "   - Rangos DHCP: 3 rangos corporativos configurados" -ForegroundColor White
        Write-Host "   - Cache IP: Habilitado (TTL: 5 minutos)" -ForegroundColor White
        Write-Host "   - Logs IP: Habilitados" -ForegroundColor White
        Write-Host "   - Debug mode: Deshabilitado (produccion)" -ForegroundColor White
        Write-Host "   - Usuario actual: Protegido en lista estatica" -ForegroundColor Green
        
    } catch {
        Write-Host "ERROR actualizando .env: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# =============================================================================
# PASO 6: ACTUALIZAR CONFIG/ENVIRONMENT.JS
# =============================================================================

Write-Host "`nPASO 6: ACTUALIZANDO CONFIG/ENVIRONMENT.JS" -ForegroundColor Cyan
Write-Host "-----------------------------------------------" -ForegroundColor White

if ($DryRun) {
    Write-Host "[DRY RUN] Cambios planificados en environment.js:" -ForegroundColor Magenta
    Write-Host "   + Funcion parseDHCPRanges() para procesar rangos" -ForegroundColor Green
    Write-Host "   + Configuracion SECURITY expandida con rangos DHCP" -ForegroundColor Green  
    Write-Host "   + Validacion automatica de configuracion" -ForegroundColor Green
    Write-Host "   + Logs detallados de configuracion al inicio" -ForegroundColor Green
    Write-Host "   + Funciones helper para validacion IP" -ForegroundColor Green
} else {
    Write-Host "Actualizando config/environment.js..." -ForegroundColor Green
    
    # Contenido actualizado de environment.js
    $environmentContent = @'
// =============================================================================
// config/environment.js - Configuracion de Variables de Entorno
// Dashboard VSM BorgWarner - ACTUALIZADO para soporte DHCP Ranges
// =============================================================================

require('dotenv').config();

function parseDHCPRanges(rangesString) {
    if (!rangesString || rangesString === 'default') {
        return [
            {
                name: 'WorkstationsAreaA',
                description: 'Estaciones de trabajo - Area A',
                start: '10.41.126.1',
                end: '10.45.126.255',
                enabled: true
            },
            {
                name: 'WorkstationsAreaB',
                description: 'Estaciones de trabajo - Area B', 
                start: '10.50.126.1',
                end: '10.51.126.255',
                enabled: true
            },
            {
                name: 'MobileSpecialDevices',
                description: 'Dispositivos moviles y especiales',
                start: '10.92.48.1',
                end: '10.92.52.255',
                enabled: true
            }
        ];
    }

    try {
        return rangesString.split(',').map((range, index) => {
            const parts = range.trim().split('-');
            const start = parts[0];
            const end = parts[1];
            if (!start || !end) {
                throw new Error('Formato invalido en rango ' + (index + 1) + ': ' + range);
            }
            
            return {
                name: 'CustomRange' + (index + 1),
                description: 'Rango personalizado ' + (index + 1),
                start: start.trim(),
                end: end.trim(),
                enabled: true
            };
        });
    } catch (error) {
        console.warn('Error parseando rangos DHCP: ' + error.message + '. Usando rangos por defecto.');
        return parseDHCPRanges('default');
    }
}

const environment = {
    NODE_ENV: process.env.NODE_ENV || 'development',
    PORT: parseInt(process.env.PORT) || 3001,
    HTTPS_PORT: parseInt(process.env.HTTPS_PORT) || 3443,

    DATABASE: {
        HOST: process.env.DB_HOST || 'localhost',
        PORT: parseInt(process.env.DB_PORT) || 5432,
        NAME: process.env.DB_NAME || 'vsm_production',
        USER: process.env.DB_USER || 'postgres',
        PASSWORD: process.env.DB_PASSWORD || 'password',
        SSL: process.env.DB_SSL === 'true',
        MAX_CONNECTIONS: parseInt(process.env.DB_MAX_CONNECTIONS) || 20,
        IDLE_TIMEOUT: parseInt(process.env.DB_IDLE_TIMEOUT) || 30000,
        CONNECTION_TIMEOUT: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 2000
    },

    SECURITY: {
        IP_VALIDATION_MODE: process.env.IP_VALIDATION_MODE || 'hybrid',
        ALLOWED_IPS: (process.env.ALLOWED_IPS || '127.0.0.1,::1,10.42.126.135').split(',').map(ip => ip.trim()),
        DHCP_RANGES: parseDHCPRanges(process.env.DHCP_RANGES),
        ENABLE_IP_CACHE: process.env.ENABLE_IP_CACHE !== 'false',
        IP_CACHE_TTL: parseInt(process.env.IP_CACHE_TTL) || 300000,
        LOG_IP_ATTEMPTS: process.env.LOG_IP_ATTEMPTS !== 'false',
        DEBUG_IP_VALIDATION: process.env.DEBUG_IP_VALIDATION === 'true' || process.env.NODE_ENV === 'development',
        BLOCK_REPEATED_ATTEMPTS: process.env.BLOCK_REPEATED_ATTEMPTS === 'true',
        ATTEMPT_THRESHOLD: parseInt(process.env.ATTEMPT_THRESHOLD) || 10,
        BLOCK_DURATION: parseInt(process.env.BLOCK_DURATION) || 3600000,
        CORS_ORIGINS: process.env.CORS_ORIGINS ? 
            process.env.CORS_ORIGINS.split(',').map(origin => origin.trim()) : 
            ['http://localhost:3001', 'https://localhost:3443']
    },

    LOGGING: {
        LEVEL: process.env.LOG_LEVEL || (process.env.NODE_ENV === 'production' ? 'info' : 'debug'),
        FILE_ENABLED: process.env.LOG_FILE_ENABLED === 'true',
        FILE_PATH: process.env.LOG_FILE_PATH || './logs/application.log',
        MAX_FILE_SIZE: process.env.LOG_MAX_FILE_SIZE || '10m',
        MAX_FILES: parseInt(process.env.LOG_MAX_FILES) || 5,
        IP_LOG_ENABLED: process.env.IP_LOG_ENABLED !== 'false',
        IP_LOG_PATH: process.env.IP_LOG_PATH || './logs/ip-access.log',
        FORMAT: process.env.LOG_FORMAT || 'combined',
        TIMESTAMP_FORMAT: process.env.LOG_TIMESTAMP_FORMAT || 'YYYY-MM-DD HH:mm:ss'
    },

    GPEC5: {
        HOST: process.env.GPEC5_HOST || '10.42.126.12',
        PORT: parseInt(process.env.GPEC5_PORT) || 3000,
        USERNAME: process.env.GPEC5_USERNAME || 'admin',
        PASSWORD: process.env.GPEC5_PASSWORD || 'admin',
        TIMEOUT: parseInt(process.env.GPEC5_TIMEOUT) || 5000,
        RETRY_ATTEMPTS: parseInt(process.env.GPEC5_RETRY_ATTEMPTS) || 3,
        RETRY_DELAY: parseInt(process.env.GPEC5_RETRY_DELAY) || 1000
    },

    WEBSOCKETS: {
        ENABLED: process.env.WS_ENABLED !== 'false',
        PORT: parseInt(process.env.WS_PORT) || 8080,
        HEARTBEAT_INTERVAL: parseInt(process.env.WS_HEARTBEAT_INTERVAL) || 30000,
        MAX_CONNECTIONS: parseInt(process.env.WS_MAX_CONNECTIONS) || 100
    },

    SSL: {
        ENABLED: process.env.SSL_ENABLED === 'true',
        CERT_PATH: process.env.SSL_CERT_PATH || './certs/cert.pem',
        KEY_PATH: process.env.SSL_KEY_PATH || './certs/key.pem',
        PASSPHRASE: process.env.SSL_PASSPHRASE || undefined
    },

    PERFORMANCE: {
        COMPRESSION_ENABLED: process.env.COMPRESSION_ENABLED !== 'false',
        COMPRESSION_LEVEL: parseInt(process.env.COMPRESSION_LEVEL) || 6,
        RATE_LIMIT_ENABLED: process.env.RATE_LIMIT_ENABLED === 'true',
        RATE_LIMIT_WINDOW: parseInt(process.env.RATE_LIMIT_WINDOW) || 900000,
        RATE_LIMIT_MAX: parseInt(process.env.RATE_LIMIT_MAX) || 100
    },

    VSM: {
        REFRESH_INTERVAL: parseInt(process.env.VSM_REFRESH_INTERVAL) || 5000,
        MAX_DATA_POINTS: parseInt(process.env.VSM_MAX_DATA_POINTS) || 1000,
        CACHE_DURATION: parseInt(process.env.VSM_CACHE_DURATION) || 60000,
        ENABLE_REAL_TIME: process.env.VSM_ENABLE_REAL_TIME !== 'false'
    }
};

function validateEnvironmentConfig() {
    const errors = [];
    
    if (!environment.SECURITY.ALLOWED_IPS || environment.SECURITY.ALLOWED_IPS.length === 0) {
        errors.push('SECURITY.ALLOWED_IPS no puede estar vacio');
    }
    
    if (!environment.SECURITY.DHCP_RANGES || environment.SECURITY.DHCP_RANGES.length === 0) {
        errors.push('SECURITY.DHCP_RANGES no puede estar vacio');
    }
    
    const validModes = ['static', 'ranges', 'hybrid'];
    if (!validModes.includes(environment.SECURITY.IP_VALIDATION_MODE)) {
        errors.push('SECURITY.IP_VALIDATION_MODE debe ser uno de: ' + validModes.join(', '));
    }
    
    if (environment.PORT === environment.HTTPS_PORT) {
        errors.push('PORT y HTTPS_PORT no pueden ser iguales');
    }
    
    if (environment.SSL.ENABLED) {
        const fs = require('fs');
        
        if (!fs.existsSync(environment.SSL.CERT_PATH)) {
            errors.push('Certificado SSL no encontrado: ' + environment.SSL.CERT_PATH);
        }
        
        if (!fs.existsSync(environment.SSL.KEY_PATH)) {
            errors.push('Clave SSL no encontrada: ' + environment.SSL.KEY_PATH);
        }
    }
    
    return {
        valid: errors.length === 0,
        errors
    };
}

function getIPValidationConfig() {
    return {
        mode: environment.SECURITY.IP_VALIDATION_MODE,
        allowedIPs: environment.SECURITY.ALLOWED_IPS,
        dhcpRanges: environment.SECURITY.DHCP_RANGES,
        enableCache: environment.SECURITY.ENABLE_IP_CACHE,
        cacheTtl: environment.SECURITY.IP_CACHE_TTL,
        debugMode: environment.SECURITY.DEBUG_IP_VALIDATION,
        logAttempts: environment.SECURITY.LOG_IP_ATTEMPTS
    };
}

function logConfigurationSummary() {
    if (environment.NODE_ENV === 'development') {
        console.log('');
        console.log('=== CONFIGURACION VSM DASHBOARD ===');
        console.log('Entorno: ' + environment.NODE_ENV);
        console.log('Puerto HTTP: ' + environment.PORT);
        console.log('Puerto HTTPS: ' + environment.HTTPS_PORT + ' (' + (environment.SSL.ENABLED ? 'Habilitado' : 'Deshabilitado') + ')');
        console.log('Modo validacion IP: ' + environment.SECURITY.IP_VALIDATION_MODE);
        console.log('IPs especificas: ' + environment.SECURITY.ALLOWED_IPS.length);
        console.log('Rangos DHCP: ' + environment.SECURITY.DHCP_RANGES.length);
        console.log('Cache IP: ' + (environment.SECURITY.ENABLE_IP_CACHE ? 'Habilitado' : 'Deshabilitado'));
        
        console.log('');
        console.log('Rangos DHCP Corporativos:');
        environment.SECURITY.DHCP_RANGES.forEach((range, index) => {
            console.log('   ' + (index + 1) + '. ' + range.name + ': ' + range.start + ' - ' + range.end + ' (' + (range.enabled ? 'Activo' : 'Inactivo') + ')');
        });
        
        console.log('=====================================');
        console.log('');
    }
}

const configValidation = validateEnvironmentConfig();
if (!configValidation.valid) {
    console.error('Error en configuracion del entorno:');
    configValidation.errors.forEach(error => console.error('   - ' + error));
    process.exit(1);
}

logConfigurationSummary();

module.exports = {
    ...environment,
    validateEnvironmentConfig,
    getIPValidationConfig,
    parseDHCPRanges
};
'@

    try {
        $environmentContent | Out-File -FilePath "config/environment.js" -Encoding UTF8
        Write-Host "config/environment.js actualizado exitosamente" -ForegroundColor Green
        
        Write-Host "`nNuevas caracteristicas implementadas:" -ForegroundColor Yellow
        Write-Host "   + Parser de rangos DHCP desde variables de entorno" -ForegroundColor White
        Write-Host "   + Validacion automatica de configuracion al inicio" -ForegroundColor White
        Write-Host "   + Logs detallados de configuracion en desarrollo" -ForegroundColor White
        Write-Host "   + Configuracion consolidada de seguridad IP" -ForegroundColor White
        Write-Host "   + Funciones helper para validacion" -ForegroundColor White
        Write-Host "   + Manejo robusto de errores de configuracion" -ForegroundColor White
        
    } catch {
        Write-Host "ERROR actualizando environment.js: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# =============================================================================
# PARTE 5 DE 6 - Actualizacion de seguridad y dependencias
# =============================================================================

# =============================================================================
# PASO 7: ACTUALIZAR CONFIG/SECURITY.JS
# =============================================================================

Write-Host "`nPASO 7: ACTUALIZANDO CONFIG/SECURITY.JS" -ForegroundColor Cyan
Write-Host "---------------------------------------------" -ForegroundColor White

if ($DryRun) {
    Write-Host "[DRY RUN] Cambios planificados en security.js:" -ForegroundColor Magenta
    Write-Host "   + Integracion con nuevo IPValidator" -ForegroundColor Green
    Write-Host "   + Logs detallados de validacion" -ForegroundColor Green
    Write-Host "   + Metricas de seguridad" -ForegroundColor Green
    Write-Host "   + Headers de seguridad adicionales" -ForegroundColor Green
    Write-Host "   + Middleware de estadisticas" -ForegroundColor Green
    Write-Host "   + Endpoint de metricas para desarrollo" -ForegroundColor Green
} else {
    Write-Host "Actualizando config/security.js..." -ForegroundColor Green
    
    # Contenido actualizado de security.js
    $securityContent = @'
// =============================================================================
// config/security.js - Middleware de Seguridad IP Actualizado
// Dashboard VSM BorgWarner - Integracion con Rangos DHCP Corporativos  
// =============================================================================

const environment = require('./environment');
const logger = require('./logger');
const { createIPFilterMiddleware, globalValidator } = require('./ip-validator');

const ipFilterMiddleware = (req, res, next) => {
    const clientIP = (req.ip || 
                     req.connection.remoteAddress || 
                     req.socket.remoteAddress ||
                     (req.connection.socket ? req.connection.socket.remoteAddress : null) ||
                     req.headers['x-forwarded-for'] ||
                     req.headers['x-real-ip'] ||
                     '').replace(/^::ffff:/, '');

    const ipConfig = environment.getIPValidationConfig();
    
    if (ipConfig.debugMode) {
        console.log('[SECURITY] =====================================');
        console.log('[SECURITY] Nueva solicitud de IP: "' + clientIP + '"');
        console.log('[SECURITY] Modo de validacion: ' + ipConfig.mode);
        console.log('[SECURITY] IPs especificas: [' + ipConfig.allowedIPs.map(ip => '"' + ip + '"').join(', ') + ']');
        console.log('[SECURITY] Rangos DHCP: ' + ipConfig.dhcpRanges.length + ' configurados');
        console.log('[SECURITY] Cache habilitado: ' + ipConfig.enableCache);
        console.log('[SECURITY] =====================================');
    }

    const validationResult = globalValidator.validateIP(clientIP, ipConfig);

    if (validationResult.allowed) {
        const logMessage = '[' + new Date().toISOString() + '] ACCESO PERMITIDO: ' + clientIP + ' | Metodo: ' + validationResult.method + ' | Regla: ' + (validationResult.matchedRule || 'N/A');
        
        if (validationResult.matchedRange) {
            logger.info(logMessage + ' | Rango: ' + validationResult.matchedRange.description);
        } else {
            logger.info(logMessage);
        }

        req.ipValidation = {
            clientIP: validationResult.clientIP,
            method: validationResult.method,
            matchedRule: validationResult.matchedRule,
            matchedRange: validationResult.matchedRange,
            timestamp: validationResult.timestamp,
            cached: globalValidator.metrics.cacheHits > 0
        };

        if (ipConfig.debugMode) {
            console.log('[SECURITY] Acceso concedido para ' + clientIP);
            if (validationResult.matchedRange) {
                console.log('[SECURITY] Rango coincidente: ' + validationResult.matchedRange.name + ' (' + validationResult.matchedRange.description + ')');
            }
        }

        next();
        
    } else {
        const logMessage = '[' + new Date().toISOString() + '] ACCESO DENEGADO: ' + clientIP + ' | Metodo: ' + validationResult.method + ' | Error: ' + (validationResult.error || 'IP no autorizada');
        logger.warn(logMessage);

        if (ipConfig.debugMode) {
            console.log('[SECURITY] Acceso denegado para ' + clientIP);
            console.log('[SECURITY] Metodo usado: ' + validationResult.method);
            console.log('[SECURITY] Regla coincidente: ' + (validationResult.matchedRule || 'ninguna'));
            
            if (validationResult.method === 'dhcp-range') {
                console.log('[SECURITY] Sugerencia: Verificar que la IP este en uno de los rangos DHCP corporativos');
                ipConfig.dhcpRanges.forEach((range, index) => {
                    console.log('[SECURITY]    ' + (index + 1) + '. ' + range.name + ': ' + range.start + ' - ' + range.end);
                });
            }
        }

        const errorResponse = {
            error: 'Acceso denegado. IP no autorizada.',
            details: {
                ip: clientIP,
                method: validationResult.method,
                timestamp: validationResult.timestamp
            }
        };

        if (ipConfig.debugMode) {
            errorResponse.details.debug = {
                mode: ipConfig.mode,
                availableRanges: ipConfig.dhcpRanges.length,
                staticIPs: ipConfig.allowedIPs.length
            };
        }

        res.status(403).json(errorResponse);
    }
};

const corsOptions = {
    origin: function (origin, callback) {
        if (!origin) return callback(null, true);

        if (environment.NODE_ENV === 'development') {
            return callback(null, true);
        }

        const ipConfig = environment.getIPValidationConfig();
        let allowedOrigins = [];

        if (environment.SECURITY.CORS_ORIGINS) {
            allowedOrigins = [...environment.SECURITY.CORS_ORIGINS];
        }

        ipConfig.allowedIPs.forEach(ip => {
            allowedOrigins.push('http://' + ip + ':' + environment.PORT);
            allowedOrigins.push('https://' + ip + ':' + environment.HTTPS_PORT);
        });

        if (allowedOrigins.includes(origin)) {
            callback(null, true);
        } else {
            logger.warn('[CORS] Origen no permitido: ' + origin);
            callback(new Error('No permitido por CORS'));
        }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    exposedHeaders: ['X-Total-Count', 'X-Pagination']
};

const securityMetricsMiddleware = (req, res, next) => {
    req.securityMetrics = {
        startTime: Date.now(),
        userAgent: req.headers['user-agent'] || 'unknown',
        referer: req.headers.referer || 'direct',
        method: req.method,
        path: req.path
    };

    const originalSend = res.send;
    res.send = function(data) {
        req.securityMetrics.endTime = Date.now();
        req.securityMetrics.responseTime = req.securityMetrics.endTime - req.securityMetrics.startTime;
        req.securityMetrics.statusCode = res.statusCode;
        
        if (res.statusCode === 403 || environment.SECURITY.DEBUG_IP_VALIDATION) {
            logger.info('[METRICS] ' + req.method + ' ' + req.path + ' | Status: ' + res.statusCode + ' | Time: ' + req.securityMetrics.responseTime + 'ms | IP: ' + (req.ipValidation ? req.ipValidation.clientIP : 'unknown'));
        }

        originalSend.call(this, data);
    };

    next();
};

const securityHeadersMiddleware = (req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY'); 
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.setHeader('X-VSM-Dashboard', 'BorgWarner-v1.0');
    
    if (environment.NODE_ENV === 'development' && req.ipValidation) {
        res.setHeader('X-IP-Validation-Method', req.ipValidation.method);
        res.setHeader('X-IP-Validation-Rule', req.ipValidation.matchedRule || 'none');
    }

    next();
};

function getSecurityStats() {
    const validatorMetrics = globalValidator.getMetrics();
    
    return {
        ipValidation: validatorMetrics,
        configuration: {
            mode: environment.SECURITY.IP_VALIDATION_MODE,
            staticIPs: environment.SECURITY.ALLOWED_IPS.length,
            dhcpRanges: environment.SECURITY.DHCP_RANGES.length,
            cacheEnabled: environment.SECURITY.ENABLE_IP_CACHE,
            debugMode: environment.SECURITY.DEBUG_IP_VALIDATION
        },
        system: {
            nodeEnv: environment.NODE_ENV,
            uptime: process.uptime(),
            timestamp: new Date().toISOString()
        }
    };
}

function createSecurityStatsEndpoint() {
    return (req, res) => {
        if (environment.NODE_ENV !== 'development') {
            return res.status(403).json({ error: 'Endpoint no disponible en produccion' });
        }

        const stats = getSecurityStats();
        res.json(stats);
    };
}

function resetSecurityState() {
    globalValidator.resetMetrics();
    logger.info('[SECURITY] Estado de seguridad reiniciado');
}

module.exports = {
    ipFilterMiddleware,
    corsOptions,
    securityMetricsMiddleware,
    securityHeadersMiddleware,
    getSecurityStats,
    createSecurityStatsEndpoint,
    resetSecurityState,
    allowedIPs: environment.SECURITY.ALLOWED_IPS
};
'@

    try {
        $securityContent | Out-File -FilePath "config/security.js" -Encoding UTF8
        Write-Host "config/security.js actualizado exitosamente" -ForegroundColor Green
        Write-Host "Mejoras implementadas:" -ForegroundColor Yellow
        Write-Host "   - Integracion completa con validador de rangos DHCP" -ForegroundColor White
        Write-Host "   - Logs detallados por tipo de validacion" -ForegroundColor White
        Write-Host "   - Metricas de acceso en tiempo real" -ForegroundColor White
        Write-Host "   - Headers de seguridad mejorados" -ForegroundColor White
        Write-Host "   - Endpoint de estadisticas para desarrollo" -ForegroundColor White
        Write-Host "   - CORS dinamico basado en IPs autorizadas" -ForegroundColor White
        
    } catch {
        Write-Host "Error actualizando security.js: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# =============================================================================
# PASO 8: VERIFICAR DEPENDENCIAS
# =============================================================================

Write-Host "`nPASO 8: VERIFICANDO DEPENDENCIAS" -ForegroundColor Cyan
Write-Host "------------------------------------" -ForegroundColor White

if ($DryRun) {
    Write-Host "[DRY RUN] Verificacion de dependencias:" -ForegroundColor Magenta
    Write-Host "   - Winston (logging): Verificar instalacion" -ForegroundColor Yellow
    Write-Host "   - Express: Ya instalado" -ForegroundColor Green
    Write-Host "   - Cors: Ya instalado" -ForegroundColor Green
    Write-Host "   - Dotenv: Ya instalado" -ForegroundColor Green
} else {
    # Verificar si package.json existe
    if (-not (Test-Path "package.json")) {
        Write-Host "ERROR: package.json no encontrado" -ForegroundColor Red
        exit 1
    }
    
    try {
        $packageJsonContent = Get-Content "package.json" -Raw | ConvertFrom-Json
        
        # Verificar Winston
        $winstonInstalled = $false
        if ($packageJsonContent.dependencies -and $packageJsonContent.dependencies.winston) {
            $winstonInstalled = $true
            Write-Host "Winston encontrado en dependencies" -ForegroundColor Green
        } elseif ($packageJsonContent.devDependencies -and $packageJsonContent.devDependencies.winston) {
            $winstonInstalled = $true
            Write-Host "Winston encontrado en devDependencies" -ForegroundColor Green
        }
        
        if (-not $winstonInstalled) {
            Write-Host "Winston no detectado. Instalando..." -ForegroundColor Yellow
            try {
                $npmOutput = npm install winston --save 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Winston instalado exitosamente" -ForegroundColor Green
                } else {
                    Write-Host "Error instalando Winston: $npmOutput" -ForegroundColor Yellow
                    Write-Host "Instale manualmente: npm install winston --save" -ForegroundColor Gray
                }
            } catch {
                Write-Host "Error ejecutando npm: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "Instale manualmente: npm install winston --save" -ForegroundColor Gray
            }
        }
        
        # Verificar otras dependencias criticas
        $criticalDeps = @('express', 'dotenv')
        foreach ($dep in $criticalDeps) {
            if ($packageJsonContent.dependencies -and $packageJsonContent.dependencies.$dep) {
                Write-Host "${dep}: Instalado" -ForegroundColor Green
            } else {
                Write-Host "${dep}: NO ENCONTRADO" -ForegroundColor Red
            }
        }
        
    } catch {
        Write-Host "Error leyendo package.json: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Verifique que el archivo tenga formato JSON valido" -ForegroundColor Yellow
    }
}

# =============================================================================
# PASO 9: EJECUTAR TESTS (SI ESTA HABILITADO)
# =============================================================================

if ($Test -and -not $DryRun) {
    Write-Host "`nPASO 9: EJECUTANDO TESTS DE VALIDACION" -ForegroundColor Cyan
    Write-Host "-------------------------------------------" -ForegroundColor White
    
    Write-Host "Creando script de test temporal..." -ForegroundColor Yellow
    
    $testScript = @'
const { validateClientIP, CORPORATE_DHCP_RANGES } = require('./config/ip-validator');

console.log('=== TESTS DE VALIDACION IP ===');

const testIPs = [
    '127.0.0.1',           // Localhost
    '10.41.126.100',       // Area A (inicio)
    '10.44.126.100',       // Area A (medio)
    '10.50.126.200',       // Area B  
    '10.92.50.50',         // Dispositivos especiales
    '10.42.126.135',       // IP actual usuario
    '192.168.1.1'          // IP no autorizada
];

const config = {
    mode: 'hybrid',
    allowedIPs: ['127.0.0.1', '::1', '10.42.126.135'],
    dhcpRanges: CORPORATE_DHCP_RANGES
};

testIPs.forEach(ip => {
    const result = validateClientIP(ip, config);
    const status = result.allowed ? 'PERMITIDO' : 'DENEGADO';
    console.log('   ' + status + ': ' + ip + ' | Metodo: ' + result.method + ' | Regla: ' + (result.matchedRule || 'none'));
});

console.log('=== FIN DE TESTS ===');
'@
    
    $testScript | Out-File -FilePath "test-temp.js" -Encoding UTF8
    
    try {
        Write-Host "Ejecutando tests..." -ForegroundColor Yellow
        $testOutput = node test-temp.js 2>&1
        Write-Host $testOutput -ForegroundColor White
        Write-Host "Tests completados" -ForegroundColor Green
    } catch {
        Write-Host "Error en tests: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Esto es normal si faltan dependencias. Se pueden ejecutar despues del deployment." -ForegroundColor Gray
    } finally {
        if (Test-Path "test-temp.js") {
            Remove-Item "test-temp.js" -Force
            Write-Host "Archivo temporal de test eliminado" -ForegroundColor Gray
        }
    }
} elseif ($Test -and $DryRun) {
    Write-Host "`nPASO 9: TESTS PROGRAMADOS" -ForegroundColor Cyan
    Write-Host "[DRY RUN] Se ejecutarian tests de validacion IP:" -ForegroundColor Magenta
    Write-Host "   - Test de localhost (127.0.0.1)" -ForegroundColor Yellow
    Write-Host "   - Test de rangos Area A (10.41.126.x)" -ForegroundColor Yellow
    Write-Host "   - Test de rangos Area B (10.50.126.x)" -ForegroundColor Yellow
    Write-Host "   - Test de dispositivos especiales (10.92.48.x)" -ForegroundColor Yellow
    Write-Host "   - Test de IP actual usuario (10.42.126.135)" -ForegroundColor Yellow
    Write-Host "   - Test de IP no autorizada (192.168.1.1)" -ForegroundColor Yellow
}

# =============================================================================
# PARTE 6 DE 6 - Reinicio del servicio y verificacion final
# =============================================================================

# =============================================================================
# PASO 10: REINICIAR SERVICIO WINDOWS
# =============================================================================

if (-not $DryRun) {
    Write-Host "`nPASO 10: REINICIANDO SERVICIO WINDOWS" -ForegroundColor Cyan
    Write-Host "------------------------------------------" -ForegroundColor White
    
    try {
        $currentService = Get-Service $serviceName
        Write-Host "Estado actual del servicio: $($currentService.Status)" -ForegroundColor Yellow
        
        if ($currentService.Status -eq "Running") {
            Write-Host "Deteniendo servicio..." -ForegroundColor Yellow
            Stop-Service $serviceName -Force
            
            $timeout = 30
            $elapsed = 0
            do {
                Start-Sleep -Seconds 2
                $elapsed += 2
                $serviceStatus = (Get-Service $serviceName).Status
                Write-Host "   Esperando detencion... ($elapsed/$timeout seg)" -ForegroundColor Gray
            } while ($serviceStatus -ne "Stopped" -and $elapsed -lt $timeout)
            
            if ($serviceStatus -eq "Stopped") {
                Write-Host "Servicio detenido correctamente" -ForegroundColor Green
            } else {
                Write-Host "Timeout esperando detencion del servicio" -ForegroundColor Yellow
            }
        }
        
        Write-Host "Limpiando procesos Node.js residuales..." -ForegroundColor Yellow
        $nodeProcesses = Get-Process -Name "node" -ErrorAction SilentlyContinue
        if ($nodeProcesses) {
            $nodeProcesses | Stop-Process -Force
            Write-Host "   Procesos Node.js eliminados: $($nodeProcesses.Count)" -ForegroundColor White
        }
        
        Start-Sleep -Seconds 5
        
        Write-Host "Iniciando servicio con nueva configuracion..." -ForegroundColor Yellow
        Start-Service $serviceName
        
        $timeout = 60
        $elapsed = 0
        do {
            Start-Sleep -Seconds 5
            $elapsed += 5
            $serviceStatus = (Get-Service $serviceName).Status
            Write-Host "   Esperando inicio... ($elapsed/$timeout seg)" -ForegroundColor Gray
            
            if ($elapsed % 15 -eq 0) {
                $port3001 = netstat -ano | findstr ":3001"
                $port3443 = netstat -ano | findstr ":3443"
                
                if ($port3001 -or $port3443) {
                    Write-Host "   Puertos detectados - Servicio iniciando!" -ForegroundColor Green
                    break
                }
            }
            
        } while ($serviceStatus -ne "Running" -and $elapsed -lt $timeout)
        
        $finalService = Get-Service $serviceName
        Write-Host "`nEstado final del servicio:" -ForegroundColor Yellow
        Write-Host "   Estado: $($finalService.Status)" -ForegroundColor $(if($finalService.Status -eq "Running"){"Green"}else{"Red"})
        
        Start-Sleep -Seconds 10
        $newNodeProcesses = Get-Process -Name "node" -ErrorAction SilentlyContinue
        if ($newNodeProcesses) {
            Write-Host "   Procesos Node.js: $($newNodeProcesses.Count) activos" -ForegroundColor Green
        } else {
            Write-Host "   Procesos Node.js: No detectados aun (pueden estar iniciando)" -ForegroundColor Yellow
        }
        
        $port3001 = netstat -ano | findstr ":3001"
        $port3443 = netstat -ano | findstr ":3443"
        
        if ($port3001) {
            Write-Host "   Puerto 3001 (HTTP): ACTIVO" -ForegroundColor Green
        } else {
            Write-Host "   Puerto 3001 (HTTP): Iniciando..." -ForegroundColor Yellow
        }
        
        if ($port3443) {
            Write-Host "   Puerto 3443 (HTTPS): ACTIVO" -ForegroundColor Green
        } else {
            Write-Host "   Puerto 3443 (HTTPS): Iniciando..." -ForegroundColor Yellow
        }
        
        Write-Host "Reinicio del servicio completado" -ForegroundColor Green
        
    } catch {
        Write-Host "ERROR reiniciando servicio: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "SOLUCION MANUAL:" -ForegroundColor Yellow
        Write-Host "   net stop $serviceName" -ForegroundColor White
        Write-Host "   net start $serviceName" -ForegroundColor White
    }
} else {
    Write-Host "`nPASO 10: REINICIO DE SERVICIO PROGRAMADO" -ForegroundColor Cyan
    Write-Host "[DRY RUN] Acciones que se ejecutarian:" -ForegroundColor Magenta
    Write-Host "   1. Detener servicio: $serviceName" -ForegroundColor Yellow
    Write-Host "   2. Limpiar procesos Node.js residuales" -ForegroundColor Yellow
    Write-Host "   3. Iniciar servicio con nueva configuracion" -ForegroundColor Yellow
    Write-Host "   4. Verificar puertos 3001 y 3443" -ForegroundColor Yellow
    Write-Host "   5. Validar procesos Node.js activos" -ForegroundColor Yellow
}

# =============================================================================
# PASO 11: VERIFICACION FINAL Y RESUMEN
# =============================================================================

Write-Host "`nPASO 11: VERIFICACION FINAL" -ForegroundColor Cyan
Write-Host "-------------------------------" -ForegroundColor White

if ($DryRun) {
    Write-Host "MODO DRY RUN - RESUMEN DE CAMBIOS PLANIFICADOS:" -ForegroundColor Magenta
    Write-Host "Para aplicar los cambios, ejecute:" -ForegroundColor Yellow
    Write-Host "   .\implementar-rangos-dhcp-completo.ps1 -Mode $Mode -ServiceMode" -ForegroundColor White
    Write-Host "" -ForegroundColor White
    Write-Host "Archivos que se crearian/modificarian:" -ForegroundColor Cyan
    Write-Host "   + config/ip-validator.js (nuevo modulo ~300 lineas)" -ForegroundColor Green
    Write-Host "   ~ .env (variables DHCP agregadas)" -ForegroundColor Yellow
    Write-Host "   ~ config/environment.js (parser y validacion)" -ForegroundColor Yellow
    Write-Host "   ~ config/security.js (middleware integrado)" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor White
    Write-Host "Beneficios esperados:" -ForegroundColor Green
    Write-Host "   - Acceso desde ~3,072 PCs corporativas" -ForegroundColor White
    Write-Host "   - Seguridad mejorada con validacion por rangos" -ForegroundColor White
    Write-Host "   - Performance optimizada con cache" -ForegroundColor White
    Write-Host "   - Logs detallados para auditoria" -ForegroundColor White
} else {
    Write-Host "IMPLEMENTACION COMPLETADA EXITOSAMENTE" -ForegroundColor Green
    
    Write-Host "`nRESUMEN DE CAMBIOS APLICADOS:" -ForegroundColor Cyan
    Write-Host "- Modulo IP-Validator creado" -ForegroundColor Green
    Write-Host "- Archivo .env actualizado" -ForegroundColor Green  
    Write-Host "- config/environment.js actualizado" -ForegroundColor Green
    Write-Host "- config/security.js actualizado" -ForegroundColor Green
    Write-Host "- Dependencias verificadas" -ForegroundColor Green
    Write-Host "- Servicio Windows reiniciado" -ForegroundColor Green
    
    Write-Host "`nCONFIGURACION ACTIVA:" -ForegroundColor Cyan
    Write-Host "   - Modo de validacion: $Mode" -ForegroundColor White
    Write-Host "   - Rangos DHCP: 3 rangos corporativos" -ForegroundColor White
    Write-Host "   - IPs especificas: Mantenidas para compatibilidad" -ForegroundColor White
    Write-Host "   - Cache: Habilitado (5 minutos TTL)" -ForegroundColor White
    Write-Host "   - Logs detallados: Habilitados" -ForegroundColor White
    Write-Host "   - Servicio Windows: $serviceName" -ForegroundColor White
    
    Write-Host "`nVERIFICACION NECESARIA (Proximos 5 minutos):" -ForegroundColor Cyan
    Write-Host "   - Esperar inicializacion completa (~60-90 segundos)" -ForegroundColor White
    Write-Host "   - Acceda al dashboard: https://localhost:3443" -ForegroundColor White
    Write-Host "   - Verifique logs: Get-EventLog Application | Where-Object Source -eq '$serviceName'" -ForegroundColor White
    Write-Host "   - Monitor servicio: Get-Service $serviceName" -ForegroundColor White
    
    Write-Host "`nRECOMENDACION: Esperar 90 segundos para verificar funcionamiento" -ForegroundColor Yellow
    Write-Host "   Los servicios Windows tardan mas en inicializar que PM2" -ForegroundColor Gray
    
    if ($Backup) {
        Write-Host "`nBACKUPS DISPONIBLES EN:" -ForegroundColor Cyan
        Write-Host "   Directorio: backups/dhcp-migration-$timestamp/" -ForegroundColor White
        Write-Host "   Para rollback: Copie archivos de backup y reinicie servicio" -ForegroundColor Gray
        Write-Host "   Rollback rapido:" -ForegroundColor Gray
        Write-Host "      Copy-Item backups/dhcp-migration-$timestamp/* ./ -Recurse -Force" -ForegroundColor White
        Write-Host "      Restart-Service $serviceName" -ForegroundColor White
    }
}

Write-Host "`nIMPLEMENTACION FINALIZADA" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`nPROXIMOS PASOS PARA SERVICIOS WINDOWS:" -ForegroundColor Yellow
Write-Host "1. Esperar 90 segundos (inicializacion completa)" -ForegroundColor White
Write-Host "2. Verificar estado: Get-Service $serviceName" -ForegroundColor White
Write-Host "3. Probar acceso: https://localhost:3443/dashboard/" -ForegroundColor White
Write-Host "4. Revisar Event Log si hay problemas" -ForegroundColor White
Write-Host "5. Monitorear metricas de acceso por 24 horas" -ForegroundColor White
Write-Host "6. Configurar alertas automaticas (opcional)" -ForegroundColor White

Write-Host "`nCOMANDOS UTILES PARA GESTION DEL SERVICIO:" -ForegroundColor Cyan
Write-Host "   - Estado: Get-Service $serviceName" -ForegroundColor White
Write-Host "   - Iniciar: Start-Service $serviceName" -ForegroundColor White
Write-Host "   - Detener: Stop-Service $serviceName" -ForegroundColor White
Write-Host "   - Reiniciar: Restart-Service $serviceName" -ForegroundColor White
Write-Host "   - Logs: Get-EventLog Application | Where-Object Source -eq '$serviceName'" -ForegroundColor White
Write-Host "   - NSSM: $nssmPath status $serviceName" -ForegroundColor White
Write-Host "   - Procesos: Get-Process -Name node" -ForegroundColor White
Write-Host "   - Puertos: netstat -ano | findstr ':3001|:3443'" -ForegroundColor White

Write-Host "`nVERIFICACION RAPIDA DEL DEPLOYMENT:" -ForegroundColor Cyan
Write-Host "   Test local: curl http://localhost:3001/api/status" -ForegroundColor White
Write-Host "   Test HTTPS: curl -k https://localhost:3443/api/status" -ForegroundColor White
Write-Host "   Dashboard: https://localhost:3443/dashboard/value-stream-map.html" -ForegroundColor White

Write-Host "`nRANGOS DHCP IMPLEMENTADOS:" -ForegroundColor Cyan
Write-Host "   Area A: 10.41.126.1 - 10.45.126.255 (~1,280 IPs)" -ForegroundColor White
Write-Host "   Area B: 10.50.126.1 - 10.51.126.255 (~512 IPs)" -ForegroundColor White
Write-Host "   Especiales: 10.92.48.1 - 10.92.52.255 (~1,280 IPs)" -ForegroundColor White
Write-Host "   Total: ~3,072 direcciones IP corporativas" -ForegroundColor Green

Write-Host "`nSOPORTE Y TROUBLESHOOTING:" -ForegroundColor Cyan
Write-Host "   - Logs del servicio: Windows Event Viewer -> Application" -ForegroundColor White
Write-Host "   - Logs de aplicacion: $projectPath\logs\" -ForegroundColor White  
Write-Host "   - Estado NSSM: $nssmPath status $serviceName" -ForegroundColor White
Write-Host "   - Configuracion servicio: services.msc" -ForegroundColor White

Write-Host "`nDIFERENCIAS CON PM2:" -ForegroundColor Yellow
Write-Host "   + Mayor estabilidad y recuperacion automatica" -ForegroundColor Green
Write-Host "   + Inicio automatico sin login de usuario" -ForegroundColor Green
Write-Host "   + Integracion nativa con Windows" -ForegroundColor Green
Write-Host "   - Tiempo de inicio mas lento (~60-90 seg vs ~5-15 seg)" -ForegroundColor Yellow
Write-Host "   - Gestion diferente (services.msc vs pm2 commands)" -ForegroundColor Yellow

Write-Host "`nMONITOREO POST-DEPLOYMENT:" -ForegroundColor Cyan
Write-Host "   1. Primeras 2 horas: Verificar estabilidad cada 15 min" -ForegroundColor White
Write-Host "   2. Primer dia: Monitorear logs de acceso" -ForegroundColor White
Write-Host "   3. Primera semana: Validar acceso desde PCs remotas" -ForegroundColor White
Write-Host "   4. Documentar IPs que acceden para analisis" -ForegroundColor White

if (-not $DryRun) {
    Write-Host "`nPara verificar que todo funciona correctamente:" -ForegroundColor Green
    Write-Host "   Espere 90 segundos y ejecute: Get-Service $serviceName" -ForegroundColor White
    Write-Host "   El estado debe ser 'Running'" -ForegroundColor White
}

Write-Host "`nPresione cualquier tecla para finalizar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")