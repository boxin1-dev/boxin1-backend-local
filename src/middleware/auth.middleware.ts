// src/middleware/auth.middleware.ts
import { NextFunction, Request, Response } from "express";
import { JwtPayload } from "../types/auth.types";
import { JwtUtil } from "../utils/jwt.util";

// Extend Express Request type
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
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "Token d'authentification requis",
      });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    const jwtUtil = new JwtUtil();

    try {
      const decoded = jwtUtil.verifyAccessToken(token);
      req.user = decoded;
      next();
    } catch (jwtError) {
      return res.status(401).json({
        success: false,
        message: "Token invalide ou expiré",
      });
    }
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur interne du serveur",
    });
  }
};

export const adminMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  if (!req.user || req.user.role !== "ADMIN") {
    return res.status(403).json({
      success: false,
      message: "Accès administrateur requis",
    });
  }
  next();
};

