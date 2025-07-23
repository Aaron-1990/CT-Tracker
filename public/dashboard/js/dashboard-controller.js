// public/dashboard/js/dashboard-controller.js
// Controlador principal del dashboard - Solo lógica de negocio

/**
 * Controlador principal del dashboard VSM
 * Maneja el estado y coordinación entre componentes
 */
class DashboardController {
    constructor() {
        this.config = window.DashboardConfig;
        this.api = window.dashboardAPI;
        this.renderer = window.dashboardRenderer;
        
        // Estado del controlador
        this.state = {
            initialized: false,
            connected: false,
            loading: true,
            error: false,
            processes: [],
            summary: null,
            lastUpdate: null
        };
        
        // Control de actualizaciones
        this.updateInterval = null;
        this.isUpdating = false;
        this.updateCount = 0;
        this.errorCount = 0;
        this.lastSuccessfulUpdate = null;
        
        this.config.Utils.log('Dashboard Controller creado');
    }

    /**
     * Inicializar dashboard
     */
    async init() {
        try {
            this.config.Utils.log('🚀 Inicializando Dashboard Controller...');
            
            // Verificar dependencias
            if (!this.validateDependencies()) {
                throw new Error('Dependencias requeridas no disponibles');
            }
            
            // Inicializar componentes
            this.renderer.init();
            this.setupEventListeners();
            
            // Cargar datos iniciales
            await this.performInitialLoad();
            
            // Iniciar actualizaciones automáticas
            this.startAutoUpdate();
            
            this.state.initialized = true;
            this.config.Utils.log('✅ Dashboard Controller inicializado');
            
        } catch (error) {
            this.config.Utils.error('❌ Error inicializando controller:', error);
            this.handleInitializationError(error);
            throw error;
        }
    }

    /**
     * Validar que todas las dependencias estén disponibles
     */
    validateDependencies() {
        const required = ['DashboardConfig', 'dashboardAPI', 'dashboardRenderer'];
        const missing = required.filter(dep => !window[dep]);
        
        if (missing.length > 0) {
            this.config.Utils.error('Dependencias faltantes:', missing);
            return false;
        }
        
        return true;
    }

    /**
     * Configurar event listeners
     */
    setupEventListeners() {
        // Visibilidad de página para pausar/reanudar actualizaciones
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.pauseAutoUpdate();
            } else {
                this.resumeAutoUpdate();
                this.performUpdate(); // Actualizar inmediatamente al volver
            }
        });

        // Botón de retry en modal de error
        const retryButton = document.getElementById('retry-button');
        if (retryButton) {
            retryButton.addEventListener('click', () => {
                this.hideErrorModal();
                this.performUpdate();
            });
        }

        // Atajos de teclado para debugging
        document.addEventListener('keydown', (event) => {
            if (event.ctrlKey || event.metaKey) {
                switch (event.key) {
                    case 'r':
                        if (event.shiftKey) {
                            event.preventDefault();
                            this.performUpdate();
                        }
                        break;
                    case 'd':
                        if (event.shiftKey) {
                            event.preventDefault();
                            this.toggleDebug();
                        }
                        break;
                }
            }
        });

        this.config.Utils.log('Event listeners configurados');
    }

    /**
     * Realizar carga inicial de datos
     */
    async performInitialLoad() {
        this.config.Utils.log('📡 Iniciando carga inicial de datos...');
        this.renderer.showLoading();
        this.state.loading = true;

        try {
            // Tiempo mínimo de loading para UX
            const startTime = Date.now();
            const result = await this.api.getLiveData();
            const elapsedTime = Date.now() - startTime;
            
            if (elapsedTime < this.config.UI.LOADING_MIN_TIME) {
                await this.delay(this.config.UI.LOADING_MIN_TIME - elapsedTime);
            }

            if (result.success) {
                this.handleSuccessfulDataLoad(result.data.data);
            } else {
                this.handleDataLoadError(result.error);
            }

        } catch (error) {
            this.config.Utils.error('Error en carga inicial:', error);
            this.handleDataLoadError(error.message);
        }
    }

    /**
     * Manejar carga exitosa de datos
     */
    handleSuccessfulDataLoad(data) {
        // Validar estructura de datos
        if (!data || !data.processes || !Array.isArray(data.processes)) {
            this.handleDataLoadError('Estructura de datos inválida');
            return;
        }

        // Actualizar estado
        this.state.connected = true;
        this.state.loading = false;
        this.state.error = false;
        this.state.processes = data.processes;
        this.state.summary = data.summary;
        this.state.lastUpdate = new Date();
        this.lastSuccessfulUpdate = new Date();
        this.errorCount = 0;

        // Renderizar UI
        this.renderer.renderProcessCards(data.processes);
        this.updateFooterDisplay(data);
        this.updateConnectionStatus('connected');

        this.config.Utils.log(`✅ Datos cargados: ${data.processes.length} procesos`);
    }

    /**
     * Manejar error en carga de datos
     */
    handleDataLoadError(error) {
        this.state.connected = false;
        this.state.loading = false;
        this.state.error = true;
        this.errorCount++;

        this.renderer.showError(error);
        this.updateConnectionStatus('error');
        
        this.config.Utils.error(`❌ Error carga #${this.errorCount}:`, error);
    }

    /**
     * Iniciar actualizaciones automáticas
     */
    startAutoUpdate() {
        if (this.updateInterval) {
            clearInterval(this.updateInterval);
        }

        this.updateInterval = setInterval(() => {
            this.performUpdate();
        }, this.config.UPDATE.INTERVAL);

        this.config.Utils.log(`🔄 Auto-actualización iniciada cada ${this.config.UPDATE.INTERVAL / 1000}s`);
    }

    /**
     * Pausar actualizaciones automáticas
     */
    pauseAutoUpdate() {
        if (this.updateInterval) {
            clearInterval(this.updateInterval);
            this.updateInterval = null;
        }
        this.config.Utils.log('⏸️ Auto-actualización pausada');
    }

    /**
     * Reanudar actualizaciones automáticas
     */
    resumeAutoUpdate() {
        if (!this.updateInterval) {
            this.startAutoUpdate();
            this.config.Utils.log('▶️ Auto-actualización reanudada');
        }
    }

    /**
     * Realizar actualización de datos
     */
    async performUpdate() {
        if (this.isUpdating) {
            this.config.Utils.log('⏭️ Saltando actualización - ya en progreso');
            return;
        }

        this.isUpdating = true;
        this.updateCount++;

        try {
            if (this.config.DEBUG.LOG_UPDATES) {
                this.config.Utils.log(`🔄 Actualización #${this.updateCount}`);
            }

            const result = await this.api.getLiveData();

            if (result.success) {
                this.handleSuccessfulUpdate(result.data.data);
            } else {
                this.handleUpdateError(result.error);
            }

        } catch (error) {
            this.handleUpdateError(error.message);
        } finally {
            this.isUpdating = false;
        }
    }

    /**
     * Manejar actualización exitosa
     */
    handleSuccessfulUpdate(data) {
        if (!data || !data.processes || !Array.isArray(data.processes)) {
            this.handleUpdateError('Datos inválidos recibidos');
            return;
        }

        // Actualizar estado
        this.state.connected = true;
        this.state.error = false;
        this.state.processes = data.processes;
        this.state.summary = data.summary;
        this.state.lastUpdate = new Date();
        this.lastSuccessfulUpdate = new Date();
        this.errorCount = 0;

        // Actualizar UI
        if (this.renderer.getLastRenderData()) {
            // Ya hay datos renderizados, solo actualizar métricas
            this.renderer.updateMetricsWithAnimation(data.processes);
        } else {
            // Primera renderización completa
            this.renderer.renderProcessCards(data.processes);
        }

        this.updateFooterDisplay(data);
        this.updateConnectionStatus('connected');

        if (this.config.DEBUG.LOG_UPDATES) {
            this.config.Utils.log(`✅ Actualización #${this.updateCount} completada`);
        }
    }

    /**
     * Manejar error en actualización
     */
    handleUpdateError(error) {
        this.state.connected = false;
        this.state.error = true;
        this.errorCount++;

        this.updateConnectionStatus('error');
        
        // Mostrar error modal solo después de varios fallos consecutivos
        if (this.errorCount >= 3) {
            this.showErrorModal(error);
        }

        this.config.Utils.error(`❌ Error actualización #${this.updateCount}:`, error);
    }

    /**
     * Actualizar display del footer
     */
    updateFooterDisplay(data) {
        const lastUpdate = this.config.Utils.formatTimestamp(data.timestamp);
        this.updateElementText('lastUpdate', lastUpdate);
        this.updateElementText('activeEquipments', data.totalEquipments || '--');
        this.updateElementText('processingStatus', this.state.connected ? 'Activo' : 'Error');
    }

    /**
     * Actualizar estado de conexión visual
     */
    updateConnectionStatus(status) {
        const statusElement = document.getElementById('connection-status');
        const indicators = document.querySelectorAll('.status-indicator');

        const statusMap = {
            'connecting': { text: 'Conectando...', color: this.config.STATUS_COLORS.WARNING },
            'connected': { text: 'Datos en Tiempo Real', color: this.config.STATUS_COLORS.ONLINE },
            'error': { text: 'Error de Conexión', color: this.config.STATUS_COLORS.ERROR },
            'offline': { text: 'Sin Conexión', color: this.config.STATUS_COLORS.OFFLINE }
        };

        const statusConfig = statusMap[status] || statusMap.offline;

        if (statusElement) {
            statusElement.textContent = statusConfig.text;
        }

        indicators.forEach(indicator => {
            indicator.style.backgroundColor = statusConfig.color;
        });
    }

    /**
     * Mostrar modal de error
     */
    showErrorModal(error) {
        const modal = document.getElementById('error-modal');
        const errorMessage = document.getElementById('error-message');
        
        if (modal && errorMessage) {
            errorMessage.textContent = error || this.config.MESSAGES.ERROR_CONNECTION;
            modal.classList.remove('hidden');
        }
    }

    /**
     * Ocultar modal de error
     */
    hideErrorModal() {
        const modal = document.getElementById('error-modal');
        if (modal) {
            modal.classList.add('hidden');
        }
    }

    /**
     * Actualizar texto de elemento
     */
    updateElementText(elementId, newText) {
        const element = document.getElementById(elementId);
        if (element && element.textContent !== newText) {
            element.textContent = newText;
        }
    }

    /**
     * Toggle debug mode
     */
    toggleDebug() {
        this.config.DEBUG.ENABLED = !this.config.DEBUG.ENABLED;
        console.log(`🔧 Debug mode ${this.config.DEBUG.ENABLED ? 'enabled' : 'disabled'}`);
        
        if (this.config.DEBUG.ENABLED) {
            console.log('📊 Dashboard State:', this.getState());
        }
    }

    /**
     * Manejar error de inicialización
     */
    handleInitializationError(error) {
        this.renderer.showError('Error de inicialización del dashboard');
        this.updateConnectionStatus('error');
        this.showErrorModal(error.message);
    }

    /**
     * Delay helper
     */
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * Obtener estado actual del dashboard
     */
    getState() {
        return {
            ...this.state,
            updateCount: this.updateCount,
            errorCount: this.errorCount,
            lastSuccessfulUpdate: this.lastSuccessfulUpdate,
            isUpdating: this.isUpdating
        };
    }

    /**
     * Obtener estadísticas del dashboard
     */
    getStats() {
        return {
            state: this.getState(),
            api: this.api.getCacheStats(),
            renderer: this.renderer.getLastRenderData()
        };
    }

    /**
     * Limpiar recursos y destruir controlador
     */
    destroy() {
        this.pauseAutoUpdate();
        this.api.cancelAllRequests();
        this.renderer.clear();
        this.state.initialized = false;
        this.config.Utils.log('🗑️ Dashboard Controller destruido');
    }
}

// Hacer disponible globalmente
window.DashboardController = DashboardController;