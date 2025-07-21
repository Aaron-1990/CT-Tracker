// =============================================================================
// src/core/entities/CycleTime.js - Tiempo de ciclo calculado
// =============================================================================
class CycleTime {
    constructor({
        id,
        equipmentId,
        lineCode,
        stationCode,
        partNumber,
        scanFromId,
        scanToId,
        serialFrom,
        serialTo,
        timestampFrom,
        timestampTo,
        cycleTimeSeconds,
        isValid,
        anomalyReason,
        calculatedAt
    }) {
        this.id = id;
        this.equipmentId = equipmentId;
        this.lineCode = lineCode;
        this.stationCode = stationCode;
        this.partNumber = partNumber;
        this.scanFromId = scanFromId;
        this.scanToId = scanToId;
        this.serialFrom = serialFrom;
        this.serialTo = serialTo;
        this.timestampFrom = timestampFrom;
        this.timestampTo = timestampTo;
        this.cycleTimeSeconds = cycleTimeSeconds;
        this.isValid = isValid;
        this.anomalyReason = anomalyReason;
        this.calculatedAt = calculatedAt;
        
        this.validate();
    }

    validate() {
        if (!this.serialFrom || !this.serialTo) {
            throw new Error('Both serials are required');
        }
        if (this.serialFrom === this.serialTo) {
            throw new Error('Serials must be different');
        }
        if (!this.timestampFrom || !this.timestampTo) {
            throw new Error('Both timestamps are required');
        }
        if (this.timestampFrom >= this.timestampTo) {
            throw new Error('Timestamp from must be before timestamp to');
        }
        if (this.cycleTimeSeconds <= 0) {
            throw new Error('Cycle time must be positive');
        }
    }

    calculateEfficiency(designCycleTime) {
        if (!designCycleTime || designCycleTime <= 0) return null;
        return (designCycleTime / this.cycleTimeSeconds) * 100;
    }

    isWithinTolerance(designCycleTime, tolerancePercentage) {
        if (!designCycleTime || !tolerancePercentage) return null;
        
        const tolerance = designCycleTime * (tolerancePercentage / 100);
        const min = designCycleTime - tolerance;
        const max = designCycleTime + tolerance;
        
        return this.cycleTimeSeconds >= min && this.cycleTimeSeconds <= max;
    }

    getDurationMinutes() {
        const diffMs = new Date(this.timestampTo) - new Date(this.timestampFrom);
        return diffMs / (1000 * 60);
    }
}

module.exports = {
    ProductionLine,
    Process,
    Equipment,
    Scan,
    CycleTime
};