// public/dashboard/js/dashboard-init.js
// Inicialización y setup del dashboard - Sin lógica de negocio

/**
 * Inicializador del dashboard VSM
 * Responsable únicamente de setup y arranque inicial
 */
class DashboardInitializer {
    constructor() {
        this.initialized = false;
        this.dependencies = [
            'DashboardConfig',
            'dashboardAPI', 
            'dashboardRenderer',
            'DashboardController'
        ];
        
        console.log('🔧 Dashboard Initializer creado');
    }

    /**
     * Verificar que todas las dependencias estén cargadas
     */
    checkDependencies() {
        const missing = this.dependencies.filter(dep => !window[dep]);
        
        if (missing.length > 0) {
            console.error('❌ Dependencias faltantes:', missing);
            return false;
        }
        
        console.log('✅ Todas las dependencias verificadas');
        return true;
    }

    /**
     * Inicializar dashboard completo
     */
    async initializeDashboard() {
        if (this.initialized) {
            console.warn('⚠️ Dashboard ya inicializado');
            return;
        }

        try {
            console.log('🚀 Iniciando inicialización del Dashboard VSM...');
            
            // Verificar dependencias
            if (!this.checkDependencies()) {
                throw new Error('Dependencias requeridas no disponibles');
            }

            // Crear instancia del controlador principal
            const controller = new window.DashboardController();
            
            // Inicializar controlador
            await controller.init();
            
            // Guardar referencia global
            window.dashboardController = controller;
            
            // Configurar utilidades de debugging si está habilitado
            this.setupDebuggingUtils();
            
            this.initialized = true;
            console.log('✅ Dashboard VSM inicializado completamente');
            
        } catch (error) {
            console.error('❌ Error fatal en inicialización:', error);
            this.handleFatalError(error);
        }
    }

    /**
     * Configurar utilidades de debugging
     */
    setupDebuggingUtils() {
        if (window.DashboardConfig.DEBUG.ENABLED) {
            // Crear objeto global de debugging
            window.Dashboard = {
                controller: window.dashboardController,
                api: window.dashboardAPI,
                renderer: window.dashboardRenderer,
                config: window.DashboardConfig,
                
                // Métodos útiles para debugging
                getStats: () => window.dashboardController.getStats(),
                forceUpdate: () => window.dashboardController.performUpdate(),
                toggleDebug: () => window.dashboardController.toggleDebug(),
                clearCache: () => window.dashboardAPI.clearCache(),
                getState: () => window.dashboardController.getState()
            };
            
            console.log('🔧 Utilidades de debugging configuradas');
            console.log('💡 Usa window.Dashboard para debugging');
        }
    }

    /**
     * Manejar errores fatales de inicialización
     */
    handleFatalError(error) {
        console.error('💥 Error fatal del dashboard:', error);
        
        // Mostrar error básico en la UI
        const container = document.getElementById('vsm-process-container');
        if (container) {
            container.innerHTML = `
                <div style="
                    text-align: center;
                    padding: 3rem;
                    color: #e74c3c;
                    background: #fdf2f2;
                    border-radius: 8px;
                    border: 1px solid #fadad7;
                    margin: 2rem;
                ">
                    <h3>❌ Error Fatal del Dashboard</h3>
                    <p>Error: ${error.message}</p>
                    <p><small>Revisa la consola del navegador para más detalles</small></p>
                    <button onclick="window.location.reload()" style="
                        background: #e74c3c;
                        color: white;
                        border: none;
                        padding: 0.8rem 2rem;
                        border-radius: 25px;
                        font-weight: bold;
                        cursor: pointer;
                        margin-top: 1rem;
                    ">Recargar Página</button>
                </div>
            `;
        }
    }

    /**
     * Verificar si el DOM está listo
     */
    isDOMReady() {
        return document.readyState === 'complete' || document.readyState === 'interactive';
    }

    /**
     * Esperar a que el DOM esté listo
     */
    waitForDOM() {
        return new Promise((resolve) => {
            if (this.isDOMReady()) {
                resolve();
            } else {
                document.addEventListener('DOMContentLoaded', resolve);
            }
        });
    }

    /**
     * Esperar a que todos los scripts se carguen
     */
    waitForScripts() {
        return new Promise((resolve) => {
            // Pequeño delay para asegurar que todos los scripts se ejecuten
            setTimeout(() => {
                if (this.checkDependencies()) {
                    resolve();
                } else {
                    // Reintentar después de un delay
                    setTimeout(() => {
                        if (this.checkDependencies()) {
                            resolve();
                        } else {
                            console.error('❌ Timeout esperando dependencias');
                            resolve(); // Resolver de todas formas para mostrar error
                        }
                    }, 1000);
                }
            }, 100);
        });
    }

    /**
     * Inicializar con todos los checks necesarios
     */
    async init() {
        try {
            console.log('⏳ Esperando DOM y scripts...');
            
            // Esperar a que el DOM esté listo
            await this.waitForDOM();
            console.log('✅ DOM listo');
            
            // Esperar a que los scripts se carguen
            await this.waitForScripts();
            console.log('✅ Scripts listos');
            
            // Inicializar dashboard
            await this.initializeDashboard();
            
        } catch (error) {
            console.error('❌ Error en inicialización:', error);
            this.handleFatalError(error);
        }
    }
}

// ===== AUTO-INICIALIZACIÓN =====
(function() {
    console.log('🔧 Configurando auto-inicialización del Dashboard VSM...');
    
    // Crear instancia del inicializador
    const initializer = new DashboardInitializer();
    
    // Inicializar automáticamente
    initializer.init();
    
    // Guardar referencia global para debugging
    window.dashboardInitializer = initializer;
    
})();