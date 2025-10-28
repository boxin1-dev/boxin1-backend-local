// src/routes/device.routes.ts
import express from "express";
import { PrismaClient } from "@prisma/client";
import { authMiddleware } from "../middleware/auth.middleware";

const router = express.Router();
const prisma = new PrismaClient();

/**
 * @swagger
 * components:
 *   schemas:
 *     Device:
 *       type: object
 *       required:
 *         - device_id
 *         - device_name
 *         - device_type_code
 *         - discovery_topic
 *         - command_topic
 *         - status_topic
 *         - last_discovery
 *       properties:
 *         device_id:
 *           type: string
 *         device_name:
 *           type: string
 *         device_type_code:
 *           type: string
 *         discovery_topic:
 *           type: string
 *         command_topic:
 *           type: string
 *         status_topic:
 *           type: string
 *         last_discovery:
 *           type: string
 *           format: date-time
 *         firmware_version:
 *           type: string
 *         ip_address:
 *           type: string
 *         device_type_id:
 *           type: integer
 *         location_id:
 *           type: integer
 *         user_notes:
 *           type: string
 *         manufacturer:
 *           type: string
 *         is_online:
 *           type: boolean
 *         is_enabled:
 *           type: boolean
 */

/**
 * @swagger
 * tags:
 *   name: Devices
 *   description: Gestion des appareils SmartBox
 */

/**
 * @swagger
 * /api/devices:
 *   post:
 *     summary: Ajouter un nouvel appareil
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Device'
 *     responses:
 *       201:
 *         description: Appareil créé avec succès
 *       400:
 *         description: Données invalides
 *       401:
 *         description: Non autorisé
 *       409:
 *         description: Un appareil avec cet ID existe déjà
 */
router.post("/", authMiddleware, async (req, res) => {
  try {
    const {
      device_id,
      device_name,
      device_type_code,
      discovery_topic,
      command_topic,
      status_topic,
      last_discovery,
      firmware_version,
      ip_address,
      device_type_id,
      location_id,
      user_notes,
    } = req.body;

    // Validation des champs requis
    const requiredFields = ["device_id", "device_name", "device_type_code", "discovery_topic", "command_topic", "status_topic", "last_discovery"];
    const missingFields = requiredFields.filter(field => !req.body[field]);

    if (missingFields.length > 0) {
      return res.status(400).json({
        success: false,
        message: "Certains champs obligatoires sont manquants",
        missing_fields: missingFields,
        required_fields: requiredFields
      });
    }

    // Vérifier si l'appareil existe déjà
    const existingDevice = await prisma.smartbox_devices.findUnique({
      where: { device_id }
    });

    if (existingDevice) {
      return res.status(409).json({
        success: false,
        message: "Un appareil avec cet ID existe déjà"
      });
    }

    const newDevice = await prisma.smartbox_devices.create({
      data: {
        device_id,
        device_name,
        device_type_code,
        discovery_topic,
        command_topic,
        status_topic,
        last_discovery: new Date(last_discovery),
        firmware_version: firmware_version || null,
        ip_address: ip_address || null,
        device_type_id: device_type_id || null,
        location_id: location_id || null,
        user_notes: user_notes || null,
        manufacturer: "SmartBox",
        is_online: false,
        is_enabled: true,
      },
    });

    res.status(201).json({
      success: true,
      message: "Appareil ajouté avec succès",
      data: newDevice,
    });
  } catch (error: any) {
    console.error("Erreur ajout appareil:", error);
    
    // Gestion spécifique des erreurs Prisma
    if (error.code === 'P2002') {
      return res.status(409).json({
        success: false,
        message: "Un appareil avec cet ID existe déjà"
      });
    }
    
    res.status(500).json({
      success: false,
      message: error.message || "Erreur interne du serveur",
    });
  }
});

/**
 * @swagger
 * /api/devices:
 *   get:
 *     summary: Récupérer tous les appareils
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Liste des appareils
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Device'
 */
router.get("/", authMiddleware, async (req, res) => {
  try {
    const devices = await prisma.smartbox_devices.findMany();
    res.json({
      success: true,
      data: devices,
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

/**
 * @swagger
 * /api/devices/{id}:
 *   get:
 *     summary: Récupérer un appareil par son ID
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: ID de l'appareil
 *     responses:
 *       200:
 *         description: Appareil trouvé
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Device'
 *       404:
 *         description: Appareil non trouvé
 */
router.get("/:id", authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    const device = await prisma.smartbox_devices.findUnique({
      where: { device_id: id }
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: "Appareil non trouvé"
      });
    }

    res.json({
      success: true,
      data: device,
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

/**
 * @swagger
 * /api/devices/{id}:
 *   put:
 *     summary: Mettre à jour un appareil
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: ID de l'appareil
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Device'
 *     responses:
 *       200:
 *         description: Appareil mis à jour avec succès
 *       404:
 *         description: Appareil non trouvé
 *       400:
 *         description: Données invalides
 */
router.put("/:id", authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const {
      device_name,
      device_type_code,
      discovery_topic,
      command_topic,
      status_topic,
      last_discovery,
      firmware_version,
      ip_address,
      device_type_id,
      location_id,
      user_notes,
      manufacturer,
      is_online,
      is_enabled,
    } = req.body;

    // Vérifier si l'appareil existe
    const existingDevice = await prisma.smartbox_devices.findUnique({
      where: { device_id: id }
    });

    if (!existingDevice) {
      return res.status(404).json({
        success: false,
        message: "Appareil non trouvé"
      });
    }

    const updatedDevice = await prisma.smartbox_devices.update({
      where: { device_id: id },
      data: {
        device_name,
        device_type_code,
        discovery_topic,
        command_topic,
        status_topic,
        last_discovery: last_discovery ? new Date(last_discovery) : existingDevice.last_discovery,
        firmware_version,
        ip_address,
        device_type_id,
        location_id,
        user_notes,
        manufacturer,
        is_online,
        is_enabled,
      },
    });

    res.json({
      success: true,
      message: "Appareil mis à jour avec succès",
      data: updatedDevice,
    });
  } catch (error: any) {
    console.error("Erreur mise à jour appareil:", error);
    
    if (error.code === 'P2025') {
      return res.status(404).json({
        success: false,
        message: "Appareil non trouvé"
      });
    }
    
    res.status(500).json({
      success: false,
      message: error.message || "Erreur interne du serveur",
    });
  }
});

/**
 * @swagger
 * /api/devices/{id}:
 *   delete:
 *     summary: Supprimer un appareil
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: ID de l'appareil
 *     responses:
 *       200:
 *         description: Appareil supprimé avec succès
 *       404:
 *         description: Appareil non trouvé
 */
router.delete("/:id", authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    // Vérifier si l'appareil existe
    const existingDevice = await prisma.smartbox_devices.findUnique({
      where: { device_id: id }
    });

    if (!existingDevice) {
      return res.status(404).json({
        success: false,
        message: "Appareil non trouvé"
      });
    }

    await prisma.smartbox_devices.delete({
      where: { device_id: id }
    });

    res.json({
      success: true,
      message: "Appareil supprimé avec succès"
    });
  } catch (error: any) {
    console.error("Erreur suppression appareil:", error);
    
    if (error.code === 'P2025') {
      return res.status(404).json({
        success: false,
        message: "Appareil non trouvé"
      });
    }
    
    res.status(500).json({
      success: false,
      message: error.message || "Erreur interne du serveur",
    });
  }
});

export default router;