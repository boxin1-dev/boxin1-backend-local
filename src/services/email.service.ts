import { OtpPurpose } from "@prisma/client";
import nodemailer from "nodemailer";

export class EmailService {
  private transporter: nodemailer.Transporter;

  constructor() {
    this.transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || "localhost",
      port: parseInt(process.env.SMTP_PORT || "587"),
      secure: process.env.SMTP_SECURE === "true",
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  }

  async sendVerificationEmail(email: string, token: string): Promise<void> {
    const verificationUrl = `${process.env.FRONTEND_URL}/api/auth/verify-email/${token}`;

    await this.transporter.sendMail({
      from: process.env.FROM_EMAIL || "noreply@boxin1.com",
      to: email,
      subject: "Vérifiez votre adresse email",
      html: `
        <div style="max-width: 600px; margin: 0 auto; font-family: Arial, sans-serif;">
          <h2>Vérification d'email</h2>
          <p>Merci de vous être inscrit ! Cliquez sur le lien ci-dessous pour vérifier votre adresse email :</p>
          <a href="${verificationUrl}" style="display: inline-block; padding: 12px 24px; background-color: #007bff; color: white; text-decoration: none; border-radius: 4px;">
            Vérifier mon email
          </a>
          <p>Ce lien expire dans 24 heures.</p>
          <p>Si vous n'avez pas créé de compte, ignorez cet email.</p>
        </div>
      `,
    });
  }

  async sendPasswordResetEmail(email: string, token: string): Promise<void> {
    const resetUrl = `${process.env.FRONTEND_URL}/reset-password/${token}`;

    await this.transporter.sendMail({
      from: process.env.FROM_EMAIL || "noreply@boxin1.com",
      to: email,
      subject: "Réinitialisation de mot de passe",
      html: `
        <div style="max-width: 600px; margin: 0 auto; font-family: Arial, sans-serif;">
          <h2>Réinitialisation de mot de passe</h2>
          <p>Vous avez demandé la réinitialisation de votre mot de passe. Cliquez sur le lien ci-dessous :</p>
          <a href="${resetUrl}" style="display: inline-block; padding: 12px 24px; background-color: #dc3545; color: white; text-decoration: none; border-radius: 4px;">
            Réinitialiser mon mot de passe
          </a>
          <p>Ce lien expire dans 1 heure.</p>
          <p>Si vous n'avez pas demandé cette réinitialisation, ignorez cet email.</p>
        </div>
      `,
    });
  }

  async sendOtpCode(
    email: string,
    code: string,
    purpose: OtpPurpose
  ): Promise<void> {
    const purposeText = {
      EMAIL_VERIFICATION: "vérification d'email",
      PASSWORD_RESET: "réinitialisation de mot de passe",
      LOGIN_VERIFICATION: "connexion",
    }[purpose];

    await this.transporter.sendMail({
      from: process.env.FROM_EMAIL || "noreply@boxin1.com",
      to: email,
      subject: `Code de vérification - ${purposeText}`,
      html: `
        <div style="max-width: 600px; margin: 0 auto; font-family: Arial, sans-serif;">
          <h2>Code de vérification</h2>
          <p>Voici votre code de vérification pour ${purposeText} :</p>
          <div style="font-size: 32px; font-weight: bold; color: #007bff; text-align: center; padding: 20px; background-color: #f8f9fa; border-radius: 4px; margin: 20px 0;">
            ${code}
          </div>
          <p>Ce code expire dans 10 minutes.</p>
          <p>Si vous n'avez pas demandé ce code, ignorez cet email.</p>
        </div>
      `,
    });
  }
}
