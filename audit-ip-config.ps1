# =============================================================================
# AUDITORIA COMPLETA - Configuracion de IPs en Dashboard VSM
# Mapeo de todos los archivos que controlan acceso por IP
# =============================================================================

Write-Host "=============================================" -ForegroundColor Green
Write-Host "AUDITORIA: CONFIGURACION DE IPs AUTORIZADAS" -ForegroundColor Green
Write-Host "Dashboard VSM BorgWarner" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Navegar al directorio del proyecto
$projectPath = "C:\Aplicaciones\mi-servidor-web"
if (-not (Test-Path $projectPath)) {
    Write-Host "ERROR: Directorio no encontrado: $projectPath" -ForegroundColor Red
    exit 1
}

Set-Location $projectPath
Write-Host "Directorio base: $projectPath" -ForegroundColor White

# Funcion para analizar contenido de archivos
function Analyze-IPConfiguration {
    param(
        [string]$FilePath,
        [string]$Description
    )
    
    Write-Host "`nARCHIVO: $FilePath" -ForegroundColor Cyan
    Write-Host "   Descripcion: $Description" -ForegroundColor Yellow
    
    if (Test-Path $FilePath) {
        Write-Host "   Estado: EXISTE" -ForegroundColor Green
        
        # Leer contenido del archivo
        $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
        
        if ($content) {
            # Buscar patrones relacionados con IPs
            $ipPatterns = @(
                "ALLOWED_IPS",
                "allowedIPs",
                "allowed_ips",
                "IP.*permit",
                "permit.*IP",
                "127\.0\.0\.1",
                "10\.42\.126\.12",
                "10\.43\.126\.200",
                "10\.43\.126\.22",
                "localhost",
                "::1"
            )
            
            $foundPatterns = @()
            
            foreach ($pattern in $ipPatterns) {
                $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                if ($matches.Count -gt 0) {
                    $foundPatterns += "$pattern ($($matches.Count) ocurrencias)"
                }
            }
            
            if ($foundPatterns.Count -gt 0) {
                Write-Host "   Patrones IP encontrados:" -ForegroundColor Yellow
                $foundPatterns | ForEach-Object { Write-Host "     + $_" -ForegroundColor White }
                
                # Extraer lineas especificas con configuracion de IPs
                $lines = $content -split "`n"
                $relevantLines = @()
                
                for ($i = 0; $i -lt $lines.Length; $i++) {
                    $line = $lines[$i].Trim()
                    if ($line -match "(ALLOWED_IPS|allowedIPs|allowed_ips)" -and $line -notmatch "^\s*//") {
                        $relevantLines += "     Linea $($i+1): $line"
                    }
                }
                
                if ($relevantLines.Count -gt 0) {
                    Write-Host "   Lineas de configuracion:" -ForegroundColor Yellow
                    $relevantLines | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
                }
            } else {
                Write-Host "   NO se encontraron configuraciones de IP" -ForegroundColor Red
            }
        } else {
            Write-Host "   Archivo vacio o no se pudo leer" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   Estado: NO EXISTE" -ForegroundColor Red
    }
}

# Lista de archivos a auditar
$filesToAudit = @(
    @{
        Path = ".env"
        Description = "Variables de entorno principales - Configuracion de IPs permitidas"
    },
    @{
        Path = ".env.example"
        Description = "Plantilla de variables de entorno"
    },
    @{
        Path = "config/environment.js"
        Description = "Configuracion de entorno de Node.js - Procesamiento de IPs"
    },
    @{
        Path = "config/security.js"
        Description = "Middleware de seguridad - Filtrado y validacion de IPs"
    },
    @{
        Path = "server.js"
        Description = "Servidor principal - Configuracion de seguridad"
    },
    @{
        Path = "server-https.js"
        Description = "Servidor HTTPS - Configuracion de seguridad"
    },
    @{
        Path = "config/database.js"
        Description = "Configuracion de base de datos"
    },
    @{
        Path = "config/logger.js"
        Description = "Configuracion de logging"
    },
    @{
        Path = "ecosystem.config.js"
        Description = "Configuracion PM2 - HTTP"
    },
    @{
        Path = "ecosystem-https.config.js"
        Description = "Configuracion PM2 - HTTPS"
    },
    @{
        Path = "package.json"
        Description = "Configuracion del proyecto"
    }
)

Write-Host "`nINICIANDO AUDITORIA DE ARCHIVOS..." -ForegroundColor White
Write-Host "================================================" -ForegroundColor White

# Auditar cada archivo
foreach ($file in $filesToAudit) {
    Analyze-IPConfiguration -FilePath $file.Path -Description $file.Description
}

Write-Host "`nBUSCANDO ARCHIVOS ADICIONALES..." -ForegroundColor White
Write-Host "================================================" -ForegroundColor White

# Buscar archivos adicionales que puedan contener configuracion de IPs
$additionalSearchPaths = @(
    "routes/*.js",
    "middleware/*.js",
    "config/*.js",
    "public/js/*.js",
    "*.json"
)

foreach ($searchPath in $additionalSearchPaths) {
    $files = Get-ChildItem -Path $searchPath -ErrorAction SilentlyContinue
    
    if ($files) {
        Write-Host "`nArchivos adicionales en: $searchPath" -ForegroundColor Cyan
        
        foreach ($file in $files) {
            if ($file.Name -notin @("package.json", "package-lock.json")) {
                $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                
                if ($content -and ($content -match "ALLOWED_IPS|allowedIPs|127\.0\.0\.1|10\.42\.126|10\.43\.126")) {
                    Write-Host "   $($file.Name) - CONTIENE CONFIGURACION DE IP" -ForegroundColor Yellow
                    
                    # Mostrar lineas relevantes
                    $lines = $content -split "`n"
                    for ($i = 0; $i -lt $lines.Length; $i++) {
                        $line = $lines[$i].Trim()
                        if ($line -match "(ALLOWED_IPS|allowedIPs|127\.0\.0\.1|10\.42\.126|10\.43\.126)" -and $line -notmatch "^\s*//") {
                            Write-Host "       Linea $($i+1): $line" -ForegroundColor Cyan
                        }
                    }
                }
            }
        }
    }
}

Write-Host "`nVERIFICANDO CONFIGURACIONES DE FIREWALL..." -ForegroundColor White
Write-Host "================================================" -ForegroundColor White

try {
    # Verificar reglas de firewall relacionadas con el proyecto
    $firewallRules = Get-NetFirewallRule | Where-Object { 
        $_.DisplayName -match "(VSM|Dashboard|Node|3001|3443)" -or 
        $_.DisplayName -match "mi-servidor-web" 
    }
    
    if ($firewallRules) {
        Write-Host "Reglas de Firewall encontradas:" -ForegroundColor Yellow
        $firewallRules | ForEach-Object { 
            Write-Host "   + $($_.DisplayName) - Estado: $($_.Enabled)" -ForegroundColor White 
        }
    } else {
        Write-Host "No se encontraron reglas de firewall especificas del proyecto" -ForegroundColor Red
    }
} catch {
    Write-Host "No se pudo verificar configuracion de firewall" -ForegroundColor Yellow
}

Write-Host "`nVERIFICANDO SERVICIOS PM2 ACTIVOS..." -ForegroundColor White
Write-Host "================================================" -ForegroundColor White

try {
    $pm2Status = pm2 jlist 2>$null | ConvertFrom-Json
    
    if ($pm2Status) {
        Write-Host "Servicios PM2 activos:" -ForegroundColor Yellow
        $pm2Status | ForEach-Object {
            Write-Host "   + $($_.name) - Estado: $($_.pm2_env.status) - Puerto: $($_.pm2_env.PORT)" -ForegroundColor White
        }
    } else {
        Write-Host "No se encontraron servicios PM2 activos" -ForegroundColor Red
    }
} catch {
    Write-Host "No se pudo obtener informacion de PM2" -ForegroundColor Yellow
}

Write-Host "`nVERIFICANDO PUERTOS ACTIVOS..." -ForegroundColor White
Write-Host "================================================" -ForegroundColor White

try {
    # Verificar puertos 3001 y 3443
    $port3001 = Get-NetTCPConnection -LocalPort 3001 -State Listen -ErrorAction SilentlyContinue
    $port3443 = Get-NetTCPConnection -LocalPort 3443 -State Listen -ErrorAction SilentlyContinue
    
    if ($port3001) {
        Write-Host "Puerto 3001: ACTIVO - Proceso: $($port3001.OwningProcess)" -ForegroundColor Green
    } else {
        Write-Host "Puerto 3001: NO ACTIVO" -ForegroundColor Red
    }
    
    if ($port3443) {
        Write-Host "Puerto 3443: ACTIVO - Proceso: $($port3443.OwningProcess)" -ForegroundColor Green
    } else {
        Write-Host "Puerto 3443: NO ACTIVO" -ForegroundColor Red
    }
    
    # Verificar conexiones desde la IP problematica
    $connections = Get-NetTCPConnection | Where-Object { $_.RemoteAddress -eq "10.43.126.22" }
    if ($connections) {
        Write-Host "Conexiones detectadas desde 10.43.126.22:" -ForegroundColor Green
        $connections | ForEach-Object { 
            Write-Host "   Estado: $($_.State), Puerto local: $($_.LocalPort)" -ForegroundColor White 
        }
    } else {
        Write-Host "No hay conexiones activas desde 10.43.126.22" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "No se pudo verificar estado de puertos" -ForegroundColor Yellow
}

Write-Host "`n=============================================" -ForegroundColor Green
Write-Host "RESUMEN DE LA AUDITORIA" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

Write-Host "`nARCHIVOS CLAVE IDENTIFICADOS:" -ForegroundColor Cyan
Write-Host "1. .env - Configuracion principal de IPs permitidas" -ForegroundColor White
Write-Host "2. config/environment.js - Procesamiento de variables de entorno" -ForegroundColor White
Write-Host "3. config/security.js - Middleware de filtrado IP" -ForegroundColor White
Write-Host "4. server.js / server-https.js - Aplicacion del middleware" -ForegroundColor White

Write-Host "`nFLUJO DE CONFIGURACION IDENTIFICADO:" -ForegroundColor Cyan
Write-Host ".env -> environment.js -> security.js -> server.js -> Cliente" -ForegroundColor Yellow

Write-Host "`nPUNTOS CRITICOS A VERIFICAR:" -ForegroundColor Red
Write-Host "+ Consistencia entre archivos de configuracion" -ForegroundColor White
Write-Host "+ Espacios en blanco en variables de entorno" -ForegroundColor White
Write-Host "+ Carga correcta del archivo .env" -ForegroundColor White
Write-Host "+ Aplicacion correcta del middleware en todos los servidores" -ForegroundColor White

Write-Host "`nPROXIMOS PASOS RECOMENDADOS:" -ForegroundColor Cyan
Write-Host "1. Verificar consistencia entre .env y environment.js" -ForegroundColor White
Write-Host "2. Confirmar que security.js esta aplicando correctamente las IPs" -ForegroundColor White
Write-Host "3. Validar que server.js y server-https.js usan el mismo middleware" -ForegroundColor White
Write-Host "4. Probar con logs de debug habilitados" -ForegroundColor White

Write-Host "`nPresiona cualquier tecla para continuar..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")