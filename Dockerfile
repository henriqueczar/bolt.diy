# ---- build stage ----
FROM node:22-bookworm-slim AS build
WORKDIR /app

# CI-friendly env
ENV HUSKY=0
ENV CI=true

# Use pnpm
RUN corepack enable && corepack prepare pnpm@9.15.9 --activate

# Accept (optional) build-time public URL
ARG VITE_PUBLIC_APP_URL
ENV VITE_PUBLIC_APP_URL=${VITE_PUBLIC_APP_URL}

# Install deps efficiently
COPY package.json pnpm-lock.yaml* ./
RUN pnpm fetch

# Copia o código-fonte
COPY . .

# Força React 18 e React-DOM 18
RUN pnpm add react@18.3.1 react-dom@18.3.1

# Instala dependências e constrói
RUN pnpm install --offline --frozen-lockfile
RUN NODE_OPTIONS=--max-old-space-size=4096 pnpm run build

# Mantém só dependências de produção
RUN pnpm prune --prod --ignore-scripts


# ---- runtime stage ----
FROM node:22-bookworm-slim AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0

# Instala curl para healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends curl \
  && rm -rf /var/lib/apt/lists/*

# Copia apenas arquivos necessários
COPY --from=build /app/build /app/build
COPY --from=build /app/node_modules /app/node_modules
COPY --from=build /app/package.json /app/package.json

EXPOSE 3000

# Healthcheck
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=5 \
  CMD curl -fsS http://localhost:3000/ || exit 1

# Start da aplicação
CMD ["node", "build/server/index.js"]
