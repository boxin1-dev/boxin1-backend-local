
import { Prisma, PrismaClient, TransactionType } from "@prisma/client";

const prisma = new PrismaClient();

export class WalletService {
    /**
     * Initialize or get existing wallet for a user
     */
    static async getWallet(userId: string) {
        let wallet = await prisma.wallet.findUnique({
            where: { userId },
            include: {
                transactions: {
                    orderBy: { createdAt: "desc" },
                    take: 10,
                },
            },
        });

        if (!wallet) {
            wallet = await prisma.wallet.create({
                data: {
                    userId,
                },
                include: {
                    transactions: true,
                },
            });
        }

        return wallet;
    }

    /**
     * Deposit funds implementation
     */
    static async deposit(userId: string, amount: number, reference?: string) {
        if (amount <= 0) throw new Error("Amount must be positive");

        return await prisma.$transaction(async (tx) => {
            const wallet = await tx.wallet.findUnique({ where: { userId } });
            if (!wallet) throw new Error("Wallet not found");

            const transaction = await tx.transaction.create({
                data: {
                    walletId: wallet.id,
                    amount,
                    type: TransactionType.DEPOSIT,
                    status: "COMPLETED",
                    reference,
                    description: "Dépôt de fonds",
                },
            });

            const updatedWallet = await tx.wallet.update({
                where: { id: wallet.id },
                data: {
                    balance: { increment: amount },
                },
            });

            return { wallet: updatedWallet, transaction };
        });
    }

    /**
     * Withdraw funds implementation
     */
    static async withdraw(userId: string, amount: number) {
        if (amount <= 0) throw new Error("Amount must be positive");

        return await prisma.$transaction(async (tx) => {
            const wallet = await tx.wallet.findUnique({ where: { userId } });
            if (!wallet) throw new Error("Wallet not found");

            if (Number(wallet.balance) < amount) {
                throw new Error("Insufficient funds");
            }

            const transaction = await tx.transaction.create({
                data: {
                    walletId: wallet.id,
                    amount: -amount, // stored as negative? or positive with type withdrawal? usually positive with type. let's keep amount positive but deduct from balance.
                    // Wait, for clarity in history, signed amount is sometimes better, but schema has type. 
                    // Let's store amount as Positive decimal in DB as per schema (Common practice), logic determines sign.
                    // Correcting: standard is often Amount is magnitude. Logic handles sign.
                    type: TransactionType.WITHDRAWAL,
                    status: "COMPLETED",
                    description: "Retrait de fonds",
                },
            });

            const updatedWallet = await tx.wallet.update({
                where: { id: wallet.id },
                data: {
                    balance: { decrement: amount },
                },
            });

            return { wallet: updatedWallet, transaction };
        });
    }

    /**
     * Pay Subscription
     */
    static async paySubscription(userId: string, amount: number) {
        if (amount <= 0) throw new Error("Invalid amount");

        return await prisma.$transaction(async (tx) => {
            const wallet = await tx.wallet.findUnique({ where: { userId } });
            if (!wallet) throw new Error("Wallet not found");

            if (Number(wallet.balance) < amount) {
                throw new Error("Insufficient funds for subscription");
            }

            // Extension de l'abonnement
            const user = await tx.user.findUnique({
                where: { id: userId },
                select: { subscriptionExpiresAt: true }
            });

            if (!user) throw new Error("User not found");

            let newExpiry = new Date();
            // Si l'abonnement est déjà actif et dans le futur, on prolonge à partir de la date d'expiration
            if (user.subscriptionExpiresAt && user.subscriptionExpiresAt > new Date()) {
                newExpiry = new Date(user.subscriptionExpiresAt);
            }
            // On ajoute 30 jours
            newExpiry.setDate(newExpiry.getDate() + 30);

            await tx.user.update({
                where: { id: userId },
                data: { subscriptionExpiresAt: newExpiry }
            });

            const transaction = await tx.transaction.create({
                data: {
                    walletId: wallet.id,
                    amount: amount,
                    type: TransactionType.SUBSCRIPTION_PAYMENT,
                    status: "COMPLETED",
                    description: `Paiement abonnement Box (Nouvelle expiration: ${newExpiry.toLocaleDateString()})`,
                },
            });

            const updatedWallet = await tx.wallet.update({
                where: { id: wallet.id },
                data: {
                    balance: { decrement: amount },
                },
            });

            return { wallet: updatedWallet, transaction, subscriptionExpiresAt: newExpiry };
        });
    }

    static async mobileMoneyDeposit(phone: string, amount: number, reference: string) {
        return await prisma.$transaction(async (tx) => {
            // 1. Find user by phone
            const user = await tx.user.findFirst({
                where: { phone },
                include: { wallet: true },
            });

            if (!user) {
                throw new Error("User with this phone number not found");
            }

            const wallet = user.wallet;

            if (!wallet) {
                // Optionally create wallet if not exists, but for now throw error
                throw new Error("Wallet not found for this user");
            }

            if (!wallet.isActive) {
                throw new Error("Wallet is inactive");
            }

            // 2. Create transaction
            const transaction = await tx.transaction.create({
                data: {
                    walletId: wallet.id,
                    type: "DEPOSIT", // Using string literal matching enum or import enum if available in context
                    amount: new Prisma.Decimal(amount),
                    status: "COMPLETED",
                    reference: reference, // Mobile Money Reference
                    description: `Mobile Money Deposit (${reference})`,
                },
            });

            // 3. Update wallet balance
            const updatedWallet = await tx.wallet.update({
                where: { id: wallet.id },
                data: {
                    balance: {
                        increment: new Prisma.Decimal(amount),
                    },
                },
                include: { transactions: { orderBy: { createdAt: 'desc' }, take: 5 } }, // Return with recent transactions
            });

            return updatedWallet;
        });
    }
}

