// src/middleware/auth.middleware.ts
import { NextFunction, Request, Response } from "express";
import { JwtPayload } from "../types/auth.types";
import { JwtUtil } from "../utils/jwt.util";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
    }
  }
}

export const authMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    console.log('🔐 Middleware auth - Headers:', req.headers);
    
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      console.log('❌ Header Authorization manquant');
      return res.status(401).json({
        success: false,
        message: "Token d'authentification requis",
      });
    }

    if (!authHeader.startsWith("Bearer ")) {
      console.log('❌ Format Bearer manquant');
      return res.status(401).json({
        success: false,
        message: "Format de token invalide. Utilisez 'Bearer <token>'",
      });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    
    if (!token) {
      console.log('❌ Token vide après Bearer');
      return res.status(401).json({
        success: false,
        message: "Token manquant",
      });
    }

    console.log('🔑 Token reçu:', token.substring(0, 50) + '...');
    
    const jwtUtil = new JwtUtil();
    const decoded = jwtUtil.verifyAccessToken(token);
    
    req.user = decoded;
    console.log('✅ Utilisateur authentifié:', decoded.email);
    next();
    
  } catch (error: any) {
    console.error('❌ Erreur authentification:', error.message);
    
    if (error.message.includes('expiré')) {
      return res.status(401).json({
        success: false,
        message: "Token expiré",
      });
    } else if (error.message.includes('invalide')) {
      return res.status(401).json({
        success: false,
        message: "Token invalide",
      });
    } else {
      return res.status(500).json({
        success: false,
        message: "Erreur d'authentification",
      });
    }
  }
};

/**
 * Middleware pour vérifier les droits administrateur
 * Doit être utilisé APRÈS authMiddleware
 */
export const adminMiddleware = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    // Vérifier que l'utilisateur est déjà authentifié par authMiddleware
    if (!req.user) {
      console.log('❌ Admin middleware - Utilisateur non authentifié');
      return res.status(401).json({
        success: false,
        message: "Authentification requise"
      });
    }

    console.log('🔍 Vérification des droits admin pour:', req.user.email);

    // Récupérer l'utilisateur depuis la base de données
    const user = await prisma.user.findUnique({
      where: { id: req.user.userId },
      select: {
        id: true,
        email: true,
        role: true,
        is_active: true
      }
    });

    if (!user) {
      console.log('❌ Utilisateur non trouvé');
      return res.status(401).json({
        success: false,
        message: "Utilisateur non trouvé"
      });
    }

    if (!user.is_active) {
      console.log('❌ Compte utilisateur désactivé');
      return res.status(401).json({
        success: false,
        message: "Compte désactivé"
      });
    }

    // Vérifier le rôle admin
    if (user.role !== 'admin') {
      console.log('❌ Accès refusé - Rôle:', user.role);
      return res.status(403).json({
        success: false,
        message: "Accès réservé aux administrateurs"
      });
    }

    console.log('✅ Droits admin vérifiés');
    next();
  } catch (error: any) {
    console.error('❌ Erreur middleware admin:', error);
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la vérification des permissions"
    });
  }
};

// Fermer la connexion Prisma lors de l'arrêt
process.on("beforeExit", async () => {
  await prisma.$disconnect();
});