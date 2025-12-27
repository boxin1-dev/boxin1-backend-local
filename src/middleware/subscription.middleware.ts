// src/middleware/subscription.middleware.ts
import { NextFunction, Request, Response } from "express";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

/**
 * Middleware to check if user has an active subscription
 * Must be used AFTER authMiddleware
 */
export const subscriptionMiddleware = async (
    req: Request,
    res: Response,
    next: NextFunction
) => {
    try {
        if (!req.user) {
            return res.status(401).json({
                success: false,
                message: "Authentification requise",
            });
        }

        // Récupérer l'utilisateur pour vérifier la date d'expiration
        const user = await prisma.user.findUnique({
            where: { id: req.user.userId },
            select: { subscriptionExpiresAt: true },
        });

        if (!user) {
            return res.status(404).json({
                success: false,
                message: "Utilisateur non trouvé",
            });
        }

        const now = new Date();
        const expiryDate = user.subscriptionExpiresAt ? new Date(user.subscriptionExpiresAt) : null;

        if (!expiryDate || expiryDate < now) {
            return res.status(403).json({
                success: false,
                message: "Votre abonnement Box est expiré ou inexistant. Veuillez le recharger dans votre profil.",
                code: "SUBSCRIPTION_EXPIRED",
                expiredAt: expiryDate,
            });
        }

        next();
    } catch (error: any) {
        console.error("Erreur middleware abonnement:", error);
        res.status(500).json({
            success: false,
            message: "Erreur lors de la vérification de l'abonnement",
        });
    }
};
