// src/services/auth.service.ts
import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";
import crypto from "crypto";
import {
  AuthResponse,
  LoginRequest,
  RegisterRequest,
} from "../types/auth.types";
import { JwtUtil } from "../utils/jwt.util";
import { EmailService } from "./email.service";
import { OtpService } from "./otp.service";

const prisma = new PrismaClient();

export class AuthService {
  private jwtUtil = new JwtUtil();
  private emailService = new EmailService();
  private otpService = new OtpService();

  async register(data: RegisterRequest): Promise<AuthResponse> {
    console.log("[AuthService] Registering user with data:", JSON.stringify(data));
    const existingUser = await prisma.user.findUnique({
      where: { email: data.email },
    });

    if (existingUser) {
      throw new Error("Cet email est déjà utilisé");
    }

    const hashedPassword = await bcrypt.hash(data.password, 12);

    const user = await prisma.user.create({
      data: {
        email: data.email,
        password: hashedPassword,
        firstName: data.firstName,
        lastName: data.lastName,
        phone: data.phone,
        wallet: {
          create: {
            balance: 0,
            currency: "Ar",
            isActive: true,
          }
        }
      },
    });

    // Génération du token de vérification d'email
    const verificationToken = crypto.randomBytes(32).toString("hex");
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24h

    await prisma.emailVerification.create({
      data: {
        token: verificationToken,
        userId: user.id,
        expiresAt,
      },
    });

    // Envoi de l'email de vérification (on ne bloque pas si l'envoi échoue)
    try {
      await this.emailService.sendVerificationEmail(
        user.email,
        verificationToken
      );
    } catch (e) {
      console.error("Échec de l'envoi de l'email de vérification:", e);
    }

    // Génération des tokens JWT
    const accessToken = this.jwtUtil.generateAccessToken({
      userId: user.id,
      email: user.email,
      role: user.role,
      subscriptionExpiresAt: user.subscriptionExpiresAt || undefined,
    });

    const refreshToken = await this.generateRefreshToken(user.id);

    return {
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName || undefined,
        lastName: user.lastName || undefined,
        role: user.role,
        isEmailVerified: user.isEmailVerified,
        subscriptionExpiresAt: user.subscriptionExpiresAt || undefined,
      },
      accessToken,
      refreshToken,
    };
  }

  async login(data: LoginRequest): Promise<AuthResponse> {
    const user = await prisma.user.findUnique({
      where: { email: data.email },
    });

    if (!user || !user.isActive) {
      throw new Error("Identifiants invalides");
    }

    const isPasswordValid = await bcrypt.compare(data.password, user.password);
    if (!isPasswordValid) {
      throw new Error("Identifiants invalides");
    }

    // Vérification OTP si fourni
    if (data.otpCode) {
      const isOtpValid = await this.otpService.verifyOtp(
        user.id,
        data.otpCode,
        "LOGIN_VERIFICATION"
      );
      if (!isOtpValid) {
        throw new Error("Code OTP invalide");
      }
    }

    // Mise à jour de la dernière connexion
    await prisma.user.update({
      where: { id: user.id },
      data: { lastLogin: new Date() },
    });

    const accessToken = this.jwtUtil.generateAccessToken({
      userId: user.id,
      email: user.email,
      role: user.role,
      subscriptionExpiresAt: user.subscriptionExpiresAt || undefined,
    });

    const refreshToken = await this.generateRefreshToken(user.id);

    return {
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName || undefined,
        lastName: user.lastName || undefined,
        role: user.role,
        isEmailVerified: user.isEmailVerified,
        subscriptionExpiresAt: user.subscriptionExpiresAt || undefined,
      },
      accessToken,
      refreshToken,
    };
  }

  async forgotPassword(email: string): Promise<void> {
    const user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      // Ne pas révéler si l'email existe ou non
      return;
    }

    // Invalider tous les tokens de reset précédents
    await prisma.passwordReset.updateMany({
      where: { userId: user.id, used: false },
      data: { used: true },
    });

    const resetToken = crypto.randomBytes(32).toString("hex");
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1h

    await prisma.passwordReset.create({
      data: {
        token: resetToken,
        userId: user.id,
        expiresAt,
      },
    });

    await this.emailService.sendPasswordResetEmail(email, resetToken);
  }

  async resetPassword(token: string, newPassword: string): Promise<void> {
    const resetRequest = await prisma.passwordReset.findUnique({
      where: { token },
      include: { user: true },
    });

    if (
      !resetRequest ||
      resetRequest.used ||
      resetRequest.expiresAt < new Date()
    ) {
      throw new Error("Token de reset invalide ou expiré");
    }

    const hashedPassword = await bcrypt.hash(newPassword, 12);

    await prisma.$transaction([
      prisma.user.update({
        where: { id: resetRequest.userId },
        data: { password: hashedPassword },
      }),
      prisma.passwordReset.update({
        where: { id: resetRequest.id },
        data: { used: true },
      }),
      // Invalider tous les refresh tokens existants
      prisma.refreshToken.deleteMany({
        where: { userId: resetRequest.userId },
      }),
    ]);
  }

  async verifyEmail(token: string): Promise<void> {
    const verification = await prisma.emailVerification.findUnique({
      where: { token },
      include: { user: true },
    });

    if (!verification || verification.expiresAt < new Date()) {
      throw new Error("Token de vérification invalide ou expiré");
    }

    await prisma.$transaction([
      prisma.user.update({
        where: { id: verification.userId },
        data: { isEmailVerified: true },
      }),
      prisma.emailVerification.delete({
        where: { id: verification.id },
      }),
    ]);
  }

  async refreshToken(
    refreshToken: string
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const tokenRecord = await prisma.refreshToken.findUnique({
      where: { token: refreshToken },
      include: { user: true },
    });

    if (!tokenRecord || tokenRecord.expiresAt < new Date()) {
      throw new Error("Refresh token invalide ou expiré");
    }

    // Supprimer l'ancien refresh token
    await prisma.refreshToken.delete({
      where: { id: tokenRecord.id },
    });

    // Générer de nouveaux tokens
    const accessToken = this.jwtUtil.generateAccessToken({
      userId: tokenRecord.user.id,
      email: tokenRecord.user.email,
      role: tokenRecord.user.role,
    });

    const newRefreshToken = await this.generateRefreshToken(
      tokenRecord.user.id
    );

    return { accessToken, refreshToken: newRefreshToken };
  }

  async logout(refreshToken: string): Promise<void> {
    await prisma.refreshToken.delete({
      where: { token: refreshToken },
    });
  }

  private async generateRefreshToken(userId: string): Promise<string> {
    const token = crypto.randomBytes(64).toString("hex");
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 jours

    await prisma.refreshToken.create({
      data: {
        token,
        userId,
        expiresAt,
      },
    });

    return token;
  }

  async updateProfile(
    userId: string,
    data: { firstName?: string; lastName?: string; phone?: string }
  ): Promise<{
    id: string;
    email: string;
    firstName: string | null;
    lastName: string | null;
    phone: string | null;
    role: string;
    isEmailVerified: boolean;
    lastLogin: Date | null;
    createdAt: Date;
  }> {
    const user = await prisma.user.update({
      where: { id: userId },
      data: {
        firstName: data.firstName,
        lastName: data.lastName,
        phone: data.phone,
      },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        phone: true,
        role: true,
        isEmailVerified: true,
        lastLogin: true,
        createdAt: true,
      },
    });

    return user;
  }

  async changePassword(
    userId: string,
    currentPassword: string,
    newPassword: string
  ): Promise<void> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new Error("Utilisateur non trouvé");
    }

    const isPasswordValid = await bcrypt.compare(currentPassword, user.password);
    if (!isPasswordValid) {
      throw new Error("Mot de passe actuel incorrect");
    }

    const hashedPassword = await bcrypt.hash(newPassword, 12);

    await prisma.$transaction([
      prisma.user.update({
        where: { id: userId },
        data: { password: hashedPassword },
      }),
      // Invalider tous les refresh tokens pour forcer reconnexion
      prisma.refreshToken.deleteMany({
        where: { userId },
      }),
    ]);
  }

  async deleteAccount(userId: string, password: string): Promise<void> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new Error("Utilisateur non trouvé");
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      throw new Error("Mot de passe incorrect");
    }

    // Supprimer toutes les données liées à l'utilisateur
    await prisma.$transaction([
      // Supprimer les refresh tokens
      prisma.refreshToken.deleteMany({
        where: { userId },
      }),
      // Supprimer les vérifications d'email en attente
      prisma.emailVerification.deleteMany({
        where: { userId },
      }),
      // Supprimer les demandes de reset de mot de passe
      prisma.passwordReset.deleteMany({
        where: { userId },
      }),
      // Supprimer les OTP
      prisma.otpCode.deleteMany({
        where: { userId },
      }),
      // Supprimer l'utilisateur
      prisma.user.delete({
        where: { id: userId },
      }),
    ]);
  }
}
