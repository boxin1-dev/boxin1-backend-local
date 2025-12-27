
import { Request, Response } from "express";
import { WalletService } from "../services/wallet.service";

// AuthRequest implied by global declaration in auth.middleware.ts
// We can use Request directly or a helper interface if needed for strict typing
// But since auth.middleware extends Express.Request, we can cast or just use Request if the global type is picked up.
// For safety/explicit typing here:


export class WalletController {

    static async getMyWallet(req: Request, res: Response) {
        try {
            const userId = req.user?.userId;
            if (!userId) return res.status(401).json({ message: "Unauthorized" });

            const wallet = await WalletService.getWallet(userId);
            res.json(wallet);
        } catch (error) {
            res.status(500).json({ message: (error as Error).message });
        }
    }

    static async deposit(req: Request, res: Response) {
        try {
            const userId = req.user?.userId;
            const { amount, reference } = req.body;
            if (!userId) return res.status(401).json({ message: "Unauthorized" });

            const result = await WalletService.deposit(userId, Number(amount), reference);
            res.json(result);
        } catch (error) {
            res.status(400).json({ message: (error as Error).message });
        }
    }

    static async withdraw(req: Request, res: Response) {
        try {
            const userId = req.user?.userId;
            const { amount } = req.body;
            if (!userId) return res.status(401).json({ message: "Unauthorized" });

            const result = await WalletService.withdraw(userId, Number(amount));
            res.json(result);
        } catch (error) {
            res.status(400).json({ message: (error as Error).message });
        }
    }

    static async paySubscription(req: Request, res: Response) {
        try {
            const userId = req.user?.userId;
            const { amount } = req.body;
            // In real app, amount might be fixed or determined by Backend, but passing it for flexibility here
            if (!userId) return res.status(401).json({ message: "Unauthorized" });

            const result = await WalletService.paySubscription(userId, Number(amount));
            res.json(result);
        } catch (error) {
            res.status(400).json({ message: (error as Error).message });
        }
    }

    static async mobileMoneyWebhook(req: Request, res: Response) {
        try {
            const { phone, amount, reference } = req.body;

            if (!phone || !amount || !reference) {
                return res.status(400).json({ message: "Missing required fields: phone, amount, reference" });
            }

            const result = await WalletService.mobileMoneyDeposit(phone, Number(amount), reference);
            res.json({ success: true, data: result });
        } catch (error) {
            res.status(400).json({ message: (error as Error).message });
        }
    }
}
