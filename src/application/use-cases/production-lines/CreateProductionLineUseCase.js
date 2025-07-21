// =============================================================================
// src/application/use-cases/production-lines/CreateProductionLineUseCase.js
// Caso de uso para crear líneas de producción VSM
// =============================================================================

const logger = require('../../../../config/logger');
const ProductionLine = require('../../../core/entities/ProductionLine');
const Process = require('../../../core/entities/Process');
const Equipment = require('../../../core/entities/Equipment');
const ParallelEquipmentGroup = require('../../../core/entities/ParallelEquipmentGroup');

/**
 * Caso de uso para crear una nueva línea de producción VSM
 * Implementa validaciones de negocio y orquestación de entidades
 */
class CreateProductionLineUseCase {
    constructor(
        productionLineRepository,
        processRepository,
        equipmentRepository,
        validationService
    ) {
        this.productionLineRepository = productionLineRepository;
        this.processRepository = processRepository;
        this.equipmentRepository = equipmentRepository;
        this.validationService = validationService;
    }

    /**
     * Ejecutar creación de línea de producción
     * @param {Object} lineData - Datos de la línea a crear
     * @returns {Promise<{success: boolean, data?: Object, errors?: Array}>}
     */
    async execute(lineData) {
        try {
            logger.info('Iniciando creación de línea de producción:', { 
                name: lineData.name,
                processCount: lineData.processes?.length 
            });

            // Paso 1: Validaciones básicas
            const validationResult = await this.validateLineData(lineData);
            if (!validationResult.isValid) {
                return {
                    success: false,
                    message: 'Datos de línea inválidos',
                    errors: validationResult.errors
                };
            }

            // Paso 2: Verificar unicidad del código
            if (lineData.code) {
                const existingLine = await this.productionLineRepository.findByCode(lineData.code);
                if (existingLine) {
                    return {
                        success: false,
                        message: 'Ya existe una línea con este código',
                        errors: ['DUPLICATE_CODE']
                    };
                }
            }

            // Paso 3: Crear entidad de línea principal
            const productionLine = new ProductionLine({
                name: lineData.name.trim(),
                code: lineData.code?.trim() || this.generateLineCode(),
                description: lineData.description?.trim(),
                status: 'draft', // Comienza como borrador
                createdAt: new Date(),
                updatedAt: new Date()
            });

            // Paso 4: Procesar y crear procesos asociados
            const createdProcesses = [];
            if (lineData.processes && Array.isArray(lineData.processes)) {
                for (let i = 0; i < lineData.processes.length; i++) {
                    const processData = lineData.processes[i];
                    
                    const processResult = await this.createProcessForLine(
                        processData, 
                        productionLine.id, 
                        i + 1
                    );
                    
                    if (!processResult.success) {
                        // Rollback: eliminar procesos ya creados
                        await this.rollbackCreatedProcesses(createdProcesses);
                        return {
                            success: false,
                            message: `Error creando proceso ${i + 1}: ${processResult.message}`,
                            errors: processResult.errors
                        };
                    }
                    
                    createdProcesses.push(processResult.data);
                }
            }

            // Paso 5: Guardar línea principal en BD
            const savedLine = await this.productionLineRepository.create(productionLine);

            // Paso 6: Asociar procesos con la línea guardada
            for (const process of createdProcesses) {
                process.productionLineId = savedLine.id;
                await this.processRepository.update(process.id, process);
            }

            // Paso 7: Calcular métricas iniciales
            await this.calculateInitialMetrics(savedLine.id);

            // Paso 8: Preparar respuesta completa
            const completeLineData = await this.getCompleteLineData(savedLine.id);

            logger.info('Línea de producción creada exitosamente:', { 
                id: savedLine.id,
                name: savedLine.name,
                processCount: createdProcesses.length
            });

            return {
                success: true,
                message: 'Línea de producción creada exitosamente',
                data: completeLineData
            };

        } catch (error) {
            logger.error('Error en CreateProductionLineUseCase:', error);
            return {
                success: false,
                message: 'Error interno creando línea de producción',
                errors: [error.message]
            };
        }
    }

    /**
     * Validar datos de entrada de la línea
     * @param {Object} lineData - Datos a validar
     * @returns {Promise<{isValid: boolean, errors: Array}>}
     */
    async validateLineData(lineData) {
        const errors = [];

        // Validaciones requeridas
        if (!lineData.name || lineData.name.trim().length < 3) {
            errors.push('El nombre debe tener al menos 3 caracteres');
        }

        if (lineData.name && lineData.name.length > 100) {
            errors.push('El nombre no puede exceder 100 caracteres');
        }

        if (lineData.code && lineData.code.length > 20) {
            errors.push('El código no puede exceder 20 caracteres');
        }

        if (lineData.description && lineData.description.length > 500) {
            errors.push('La descripción no puede exceder 500 caracteres');
        }

        // Validar estructura de procesos
        if (lineData.processes) {
            if (!Array.isArray(lineData.processes)) {
                errors.push('Los procesos deben ser un arreglo');
            } else if (lineData.processes.length > 20) {
                errors.push('Una línea no puede tener más de 20 procesos');
            } else {
                // Validar cada proceso
                for (let i = 0; i < lineData.processes.length; i++) {
                    const processErrors = await this.validateProcessData(lineData.processes[i], i + 1);
                    errors.push(...processErrors);
                }
            }
        }

        return {
            isValid: errors.length === 0,
            errors
        };
    }

    /**
     * Validar datos de un proceso individual
     * @param {Object} processData - Datos del proceso
     * @param {number} processIndex - Índice del proceso (para errores)
     * @returns {Promise<Array>} Array de errores
     */
    async validateProcessData(processData, processIndex) {
        const errors = [];

        if (!processData.name || processData.name.trim().length < 2) {
            errors.push(`Proceso ${processIndex}: el nombre debe tener al menos 2 caracteres`);
        }

        if (processData.cycleTime && (isNaN(processData.cycleTime) || processData.cycleTime <= 0)) {
            errors.push(`Proceso ${processIndex}: tiempo de ciclo debe ser un número positivo`);
        }

        if (processData.setupTime && (isNaN(processData.setupTime) || processData.setupTime < 0)) {
            errors.push(`Proceso ${processIndex}: tiempo de setup debe ser un número no negativo`);
        }

        // Validar equipos del proceso
        if (processData.equipment && Array.isArray(processData.equipment)) {
            if (processData.equipment.length > 10) {
                errors.push(`Proceso ${processIndex}: no puede tener más de 10 equipos`);
            }

            for (let j = 0; j < processData.equipment.length; j++) {
                const equipmentErrors = await this.validateEquipmentData(
                    processData.equipment[j], 
                    processIndex, 
                    j + 1
                );
                errors.push(...equipmentErrors);
            }
        }

        return errors;
    }

    /**
     * Validar datos de equipo individual
     * @param {Object} equipmentData - Datos del equipo
     * @param {number} processIndex - Índice del proceso
     * @param {number} equipmentIndex - Índice del equipo
     * @returns {Promise<Array>} Array de errores
     */
    async validateEquipmentData(equipmentData, processIndex, equipmentIndex) {
        const errors = [];

        if (!equipmentData.name || equipmentData.name.trim().length < 2) {
            errors.push(`Proceso ${processIndex}, Equipo ${equipmentIndex}: nombre requerido`);
        }

        // Validar equipos paralelos
        if (equipmentData.type === 'parallel') {
            if (!equipmentData.equipment || !Array.isArray(equipmentData.equipment)) {
                errors.push(`Proceso ${processIndex}, Equipo ${equipmentIndex}: grupo paralelo debe tener equipos`);
            } else if (equipmentData.equipment.length < 2) {
                errors.push(`Proceso ${processIndex}, Equipo ${equipmentIndex}: grupo paralelo necesita al menos 2 equipos`);
            } else if (equipmentData.equipment.length > 5) {
                errors.push(`Proceso ${processIndex}, Equipo ${equipmentIndex}: grupo paralelo no puede tener más de 5 equipos`);
            }
        }

        // Verificar que el equipo exista si se proporciona ID
        if (equipmentData.id && !equipmentData.id.startsWith('temp_')) {
            const existingEquipment = await this.equipmentRepository.findById(equipmentData.id);
            if (!existingEquipment) {
                errors.push(`Proceso ${processIndex}, Equipo ${equipmentIndex}: equipo no encontrado`);
            }
        }

        return errors;
    }

    /**
     * Crear proceso asociado a una línea
     * @param {Object} processData - Datos del proceso
     * @param {string} lineId - ID de la línea
     * @param {number} sequence - Secuencia del proceso
     * @returns {Promise<{success: boolean, data?: Object, errors?: Array}>}
     */
    async createProcessForLine(processData, lineId, sequence) {
        try {
            // Crear entidad proceso
            const process = new Process({
                name: processData.name.trim(),
                description: processData.description?.trim(),
                sequence: sequence,
                cycleTime: processData.cycleTime || null,
                setupTime: processData.setupTime || null,
                productionLineId: lineId,
                createdAt: new Date(),
                updatedAt: new Date()
            });

            // Guardar proceso
            const savedProcess = await this.processRepository.create(process);

            // Crear equipos asociados
            const createdEquipment = [];
            if (processData.equipment && Array.isArray(processData.equipment)) {
                for (const equipmentData of processData.equipment) {
                    const equipmentResult = await this.createEquipmentForProcess(
                        equipmentData,
                        savedProcess.id
                    );
                    
                    if (equipmentResult.success) {
                        createdEquipment.push(equipmentResult.data);
                    }
                }
            }

            return {
                success: true,
                data: {
                    ...savedProcess,
                    equipment: createdEquipment
                }
            };

        } catch (error) {
            logger.error('Error creando proceso:', error);
            return {
                success: false,
                message: 'Error creando proceso',
                errors: [error.message]
            };
        }
    }

    /**
     * Crear equipo asociado a un proceso
     * @param {Object} equipmentData - Datos del equipo
     * @param {string} processId - ID del proceso
     * @returns {Promise<{success: boolean, data?: Object}>}
     */
    async createEquipmentForProcess(equipmentData, processId) {
        try {
            if (equipmentData.type === 'parallel') {
                // Crear grupo de equipos paralelos
                const parallelGroup = new ParallelEquipmentGroup({
                    name: equipmentData.name.trim(),
                    processId: processId,
                    aggregationMethod: 'weighted_average', // Por defecto
                    createdAt: new Date(),
                    updatedAt: new Date()
                });

                const savedGroup = await this.equipmentRepository.createParallelGroup(parallelGroup);

                // Crear equipos individuales del grupo
                const groupEquipment = [];
                if (equipmentData.equipment && Array.isArray(equipmentData.equipment)) {
                    for (const individualEquip of equipmentData.equipment) {
                        const equipment = new Equipment({
                            name: individualEquip.name.trim(),
                            processId: processId,
                            parallelGroupId: savedGroup.id,
                            csvUrl: individualEquip.csvUrl || '',
                            status: 'active',
                            createdAt: new Date(),
                            updatedAt: new Date()
                        });

                        const saved = await this.equipmentRepository.create(equipment);
                        groupEquipment.push(saved);
                    }
                }

                return {
                    success: true,
                    data: {
                        ...savedGroup,
                        equipment: groupEquipment
                    }
                };

            } else {
                // Crear equipo individual
                const equipment = new Equipment({
                    name: equipmentData.name.trim(),
                    processId: processId,
                    csvUrl: equipmentData.csvUrl || '',
                    cycleTime: equipmentData.cycleTime || null,
                    status: 'active',
                    createdAt: new Date(),
                    updatedAt: new Date()
                });

                const savedEquipment = await this.equipmentRepository.create(equipment);

                return {
                    success: true,
                    data: savedEquipment
                };
            }

        } catch (error) {
            logger.error('Error creando equipo:', error);
            return {
                success: false,
                message: 'Error creando equipo',
                errors: [error.message]
            };
        }
    }

    /**
     * Rollback de procesos creados en caso de error
     * @param {Array} createdProcesses - Procesos a eliminar
     */
    async rollbackCreatedProcesses(createdProcesses) {
        try {
            for (const process of createdProcesses) {
                await this.processRepository.delete(process.id);
                logger.debug('Proceso eliminado en rollback:', process.id);
            }
        } catch (error) {
            logger.error('Error en rollback de procesos:', error);
        }
    }

    /**
     * Calcular métricas iniciales de la línea
     * @param {string} lineId - ID de la línea
     */
    async calculateInitialMetrics(lineId) {
        try {
            // TODO: Implementar cálculos iniciales de métricas VSM
            logger.debug('Calculando métricas iniciales para línea:', lineId);
        } catch (error) {
            logger.error('Error calculando métricas iniciales:', error);
        }
    }

    /**
     * Obtener datos completos de la línea creada
     * @param {string} lineId - ID de la línea
     * @returns {Promise<Object>} Datos completos de la línea
     */
    async getCompleteLineData(lineId) {
        try {
            const line = await this.productionLineRepository.findByIdWithDetails(lineId);
            return line;
        } catch (error) {
            logger.error('Error obteniendo datos completos de línea:', error);
            return null;
        }
    }

    /**
     * Generar código único para la línea
     * @returns {string} Código generado
     */
    generateLineCode() {
        const timestamp = Date.now().toString().slice(-6);
        return `LP${timestamp}`;
    }
}

module.exports = CreateProductionLineUseCase;