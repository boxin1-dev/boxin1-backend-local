FROM node:lts-alpine AS builder

WORKDIR /app

RUN npm install -g pnpm

COPY . .

RUN pnpm install --frozen-lockfile 

RUN npx prisma generate

RUN pnpm tsc

FROM node:lts-alpine AS engine-builder

WORKDIR /app

COPY --chown=node:node --from=builder /app/prisma/schema.prisma ./app/prisma/

RUN npx prisma generate --schema=./app/prisma/schema.prisma

FROM node:lts-alpine AS runner

ENV NODE_ENV=production

WORKDIR /app

RUN npm install -g pnpm

COPY --chown=node:node --from=builder /app/package.json .

COPY --chown=node:node --from=builder /app/dist .

RUN pnpm install --production

COPY --chown=node:node --from=engine-builder  /app/node_modules/.prisma/client ./node_modules/.prisma/client

EXPOSE 3000

CMD ["sh", "-c", "npx prisma migrate deploy && node index.js"]