
import { Router } from "express";
import { WalletController } from "../controllers/wallet.controller";
import { authMiddleware } from "../middleware/auth.middleware";

const router = Router();

// Public Webhook Route (Before Auth Middleware)
router.post("/webhook/mobile-money", WalletController.mobileMoneyWebhook);

// Apply auth middleware to all wallet routes
router.use(authMiddleware);

router.get("/", WalletController.getMyWallet);
router.post("/deposit", WalletController.deposit);
router.post("/withdraw", WalletController.withdraw);
router.post("/pay-subscription", WalletController.paySubscription);

export default router;
