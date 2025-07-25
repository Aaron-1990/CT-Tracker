# =============================================================================
# VERIFICACION COMPLETA CONFIGURACION ENTERPRISE 24/7
# Dashboard VSM BorgWarner - Validacion sistematica
# =============================================================================

Write-Host "VERIFICACION ENTERPRISE DASHBOARD VSM BORGWARNER" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor White

$resultados = @()
$puntuacionTotal = 0
$puntuacionMaxima = 8

# =============================================================================
# 1. VERIFICAR ESTADO DASHBOARD
# =============================================================================
Write-Host "`n1. VERIFICANDO ESTADO DASHBOARD..." -ForegroundColor Cyan

try {
    $pm2Status = pm2 jlist | ConvertFrom-Json
    $dashboard = $pm2Status | Where-Object { $_.name -eq "vsm-dashboard-borgwarner" }
    
    if ($dashboard -and $dashboard.pm2_env.status -eq "online") {
        Write-Host "   OK: Dashboard online y funcionando" -ForegroundColor Green
        $resultados += "OK Dashboard VSM: ONLINE"
        $puntuacionTotal++
    } else {
        Write-Host "   ERROR: Dashboard no esta funcionando" -ForegroundColor Red
        $resultados += "ERROR Dashboard VSM: OFFLINE"
    }
} catch {
    Write-Host "   ERROR: No se puede verificar PM2" -ForegroundColor Red
    $resultados += "ERROR Dashboard VSM: ERROR PM2"
}

# =============================================================================
# 2. VERIFICAR POLITICAS DE ENERGIA
# =============================================================================
Write-Host "`n2. VERIFICANDO POLITICAS DE ENERGIA..." -ForegroundColor Cyan

try {
    $standbyAC = (powercfg /query SCHEME_CURRENT | Select-String "Standby timeout.*AC.*0x00000000")
    $hibernateAC = (powercfg /query SCHEME_CURRENT | Select-String "Hibernate timeout.*AC.*0x00000000")
    
    if ($standbyAC -and $hibernateAC) {
        Write-Host "   OK: Configurado para nunca hibernar/standby" -ForegroundColor Green
        $resultados += "OK Energia 24/7: CONFIGURADO"
        $puntuacionTotal++
    } else {
        Write-Host "   ADVERTENCIA: Politicas de energia no optimas" -ForegroundColor Yellow
        $resultados += "ADVERTENCIA Energia 24/7: PARCIAL"
    }
} catch {
    Write-Host "   ERROR: No se pueden verificar politicas de energia" -ForegroundColor Red
    $resultados += "ERROR Energia 24/7: ERROR"
}

# =============================================================================
# 3. VERIFICAR AUTO-LOGIN
# =============================================================================
Write-Host "`n3. VERIFICANDO AUTO-LOGIN..." -ForegroundColor Cyan

try {
    $autoLogin = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
    $defaultUser = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultUserName" -ErrorAction SilentlyContinue
    
    if ($autoLogin.AutoAdminLogon -eq "1" -and $defaultUser.DefaultUserName) {
        Write-Host "   OK: Auto-login configurado para usuario: $($defaultUser.DefaultUserName)" -ForegroundColor Green
        $resultados += "OK Auto-login: CONFIGURADO"
        $puntuacionTotal++
    } else {
        Write-Host "   ADVERTENCIA: Auto-login no completamente configurado" -ForegroundColor Yellow
        $resultados += "ADVERTENCIA Auto-login: PARCIAL"
    }
} catch {
    Write-Host "   ERROR: No se puede verificar auto-login" -ForegroundColor Red
    $resultados += "ERROR Auto-login: ERROR"
}

# =============================================================================
# 4. VERIFICAR FIREWALL
# =============================================================================
Write-Host "`n4. VERIFICANDO FIREWALL..." -ForegroundColor Cyan

try {
    $firewallRule = Get-NetFirewallRule -DisplayName "Dashboard VSM Puerto 3001" -ErrorAction SilentlyContinue
    
    if ($firewallRule -and $firewallRule.Enabled -eq "True") {
        Write-Host "   OK: Regla de firewall activa para puerto 3001" -ForegroundColor Green
        $resultados += "OK Firewall: CONFIGURADO"
        $puntuacionTotal++
    } else {
        Write-Host "   ERROR: Regla de firewall no encontrada" -ForegroundColor Red
        $resultados += "ERROR Firewall: NO CONFIGURADO"
    }
} catch {
    Write-Host "   ERROR: No se puede verificar firewall" -ForegroundColor Red
    $resultados += "ERROR Firewall: ERROR"
}

# =============================================================================
# 5. VERIFICAR SCRIPT STARTUP
# =============================================================================
Write-Host "`n5. VERIFICANDO SCRIPT STARTUP..." -ForegroundColor Cyan

$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\vsm-dashboard-startup.bat"

if (Test-Path $startupPath) {
    Write-Host "   OK: Script de inicio automatico encontrado" -ForegroundColor Green
    $resultados += "OK Startup Script: CONFIGURADO"
    $puntuacionTotal++
} else {
    Write-Host "   ERROR: Script de startup no encontrado" -ForegroundColor Red
    $resultados += "ERROR Startup Script: NO ENCONTRADO"
}

# =============================================================================
# 6. VERIFICAR TAREA PROGRAMADA
# =============================================================================
Write-Host "`n6. VERIFICANDO TAREA PROGRAMADA..." -ForegroundColor Cyan

try {
    $scheduledTask = Get-ScheduledTask -TaskName "VSM Dashboard Weekly Restart" -ErrorAction SilentlyContinue
    
    if ($scheduledTask -and $scheduledTask.State -eq "Ready") {
        Write-Host "   OK: Tarea de reinicio semanal configurada" -ForegroundColor Green
        $resultados += "OK Reinicio Programado: CONFIGURADO"
        $puntuacionTotal++
    } else {
        Write-Host "   ERROR: Tarea programada no encontrada o inactiva" -ForegroundColor Red
        $resultados += "ERROR Reinicio Programado: NO CONFIGURADO"
    }
} catch {
    Write-Host "   ERROR: No se puede verificar tarea programada" -ForegroundColor Red
    $resultados += "ERROR Reinicio Programado: ERROR"
}

# =============================================================================
# 7. VERIFICAR ACCESO HTTP
# =============================================================================
Write-Host "`n7. VERIFICANDO ACCESO HTTP..." -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "http://localhost:3001/api/status" -UseBasicParsing -TimeoutSec 10
    
    if ($response.StatusCode -eq 200) {
        Write-Host "   OK: Servidor respondiendo en puerto 3001" -ForegroundColor Green
        $resultados += "OK Acceso HTTP: FUNCIONANDO"
        $puntuacionTotal++
    } else {
        Write-Host "   ERROR: Servidor no responde correctamente" -ForegroundColor Red
        $resultados += "ERROR Acceso HTTP: ERROR"
    }
} catch {
    Write-Host "   ERROR: No se puede acceder al servidor" -ForegroundColor Red
    $resultados += "ERROR Acceso HTTP: NO ACCESIBLE"
}

# =============================================================================
# 8. VERIFICAR SCRIPT MONITOR
# =============================================================================
Write-Host "`n8. VERIFICANDO SCRIPT MONITOR..." -ForegroundColor Cyan

if (Test-Path ".\monitor-dashboard.bat") {
    Write-Host "   OK: Script de monitoreo disponible" -ForegroundColor Green
    $resultados += "OK Monitor Script: DISPONIBLE"
    $puntuacionTotal++
} else {
    Write-Host "   ERROR: Script de monitoreo no encontrado" -ForegroundColor Red
    $resultados += "ERROR Monitor Script: NO ENCONTRADO"
}

# =============================================================================
# RESUMEN FINAL
# =============================================================================
Write-Host "`n=================================================" -ForegroundColor White
Write-Host "RESUMEN VERIFICACION ENTERPRISE" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor White

$porcentajeCompletitud = [math]::Round(($puntuacionTotal / $puntuacionMaxima) * 100, 1)

foreach ($resultado in $resultados) {
    Write-Host "   $resultado"
}

Write-Host "`nPUNTUACION TOTAL: $puntuacionTotal / $puntuacionMaxima" -ForegroundColor White

if ($porcentajeCompletitud -ge 90) {
    Write-Host "ESTADO: CONFIGURACION ENTERPRISE COMPLETA ($porcentajeCompletitud%)" -ForegroundColor Green
    Write-Host "OK SERVIDOR 24/7 LISTO PARA PRODUCCION" -ForegroundColor Green
} elseif ($porcentajeCompletitud -ge 75) {
    Write-Host "ESTADO: CONFIGURACION MAYORMENTE COMPLETA ($porcentajeCompletitud%)" -ForegroundColor Yellow
    Write-Host "ADVERTENCIA REVISAR ELEMENTOS PENDIENTES" -ForegroundColor Yellow
} else {
    Write-Host "ESTADO: CONFIGURACION INCOMPLETA ($porcentajeCompletitud%)" -ForegroundColor Red
    Write-Host "ERROR REQUIERE CONFIGURACION ADICIONAL" -ForegroundColor Red
}

Write-Host "`nURLs DE ACCESO CONFIRMADAS:" -ForegroundColor White
Write-Host "   Local: http://localhost:3001" -ForegroundColor Gray
Write-Host "   Red:   http://10.42.126.12:3001" -ForegroundColor Gray
Write-Host "   VSM:   http://localhost:3001/dashboard/value-stream-map.html" -ForegroundColor Gray
Write-Host "   Admin: http://localhost:3001/admin" -ForegroundColor Gray

Write-Host "`nPROXIMO PASO: Probar acceso desde otra PC de la red" -ForegroundColor Cyan

pause