# syntax=docker/dockerfile:1.7
# Multi-stage: Next.js standalone (production server) + Prisma migrate at startup.
FROM node:22-bookworm-slim AS base
ENV PNPM_HOME="/pnpm" \
  PATH="/pnpm:/usr/local/bin:$PATH" \
  NEXT_TELEMETRY_DISABLED=1
# Prisma engines expect OpenSSL on bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
RUN corepack enable
WORKDIR /app

FROM base AS deps
COPY package.json pnpm-lock.yaml ./
# postinstall runs `prisma generate` — schema must be present.
COPY prisma ./prisma
COPY prisma.config.ts ./
# prisma.config.ts resolves this at generate time (no real DB contact required).
ENV POSTGRES_PRISMA_URL=postgres://build:build@127.0.0.1:5432/build?schema=public
RUN pnpm install --frozen-lockfile
# pnpm uses symlinks for node_modules/prisma; copy dereferenced for the final stage (npm install there breaks the pnpm tree).
RUN mkdir -p /opt && cp -Lr /app/node_modules/prisma /opt/prisma-nm

FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Generate + build only: URL not used to connect, only to satisfy config parse.
ARG POSTGRES_PRISMA_URL=postgres://build:build@127.0.0.1:5432/build?schema=public
ENV POSTGRES_PRISMA_URL=${POSTGRES_PRISMA_URL}
RUN pnpm exec prisma generate && pnpm run build

FROM base AS production
ARG NODE_VERSION=22
# Pin global CLI to the same Prisma line as the app; migrate deploy is startup-only.
RUN npm install -g prisma@7.3.0
ENV NODE_ENV=production \
  NEXT_TELEMETRY_DISABLED=1 \
  PORT=3000 \
  HOSTNAME=0.0.0.0

RUN groupadd --system --gid 1001 nodejs \
  && useradd --system --uid 1001 -g nodejs nextjs

WORKDIR /app
COPY --from=builder /app/public ./public
# Standalone output: server.js, traced node_modules, and package.json.
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/prisma.config.ts ./prisma.config.ts
# Next standalone omits the `prisma` package. Use dereferenced copy from the deps stage (avoids
# mixing npm on a pnpm/standalone `node_modules`, which can fail).
COPY --from=deps /opt/prisma-nm /app/node_modules/prisma
COPY docker/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh \
  && chown -R nextjs:nodejs /app
USER nextjs
EXPOSE 3000
ENTRYPOINT ["/docker-entrypoint.sh"]
