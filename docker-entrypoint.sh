#!/bin/sh
# docker-entrypoint.sh — Onyx Estates OpenClaw configuration overlay.
# Writes openclaw.json from env vars on every start, seeds workspace files.
# Runs on top of the official ghcr.io/openclaw/openclaw image.
#
# Required env vars:
#   ANTHROPIC_API_KEY, GEMINI_API_KEY,
#   TELEGRAM_BOT_TOKEN, TELEGRAM_ADMIN_ID_ALEX, TELEGRAM_ADMIN_ID_CLEO,
#   TELEGRAM_GROUP_PROPERTIES, TELEGRAM_GROUP_CLIENTS, TELEGRAM_GROUP_MARKETING,
#   OPENCLAW_GATEWAY_TOKEN
#
# Optional env vars:
#   OPENCLAW_STATE_DIR (default: /data)
#   OPENCLAW_DEFAULT_MODEL (default: anthropic/claude-sonnet-4-6)
#   OPENCLAW_WHATSAPP_AGENT_MODEL (default: anthropic/claude-sonnet-4-6)
#   OPENCLAW_MARKETING_MODEL, OPENCLAW_MAIN_MODEL
#   OPENCLAW_WHATSAPP_PLUGIN (default: false)

set -e

STATE_DIR="${OPENCLAW_STATE_DIR:-/data}"
CONFIG_PATH="$STATE_DIR/openclaw.json"
DEFAULT_MODEL="${OPENCLAW_DEFAULT_MODEL:-anthropic/claude-sonnet-4-6}"
WA_MODEL="${OPENCLAW_WHATSAPP_AGENT_MODEL:-anthropic/claude-sonnet-4-6}"
MARKETING_MODEL="${OPENCLAW_MARKETING_MODEL:-anthropic/claude-sonnet-4-6}"
MAIN_MODEL="${OPENCLAW_MAIN_MODEL:-google/gemini-3.1-pro}"
WA_PLUGIN="${OPENCLAW_WHATSAPP_PLUGIN:-false}"

# Validate required env vars
missing=""
for var in TELEGRAM_BOT_TOKEN TELEGRAM_ADMIN_ID_ALEX TELEGRAM_ADMIN_ID_CLEO \
           TELEGRAM_GROUP_PROPERTIES TELEGRAM_GROUP_CLIENTS TELEGRAM_GROUP_MARKETING \
           OPENCLAW_GATEWAY_TOKEN; do
  eval val=\$$var
  if [ -z "$val" ]; then
    missing="$missing $var"
  fi
done

if [ -n "$missing" ]; then
  echo "[entrypoint] WARNING: Missing env vars:$missing — config may be incomplete"
fi

# Preserve meta section from existing config if present
META=""
if [ -f "$CONFIG_PATH" ]; then
  META=$(node -e '
    try {
      const c = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
      if (c.meta) console.log(JSON.stringify(c.meta));
    } catch {}
  ' "$CONFIG_PATH" 2>/dev/null || echo "")
fi
if [ -z "$META" ]; then
  META='{"lastTouchedVersion":"entrypoint"}'
fi

# Write the canonical config
cat > "$CONFIG_PATH" << ENDCONFIG
{
  "meta": $META,
  "agents": {
    "defaults": {
      "model": {
        "primary": "$DEFAULT_MODEL"
      },
      "models": {
        "google/gemini-3.1-pro": {
          "alias": "gemini",
          "params": {
            "thinkingMode": "high",
            "showThinking": false
          }
        },
        "google/gemini-3-flash-preview": {
          "alias": "gemini-flash",
          "params": {
            "thinkingMode": "high",
            "showThinking": false
          }
        },
        "google/gemini-3.1-flash-lite-preview": {
          "alias": "gemini-lite",
          "params": {
            "showThinking": false
          }
        },
        "anthropic/claude-sonnet-4-6": {
          "alias": "sonnet",
          "params": {
            "cacheRetention": "short"
          }
        },
        "anthropic/claude-opus-4-6": {
          "alias": "opus",
          "params": {
            "cacheRetention": "short"
          }
        },
        "anthropic/claude-haiku-4-5": {
          "alias": "haiku",
          "params": {
            "cacheRetention": "short"
          }
        }
      },
      "sandbox": {
        "mode": "off"
      },
      "compaction": {
        "mode": "safeguard"
      },
      "heartbeat": {
        "every": "2h"
      },
      "maxConcurrent": 2,
      "subagents": {
        "maxConcurrent": 4
      }
    },
    "list": [
      {
        "id": "main",
        "default": false,
        "model": "$MAIN_MODEL"
      },
      {
        "id": "operations",
        "default": true,
        "name": "operations",
        "workspace": "$STATE_DIR/workspace-operations",
        "agentDir": "$STATE_DIR/agents/operations/agent",
        "model": "$DEFAULT_MODEL",
        "subagents": {
          "allowAgents": ["marketing", "whatsapp"]
        }
      },
      {
        "id": "marketing",
        "default": false,
        "name": "marketing",
        "workspace": "$STATE_DIR/workspace-marketing",
        "agentDir": "$STATE_DIR/agents/marketing/agent",
        "model": "$MARKETING_MODEL",
        "subagents": {
          "allowAgents": ["operations"]
        }
      },
      {
        "id": "whatsapp",
        "default": false,
        "name": "whatsapp",
        "workspace": "$STATE_DIR/workspace-whatsapp",
        "model": "$WA_MODEL",
        "subagents": {
          "allowAgents": ["operations"]
        },
        "tools": {
          "deny": [
            "gateway", "process", "cron", "nodes", "canvas",
            "browser", "write", "edit", "subagents",
            "sessions_spawn"
          ]
        }
      }
    ]
  },
  "tools": {
    "agentToAgent": {
      "enabled": true,
      "allow": ["operations", "marketing", "whatsapp"]
    }
  },
  "session": {
    "agentToAgent": {
      "maxPingPongTurns": 3
    }
  },
  "bindings": [
    {
      "agentId": "operations",
      "match": { "channel": "telegram", "peer": { "kind": "group", "id": "-${TELEGRAM_GROUP_PROPERTIES}" } }
    },
    {
      "agentId": "operations",
      "match": { "channel": "telegram", "peer": { "kind": "group", "id": "-${TELEGRAM_GROUP_CLIENTS}" } }
    },
    {
      "agentId": "marketing",
      "match": { "channel": "telegram", "peer": { "kind": "group", "id": "-${TELEGRAM_GROUP_MARKETING}" } }
    },
    {
      "agentId": "operations",
      "match": { "channel": "telegram" }
    }
  ],
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto",
    "restart": true,
    "ownerDisplay": "raw"
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "allowlist",
      "botToken": "${TELEGRAM_BOT_TOKEN}",
      "groups": {
        "-${TELEGRAM_GROUP_PROPERTIES}": { "requireMention": true },
        "-${TELEGRAM_GROUP_CLIENTS}": { "requireMention": true },
        "-${TELEGRAM_GROUP_MARKETING}": { "requireMention": true }
      },
      "allowFrom": [
        "tg:${TELEGRAM_ADMIN_ID_ALEX}",
        "tg:${TELEGRAM_ADMIN_ID_CLEO}"
      ],
      "groupAllowFrom": [
        "tg:${TELEGRAM_ADMIN_ID_ALEX}",
        "tg:${TELEGRAM_ADMIN_ID_CLEO}"
      ],
      "groupPolicy": "allowlist",
      "streaming": "partial"
    }
  },
  "gateway": {
    "bind": "lan",
    "controlUi": {
      "enabled": true,
      "allowedOrigins": [
        "http://localhost:18789",
        "http://127.0.0.1:18789",
        "https://openclaw.onyxestates.eu"
      ],
      "allowInsecureAuth": false
    },
    "auth": {
      "mode": "token",
      "token": "${OPENCLAW_GATEWAY_TOKEN}"
    }
  },
  "cron": {
    "enabled": true,
    "maxConcurrentRuns": 2,
    "sessionRetention": "24h"
  },
  "plugins": {
    "entries": {
      "whatsapp": {
        "enabled": $WA_PLUGIN,
        "hooks": {
          "allowPromptInjection": false
        }
      },
      "telegram": {
        "enabled": true
      }
    }
  }
}
ENDCONFIG

echo "[entrypoint] Config written to $CONFIG_PATH"

# Seed workspace files from image to persistent volume.
# Always overwrites to ensure workspace docs stay in sync with the image.
WORKSPACES_SRC="/app/onyx-workspaces"
if [ -d "$WORKSPACES_SRC" ]; then
  for ws in "$WORKSPACES_SRC"/workspace-*; do
    ws_name="$(basename "$ws")"
    ws_dest="$STATE_DIR/$ws_name"
    mkdir -p "$ws_dest"
    cp -r "$ws"/* "$ws_dest/" 2>/dev/null || true
  done
  echo "[entrypoint] Workspaces seeded to $STATE_DIR"
fi

# Remove BOOTSTRAP.md files that trigger the setup wizard
find "$STATE_DIR" -name "BOOTSTRAP.md" -delete 2>/dev/null || true

# Let doctor fix any config issues (removes unrecognized keys, adds missing fields)
node openclaw.mjs doctor --fix 2>/dev/null || true

echo "[entrypoint] Agents: main, operations, marketing, whatsapp"
echo "[entrypoint] Models: operations=$DEFAULT_MODEL | marketing=$MARKETING_MODEL | whatsapp=$WA_MODEL | main=$MAIN_MODEL"
echo "[entrypoint] WhatsApp plugin: $WA_PLUGIN"

# Hand off to OpenClaw
exec "$@"
