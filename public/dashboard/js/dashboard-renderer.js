// public/dashboard/js/dashboard-renderer.js
// Renderizado dinámico de componentes UI

/**
 * Clase para renderizado dinámico del dashboard
 */
class DashboardRenderer {
    constructor() {
        this.config = window.DashboardConfig;
        this.container = null;
        this.lastRenderData = null;
        this.animationQueue = [];
    }

    /**
     * Inicializar renderer
     */
    init() {
        this.container = document.getElementById('vsm-process-container');
        if (!this.container) {
            throw new Error('Container element not found');
        }
        
        this.config.Utils.log('Dashboard renderer initialized');
    }

    /**
     * Renderizar tarjetas de proceso completas
     */
    renderProcessCards(processes) {
        if (!processes || !Array.isArray(processes)) {
            this.showError('Datos de procesos inválidos');
            return;
        }

        let html = '';
        
        processes.forEach((process, index) => {
            html += this.createProcessCardHTML(process);
            
            // Agregar flecha entre procesos (excepto el último)
            if (index < processes.length - 1) {
                html += '<div class="flow-arrow">→</div>';
            }
        });

        this.container.innerHTML = html;
        this.lastRenderData = { processes, timestamp: new Date() };
        
        this.config.Utils.log(`Rendered ${processes.length} process cards`);
    }

    /**
     * Crear HTML de tarjeta de proceso individual
     */
    createProcessCardHTML(process) {
        const icon = this.config.Utils.getProcessIcon(process.processName);
        const equipmentList = this.getEquipmentList(process.equipments);
        const equipmentCount = process.equipments?.length || 0;
        const typeText = process.type === 'parallel' ? 'Paralelo' : 'Secuencial';

        return `
            <div class="process-card" data-process="${process.processName}">
                ${this.createRealTimeIndicator()}
                ${this.createProcessHeader(icon, process.displayName)}
                ${this.createEquipmentInfo(equipmentCount, equipmentList, typeText)}
                ${this.createMetricsGrid(process)}
                ${this.createBigMetrics(process)}
                ${this.createOutlierStatus(process.metrics)}
            </div>
        `;
    }

    /**
     * Crear indicador de tiempo real
     */
    createRealTimeIndicator() {
        return '<div class="realtime-indicator"></div>';
    }

    /**
     * Crear header del proceso
     */
    createProcessHeader(icon, displayName) {
        return `<div class="process-title">${icon} ${displayName}</div>`;
    }

    /**
     * Crear información de equipos
     */
    createEquipmentInfo(count, list, type) {
        return `
            <div class="equipment-info">
                Equipos (${count}): ${list}<br>
                Configuración: ${type}
            </div>
        `;
    }

    /**
     * Crear grid de métricas principales
     */
    createMetricsGrid(process) {
        const metrics = process.metrics || {};
        const processName = process.processName;

        return `
            <div class="metrics-grid">
                <div class="metric-item">
                    <span class="metric-value" id="${processName}-design">
                        ${this.config.Utils.formatNumber(process.designTime)}s
                    </span>
                    <span class="metric-label">Diseño</span>
                </div>
                <div class="metric-item">
                    <span class="metric-value" id="${processName}-real">
                        ${this.formatMetricValue(metrics.realTime, 's')}
                    </span>
                    <span class="metric-label">Tiempo Real</span>
                </div>
                <div class="metric-item">
                    <span class="metric-value" id="${processName}-hourly">
                        ${this.formatMetricValue(metrics.hourlyAverage, 's')}
                    </span>
                    <span class="metric-label">Promedio 1h</span>
                </div>
                <div class="metric-item">
                    <span class="metric-value" id="${processName}-oee">
                        ${this.formatMetricValue(metrics.oee, '%')}
                    </span>
                    <span class="metric-label">OEE</span>
                </div>
            </div>
        `;
    }

    /**
     * Crear métricas grandes (destacadas)
     */
    createBigMetrics(process) {
        const pieces = process.pieces || {};
        const metrics = process.metrics || {};
        const processName = process.processName;
        const efficiencyClass = this.config.Utils.getEfficiencyClass(metrics.efficiency);

        return `
            <div class="big-metrics">
                <div class="big-metric">
                    <div class="big-metric-value" id="${processName}-pieces">
                        ${this.config.Utils.formatLargeNumber(pieces.ok)}
                    </div>
                    <div class="big-metric-label">Piezas OK</div>
                </div>
                <div class="big-metric ${efficiencyClass}">
                    <div class="big-metric-value" id="${processName}-efficiency">
                        ${this.formatMetricValue(metrics.efficiency, '%')}
                    </div>
                    <div class="big-metric-label">Eficiencia</div>
                </div>
            </div>
        `;
    }

    /**
     * Crear estado de outliers
     */
    createOutlierStatus(metrics) {
        if (!metrics) return '';

        const status = this.config.Utils.getOutlierStatus(metrics.outlierPercentage);
        const statusText = this.getOutlierStatusText(status);

        return `
            <div class="outlier-status">
                <span class="outlier-indicator outlier-${status}">
                    ${statusText}
                </span>
            </div>
        `;
    }

    /**
     * Obtener lista de equipos formateada
     */
    getEquipmentList(equipments) {
        if (!equipments || equipments.length === 0) return 'N/A';
        
        const names = equipments.map(eq => eq.equipmentId);
        if (names.length <= 3) {
            return names.join(', ');
        }
        
        return `${names.slice(0, 2).join(', ')} y ${names.length - 2} más`;
    }

    /**
     * Formatear valor de métrica
     */
    formatMetricValue(value, unit = '') {
        if (value === null || value === undefined || isNaN(value)) {
            return '--';
        }
        return `${this.config.Utils.formatNumber(value)}${unit}`;
    }

    /**
     * Obtener texto de estado de outliers
     */
    getOutlierStatusText(status) {
        const statusMap = {
            'normal': 'Normal',
            'warning': 'Alerta',
            'critical': 'Crítico'
        };
        return statusMap[status] || 'Normal';
    }

    /**
     * Actualizar métricas individuales con animación
     */
    updateMetricsWithAnimation(processes) {
        if (!processes) return;

        processes.forEach(process => {
            this.updateProcessMetrics(process);
        });
    }

    /**
     * Actualizar métricas de un proceso específico
     */
    updateProcessMetrics(process) {
        const processName = process.processName;
        const metrics = process.metrics || {};
        const pieces = process.pieces || {};

        // Actualizar valores con animación
        this.updateElementWithAnimation(`${processName}-real`, this.formatMetricValue(metrics.realTime, 's'));
        this.updateElementWithAnimation(`${processName}-hourly`, this.formatMetricValue(metrics.hourlyAverage, 's'));
        this.updateElementWithAnimation(`${processName}-oee`, this.formatMetricValue(metrics.oee, '%'));
        this.updateElementWithAnimation(`${processName}-pieces`, this.config.Utils.formatLargeNumber(pieces.ok));
        this.updateElementWithAnimation(`${processName}-efficiency`, this.formatMetricValue(metrics.efficiency, '%'));

        // Actualizar clase de eficiencia
        this.updateEfficiencyClass(processName, metrics.efficiency);
        
        // Actualizar estado de outliers
        this.updateOutlierIndicator(processName, metrics);
    }

    /**
     * Actualizar elemento con animación
     */
    updateElementWithAnimation(elementId, newValue) {
        const element = document.getElementById(elementId);
        if (!element) return;

        const currentValue = element.textContent;
        if (currentValue !== newValue) {
            // Agregar clase de animación
            element.classList.add('metric-updated');
            element.textContent = newValue;

            // Remover clase después de la animación
            setTimeout(() => {
                element.classList.remove('metric-updated');
            }, this.config.UPDATE.ANIMATION_DURATION);
        }
    }

    /**
     * Actualizar clase de eficiencia
     */
    updateEfficiencyClass(processName, efficiency) {
        const element = document.querySelector(`[data-process="${processName}"] .big-metric:last-child`);
        if (!element) return;

        // Remover clases anteriores
        element.classList.remove('efficiency-excellent', 'efficiency-good', 'efficiency-warning', 'efficiency-critical');
        
        // Agregar nueva clase
        const newClass = this.config.Utils.getEfficiencyClass(efficiency);
        if (newClass) {
            element.classList.add(newClass);
        }
    }

    /**
     * Actualizar indicador de outliers
     */
    updateOutlierIndicator(processName, metrics) {
        const element = document.querySelector(`[data-process="${processName}"] .outlier-indicator`);
        if (!element) return;

        const status = this.config.Utils.getOutlierStatus(metrics.outlierPercentage);
        const statusText = this.getOutlierStatusText(status);

        // Actualizar clase y texto
        element.className = `outlier-indicator outlier-${status}`;
        element.textContent = statusText;
    }

    /**
     * Mostrar mensaje de carga
     */
    showLoading(message = null) {
        const loadingMessage = message || this.config.MESSAGES.LOADING;
        this.container.innerHTML = `
            <div class="loading-message">
                <div class="loading-spinner"></div>
                <p>${loadingMessage}</p>
            </div>
        `;
    }

    /**
     * Mostrar mensaje de error
     */
    showError(message = null) {
        const errorMessage = message || this.config.MESSAGES.ERROR_CONNECTION;
        this.container.innerHTML = `
            <div class="error-message">
                <p>❌ ${errorMessage}</p>
                <small>Reintentando en ${this.config.UPDATE.INTERVAL / 1000} segundos...</small>
            </div>
        `;
    }

    /**
     * Mostrar mensaje de sin datos
     */
    showNoData() {
        this.container.innerHTML = `
            <div class="error-message">
                <p>📭 ${this.config.MESSAGES.NO_DATA}</p>
                <small>Verificando conexión con equipos...</small>
            </div>
        `;
    }

    /**
     * Limpiar contenedor
     */
    clear() {
        if (this.container) {
            this.container.innerHTML = '';
        }
        this.lastRenderData = null;
    }

    /**
     * Obtener datos del último renderizado
     */
    getLastRenderData() {
        return this.lastRenderData;
    }
}

// Crear instancia global
window.dashboardRenderer = new DashboardRenderer();