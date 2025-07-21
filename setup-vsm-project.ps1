# install-dependencies-fixed.ps1
# Script corregido para instalar dependencias del proyecto VSM

Write-Host "📦 Instalando dependencias del proyecto VSM..." -ForegroundColor Green

# Verificar que estamos en el directorio correcto
if (!(Test-Path "package.json")) {
    Write-Host "❌ Error: No se encontró package.json" -ForegroundColor Red
    exit 1
}

Write-Host "`n🧹 Limpiando instalación anterior..." -ForegroundColor Yellow
if (Test-Path "node_modules") {
    Remove-Item -Recurse -Force "node_modules"
    Write-Host "✅ node_modules eliminado" -ForegroundColor Green
}

if (Test-Path "package-lock.json") {
    Remove-Item -Force "package-lock.json"
    Write-Host "✅ package-lock.json eliminado" -ForegroundColor Green
}

Write-Host "`n📥 Instalando dependencias principales en lote..." -ForegroundColor Cyan

# Instalar todas las dependencias principales de una vez
$mainDependencies = @(
    "simple-statistics",
    "mathjs", 
    "node-cache",
    "async",
    "validator",
    "multer",
    "joi",
    "helmet",
    "compression",
    "express-rate-limit",
    "uuid",
    "moment"
)

$dependencyString = $mainDependencies -join " "
Write-Host "Ejecutando: npm install $dependencyString" -ForegroundColor Gray

try {
    $result = npm install $dependencyString 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Dependencias principales instaladas exitosamente" -ForegroundColor Green
    } else {
        Write-Host "❌ Error instalando dependencias principales:" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Excepción instalando dependencias: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n📥 Instalando dependencias de desarrollo..." -ForegroundColor Cyan

$devDependencies = @(
    "nodemon",
    "jest", 
    "supertest",
    "@types/node",
    "eslint",
    "eslint-config-standard",
    "eslint-plugin-import",
    "eslint-plugin-node",
    "eslint-plugin-promise",
    "prettier",
    "@faker-js/faker",
    "sinon"
)

$devDependencyString = $devDependencies -join " "
Write-Host "Ejecutando: npm install --save-dev $devDependencyString" -ForegroundColor Gray

try {
    $result = npm install --save-dev $devDependencyString 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Dependencias de desarrollo instaladas exitosamente" -ForegroundColor Green
    } else {
        Write-Host "❌ Error instalando dependencias de desarrollo:" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Excepción instalando dependencias dev: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🔍 Verificando instalación..." -ForegroundColor Yellow

# Verificar que se instalaron correctamente
Write-Host "📊 Verificando dependencias críticas..." -ForegroundColor Cyan

$criticalDeps = @(
    "express",
    "pg", 
    "simple-statistics",
    "mathjs",
    "joi",
    "helmet"
)

foreach ($dep in $criticalDeps) {
    try {
        $version = npm list $dep --depth=0 2>$null | Select-String "$dep@"
        if ($version) {
            Write-Host "✅ $dep: $($version.ToString().Split('@')[1])" -ForegroundColor Green
        } else {
            Write-Host "❌ $dep: No instalado" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ $dep: Error verificando" -ForegroundColor Red
    }
}

Write-Host "`n📋 Resumen de la instalación:" -ForegroundColor Yellow

# Mostrar resumen final
try {
    $packageJson = Get-Content "package.json" | ConvertFrom-Json
    $depCount = if ($packageJson.dependencies) { $packageJson.dependencies.PSObject.Properties.Count } else { 0 }
    $devDepCount = if ($packageJson.devDependencies) { $packageJson.devDependencies.PSObject.Properties.Count } else { 0 }
    
    Write-Host "📦 Dependencias de producción: $depCount" -ForegroundColor Cyan
    Write-Host "🛠️  Dependencias de desarrollo: $devDepCount" -ForegroundColor Cyan
    Write-Host "📊 Total: $($depCount + $devDepCount)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Error leyendo package.json" -ForegroundColor Red
}

# Verificar node_modules
if (Test-Path "node_modules") {
    $nodeModulesSize = (Get-ChildItem "node_modules" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "📁 Tamaño de node_modules: $([math]::Round($nodeModulesSize, 2)) MB" -ForegroundColor Cyan
} else {
    Write-Host "❌ Directorio node_modules no encontrado" -ForegroundColor Red
}

Write-Host "`n🚀 Instalación completada" -ForegroundColor Green
Write-Host "💡 Próximo paso: configurar .env y ejecutar npm run dev" -ForegroundColor Yellow