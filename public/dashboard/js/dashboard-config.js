// public/dashboard/js/dashboard-config.js
// Configuración global del dashboard VSM

/**
 * Configuración central del dashboard
 */
window.DashboardConfig = {
    // ===== CONFIGURACIÓN DE API =====
    API: {
        BASE_URL: '/api/gpec5',
        ENDPOINTS: {
            LIVE_DATA: '/data/live',
            CONFIGURATION: '/configuration',
            PROCESS_DATA: '/process',
            STATS: '/stats'
        },
        TIMEOUT: 10000, // 10 segundos
        RETRY_ATTEMPTS: 3,
        RETRY_DELAY: 2000 // 2 segundos
    },

    // ===== CONFIGURACIÓN DE ACTUALIZACIÓN =====
    UPDATE: {
        INTERVAL: 30000, // 30 segundos
        FAST_INTERVAL: 5000, // 5 segundos para modo rápido
        SLOW_INTERVAL: 60000, // 1 minuto para modo lento
        ANIMATION_DURATION: 300 // Duración de animaciones
    },

    // ===== ICONOS DE PROCESOS =====
    PROCESS_ICONS: {
        'WAVE_SOLDER': '🌊',
        'CONTINUITY': '⚡',
        'PLASMA': '🔬',
        'PCB_PRESS': '🔧',
        'COVER_DISPENSE': '💧',
        'COVER_PRESS': '🗜️',
        'HOT_TEST': '🔥'
    },

    // ===== COLORES DE ESTADO =====
    STATUS_COLORS: {
        ONLINE: '#27ae60',
        WARNING: '#f39c12',
        ERROR: '#e74c3c',
        OFFLINE: '#95a5a6'
    },

    // ===== UMBRALES DE EFICIENCIA =====
    EFFICIENCY_THRESHOLDS: {
        EXCELLENT: 120,
        GOOD: 100,
        WARNING: 85,
        CRITICAL: 70
    },

    // ===== UMBRALES DE OEE =====
    OEE_THRESHOLDS: {
        EXCELLENT: 85,
        GOOD: 75,
        WARNING: 65,
        CRITICAL: 50
    },

    // ===== CONFIGURACIÓN DE OUTLIERS =====
    OUTLIERS: {
        NORMAL_THRESHOLD: 5,      // % máximo para considerarse normal
        WARNING_THRESHOLD: 15,    // % máximo para considerarse warning
        CRITICAL_THRESHOLD: 25    // % máximo antes de crítico
    },

    // ===== CONFIGURACIÓN DE UI =====
    UI: {
        LOADING_MIN_TIME: 1000,   // Tiempo mínimo de loading para UX
        ERROR_DISPLAY_TIME: 5000, // Tiempo de display de errores
        SUCCESS_FLASH_TIME: 500,  // Tiempo de flash de éxito
        TOAST_DURATION: 3000      // Duración de notificaciones toast
    },

    // ===== FORMATEO DE DATOS =====
    FORMATTING: {
        DECIMAL_PLACES: 1,
        PERCENTAGE_PLACES: 1,
        LARGE_NUMBER_THRESHOLD: 1000,
        DATE_FORMAT: 'es-MX',
        TIME_FORMAT: {
            hour12: false,
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        }
    },

    // ===== CONFIGURACIÓN DE DEBUG =====
    DEBUG: {
        ENABLED: true, // Cambiar a true para debugging
        LOG_API_CALLS: false,
        LOG_UPDATES: false,
        LOG_ERRORS: true,
        SHOW_PERFORMANCE: false
    },

    // ===== MENSAJES DE USUARIO =====
    MESSAGES: {
        LOADING: '🔄 Cargando procesos de la línea GPEC5...',
        ERROR_CONNECTION: 'Error conectando con el servidor GPEC5',
        ERROR_DATA: 'Error procesando datos de la línea',
        NO_DATA: 'No hay datos disponibles para mostrar',
        RETRY: 'Reintentando conexión...',
        SUCCESS_UPDATE: 'Datos actualizados correctamente',
        OFFLINE: 'Modo fuera de línea - usando últimos datos'
    },

    // ===== CONFIGURACIÓN DE RESPONSIVIDAD =====
    BREAKPOINTS: {
        MOBILE: 480,
        TABLET: 768,
        DESKTOP: 1024,
        LARGE: 1400
    }
};

/**
 * Utilidades de configuración
 */
window.DashboardConfig.Utils = {
    /**
     * Obtener URL completa de endpoint
     */
    getApiUrl: function(endpoint) {
        return window.DashboardConfig.API.BASE_URL + window.DashboardConfig.API.ENDPOINTS[endpoint];
    },

    /**
     * Obtener icono de proceso
     */
    getProcessIcon: function(processName) {
        return window.DashboardConfig.PROCESS_ICONS[processName] || '⚙️';
    },

    /**
     * Obtener clase CSS de eficiencia
     */
    getEfficiencyClass: function(efficiency) {
        if (!efficiency || isNaN(efficiency)) return '';
        
        const thresholds = window.DashboardConfig.EFFICIENCY_THRESHOLDS;
        if (efficiency >= thresholds.EXCELLENT) return 'efficiency-excellent';
        if (efficiency >= thresholds.GOOD) return 'efficiency-good';
        if (efficiency >= thresholds.WARNING) return 'efficiency-warning';
        return 'efficiency-critical';
    },

    /**
     * Obtener clase CSS de OEE
     */
    getOEEClass: function(oee) {
        if (!oee || isNaN(oee)) return '';
        
        const thresholds = window.DashboardConfig.OEE_THRESHOLDS;
        if (oee >= thresholds.EXCELLENT) return 'oee-excellent';
        if (oee >= thresholds.GOOD) return 'oee-good';
        if (oee >= thresholds.WARNING) return 'oee-warning';
        return 'oee-critical';
    },

    /**
     * Obtener estado de outliers
     */
    getOutlierStatus: function(percentage) {
        if (!percentage) return 'normal';
        const outliers = window.DashboardConfig.OUTLIERS;
        if (percentage <= outliers.NORMAL_THRESHOLD) return 'normal';
        if (percentage <= outliers.WARNING_THRESHOLD) return 'warning';
        return 'critical';
    },

    /**
     * Formatear número con decimales
     */
    formatNumber: function(value, decimals) {
        if (value === null || value === undefined || isNaN(value)) return '--';
        
        const places = decimals !== null && decimals !== undefined ? 
            decimals : window.DashboardConfig.FORMATTING.DECIMAL_PLACES;
        return Number(value).toFixed(places);
    },

    /**
     * Formatear número grande con separadores
     */
    formatLargeNumber: function(value) {
        if (value === null || value === undefined || isNaN(value)) return '--';
        
        return value >= window.DashboardConfig.FORMATTING.LARGE_NUMBER_THRESHOLD 
            ? value.toLocaleString() 
            : value.toString();
    },

    /**
     * Formatear timestamp
     */
    formatTimestamp: function(timestamp) {
        if (!timestamp) return '--';
        
        const date = new Date(timestamp);
        const formatting = window.DashboardConfig.FORMATTING;
        return date.toLocaleTimeString(formatting.DATE_FORMAT, formatting.TIME_FORMAT);
    },

    /**
     * Log de debug condicional
     */
    log: function() {
        if (window.DashboardConfig.DEBUG.ENABLED) {
            console.log('[Dashboard]', ...arguments);
        }
    },

    /**
     * Log de error
     */
    error: function() {
        if (window.DashboardConfig.DEBUG.LOG_ERRORS) {
            console.error('[Dashboard Error]', ...arguments);
        }
    }
};

// Hacer disponible globalmente con alias corto
window.Config = window.DashboardConfig;

// Log inicial si debug está habilitado
if (window.DashboardConfig.DEBUG.ENABLED) {
    console.log('🔧 Dashboard Config loaded:', window.DashboardConfig);
}

console.log('✅ Dashboard Config cargado correctamente');