// =============================================================================
// src/core/entities/Process.js - Proceso en la línea de producción
// =============================================================================
class Process {
    constructor({
        id,
        lineCode,
        sequence,
        processCode,
        processName,
        designCycleTimeSeconds,
        designProcessTimeSeconds,
        targetOeePercentage,
        processIcon,
        processColor,
        position,
        active,
        createdAt,
        updatedAt
    }) {
        this.id = id;
        this.lineCode = lineCode;
        this.sequence = sequence;
        this.processCode = processCode;
        this.processName = processName;
        this.designCycleTimeSeconds = designCycleTimeSeconds;
        this.designProcessTimeSeconds = designProcessTimeSeconds;
        this.targetOeePercentage = targetOeePercentage;
        this.processIcon = processIcon;
        this.processColor = processColor;
        this.position = position;
        this.active = active;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        
        this.equipments = []; // Array de Equipment entities
        
        this.validate();
    }

    validate() {
        if (!this.processCode || this.processCode.trim().length === 0) {
            throw new Error('Process code is required');
        }
        if (!this.processName || this.processName.trim().length === 0) {
            throw new Error('Process name is required');
        }
        if (!this.sequence || this.sequence <= 0) {
            throw new Error('Process sequence must be positive');
        }
        if (this.designCycleTimeSeconds && this.designCycleTimeSeconds <= 0) {
            throw new Error('Design cycle time must be positive');
        }
    }

    addEquipment(equipment) {
        if (this.equipments.find(e => e.equipmentCode === equipment.equipmentCode)) {
            throw new Error(`Equipment ${equipment.equipmentCode} already exists in this process`);
        }
        this.equipments.push(equipment);
    }

    removeEquipment(equipmentCode) {
        this.equipments = this.equipments.filter(e => e.equipmentCode !== equipmentCode);
    }

    getEquipmentByCode(equipmentCode) {
        return this.equipments.find(e => e.equipmentCode === equipmentCode);
    }

    hasParallelEquipments() {
        return this.equipments.length > 1;
    }

    getTotalDesignThroughput() {
        if (this.equipments.length === 0) return 0;
        
        // Para equipos paralelos, sumar la capacidad teórica
        return this.equipments.reduce((total, equipment) => {
            if (equipment.designCycleTimeSeconds > 0) {
                return total + (3600 / equipment.designCycleTimeSeconds); // piezas por hora
            }
            return total;
        }, 0);
    }

    getBottleneckEquipment() {
        if (this.equipments.length <= 1) return null;
        
        // El equipo más lento es el cuello de botella
        return this.equipments.reduce((slowest, current) => {
            if (!slowest) return current;
            
            const slowestThroughput = slowest.designCycleTimeSeconds > 0 ? 
                3600 / slowest.designCycleTimeSeconds : 0;
            const currentThroughput = current.designCycleTimeSeconds > 0 ? 
                3600 / current.designCycleTimeSeconds : 0;
                
            return currentThroughput < slowestThroughput ? current : slowest;
        }, null);
    }
}