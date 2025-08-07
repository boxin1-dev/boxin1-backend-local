// src/routes/auth.routes.ts
import { Router } from 'express';
import { body } from 'express-validator';
import rateLimit from 'express-rate-limit';
import { AuthController } from '../controllers/auth.controller';
import { authMiddleware } from '../middleware/auth.middleware';

const router = Router();
const authController = new AuthController();

// Rate limiters
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 tentatives par IP
  message: {
    success: false,
    message: 'Trop de tentatives, veuillez réessayer plus tard'
  }
});

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  message: {
    success: false,
    message: 'Trop de requêtes, veuillez réessayer plus tard'
  }
});

// Validations
const registerValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Email invalide'),
  body('password')
    .isLength({ min: 8 })
    .withMessage('Le mot de passe doit contenir au moins 8 caractères')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage('Le mot de passe doit contenir au moins une minuscule, une majuscule et un chiffre'),
  body('firstName')
    .optional()
    .isLength({ min: 2, max: 50 })
    .withMessage('Le prénom doit contenir entre 2 et 50 caractères'),
  body('lastName')
    .optional()
    .isLength({ min: 2, max: 50 })
    .withMessage('Le nom doit contenir entre 2 et 50 caractères')
];

const loginValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Email invalide'),
  body('password')
    .notEmpty()
    .withMessage('Mot de passe requis'),
  body('otpCode')
    .optional()
    .isLength({ min: 6, max: 6 })
    .withMessage('Le code OTP doit contenir 6 caractères')
];

const forgotPasswordValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Email invalide')
];

const resetPasswordValidation = [
  body('token')
    .notEmpty()
    .withMessage('Token requis'),
  body('newPassword')
    .isLength({ min: 8 })
    .withMessage('Le mot de passe doit contenir au moins 8 caractères')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage('Le mot de passe doit contenir au moins une minuscule, une majuscule et un chiffre')
];

const refreshTokenValidation = [
  body('refreshToken')
    .notEmpty()
    .withMessage('Refresh token requis')
];

const otpValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Email invalide'),
  body('purpose')
    .isIn(['EMAIL_VERIFICATION', 'PASSWORD_RESET', 'LOGIN_VERIFICATION'])
    .withMessage('Purpose invalide')
];

const verifyOtpValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Email invalide'),
  body('code')
    .isLength({ min: 6, max: 6 })
    .withMessage('Code OTP invalide'),
  body('purpose')
    .isIn(['EMAIL_VERIFICATION', 'PASSWORD_RESET', 'LOGIN_VERIFICATION'])
    .withMessage('Purpose invalide')
];

// Routes publiques
router.post('/register', generalLimiter, registerValidation, authController.register);
router.post('/login', authLimiter, loginValidation, authController.login);
router.post('/forgot-password', generalLimiter, forgotPasswordValidation, authController.forgotPassword);
router.post('/reset-password', generalLimiter, resetPasswordValidation, authController.resetPassword);
router.get('/verify-email/:token', generalLimiter, authController.verifyEmail);
router.post('/refresh-token', generalLimiter, refreshTokenValidation, authController.refreshToken);
router.post('/logout', authController.logout);

// Routes OTP
router.post('/generate-otp', generalLimiter, otpValidation, authController.generateOtp);
router.post('/verify-otp', generalLimiter, verifyOtpValidation, authController.verifyOtp);

// Routes protégées
router.get('/profile', authMiddleware, authController.getProfile);

export default router;