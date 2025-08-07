import { OtpPurpose, PrismaClient } from "@prisma/client";
import crypto from "crypto";
import { EmailService } from "./email.service";

const prisma = new PrismaClient();

export class OtpService {
  private emailService = new EmailService();

  async generateOtp(email: string, purpose: OtpPurpose): Promise<void> {
    const user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      throw new Error("Utilisateur non trouvé");
    }

    // Invalider les anciens codes OTP
    await prisma.otpCode.updateMany({
      where: {
        userId: user.id,
        purpose,
        used: false,
      },
      data: { used: true },
    });

    // Générer un nouveau code à 6 chiffres
    const code = crypto.randomInt(100000, 999999).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await prisma.otpCode.create({
      data: {
        code,
        userId: user.id,
        purpose,
        expiresAt,
      },
    });

    // Envoyer l'OTP par email
    await this.emailService.sendOtpCode(email, code, purpose);
  }

  async verifyOtp(
    userId: string,
    code: string,
    purpose: OtpPurpose
  ): Promise<boolean> {
    const otpRecord = await prisma.otpCode.findFirst({
      where: {
        userId,
        code,
        purpose,
        used: false,
        expiresAt: { gt: new Date() },
      },
    });

    if (!otpRecord) {
      return false;
    }

    // Marquer le code comme utilisé
    await prisma.otpCode.update({
      where: { id: otpRecord.id },
      data: { used: true },
    });

    return true;
  }

  async verifyOtpByEmail(
    email: string,
    code: string,
    purpose: OtpPurpose
  ): Promise<boolean> {
    const user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      return false;
    }

    return this.verifyOtp(user.id, code, purpose);
  }
}
