// src/routes/auth.routes.ts
import { Router } from "express";
import rateLimit from "express-rate-limit";
import { body } from "express-validator";
import { AuthController } from "../controllers/auth.controller";
import { authMiddleware } from "../middleware/auth.middleware";

/**
 * @swagger
 * components:
 *   schemas:
 *     User:
 *       type: object
 *       required:
 *         - email
 *         - password
 *       properties:
 *         id:
 *           type: string
 *           description: ID unique de l'utilisateur
 *         email:
 *           type: string
 *           format: email
 *           description: Email de l'utilisateur
 *         firstName:
 *           type: string
 *           description: Prénom de l'utilisateur
 *         lastName:
 *           type: string
 *           description: Nom de l'utilisateur
 *         password:
 *           type: string
 *           minLength: 8
 *           description: Mot de passe de l'utilisateur
 *
 *     AuthResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *         message:
 *           type: string
 *         data:
 *           type: object
 *         token:
 *           type: string
 *         refreshToken:
 *           type: string
 *
 *     Error:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: false
 *         message:
 *           type: string
 *           description: Message d'erreur
 *
 *   securitySchemes:
 *     bearerAuth:
 *       type: http
 *       scheme: bearer
 *       bearerFormat: JWT
 */

const router = Router();
const authController = new AuthController();

// Rate limiters
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 tentatives par IP
  message: {
    success: false,
    message: "Trop de tentatives, veuillez réessayer plus tard",
  },
});

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  message: {
    success: false,
    message: "Trop de requêtes, veuillez réessayer plus tard",
  },
});

// Validations
const registerValidation = [
  body("email").isEmail().normalizeEmail().withMessage("Email invalide"),
  body("password")
    .isLength({ min: 8 })
    .withMessage("Le mot de passe doit contenir au moins 8 caractères")
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage(
      "Le mot de passe doit contenir au moins une minuscule, une majuscule et un chiffre"
    ),
  body("firstName")
    .optional()
    .isLength({ min: 2, max: 50 })
    .withMessage("Le prénom doit contenir entre 2 et 50 caractères"),
  body("lastName")
    .optional()
    .isLength({ min: 2, max: 50 })
    .withMessage("Le nom doit contenir entre 2 et 50 caractères"),
];

const loginValidation = [
  body("email").isEmail().normalizeEmail().withMessage("Email invalide"),
  body("password").notEmpty().withMessage("Mot de passe requis"),
  body("otpCode")
    .optional()
    .isLength({ min: 6, max: 6 })
    .withMessage("Le code OTP doit contenir 6 caractères"),
];

const forgotPasswordValidation = [
  body("email").isEmail().normalizeEmail().withMessage("Email invalide"),
];

const resetPasswordValidation = [
  body("token").notEmpty().withMessage("Token requis"),
  body("newPassword")
    .isLength({ min: 8 })
    .withMessage("Le mot de passe doit contenir au moins 8 caractères")
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage(
      "Le mot de passe doit contenir au moins une minuscule, une majuscule et un chiffre"
    ),
];

const refreshTokenValidation = [
  body("refreshToken").notEmpty().withMessage("Refresh token requis"),
];

const otpValidation = [
  body("email").isEmail().normalizeEmail().withMessage("Email invalide"),
  body("purpose")
    .isIn(["EMAIL_VERIFICATION", "PASSWORD_RESET", "LOGIN_VERIFICATION"])
    .withMessage("Purpose invalide"),
];

const verifyOtpValidation = [
  body("email").isEmail().normalizeEmail().withMessage("Email invalide"),
  body("code").isLength({ min: 6, max: 6 }).withMessage("Code OTP invalide"),
  body("purpose")
    .isIn(["EMAIL_VERIFICATION", "PASSWORD_RESET", "LOGIN_VERIFICATION"])
    .withMessage("Purpose invalide"),
];

/**
 * @swagger
 * /api/auth/register:
 *   post:
 *     summary: Inscription d'un nouvel utilisateur
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: user@example.com
 *               password:
 *                 type: string
 *                 minLength: 8
 *                 example: Password123
 *               firstName:
 *                 type: string
 *                 example: John
 *               lastName:
 *                 type: string
 *                 example: Doe
 *     responses:
 *       201:
 *         description: Utilisateur créé avec succès
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       400:
 *         description: Données invalides
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       429:
 *         description: Trop de requêtes
 */
router.post(
  "/register",
  generalLimiter,
  registerValidation,
  authController.register
);

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Connexion utilisateur
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: user@example.com
 *               password:
 *                 type: string
 *                 example: Password123
 *               otpCode:
 *                 type: string
 *                 minLength: 6
 *                 maxLength: 6
 *                 example: "123456"
 *     responses:
 *       200:
 *         description: Connexion réussie
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       401:
 *         description: Identifiants invalides
 *       429:
 *         description: Trop de tentatives
 */
router.post("/login", authLimiter, loginValidation, authController.login);

/**
 * @swagger
 * /api/auth/forgot-password:
 *   post:
 *     summary: Demande de réinitialisation de mot de passe
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: user@example.com
 *     responses:
 *       200:
 *         description: Email de réinitialisation envoyé
 */
router.post(
  "/forgot-password",
  generalLimiter,
  forgotPasswordValidation,
  authController.forgotPassword
);

/**
 * @swagger
 * /api/auth/reset-password:
 *   post:
 *     summary: Réinitialisation du mot de passe
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - token
 *               - newPassword
 *             properties:
 *               token:
 *                 type: string
 *                 example: "reset-token-here"
 *               newPassword:
 *                 type: string
 *                 minLength: 8
 *                 example: NewPassword123
 *     responses:
 *       200:
 *         description: Mot de passe réinitialisé avec succès
 */
router.post(
  "/reset-password",
  generalLimiter,
  resetPasswordValidation,
  authController.resetPassword
);

/**
 * @swagger
 * /api/auth/verify-email/{token}:
 *   get:
 *     summary: Vérification de l'email
 *     tags: [Authentication]
 *     parameters:
 *       - in: path
 *         name: token
 *         required: true
 *         schema:
 *           type: string
 *         description: Token de vérification
 *     responses:
 *       200:
 *         description: Email vérifié avec succès
 */
router.get("/verify-email/:token", generalLimiter, authController.verifyEmail);

/**
 * @swagger
 * /api/auth/refresh-token:
 *   post:
 *     summary: Renouvellement du token d'accès
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - refreshToken
 *             properties:
 *               refreshToken:
 *                 type: string
 *                 example: "refresh-token-here"
 *     responses:
 *       200:
 *         description: Token renouvelé avec succès
 */
router.post(
  "/refresh-token",
  generalLimiter,
  refreshTokenValidation,
  authController.refreshToken
);

/**
 * @swagger
 * /api/auth/logout:
 *   post:
 *     summary: Déconnexion utilisateur
 *     tags: [Authentication]
 *     responses:
 *       200:
 *         description: Déconnexion réussie
 */
router.post("/logout", authController.logout);

/**
 * @swagger
 * /api/auth/generate-otp:
 *   post:
 *     summary: Génération d'un code OTP
 *     tags: [OTP]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - purpose
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: user@example.com
 *               purpose:
 *                 type: string
 *                 enum: [EMAIL_VERIFICATION, PASSWORD_RESET, LOGIN_VERIFICATION]
 *                 example: EMAIL_VERIFICATION
 *     responses:
 *       200:
 *         description: Code OTP généré et envoyé
 */
router.post(
  "/generate-otp",
  generalLimiter,
  otpValidation,
  authController.generateOtp
);

/**
 * @swagger
 * /api/auth/verify-otp:
 *   post:
 *     summary: Vérification d'un code OTP
 *     tags: [OTP]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - code
 *               - purpose
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: user@example.com
 *               code:
 *                 type: string
 *                 minLength: 6
 *                 maxLength: 6
 *                 example: "123456"
 *               purpose:
 *                 type: string
 *                 enum: [EMAIL_VERIFICATION, PASSWORD_RESET, LOGIN_VERIFICATION]
 *                 example: EMAIL_VERIFICATION
 *     responses:
 *       200:
 *         description: Code OTP vérifié avec succès
 */
router.post(
  "/verify-otp",
  generalLimiter,
  verifyOtpValidation,
  authController.verifyOtp
);

/**
 * @swagger
 * /api/auth/profile:
 *   get:
 *     summary: Récupération du profil utilisateur
 *     tags: [User Profile]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Profil utilisateur récupéré avec succès
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/User'
 *       401:
 *         description: Token d'authentification manquant ou invalide
 */
router.get("/profile", authMiddleware, authController.getProfile);

// Validations pour les nouvelles routes
const updateProfileValidation = [
  body("firstName")
    .optional()
    .isLength({ min: 1, max: 50 })
    .withMessage("Le prénom doit contenir entre 1 et 50 caractères"),
  body("lastName")
    .optional()
    .isLength({ min: 1, max: 50 })
    .withMessage("Le nom doit contenir entre 1 et 50 caractères"),
  body("phone")
    .optional()
    .isLength({ min: 10, max: 20 })
    .withMessage("Le numéro de téléphone doit contenir entre 10 et 20 caractères"),
];

const changePasswordValidation = [
  body("currentPassword")
    .notEmpty()
    .withMessage("Le mot de passe actuel est requis"),
  body("newPassword")
    .isLength({ min: 8 })
    .withMessage("Le nouveau mot de passe doit contenir au moins 8 caractères")
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage(
      "Le nouveau mot de passe doit contenir au moins une minuscule, une majuscule et un chiffre"
    ),
];

const deleteAccountValidation = [
  body("password").notEmpty().withMessage("Le mot de passe est requis"),
];

/**
 * @swagger
 * /api/auth/profile:
 *   patch:
 *     summary: Mise à jour du profil utilisateur
 *     tags: [User Profile]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               firstName:
 *                 type: string
 *                 example: John
 *               lastName:
 *                 type: string
 *                 example: Doe
 *               phone:
 *                 type: string
 *                 example: "+33612345678"
 *     responses:
 *       200:
 *         description: Profil mis à jour avec succès
 *       401:
 *         description: Non authentifié
 */
router.patch(
  "/profile",
  authMiddleware,
  generalLimiter,
  updateProfileValidation,
  authController.updateProfile
);

/**
 * @swagger
 * /api/auth/password:
 *   patch:
 *     summary: Changement de mot de passe
 *     tags: [User Profile]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - currentPassword
 *               - newPassword
 *             properties:
 *               currentPassword:
 *                 type: string
 *                 example: OldPassword123
 *               newPassword:
 *                 type: string
 *                 minLength: 8
 *                 example: NewPassword123
 *     responses:
 *       200:
 *         description: Mot de passe changé avec succès
 *       401:
 *         description: Mot de passe actuel incorrect
 */
router.patch(
  "/password",
  authMiddleware,
  authLimiter,
  changePasswordValidation,
  authController.changePassword
);

/**
 * @swagger
 * /api/auth/account:
 *   delete:
 *     summary: Suppression du compte utilisateur
 *     tags: [User Profile]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - password
 *             properties:
 *               password:
 *                 type: string
 *                 example: MyPassword123
 *     responses:
 *       200:
 *         description: Compte supprimé avec succès
 *       401:
 *         description: Mot de passe incorrect
 */
router.delete(
  "/account",
  authMiddleware,
  authLimiter,
  deleteAccountValidation,
  authController.deleteAccount
);

export default router;
