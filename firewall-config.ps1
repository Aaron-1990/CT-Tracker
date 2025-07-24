# CONFIGURACION DE FIREWALL WINDOWS - DASHBOARD VSM BORGWARNER
Write-Host "Configurando Firewall para Dashboard VSM BorgWarner..." -ForegroundColor Green

# Eliminar regla existente si existe
$existingRule = Get-NetFirewallRule -DisplayName "VSM Dashboard BorgWarner" -ErrorAction SilentlyContinue
if ($existingRule) {
    Write-Host "Eliminando regla existente..." -ForegroundColor Yellow
    Remove-NetFirewallRule -DisplayName "VSM Dashboard BorgWarner"
}

# Crear nueva regla de firewall
Write-Host "Creando regla de firewall para puerto 3001..." -ForegroundColor Cyan

New-NetFirewallRule -DisplayName "VSM Dashboard BorgWarner" -Direction Inbound -Protocol TCP -LocalPort 3001 -Action Allow -Profile Domain,Private -Description "Dashboard VSM para monitoreo BorgWarner" -RemoteAddress "10.42.126.0/24","10.43.126.0/24","10.45.126.0/24","127.0.0.1"

# Verificar creacion
$newRule = Get-NetFirewallRule -DisplayName "VSM Dashboard BorgWarner"
if ($newRule) {
    Write-Host "Regla de firewall creada exitosamente" -ForegroundColor Green
    Write-Host "Puerto 3001 TCP habilitado para redes corporativas" -ForegroundColor White
} else {
    Write-Host "Error al crear la regla de firewall" -ForegroundColor Red
}

# Configurar Node.js
$nodePath = "C:\Program Files\nodejs\node.exe"
if (Test-Path $nodePath) {
    New-NetFirewallRule -DisplayName "Node.js VSM BorgWarner" -Direction Inbound -Program $nodePath -Action Allow -Profile Domain,Private -Description "Node.js para Dashboard VSM"
    Write-Host "Node.js configurado en firewall" -ForegroundColor Green
} else {
    Write-Host "Node.js no encontrado en ruta estandar" -ForegroundColor Yellow
}

Write-Host "CONFIGURACION COMPLETADA" -ForegroundColor Green
Write-Host "Ejecuta: node server.js para iniciar el servidor" -ForegroundColor Cyan