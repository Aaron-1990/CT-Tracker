// =============================================================================
// PROCESS NUMBERING - Numeración automática de procesos VSM
// Archivo minimalista para mantener solo la numeración sin controles de zoom
// =============================================================================

/**
 * Agregar números de secuencia a las tarjetas de proceso
 */
function addSequenceNumbers() {
    var processCards = document.querySelectorAll('.process-card');
    console.log('Agregando numeración a', processCards.length, 'procesos');
    
    for (var i = 0; i < processCards.length; i++) {
        var card = processCards[i];
        
        // Remover numeración existente para evitar duplicados
        var existingSequence = card.querySelector('.process-sequence');
        if (existingSequence) {
            existingSequence.remove();
        }
        
        // Crear nuevo elemento de secuencia
        var sequence = document.createElement('div');
        sequence.className = 'process-sequence';
        sequence.textContent = i + 1;
        
        // Asegurar que la tarjeta tenga position relative
        card.style.position = 'relative';
        
        // Agregar el número a la tarjeta
        card.appendChild(sequence);
    }
}

/**
 * Reinicializar numeración (útil cuando se actualizan los procesos dinámicamente)
 */
function refreshProcessNumbers() {
    console.log('Refrescando numeración de procesos...');
    addSequenceNumbers();
}

/**
 * Inicialización automática cuando se carga la página
 */
document.addEventListener('DOMContentLoaded', function() {
    console.log('🔢 Sistema de numeración de procesos iniciado');
    
    // Verificar que existe el contenedor VSM
    if (document.querySelector('.vsm-flow')) {
        // Agregar numeración inicial
        addSequenceNumbers();
        
        // Observar cambios en el contenedor para renumerar automáticamente
        setupAutoRenumbering();
        
        console.log('✅ Numeración de procesos inicializada correctamente');
    } else {
        console.log('⚠️ Contenedor .vsm-flow no encontrado');
    }
});

/**
 * Configurar observador para renumeración automática
 * Útil cuando se cargan procesos dinámicamente desde el servidor
 */
function setupAutoRenumbering() {
    var vsmContainer = document.querySelector('.vsm-flow');
    if (!vsmContainer) return;
    
    // Crear observer para detectar cambios en el DOM
    var observer = new MutationObserver(function(mutations) {
        var shouldRenumber = false;
        
        mutations.forEach(function(mutation) {
            // Si se agregaron o quitaron process-cards
            if (mutation.type === 'childList') {
                mutation.addedNodes.forEach(function(node) {
                    if (node.nodeType === 1 && node.classList.contains('process-card')) {
                        shouldRenumber = true;
                    }
                });
                
                mutation.removedNodes.forEach(function(node) {
                    if (node.nodeType === 1 && node.classList.contains('process-card')) {
                        shouldRenumber = true;
                    }
                });
            }
        });
        
        if (shouldRenumber) {
            console.log('🔄 Cambios detectados en procesos, renumerando...');
            setTimeout(addSequenceNumbers, 100); // Pequeño delay para que termine el cambio
        }
    });
    
    // Configurar observer
    observer.observe(vsmContainer, {
        childList: true,
        subtree: true
    });
    
    console.log('👁️ Observer de renumeración automática configurado');
}

// Hacer funciones disponibles globalmente para uso manual si es necesario
window.addSequenceNumbers = addSequenceNumbers;
window.refreshProcessNumbers = refreshProcessNumbers;