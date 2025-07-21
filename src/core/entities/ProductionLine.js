// =============================================================================
// src/core/entities/ProductionLine.js - Línea de producción completa
// =============================================================================
class ProductionLine {
    constructor({
        id,
        lineCode,
        lineName,
        description,
        targetPiecesPerHour,
        targetOeePercentage,
        plannedProductionTimeHours,
        displayOrder,
        lineColor,
        lineIcon,
        shiftConfiguration,
        active,
        createdAt,
        updatedAt
    }) {
        this.id = id;
        this.lineCode = lineCode;
        this.lineName = lineName;
        this.description = description;
        this.targetPiecesPerHour = targetPiecesPerHour;
        this.targetOeePercentage = targetOeePercentage;
        this.plannedProductionTimeHours = plannedProductionTimeHours;
        this.displayOrder = displayOrder;
        this.lineColor = lineColor;
        this.lineIcon = lineIcon;
        this.shiftConfiguration = shiftConfiguration;
        this.active = active;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        
        this.processes = []; // Array de Process entities
        
        this.validate();
    }

    validate() {
        if (!this.lineCode || this.lineCode.trim().length === 0) {
            throw new Error('Line code is required');
        }
        if (!this.lineName || this.lineName.trim().length === 0) {
            throw new Error('Line name is required');
        }
        if (this.targetPiecesPerHour && this.targetPiecesPerHour <= 0) {
            throw new Error('Target pieces per hour must be positive');
        }
        if (this.targetOeePercentage && (this.targetOeePercentage <= 0 || this.targetOeePercentage > 100)) {
            throw new Error('Target OEE percentage must be between 0 and 100');
        }
    }

    addProcess(process) {
        if (this.processes.find(p => p.sequence === process.sequence)) {
            throw new Error(`Process with sequence ${process.sequence} already exists`);
        }
        this.processes.push(process);
        this.processes.sort((a, b) => a.sequence - b.sequence);
    }

    removeProcess(sequence) {
        this.processes = this.processes.filter(p => p.sequence !== sequence);
    }

    getProcessBySequence(sequence) {
        return this.processes.find(p => p.sequence === sequence);
    }

    getTotalDesignCycleTime() {
        return this.processes.reduce((total, process) => total + process.designCycleTimeSeconds, 0);
    }

    isBalanced() {
        if (this.processes.length < 2) return true;
        
        const cycleTimes = this.processes.map(p => p.designCycleTimeSeconds);
        const maxTime = Math.max(...cycleTimes);
        const minTime = Math.min(...cycleTimes);
        
        // Considerar balanceada si la diferencia es menor al 10%
        return (maxTime - minTime) / maxTime < 0.1;
    }
}