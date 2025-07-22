// public/dashboard/js/vsm-dashboard-main.js

// Variables globales
let gpec5Processor;
let fallbackMode = false;

// Inicialización del sistema
document.addEventListener('DOMContentLoaded', async function() {
    console.log('🗺️ Dashboard VSM iniciado - Conectando con datos reales GPEC5');
    console.log('🔗 URLs de equipos configuradas:');
    console.log('   - Wave Solder: mxryfis4.global.borgwarner.net');
    console.log('   - Continuity (3 equipos): CONT01, CONT02, CONT03');
    console.log('   - Hot Test (10 equipos): HTFT_01 a HTFT_11');
    
    // Mostrar indicador de carga inicial
    showLoadingIndicator();
    
    // Inicializar procesador de datos reales
    gpec5Processor = new GPEC5DataProcessor();
    
    try {
        await gpec5Processor.initialize();
        hideLoadingIndicator();
        showSuccessMessage();
        console.log('✅ Sistema VSM conectado con datos reales de GPEC5');
        
    } catch (error) {
        console.error('❌ Error conectando con datos reales:', error);
        hideLoadingIndicator();
        showErrorMessage(error.message);
        
        // Activar modo simulado como fallback
        initializeFallbackMode();
    }
});

// Mostrar indicador de carga
function showLoadingIndicator() {
    const loading = document.createElement('div');
    loading.id = 'loading-indicator';
    loading.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0,0,0,0.8);
        color: white;
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        font-size: 1.5rem;
        z-index: 10000;
    `;
    
    loading.innerHTML = `
        <div style="text-align: center;">
            <div style="font-size: 4rem; margin-bottom: 20px; animation: spin 2s linear infinite;">🔄</div>
            <div style="margin-bottom: 10px;">Conectando con GPEC5...</div>
            <div style="font-size: 1rem; opacity: 0.8;">Procesando datos de mxryfis4.global.borgwarner.net</div>
        </div>
        <style>
            @keyframes spin {
                from { transform: rotate(0deg); }
                to { transform: rotate(360deg); }
            }
        </style>
    `;
    
    document.body.appendChild(loading);
}

// Ocultar indicador de carga
function hideLoadingIndicator() {
    const loading = document.getElementById('loading-indicator');
    if (loading) {
        loading.remove();
    }
}

// Mostrar mensaje de éxito
function showSuccessMessage() {
    const successAlert = document.createElement('div');
    successAlert.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: #27ae60;
        color: white;
        padding: 1rem;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.3);
        z-index: 1000;
        animation: slideIn 0.3s ease-out;
    `;
    successAlert.innerHTML = `
        <strong>✅ Conectado a GPEC5</strong><br>
        Datos en tiempo real activos
    `;
    
    document.body.appendChild(successAlert);
    
    setTimeout(() => {
        successAlert.remove();
    }, 5000);
}

// Mostrar mensaje de error
function showErrorMessage(errorMessage) {
    const errorAlert = document.createElement('div');
    errorAlert.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: #e74c3c;
        color: white;
        padding: 1rem;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.3);
        z-index: 1000;
    `;
    errorAlert.innerHTML = `
        <strong>⚠️ Error Conexión</strong><br>
        Activando modo simulado<br>
        <small>${errorMessage}</small>
    `;
    
    document.body.appendChild(errorAlert);
    
    setTimeout(() => {
        errorAlert.remove();
    }, 8000);
}

// Modo simulado como fallback
function initializeFallbackMode() {
    console.log('🔄 Iniciando modo simulado como fallback...');
    fallbackMode = true;
    
    // Actualizar indicador de estado
    const connectionStatus = document.getElementById('connection-status');
    if (connectionStatus) {
        connectionStatus.textContent = 'Modo Simulado';
        connectionStatus.style.color = '#f39c12';
    }
    
    // Inicializar datos simulados para GPEC5
    const simulatedData = {
        processes: [
            {
                processName: 'WAVE_SOLDER',
                displayName: 'Wave Solder',
                designTime: 45,
                metrics: {
                    realTime: 47,
                    hourlyAverage: 48,
                    oee: 94.2,
                    efficiency: 95.7,
                    outlierStatus: 'normal',
                    outlierPercentage: 2.1
                },
                pieces: { ok: 892, ng: 18, total: 910 }
            },
            {
                processName: 'CONTINUITY',
                displayName: 'Continuity Test',
                designTime: 30,
                metrics: {
                    realTime: 32,
                    hourlyAverage: 31,
                    oee: 96.8,
                    efficiency: 93.8,
                    outlierStatus: 'normal',
                    outlierPercentage: 1.7
                },
                pieces: { ok: 1145, ng: 12, total: 1157 }
            },
            {
                processName: 'HOT_TEST',
                displayName: 'Hot Test',
                designTime: 60,
                metrics: {
                    realTime: 63,
                    hourlyAverage: 65,
                    oee: 91.2,
                    efficiency: 95.2,
                    outlierStatus: 'warning',
                    outlierPercentage: 6.3
                },
                pieces: { ok: 2347, ng: 45, total: 2392 }
            }
        ],
        summary: {
            totalOKPieces: 4384,
            totalCycleTime: 140,
            avgEfficiency: 94.9,
            outlierPercentage: 3.2,
            throughput: 25.7,
            uptime: 98.1
        },
        timestamp: new Date()
    };

    // Procesar datos simulados
    if (gpec5Processor) {
        gpec5Processor.processRealData(simulatedData);
    }

    // Actualizar datos simulados cada 30 segundos
    setInterval(() => {
        // Simular pequeñas variaciones en los datos
        simulatedData.processes.forEach(process => {
            const variation = (Math.random() - 0.5) * 4; // ±2s variación
            process.metrics.realTime = Math.max(1, process.designTime + variation);
            process.metrics.hourlyAverage = process.metrics.realTime + (Math.random() - 0.5) * 2;
            process.metrics.oee = Math.max(80, Math.min(100, 95 + (Math.random() - 0.5) * 10));
            process.pieces.ok += Math.floor(Math.random() * 5);
        });

        // Actualizar resumen
        simulatedData.summary.totalOKPieces = simulatedData.processes.reduce((sum, p) => sum + p.pieces.ok, 0);
        simulatedData.summary.totalCycleTime = simulatedData.processes.reduce((sum, p) => sum + p.metrics.realTime, 0);
        simulatedData.timestamp = new Date();

        if (gpec5Processor) {
            gpec5Processor.processRealData(simulatedData);
        }
    }, 30000);
}

// Funciones de control para debugging y administración
window.vsmDebug = {
    gpec5Processor,
    fallbackMode,
    getStats: async () => {
        if (gpec5Processor && !fallbackMode) {
            return await gpec5Processor.getSystemStats();
        }
        return { mode: 'fallback', timestamp: new Date() };
    },
    reconnect: async () => {
        if (gpec5Processor && !fallbackMode) {
            gpec5Processor.cleanup();
            gpec5Processor = new GPEC5DataProcessor();
            await gpec5Processor.initialize();
        }
    },
    fetchData: async () => {
        if (gpec5Processor && !fallbackMode) {
            await gpec5Processor.fetchLiveData();
        }
    },
    testConnection: async () => {
        try {
            const response = await fetch('/api/gpec5/configuration');
            const result = await response.json();
            console.log('🔧 Test conexión:', result);
            return result;
        } catch (error) {
            console.error('❌ Error test:', error);
            return { error: error.message };
        }
    },
    toggleMode: () => {
        if (fallbackMode) {
            console.log('🔄 Intentando cambiar a modo real...');
            location.reload();
        } else {
            console.log('🔄 Cambiando a modo simulado...');
            initializeFallbackMode();
        }
    }
};

// Cleanup al cerrar la página
window.addEventListener('beforeunload', function() {
    if (gpec5Processor) {
        gpec5Processor.cleanup();
    }
});

// Manejo de errores global
window.addEventListener('error', function(event) {
    console.error('🚨 Error en Dashboard VSM:', event.error);
});

// Auto-refresh de la página si hay errores críticos
let errorCount = 0;
window.addEventListener('error', function() {
    errorCount++;
    if (errorCount > 5) {
        console.log('🔄 Demasiados errores, refrescando página...');
        setTimeout(() => {
            window.location.reload();
        }, 5000);
    }
});

// Eventos de visibilidad de la página
document.addEventListener('visibilitychange', function() {
    if (document.visibilityState === 'visible' && gpec5Processor && !fallbackMode) {
        // Refrescar datos cuando la página vuelve a ser visible
        console.log('👁️ Página visible, refrescando datos...');
        gpec5Processor.fetchLiveData();
    }
});

console.log('🎯 Dashboard VSM GPEC5 cargado completamente');
console.log('💡 Debug: window.vsmDebug contiene controles del sistema');
console.log('🔗 Conectando con URLs reales de borgwarner.net...');