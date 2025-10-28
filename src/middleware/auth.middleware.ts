// src/middleware/auth.middleware.ts
import { NextFunction, Request, Response } from "express";
import { JwtPayload } from "../types/auth.types";
import { JwtUtil } from "../utils/jwt.util";

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