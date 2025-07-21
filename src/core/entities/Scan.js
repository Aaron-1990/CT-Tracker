// =============================================================================
// src/core/entities/Scan.js - Registro de escaneo del CSV
// =============================================================================
class Scan {
    constructor({
        id,
        serial,
        lineCode,
        partNumber,
        processName,
        stationCode,
        status,
        timestamp,
        equipmentId,
        createdAt
    }) {
        this.id = id;
        this.serial = serial;
        this.lineCode = lineCode;
        this.partNumber = partNumber;
        this.processName = processName;
        this.stationCode = stationCode;
        this.status = status;
        this.timestamp = timestamp;
        this.equipmentId = equipmentId;
        this.createdAt = createdAt;
        
        this.validate();
    }

    validate() {
        if (!this.serial || this.serial.trim().length === 0) {
            throw new Error('Serial is required');
        }
        if (!this.status || this.status.trim().length === 0) {
            throw new Error('Status is required');
        }
        if (!this.timestamp) {
            throw new Error('Timestamp is required');
        }
    }

    isBREQ() {
        return this.status === 'BREQ';
    }

    isBCMP() {
        return this.status.startsWith('BCMP');
    }

    isBCMPOK() {
        return this.status === 'BCMP OK';
    }

    isBCMPNG() {
        return this.status === 'BCMP NG' || (this.status.startsWith('BCMP') && this.status !== 'BCMP OK');
    }

    isProcessComplete() {
        return this.isBCMP();
    }

    isSuccessful() {
        return this.isBCMPOK();
    }
}