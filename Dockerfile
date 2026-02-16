# ---------- Builder ----------
FROM node:20-alpine AS builder
WORKDIR /app

RUN corepack enable

COPY . .

# Install deps
RUN pnpm install --frozen-lockfile

# Build workspace deps (needed by client)
RUN pnpm --filter stoat.js run build
RUN pnpm --filter solid-livekit-components run build

# IMPORTANT: build lingui-solid workspace plugins so dist/index.cjs exists
RUN pnpm --filter "@lingui-solid/babel-plugin-lingui-macro" run build
RUN pnpm --filter "@lingui-solid/babel-plugin-extract-messages" run build

# Ensure assets exist in /public (prevents missing wordmark.svg etc.)
RUN rm -rf /app/packages/client/public/assets \
    && mkdir -p /app/packages/client/public \
    && pnpm --filter client exec node scripts/copyAssets.mjs

# Generate and compile i18n catalogs
RUN pnpm --filter client exec npx lingui extract || true
RUN pnpm --filter client exec npx lingui compile

# Build web client
ENV NODE_OPTIONS=--max-old-space-size=3072
RUN pnpm --filter client exec vite build

# ---------- Runtime ----------
FROM caddy:2-alpine
COPY --from=builder /app/packages/client/dist /usr/share/caddy

RUN printf ":80 {\n  root * /usr/share/caddy\n  try_files {path} /index.html\n  file_server\n}\n" > /etc/caddy/Caddyfile
