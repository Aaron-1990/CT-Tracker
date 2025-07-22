// public/dashboard/js/gpec5-data-processor.js

class GPEC5DataProcessor {
    constructor() {
        this.apiBaseUrl = '/api/gpec5';
        this.wsUrl = `ws://${window.location.hostname}:3002/gpec5-realtime`;
        this.websocket = null;
        this.isConnected = false;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        this.pollingActive = false;
        this.lastData = null;
    }

    async initialize() {
        try {
            console.log('🔄 Inicializando conexión con datos reales GPEC5...');
            
            // Obtener configuración inicial
            await this.loadConfiguration();
            
            // Iniciar polling si no está activo
            await this.startPolling();
            
            // Conectar WebSocket para actualizaciones en tiempo real
            this.connectWebSocket();
            
            // Obtener datos iniciales
            await this.fetchLiveData();
            
            console.log('✅ Conexión con GPEC5 establecida');
            
        } catch (error) {
            console.error('❌ Error inicializando conexión GPEC5:', error);
            this.showConnectionError(error.message);
        }
    }

    async loadConfiguration() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/configuration`);
            const result = await response.json();
            
            if (result.success) {
                console.log('📋 Configuración GPEC5 cargada:', result.data);
                this.updateConfigurationDisplay(result.data);
                return result.data;
            } else {
                throw new Error(result.error || 'Error cargando configuración');
            }
        } catch (error) {
            console.error('Error loading configuration:', error);
            throw error;
        }
    }

    async startPolling() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/polling/start`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' }
            });
            
            const result = await response.json();
            
            if (result.success) {
                this.pollingActive = true;
                console.log('🔄 Polling GPEC5 iniciado');
                this.updateConnectionStatus('Polling Activo');
            } else {
                console.warn('⚠️ Polling ya activo o error:', result.message);
            }
        } catch (error) {
            console.error('Error starting polling:', error);
            throw error;
        }
    }

    async fetchLiveData() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/data/live`);
            const result = await response.json();
            
            if (result.success) {
                this.lastData = result.data;
                this.processRealData(result.data);
                console.log('📊 Datos GPEC5 actualizados:', result.data);
            } else {
                throw new Error(result.error || 'Error obteniendo datos');
            }
        } catch (error) {
            console.error('Error fetching live data:', error);
            this.showConnectionError('Error obteniendo datos en tiempo real');
        }
    }

    connectWebSocket() {
        try {
            this.websocket = new WebSocket(this.wsUrl);
            
            this.websocket.onopen = () => {
                this.isConnected = true;
                this.reconnectAttempts = 0;
                console.log('🔗 WebSocket GPEC5 conectado');
                this.updateConnectionStatus('Tiempo Real Activo');
            };
            
            this.websocket.onmessage = (event) => {
                try {
                    const message = JSON.parse(event.data);
                    this.handleWebSocketMessage(message);
                } catch (error) {
                    console.error('Error parsing WebSocket message:', error);
                }
            };
            
            this.websocket.onclose = () => {
                this.isConnected = false;
                console.log('🔌 WebSocket GPEC5 desconectado');
                this.updateConnectionStatus('Reconectando...');
                this.scheduleReconnect();
            };
            
            this.websocket.onerror = (error) => {
                console.error('WebSocket error:', error);
                this.updateConnectionStatus('Error Conexión');
            };
            
        } catch (error) {
            console.error('Error connecting WebSocket:', error);
            this.updateConnectionStatus('WebSocket No Disponible');
        }
    }

    handleWebSocketMessage(message) {
        switch (message.type) {
            case 'initial_data':
            case 'data_update':
                this.lastData = message.data;
                this.processRealData(message.data);
                break;
            case 'outlier_detected':
                this.showOutlierAlert(message.data);
                break;
            case 'error':
                console.error('WebSocket error message:', message.data);
                break;
            default:
                console.log('Unknown WebSocket message type:', message.type);
        }
    }

    processRealData(lineData) {
        if (lineData.error) {
            this.showConnectionError(lineData.error);
            return;
        }

        // Actualizar cada proceso en el dashboard
        lineData.processes.forEach(processData => {
            this.updateProcessDisplay(processData);
        });

        // Actualizar resumen general
        if (lineData.summary) {
            this.updateSummaryDisplay(lineData.summary);
        }

        // Actualizar timestamp
        this.updateLastUpdateTime(lineData.timestamp);
    }

    updateProcessDisplay(processData) {
        const processMap = {
            'WAVE_SOLDER': 'wave',
            'CONTINUITY': 'cont', 
            'PLASMA': 'plas',
            'PCB_PRESS': 'pcb',
            'COVER_DISPENSE': 'covd',
            'COVER_PRESS': 'covp',
            'HOT_TEST': 'htft'
        };

        const prefix = processMap[processData.processName];
        if (!prefix) {
            console.warn('Proceso no mapeado:', processData.processName);
            return;
        }

        const metrics = processData.metrics;
        
        // Actualizar métricas con animación
        this.updateMetricWithAnimation(`${prefix}-design`, `${processData.designTime}s`);
        this.updateMetricWithAnimation(`${prefix}-real`, `${metrics.realTime}s`);
        this.updateMetricWithAnimation(`${prefix}-hourly`, `${metrics.hourlyAverage}s`);
        this.updateMetricWithAnimation(`${prefix}-oee`, `${metrics.oee}%`);
        this.updateMetricWithAnimation(`${prefix}-pieces`, processData.pieces.ok.toLocaleString());
        this.updateMetricWithAnimation(`${prefix}-efficiency`, `${metrics.efficiency}%`);

        // Actualizar indicador de outliers
        this.updateOutlierIndicator(prefix, metrics.outlierStatus, metrics.outlierPercentage);
    }

    updateOutlierIndicator(prefix, status, percentage) {
        const realTimeElement = document.getElementById(`${prefix}-real`);
        if (realTimeElement && realTimeElement.nextElementSibling) {
            const outlierIndicator = realTimeElement.nextElementSibling;
            if (outlierIndicator.classList.contains('outlier-indicator')) {
                outlierIndicator.className = `outlier-indicator outlier-${status}`;
                outlierIndicator.textContent = status === 'normal' ? 'Normal' : 
                                             status === 'warning' ? `±2σ (${percentage}%)` : 
                                             `Outlier (${percentage}%)`;
            }
        }
    }

    updateSummaryDisplay(summary) {
        this.updateMetricWithAnimation('total-pieces', summary.totalOKPieces.toLocaleString());
        this.updateMetricWithAnimation('total-cycle-time', `${summary.totalCycleTime}s`);
        this.updateMetricWithAnimation('line-efficiency', `${summary.avgEfficiency}%`);
        this.updateMetricWithAnimation('outliers-detected', `${summary.outlierPercentage}%`);
        this.updateMetricWithAnimation('throughput', summary.throughput.toString());
        this.updateMetricWithAnimation('uptime', `${summary.uptime}%`);
    }

    updateMetricWithAnimation(elementId, value) {
        const element = document.getElementById(elementId);
        if (element && element.textContent !== value) {
            element.classList.add('updating');
            element.textContent = value;
            
            setTimeout(() => {
                element.classList.remove('updating');
            }, 500);
        }
    }

    updateLastUpdateTime(timestamp) {
        const timeElement = document.getElementById('last-update-time');
        if (timeElement) {
            const date = new Date(timestamp);
            timeElement.textContent = date.toLocaleString('es-ES', {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit'
            });
        }
    }

    updateConnectionStatus(status) {
        const statusElement = document.getElementById('connection-status');
        if (statusElement) {
            statusElement.textContent = status;
        }
    }

    updateConfigurationDisplay(config) {
        // Actualizar contadores de configuración
        const equipmentCount = config.totalEquipments || 0;
        const processCount = Object.keys(config.processes || {}).length;
        
        console.log(`📊 GPEC5: ${processCount} procesos, ${equipmentCount} equipos configurados`);
    }

    showConnectionError(errorMessage) {
        const alert = document.createElement('div');
        alert.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: #e74c3c;
            color: white;
            padding: 1rem;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3);
            z-index: 1000;
            max-width: 300px;
        `;
        alert.innerHTML = `
            <strong>❌ Error Conexión GPEC5</strong><br>
            ${errorMessage}
        `;
        
        document.body.appendChild(alert);
        
        setTimeout(() => {
            alert.remove();
        }, 8000);
    }

    showOutlierAlert(data) {
        const alert = document.createElement('div');
        alert.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: #f39c12;
            color: white;
            padding: 1rem;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3);
            z-index: 1000;
            animation: slideIn 0.3s ease-out;
        `;
        alert.innerHTML = `
            <strong>⚠️ Outlier Detectado</strong><br>
            ${data.process} - ${data.equipment}<br>
            Tiempo: ${data.cycleTime}s (±${data.sigmaLevel?.toFixed(1) || '?'}σ)
        `;
        
        document.body.appendChild(alert);
        
        setTimeout(() => {
            alert.remove();
        }, 6000);
    }

    scheduleReconnect() {
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
            
            setTimeout(() => {
                console.log(`🔄 Intentando reconectar WebSocket (${this.reconnectAttempts}/${this.maxReconnectAttempts})...`);
                this.connectWebSocket();
            }, delay);
        } else {
            console.error('❌ Máximo número de intentos de reconexión alcanzado');
            this.updateConnectionStatus('Conexión Perdida');
        }
    }

    async getSystemStats() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/stats`);
            const result = await response.json();
            
            if (result.success) {
                console.log('📊 Estadísticas del sistema:', result.data);
                return result.data;
            } else {
                throw new Error(result.error || 'Error obteniendo estadísticas');
            }
        } catch (error) {
            console.error('Error getting system stats:', error);
            return null;
        }
    }

    cleanup() {
        if (this.websocket) {
            this.websocket.close();
        }
        this.isConnected = false;
        console.log('🧹 GPEC5DataProcessor cleanup completed');
    }
}