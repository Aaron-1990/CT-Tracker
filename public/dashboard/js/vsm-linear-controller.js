// VSM Linear Controller - Clean Version
class VSMLinearController {
    constructor() {
        this.currentZoom = 1;
        this.init();
    }
    
    init() {
        this.addControls();
        this.addSequenceNumbers();
    }
    
    addControls() {
        var vsmFlow = document.querySelector('.vsm-flow');
        if (!vsmFlow) return;
        
        var controls = document.createElement('div');
        controls.className = 'vsm-controls';
        controls.innerHTML = 
            '<div style="color: #666; font-size: 0.9rem;">Value Stream Map - Linea GPEC5</div>' +
            '<div style="color: #999; font-size: 0.8rem;">Deslizar para navegar</div>' +
            '<button class="zoom-btn" onclick="vsmController.zoomOut()">- Zoom Out</button>' +
            '<button class="zoom-btn" onclick="vsmController.zoomIn()">+ Zoom In</button>' +
            '<button class="zoom-btn" onclick="vsmController.resetZoom()">Reset</button>';
        
        vsmFlow.parentNode.insertBefore(controls, vsmFlow);
    }
    
    addSequenceNumbers() {
        var processCards = document.querySelectorAll('.process-card');
        for (var i = 0; i < processCards.length; i++) {
            var card = processCards[i];
            var sequence = document.createElement('div');
            sequence.className = 'process-sequence';
            sequence.textContent = i + 1;
            card.style.position = 'relative';
            card.appendChild(sequence);
        }
    }
    
    zoomOut() {
        if (this.currentZoom > 0.5) {
            this.currentZoom -= 0.1;
            this.applyZoom();
        }
    }
    
    zoomIn() {
        if (this.currentZoom < 1) {
            this.currentZoom += 0.1;
            this.applyZoom();
        }
    }
    
    resetZoom() {
        this.currentZoom = 1;
        this.applyZoom();
    }
    
    applyZoom() {
        var container = document.querySelector('.vsm-flow');
        if (container) {
            container.style.transform = 'scale(' + this.currentZoom + ')';
            container.style.transformOrigin = 'left top';
            console.log('Zoom: ' + Math.round(this.currentZoom * 100) + '%');
        }
    }
}

// Inicializar
document.addEventListener('DOMContentLoaded', function() {
    if (document.querySelector('.vsm-flow')) {
        window.vsmController = new VSMLinearController();
        console.log('VSM Controller inicializado');
    }
});