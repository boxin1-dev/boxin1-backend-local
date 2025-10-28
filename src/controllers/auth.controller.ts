// src/controllers/auth.controller.ts
import { Request, Response } from "express";
import { validationResult } from "express-validator";
import { AuthService } from "../services/auth.service";
import { OtpService } from "../services/otp.service";
import { ApiResponse } from "../types/auth.types";

export class AuthController {
  private authService = new AuthService();
  private otpService = new OtpService();

  register = async (req: Request, res: Response) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Données invalides",
          errors: errors.array(),
        });
      }

      const result = await this.authService.register(req.body);

      res.status(201).json({
        success: true,
        message: "Compte créé avec succès. Vérifiez votre email.",
        data: result,
      } as ApiResponse);
    } catch (error: any) {
      res.status(400).json({
        success: false,
        message: error.message,
        error: process.env.NODE_ENV === "development" ? error.stack : undefined,
      } as ApiResponse);
    }
  };

  login = async (req: Request, res: Response) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Données invalides",
          errors: errors.array(),
        });
      }

      const result = await this.authService.login(req.body);

      
      res.json({
        success: true,
        message: "Connexion réussie",
        data: result,
      } as ApiResponse);
      
    } catch (error: any) {
      res.status(401).json({
        success: false,
        message: error.message,
      } as ApiResponse);
    }
  };

  forgotPassword = async (req: Request, res: Response) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Email invalide",
          errors: errors.array(),
        });
      }

      await this.authService.forgotPassword(req.body.email);

      res.json({
        success: true,
        message:
          "Si cet email existe, un lien de réinitialisation a été envoyé.",
      } as ApiResponse);
    } catch (error: any) {
      res.status(500).json({
        success: false,
        message: "Erreur interne du serveur",
      } as ApiResponse);
    }
  };

  resetPassword = async (req: Request, res: Response) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Données invalides",
          errors: errors.array(),
        });
      }

      await this.authService.resetPassword(
        req.body.token,
        req.body.newPassword
      );

      res.json({
        success: true,
        message: "Mot de passe réinitialisé avec succès",
      } as ApiResponse);
    } catch (error: any) {
      res.status(400).json({
        success: false,
        message: error.message,
      } as ApiResponse);
    }
  };

  verifyEmail = async (req: Request, res: Response) => {
    try {
      const { token } = req.params;

      await this.authService.verifyEmail(token);

      res.json({
        success: true,
        message: "Email vérifié avec succès",
      } as ApiResponse);
    } catch (error: any) {
      res.status(400).json({
        success: false,
        message: error.message,
      } as ApiResponse);
    }
  };

  refreshToken = async (req: Request, res: Response) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Refresh token requis",
          errors: errors.array(),
        });
      }

      const result = await this.authService.refreshToken(req.body.refreshToken);

      res.json({
        success: true,
        message: "Tokens renouvelés",
        data: result,
      } as ApiResponse);
    } catch (error: any) {
      res.status(401).json({
        success: false,
        message: error.message,
      } as ApiResponse);
    }
  };

  logout = async (req: Request, res: Response) => {
    try {
      const { refreshToken } = req.body;

      if (refreshToken) {
        await this.authService.logout(refreshToken);
      }

      res.json({
        success: true,
        message: "Déconnexion réussie",
      } as ApiResponse);
    } catch (error: any) {
      res.json({
        success: true,
        message: "Déconnexion réussie",
      } as ApiResponse);
    }
  };

  generateOtp = async (req: Request, res: Response) => {
    try {
      const { email, purpose } = req.body;

      await this.otpService.generateOtp(email, purpose);

      res.json({
        success: true,
        message: "Code OTP envoyé",
      } as ApiResponse);
    } catch (error: any) {
      res.status(400).json({
        success: false,
        message: error.message,
      } as ApiResponse);
    }
  };

  verifyOtp = async (req: Request, res: Response) => {
    try {
      const { email, code, purpose } = req.body;

      const result = await this.otpService.verifyOtpByEmail(
        email,
        code,
        purpose
      );

      res.json({
        success: true,
        message: result ? "Code OTP valide" : "Code OTP invalide",
        data: { valid: result },
      } as ApiResponse);
    } catch (error: any) {
      res.status(400).json({
        success: false,
        message: error.message,
      } as ApiResponse);
    }
  };

  getProfile = async (req: Request, res: Response) => {
    try {
      const userId = req.user?.userId;
      
      if (!userId) {
        return res.status(401).json({
          success: false,
          message: "Non authentifié",
        } as ApiResponse);
      }

      // Récupérer les infos de l'utilisateur depuis la DB
      const { PrismaClient } = await import("@prisma/client");
      const prisma = new PrismaClient();

      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          email: true,
          firstName: true,
          lastName: true,
          role: true,
          isEmailVerified: true,
          lastLogin: true,
          createdAt: true,
        },
      });

      if (!user) {
        return res.status(404).json({
          success: false,
          message: "Utilisateur non trouvé",
        } as ApiResponse);
      }

      res.json({
        success: true,
        message: "Profil récupéré",
        data: { user },
      } as ApiResponse);
    } catch (error: any) {
      res.status(500).json({
        success: false,
        message: "Erreur interne du serveur",
      } as ApiResponse);
    }
  };
}
