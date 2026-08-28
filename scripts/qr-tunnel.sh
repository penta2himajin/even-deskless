#!/usr/bin/env bash
# Optional: Cloudflare quick tunnel + evenhub QR for Cloud Agent → glasses.
# Not part of verify:deskless.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-5173}"
LOG="${CF_TUNNEL_LOG:-/tmp/even-deskless-cf-tunnel.log}"
CLOUDFLARED="${CLOUDFLARED:-cloudflared}"

if ! command -v "$CLOUDFLARED" >/dev/null 2>&1; then
  if [[ -x /tmp/cloudflared ]]; then
    CLOUDFLARED=/tmp/cloudflared
  else
    echo "error: cloudflared not found. Install it or set CLOUDFLARED=..." >&2
    exit 1
  fi
fi

if ! curl -sf "http://127.0.0.1:${PORT}/" >/dev/null; then
  echo "error: nothing answering on http://127.0.0.1:${PORT}/ — start Vite first (npm run dev)" >&2
  exit 1
fi

# Reuse an existing quick-tunnel URL if still logged.
URL="$(grep -Eo 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$LOG" 2>/dev/null | head -1 || true)"

if [[ -z "$URL" ]]; then
  echo "qr-tunnel: starting cloudflared → :${PORT} (log: $LOG)"
  : >"$LOG"
  # shellcheck disable=SC2094
  "$CLOUDFLARED" tunnel --url "http://127.0.0.1:${PORT}" >"$LOG" 2>&1 &
  CF_PID=$!
  trap 'kill "$CF_PID" 2>/dev/null || true' EXIT
  for _ in $(seq 1 40); do
    URL="$(grep -Eo 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$LOG" 2>/dev/null | head -1 || true)"
    if [[ -n "$URL" ]]; then break; fi
    sleep 1
  done
fi

if [[ -z "$URL" ]]; then
  echo "error: could not parse trycloudflare URL from $LOG" >&2
  tail -40 "$LOG" >&2 || true
  exit 1
fi

echo "qr-tunnel: $URL"

EVENHUB="$ROOT/examples/bare/node_modules/.bin/evenhub"
if [[ ! -x "$EVENHUB" ]]; then
  EVENHUB="$(command -v evenhub || true)"
fi
if [[ -z "$EVENHUB" ]]; then
  echo "error: evenhub CLI not found (npm i in examples/bare or install @evenrealities/evenhub-cli)" >&2
  exit 1
fi

exec "$EVENHUB" qr --url "$URL"
