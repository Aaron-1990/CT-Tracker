// public/dashboard/js/dashboard-api.js
// Manejo de comunicación con el backend
// VERSIÓN COMPATIBLE - Fix para Utils y funciones de diagnóstico

/**
 * Clase para manejo de API del dashboard
 */
class DashboardAPI {
    constructor() {
        this.config = window.DashboardConfig;
        this.cache = new Map();
        this.requestId = 0;
        this.abortControllers = new Map();
        
        // ✅ FIX 1: Timeout dinámico más conservador
        this.dynamicTimeout = (this.config?.API?.TIMEOUT || 10000) * 3; // 30 segundos por defecto
        this.maxTimeout = 60000;
        this.timeoutMultiplier = 1.2;
        
        // ✅ FIX 2: Estado de salud simplificado
        this.serverHealth = {
            isHealthy: true,
            lastCheck: Date.now(),
            consecutiveFailures: 0
        };
        
        // ✅ FIX 3: Sistema de logging compatible
        this.logger = this.createCompatibleLogger();
        
        // Inicializar verificaciones después de un delay
        setTimeout(() => this.initializeHealthCheck(), 2000);
    }

    /**
     * ✅ FIX 4: Logger compatible que no depende de Utils
     */
    createCompatibleLogger() {
        return {
            log: (message, data = null) => {
                if (this.config?.DEBUG?.LOG_API_CALLS) {
                    console.log(`[DashboardAPI] ${message}`, data || '');
                }
            },
            warn: (message, data = null) => {
                console.warn(`[DashboardAPI] ${message}`, data || '');
            },
            error: (message, data = null) => {
                console.error(`[DashboardAPI] ${message}`, data || '');
            }
        };
    }

    /**
     * Verificación inicial simplificada
     */
    async initializeHealthCheck() {
        try {
            await this.checkServerHealth();
            await this.ensurePollingActive();
        } catch (error) {
            this.logger.error('Error en health check inicial:', error);
        }
    }

    /**
     * Verificar salud del servidor
     */
    async checkServerHealth() {
        try {
            const response = await fetch('/health', {
                method: 'GET',
                signal: AbortSignal.timeout(5000)
            });
            
            if (response.ok) {
                this.serverHealth.isHealthy = true;
                this.serverHealth.consecutiveFailures = 0;
                this.serverHealth.lastCheck = Date.now();
                return true;
            } else {
                throw new Error(`Health check failed: ${response.status}`);
            }
        } catch (error) {
            this.serverHealth.consecutiveFailures++;
            this.serverHealth.isHealthy = this.serverHealth.consecutiveFailures < 3;
            this.logger.warn('Server health check failed:', error.message);
            return false;
        }
    }

    /**
     * Asegurar que el polling esté activo
     */
    async ensurePollingActive() {
        try {
            const statusResponse = await fetch('/api/status', {
                signal: AbortSignal.timeout(5000)
            });
            
            if (statusResponse.ok) {
                const status = await statusResponse.json();
                
                if (!status.gpec5?.polling) {
                    this.logger.log('Polling inactivo, intentando reiniciar...');
                    
                    const startResponse = await fetch('/api/gpec5/polling/start', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        signal: AbortSignal.timeout(10000)
                    });
                    
                    if (startResponse.ok) {
                        const result = await startResponse.json();
                        this.logger.log('Polling reiniciado:', result);
                    }
                }
            }
        } catch (error) {
            this.logger.warn('Error verificando polling:', error.message);
        }
    }

    /**
     * Realizar petición HTTP con manejo de errores y reintentos
     * ✅ FIX 5: Uso del logger compatible
     */
    async makeRequest(endpoint, options = {}) {
        const requestId = ++this.requestId;
        const url = `${this.config.API.BASE_URL}${endpoint}`;
        
        // Verificar salud del servidor para endpoints críticos
        if (endpoint.includes('/data/live') && !this.serverHealth.isHealthy) {
            await this.checkServerHealth();
        }
        
        const controller = new AbortController();
        this.abortControllers.set(requestId, controller);

        // Timeout dinámico mejorado
        let currentTimeout = this.dynamicTimeout;
        if (endpoint.includes('/data/live')) {
            currentTimeout = Math.max(currentTimeout, 30000); // Mínimo 30s para live data
        }

        const requestOptions = {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'X-Request-ID': requestId.toString()
            },
            signal: controller.signal,
            ...options
        };

        let attempt = 0;
        let lastError;

        while (attempt < this.config.API.RETRY_ATTEMPTS) {
            try {
                if (this.config.DEBUG.LOG_API_CALLS) {
                    this.logger.log(`Request [${requestId}] Attempt ${attempt + 1}:`, {
                        url,
                        timeout: currentTimeout
                    });
                }

                const response = await Promise.race([
                    fetch(url, requestOptions),
                    this.createTimeoutPromise(currentTimeout, requestId)
                ]);

                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }

                const data = await response.json();
                
                if (this.config.DEBUG.LOG_API_CALLS) {
                    this.logger.log(`Response [${requestId}]:`, {
                        status: response.status,
                        hasData: !!data
                    });
                }

                // Resetear timeout en caso de éxito
                if (this.dynamicTimeout > (this.config?.API?.TIMEOUT || 10000) * 3) {
                    this.dynamicTimeout = Math.max(
                        this.dynamicTimeout * 0.9, 
                        (this.config?.API?.TIMEOUT || 10000) * 3
                    );
                }

                this.serverHealth.isHealthy = true;
                this.serverHealth.consecutiveFailures = 0;
                this.abortControllers.delete(requestId);
                
                return {
                    success: true,
                    data: data,
                    timestamp: new Date(),
                    requestId
                };

            } catch (error) {
                lastError = error;
                attempt++;

                if (error.name === 'AbortError') {
                    this.logger.log(`Request [${requestId}] aborted`);
                    break;
                }

                if (error.message.includes('timeout')) {
                    this.dynamicTimeout = Math.min(this.dynamicTimeout * this.timeoutMultiplier, this.maxTimeout);
                    currentTimeout = this.dynamicTimeout;
                    
                    this.logger.warn(`Request [${requestId}] timeout, aumentando a ${currentTimeout}ms`);
                    
                    if (endpoint.includes('/data/live')) {
                        setTimeout(() => this.ensurePollingActive(), 1000);
                    }
                }

                if (attempt < this.config.API.RETRY_ATTEMPTS) {
                    const retryDelay = this.config.API.RETRY_DELAY * attempt;
                    this.logger.log(`Request [${requestId}] failed, retrying in ${retryDelay}ms...`, error.message);
                    await this.delay(retryDelay);
                } else {
                    this.logger.error(`Request [${requestId}] failed after ${this.config.API.RETRY_ATTEMPTS} attempts:`, error);
                    this.serverHealth.consecutiveFailures++;
                }
            }
        }

        this.abortControllers.delete(requestId);

        return {
            success: false,
            error: lastError.message,
            timestamp: new Date(),
            requestId,
            serverHealth: this.serverHealth.isHealthy
        };
    }

    /**
     * Crear promesa de timeout
     */
    createTimeoutPromise(timeoutMs = null, requestId = null) {
        const timeout = timeoutMs || this.dynamicTimeout;
        
        return new Promise((_, reject) => {
            setTimeout(() => {
                const message = `Request${requestId ? ` [${requestId}]` : ''} timeout after ${timeout}ms`;
                reject(new Error(message));
            }, timeout);
        });
    }

    /**
     * Delay helper
     */
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * Cancelar petición específica
     */
    cancelRequest(requestId) {
        const controller = this.abortControllers.get(requestId);
        if (controller) {
            controller.abort();
            this.abortControllers.delete(requestId);
        }
    }

    /**
     * Cancelar todas las peticiones pendientes
     */
    cancelAllRequests() {
        for (const [id, controller] of this.abortControllers) {
            controller.abort();
        }
        this.abortControllers.clear();
    }

    /**
     * Obtener datos en tiempo real de la línea
     * ✅ FIX 6: Sin dependencias de Utils
     */
    async getLiveData() {
        const cacheKey = 'liveData';
        const cached = this.cache.get(cacheKey);
        
        // Usar cache si es reciente (menos de 10 segundos)
        if (cached && (Date.now() - cached.timestamp) < 10000) {
            if (this.config.DEBUG.LOG_API_CALLS) {
                this.logger.log('Using cached live data');
            }
            return cached;
        }

        try {
            const result = await this.makeRequest(this.config.API.ENDPOINTS.LIVE_DATA);
            
            if (result.success) {
                this.cache.set(cacheKey, result);
                
                // Validar datos básicamente
                const validation = this.validateLineData(result.data);
                if (!validation.valid) {
                    this.logger.warn('Live data validation failed:', validation.error);
                }
            } else {
                this.logger.error('Live data request failed:', result.error);
                
                // Diagnóstico automático en caso de fallo
                setTimeout(async () => {
                    await this.checkServerHealth();
                    await this.ensurePollingActive();
                }, 2000);
            }
            
            return result;
            
        } catch (error) {
            this.logger.error('Error in getLiveData:', error);
            throw error;
        }
    }

    /**
     * Obtener configuración de equipos
     */
    async getConfiguration() {
        const cacheKey = 'configuration';
        const cached = this.cache.get(cacheKey);
        
        if (cached && (Date.now() - cached.timestamp) < 300000) {
            return cached;
        }

        const result = await this.makeRequest(this.config.API.ENDPOINTS.CONFIGURATION);
        
        if (result.success) {
            this.cache.set(cacheKey, result);
        }
        
        return result;
    }

    /**
     * Obtener datos de proceso específico
     */
    async getProcessData(processName) {
        const result = await this.makeRequest(`${this.config.API.ENDPOINTS.PROCESS_DATA}/${processName}`);
        return result;
    }

    /**
     * Obtener estadísticas del sistema
     */
    async getSystemStats() {
        const result = await this.makeRequest(this.config.API.ENDPOINTS.STATS);
        return result;
    }

    /**
     * Validar respuesta de API
     */
    validateApiResponse(response) {
        if (!response) {
            return { valid: false, error: 'No response received' };
        }

        if (!response.success) {
            return { valid: false, error: response.error || 'API request failed' };
        }

        if (!response.data) {
            return { valid: false, error: 'No data in response' };
        }

        return { valid: true };
    }

    /**
     * Validar datos de línea
     */
    validateLineData(lineData) {
        if (!lineData) {
            return { valid: false, error: 'No line data' };
        }

        if (!lineData.processes || !Array.isArray(lineData.processes)) {
            return { valid: false, error: 'Invalid processes data' };
        }

        if (lineData.processes.length === 0) {
            return { valid: false, error: 'No processes found' };
        }

        return { valid: true };
    }

    /**
     * Limpiar cache
     */
    clearCache() {
        this.cache.clear();
        this.logger.log('API cache cleared');
    }

    /**
     * Obtener estadísticas del cache
     */
    getCacheStats() {
        return {
            size: this.cache.size,
            keys: Array.from(this.cache.keys()),
            pendingRequests: this.abortControllers.size,
            currentTimeout: this.dynamicTimeout,
            serverHealth: this.serverHealth
        };
    }

    /**
     * ✅ FIX 7: Diagnóstico simplificado
     */
    async runDiagnostics() {
        console.log('🔍 Ejecutando diagnóstico completo...');
        
        const results = {
            serverHealth: await this.checkServerHealth(),
            pollingActive: false,
            endpointsStatus: {}
        };
        
        // Verificar endpoints básicos
        const endpoints = ['/health', '/api/status'];
        
        for (const endpoint of endpoints) {
            try {
                const response = await fetch(endpoint, { signal: AbortSignal.timeout(5000) });
                results.endpointsStatus[endpoint] = {
                    status: response.status,
                    ok: response.ok
                };
            } catch (error) {
                results.endpointsStatus[endpoint] = {
                    error: error.message
                };
            }
        }
        
        // Verificar polling
        try {
            const statusResponse = await fetch('/api/status');
            if (statusResponse.ok) {
                const status = await statusResponse.json();
                results.pollingActive = status.gpec5?.polling || false;
            }
        } catch (error) {
            results.pollingError = error.message;
        }
        
        console.log('📊 Resultados del diagnóstico:', results);
        return results;
    }
}

// ✅ FIX 8: Funciones globales de reparación
window.repararPolling = async function() {
    console.log('🔧 Reparando polling GPEC5...');
    
    try {
        // Detener polling
        const stopResponse = await fetch('/api/gpec5/polling/stop', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        const stopResult = await stopResponse.json();
        console.log('⏹️ Stop result:', stopResult);
        
        // Esperar 3 segundos
        await new Promise(resolve => setTimeout(resolve, 3000));
        
        // Iniciar polling
        const startResponse = await fetch('/api/gpec5/polling/start', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        const startResult = await startResponse.json();
        console.log('▶️ Start result:', startResult);
        
        if (startResult.success) {
            console.log('✅ Polling reparado exitosamente');
            
            // Limpiar cache y recargar
            if (window.dashboardAPI) {
                window.dashboardAPI.clearCache();
            }
            setTimeout(() => {
                console.log('🔄 Recargando página...');
                window.location.reload();
            }, 2000);
        } else {
            console.error('❌ Error reparando polling:', startResult.error);
        }
        
    } catch (error) {
        console.error('❌ Error en reparación de polling:', error);
    }
};

window.verificarServidor = async function() {
    console.log('🔍 Verificando estado del servidor...');
    
    const endpoints = [
        { url: '/health', descripcion: 'Health Check' },
        { url: '/api/status', descripcion: 'Status API' },
        { url: '/api/gpec5/configuration', descripcion: 'GPEC5 Config' },
        { url: '/api/gpec5/data/live', descripcion: 'Live Data' }
    ];
    
    for (const endpoint of endpoints) {
        try {
            const startTime = Date.now();
            const response = await fetch(endpoint.url, {
                signal: AbortSignal.timeout(15000)
            });
            const endTime = Date.now();
            
            if (response.ok) {
                console.log(`✅ ${endpoint.descripcion}: OK en ${endTime - startTime}ms`);
            } else {
                console.warn(`⚠️ ${endpoint.descripcion}: ${response.status} en ${endTime - startTime}ms`);
            }
        } catch (error) {
            console.error(`❌ ${endpoint.descripcion}: ${error.message}`);
        }
    }
};

window.ajustarTimeout = function(nuevoTimeout) {
    if (!window.dashboardAPI) {
        console.error('❌ dashboardAPI no disponible');
        return;
    }
    
    const timeoutAnterior = window.dashboardAPI.dynamicTimeout;
    window.dashboardAPI.dynamicTimeout = nuevoTimeout;
    
    console.log(`⏱️ Timeout ajustado: ${timeoutAnterior}ms → ${nuevoTimeout}ms`);
};

// Crear instancia global
window.dashboardAPI = new DashboardAPI();

// Auto-verificación al cargar
document.addEventListener('DOMContentLoaded', () => {
    setTimeout(() => {
        if (window.dashboardAPI && typeof window.dashboardAPI.runDiagnostics === 'function') {
            window.dashboardAPI.runDiagnostics().catch(console.error);
        }
    }, 3000);
});

console.log('🔧 Dashboard API compatible cargado con funciones de reparación globales');