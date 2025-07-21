// =============================================================================
// src/core/entities/Equipment.js - Equipo individual
// =============================================================================
class Equipment {
    constructor({
        id,
        equipmentCode,
        equipmentName,
        processName,
        csvUrl,
        lineCode,
        processSequence,
        designCycleTimeSeconds,
        designProcessTimeSeconds,
        tolerancePercentage,
        pollingIntervalSeconds,
        active,
        lastProcessedTimestamp,
        createdAt,
        updatedAt
    }) {
        this.id = id;
        this.equipmentCode = equipmentCode;
        this.equipmentName = equipmentName;
        this.processName = processName;
        this.csvUrl = csvUrl;
        this.lineCode = lineCode;
        this.processSequence = processSequence;
        this.designCycleTimeSeconds = designCycleTimeSeconds;
        this.designProcessTimeSeconds = designProcessTimeSeconds;
        this.tolerancePercentage = tolerancePercentage || 15.0;
        this.pollingIntervalSeconds = pollingIntervalSeconds || 30;
        this.active = active;
        this.lastProcessedTimestamp = lastProcessedTimestamp;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        
        this.validate();
    }

    validate() {
        if (!this.equipmentCode || this.equipmentCode.trim().length === 0) {
            throw new Error('Equipment code is required');
        }
        if (!this.equipmentName || this.equipmentName.trim().length === 0) {
            throw new Error('Equipment name is required');
        }
        if (!this.csvUrl || this.csvUrl.trim().length === 0) {
            throw new Error('CSV URL is required');
        }
        if (this.designCycleTimeSeconds && this.designCycleTimeSeconds <= 0) {
            throw new Error('Design cycle time must be positive');
        }
        if (this.tolerancePercentage && (this.tolerancePercentage < 0 || this.tolerancePercentage > 100)) {
            throw new Error('Tolerance percentage must be between 0 and 100');
        }
    }

    isOnline() {
        if (!this.lastProcessedTimestamp) return false;
        
        const now = new Date();
        const lastUpdate = new Date(this.lastProcessedTimestamp);
        const diffMinutes = (now - lastUpdate) / (1000 * 60);
        
        return diffMinutes <= 5; // Considerar online si la última actualización fue hace menos de 5 minutos
    }

    getToleranceRange() {
        if (!this.designCycleTimeSeconds || !this.tolerancePercentage) {
            return { min: null, max: null };
        }
        
        const tolerance = this.designCycleTimeSeconds * (this.tolerancePercentage / 100);
        return {
            min: this.designCycleTimeSeconds - tolerance,
            max: this.designCycleTimeSeconds + tolerance
        };
    }

    isWithinTolerance(actualCycleTime) {
        const range = this.getToleranceRange();
        if (!range.min || !range.max) return null;
        
        return actualCycleTime >= range.min && actualCycleTime <= range.max;
    }

    calculateEfficiency(actualCycleTime) {
        if (!this.designCycleTimeSeconds || !actualCycleTime || actualCycleTime <= 0) {
            return null;
        }
        
        return (this.designCycleTimeSeconds / actualCycleTime) * 100;
    }
}