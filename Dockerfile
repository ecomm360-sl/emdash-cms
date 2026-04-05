# Stage 1: Build
FROM node:22-slim AS builder

RUN corepack enable && corepack prepare pnpm@10.28.0 --activate

WORKDIR /app

# Copy everything needed for the monorepo build
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY tsconfig.base.json tsconfig.json ./

# Copy all packages and the blog template (needed for workspace resolution)
COPY packages/ packages/
COPY templates/blog/ templates/blog/

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build workspace packages first, then the blog template
RUN pnpm run build
RUN cd templates/blog && pnpm run build

# Stage 2: Production
FROM node:22-slim AS runtime

WORKDIR /app

# Copy the built blog template output
COPY --from=builder /app/templates/blog/dist ./dist
COPY --from=builder /app/templates/blog/seed ./seed

# Copy node_modules (includes workspace links)
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/templates/blog/node_modules ./templates/blog/node_modules

# Create directories for persistent data
RUN mkdir -p /app/data /app/uploads

ENV HOST=0.0.0.0
ENV PORT=4321
ENV NODE_ENV=production

EXPOSE 4321

CMD ["node", "./dist/server/entry.mjs"]
