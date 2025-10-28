FROM node:lts-alpine AS builder

WORKDIR /app

RUN npm install -g pnpm

COPY . .

RUN pnpm install --frozen-lockfile

RUN npx prisma generate

RUN pnpm tsc

FROM node:lts-alpine AS runner

ENV NODE_ENV=production

WORKDIR /app

RUN npm install -g pnpm

# Copier package.json et pnpm-lock.yaml
COPY --chown=node:node --from=builder /app/package.json .
COPY --chown=node:node --from=builder /app/pnpm-lock.yaml .

# Installer TOUTES les dépendances (y compris devDependencies pour avoir prisma)
RUN pnpm install --frozen-lockfile

# Copier le code compilé et le schéma Prisma
COPY --chown=node:node --from=builder /app/dist .
COPY --chown=node:node --from=builder /app/prisma ./prisma

# Régénérer le client Prisma dans l'environnement de production
RUN npx prisma generate

EXPOSE 3000

CMD ["sh", "-c", "npx prisma migrate deploy && node index.js"]