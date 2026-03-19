# Onyx Estates — OpenClaw overlay
# Extends the official upstream image with our workspace files and config.
# All OpenClaw updates come from upstream automatically.
FROM ghcr.io/openclaw/openclaw:latest

# Switch to root for system-level installs (upstream sets USER node)
USER root

# Install Chromium for browser-based scraping (Idealista)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb && \
    mkdir -p /home/node/.cache/ms-playwright && \
    PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
    node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
    chown -R node:node /home/node/.cache/ms-playwright && \
    rm -rf /var/lib/apt/lists/*

# Onyx workspace files — seeded to /data on every start by entrypoint
COPY --chown=node:node onyx-workspaces /app/onyx-workspaces

# Custom entrypoint that writes openclaw.json from env vars
COPY --chown=node:node docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod 755 /app/docker-entrypoint.sh

# Back to non-root
USER node

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
