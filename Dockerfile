# syntax=docker/dockerfile:1.6

ARG NODE_IMAGE=node:20-bookworm-slim

FROM ${NODE_IMAGE} AS base

ARG PNPM_VERSION=9.12.3
ENV PNPM_HOME=/pnpm
ENV PATH="${PNPM_HOME}:${PATH}"
WORKDIR /app

RUN corepack enable \
  && corepack prepare pnpm@${PNPM_VERSION} --activate \
  && pnpm config set store-dir /pnpm/store \
  && mkdir -p /pnpm/store

FROM base AS deps
COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,target=/pnpm/store,sharing=locked \
  pnpm install --frozen-lockfile --ignore-scripts

FROM base AS builder
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV POSTGRES_URL="postgres://postgres:postgres@localhost:5432/postgres"
COPY --from=deps /pnpm/store /pnpm/store
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN --mount=type=cache,target=/pnpm/store,sharing=locked \
  pnpm exec next build
RUN pnpm prune --prod

FROM ${NODE_IMAGE} AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000

RUN groupadd --system --gid 1001 nextjs \
  && useradd --system --uid 1001 --gid nextjs --home-dir /home/nextjs --create-home --shell /usr/sbin/nologin nextjs

# Install postgresql-client for pg_isready
RUN apt-get update && apt-get install -y postgresql-client && rm -rf /var/lib/apt/lists/*

COPY --from=deps /pnpm/store /pnpm/store
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/package.json ./
COPY --from=builder /app/pnpm-lock.yaml ./
COPY --from=builder /app/lib ./lib
COPY --from=builder /app/scripts ./scripts

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 CMD node -e "const http=require('node:http');const req=http.request({host:'127.0.0.1',port:process.env.PORT||3000,path:'/api/health'});req.on('response',res=>{res.resume();if(res.statusCode&&res.statusCode<400){process.exit(0);}process.exit(1);});req.on('error',()=>process.exit(1));req.setTimeout(4000,()=>{req.destroy();process.exit(1);});req.end();"

USER nextjs

ENTRYPOINT ["/app/scripts/start.sh"]
CMD ["node", "server.js"]
