document.addEventListener('DOMContentLoaded', () => {
    const statusElement = document.getElementById('status');
    
    // Función para verificar el estado del servidor
    const checkServerStatus = async () => {
        try {
            const response = await fetch('/api/status');
            const data = await response.json();
            
            statusElement.innerHTML = `
                <div class="status-online">
                    <p><strong>Estado:</strong> ${data.status}</p>
                    <p><strong>Fecha y hora:</strong> ${new Date(data.timestamp).toLocaleString()}</p>
                    <p><strong>Servidor:</strong> ${data.server}</p>
                    <p><strong>Versión Node.js:</strong> ${data.nodejs}</p>
                </div>
            `;
        } catch (error) {
            statusElement.innerHTML = `
                <div class="status-offline">
                    <p><strong>Error de conexión con el servidor</strong></p>
                    <p>Detalle: ${error.message}</p>
                </div>
            `;
        }
    };
    
    // Verificar estado inicial
    checkServerStatus();
    
    // Verificar estado cada 30 segundos
    setInterval(checkServerStatus, 30000);
});