// public/dashboard/js/dashboard-main.js
// Controlador principal del dashboard

/**
 * Controlador principal del dashboard VSM
 */
class DashboardController {
    constructor() {
        this.config = window.DashboardConfig;
        this.api = window.dashboardAPI;
        this.renderer = window.dashboardRenderer;
        
        this.updateInterval = null;
        this.isUpdating = false;
        this.updateCount = 0;
        this.lastSuccessfulUpdate = null;
        this.errorCount = 0;
        
        // Estados del dashboard
        this.state = {
            connected: false,
            loading: true,
            error: false,
            processes: [],
            summary: null,
            lastUpdate: null
        };
    }

    /**
     * Inicializar dashboard
     */
    async init() {
        try {
            this.config.Utils.log('🚀 Inicializando Dashboard VSM...');
            
            // Inicializar componentes
            this.renderer.init();
            this.setupEventListeners();
            this.updateConnectionStatus('connecting');
            
            // Realizar primera carga
            await this.performInitialLoad();
            
            // Iniciar actualizaciones automáticas
            this.startAutoUpdate();
            
            this.config.Utils.log('✅ Dashboard inicializado correctamente');
            
        } catch (error) {
            this.config.Utils.error('❌ Error inicializando dashboard:', error);
            this.handleInitializationError(error);
        }
    }

    /**
     * Realizar carga inicial de datos
     */
    async performInitialLoad() {
        this.renderer.showLoading();
        this.state.loading = true;

        try {
            // Mostrar loading mínimo para UX
            const startTime = Date.now();
            const result = await this.api.getLiveData();
            const elapsedTime = Date.now() - startTime;
            
            if (elapsedTime < this.config.UI.LOADING_MIN_TIME) {
                await this.delay(this.config.UI.LOADING_MIN_TIME - elapsedTime);
            }

            if (result.success) {
                this.handleSuccessfulDataLoad(result.data);
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
        // Validar datos
        const validation = this.api.validateLineData(data);
        if (!validation.valid) {
            this.handleDataLoadError(validation.error);
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
        this.updateSummaryDisplay(data.summary);
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
        
        this.config.Utils.error(`❌ Error carga de datos (intento ${this.errorCount}):`, error);
    }

    /**
     * Configurar event listeners
     */
    setupEventListeners() {
        // Visibilidad de página
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

        // Atajos de teclado
        document.addEventListener('keydown', (event) => {
            if (event.ctrlKey || event.metaKey) {
                switch (event.key) {
                    case 'r':
                        event.preventDefault();
                        this.performUpdate();
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
                this.handleSuccessfulUpdate(result.data);
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
        const validation = this.api.validateLineData(data);
        if (!validation.valid) {
            this.handleUpdateError(validation.error);
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

        // Actualizar UI con animaciones
        if (this.renderer.getLastRenderData()) {
            // Si ya hay datos renderizados, solo actualizar métricas
            this.renderer.updateMetricsWithAnimation(data.processes);
        } else {
            // Primera renderización completa
            this.renderer.renderProcessCards(data.processes);
        }

        this.updateSummaryDisplay(data.summary);
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
        
        // Mostrar error modal solo después de varios fallos
        if (this.errorCount >= 3) {
            this.showErrorModal(error);
        }

        this.config.Utils.error(`❌ Error actualización #${this.updateCount}:`, error);
    }

    /**
     * Actualizar display del resumen
     */
    updateSummaryDisplay(summary) {
        if (!summary) return;

        this.updateElementText('totalPieces', this.config.Utils.formatLargeNumber(summary.totalPieces));
        this.updateElementText('avgEfficiency', summary.avgEfficiency ? `${this.config.Utils.formatNumber(summary.avgEfficiency)}%` : '--');
        this.updateElementText('totalCycleTime', summary.totalCycleTime ? `${this.config.Utils.formatNumber(summary.totalCycleTime)}s` : '--');
        this.updateElementText('avgOEE', summary.avgOEE ? `${this.config.Utils.formatNumber(summary.avgOEE)}%` : '--');
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
            console.log('📊 Dashboard State:', this.state);
            console.log('📡 API Cache Stats:', this.api.getCacheStats());
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
     * Obtener estadísticas del dashboard
     */
    getStats() {
        return {
            state: this.state,
            updateCount: this.updateCount,
            errorCount: this.errorCount,
            lastSuccessfulUpdate: this.lastSuccessfulUpdate,
            isUpdating: this.isUpdating,
            api: this.api.getCacheStats()
        };
    }

    /**
     * Destruir dashboard y limpiar recursos
     */
    destroy() {
        this.pauseAutoUpdate();
        this.api.cancelAllRequests();
        this.renderer.clear();
        this.config.Utils.log('🗑️ Dashboard destruido');
    }
}

// ===== INICIALIZACIÓN AUTOMÁTICA =====
document.addEventListener('DOMContentLoaded', async () => {
    try {
        // Crear instancia global del controlador
        window.dashboardController = new DashboardController();
        
        // Inicializar dashboard
        await window.dashboardController.init();
        
        // Exponer utilidades globales para debugging
        if (window.DashboardConfig.DEBUG.ENABLED) {
            window.Dashboard = {
                controller: window.dashboardController,
                api: window.dashboardAPI,
                renderer: window.dashboardRenderer,
                config: window.DashboardConfig,
                
                // Métodos de debugging
                getStats: () => window.dashboardController.getStats(),
                forceUpdate: () => window.dashboardController.performUpdate(),
                toggleDebug: () => window.dashboardController.toggleDebug(),
                clearCache: () => window.dashboardAPI.clearCache()
            };
        }
        
    } catch (error) {
        console.error('❌ Error fatal inicializando dashboard:', error);
        
        // Mostrar error básico si falla todo
        const container = document.getElementById('vsm-process-container');
        if (container) {
            container.innerHTML = `
                <div class="error-message">
                    <p>❌ Error fatal del dashboard</p>
                    <small>Por favor recarga la página</small>
                </div>
            `;
        }
    }
});