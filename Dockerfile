FROM node:lts-alpine AS builder

WORKDIR /app

# Installer les dépendances système nécessaires
RUN apk add --no-cache openssl libc6-compat curl

# Installer pnpm globalement
RUN npm install -g pnpm

# Copier d'abord package.json et pnpm-lock.yaml pour le cache
COPY package.json pnpm-lock.yaml* ./

# Installer les dépendances
RUN pnpm install --no-frozen-lockfile

# Copier le reste du code
COPY . .

# Générer le client Prisma avec retry et timeout augmenté
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
ENV PRISMA_GENERATE_SKIP_AUTOINSTALL=false
RUN npx prisma generate --schema=./prisma/schema.prisma || \
    (sleep 5 && npx prisma generate --schema=./prisma/schema.prisma) || \
    (sleep 10 && npx prisma generate --schema=./prisma/schema.prisma)

# Compiler TypeScript
RUN pnpm tsc

FROM node:lts-alpine AS runner

ENV NODE_ENV=production

WORKDIR /app

# Installer les dépendances système nécessaires
RUN apk add --no-cache openssl libc6-compat

# Installer pnpm globalement
RUN npm install -g pnpm

# Copier package.json et pnpm-lock.yaml
COPY --chown=node:node package.json pnpm-lock.yaml* ./

# Installer TOUTES les dépendances (y compris devDependencies pour avoir prisma)
RUN pnpm install --prod=false --no-frozen-lockfile

# Copier le code compilé et le schéma Prisma
COPY --chown=node:node --from=builder /app/dist ./dist
COPY --chown=node:node --from=builder /app/prisma ./prisma

# Régénérer le client Prisma dans l'environnement de production
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
RUN npx prisma generate --schema=./prisma/schema.prisma

# Utiliser l'utilisateur non-root pour la sécurité
USER node

EXPOSE 3000

# Lancer avec le bon chemin (selon la structure du dossier dist)
CMD ["sh", "-c", "ls -la /app/dist && node /app/dist/index.js || node /app/dist/src/index.js || node /app/dist/server.js"]