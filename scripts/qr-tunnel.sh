#!/usr/bin/env bash
# Optional: Cloudflare quick tunnel + evenhub QR for Cloud Agent → glasses.
# Not part of verify:deskless.
#
# Lifecycle: when this script starts cloudflared, it backgrounds the process.
# `exec evenhub qr` replaces this shell (EXIT trap does not run), so the tunnel
# stays up for Scan QR. Reuse depends on CF_TUNNEL_LOG + a live HTTPS probe —
# delete the log or kill cloudflared to force a new quick-tunnel URL.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-5173}"
LOG="${CF_TUNNEL_LOG:-/tmp/even-deskless-cf-tunnel.log}"
CLOUDFLARED="${CLOUDFLARED:-cloudflared}"
PROBE_TIMEOUT_SEC="${QR_TUNNEL_PROBE_TIMEOUT_SEC:-8}"

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

# Reuse a logged quick-tunnel URL only if HTTPS still responds.
URL="$(grep -Eo 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$LOG" 2>/dev/null | head -1 || true)"
if [[ -n "$URL" ]]; then
  if curl -sfI --max-time "$PROBE_TIMEOUT_SEC" "$URL" >/dev/null 2>&1; then
    echo "qr-tunnel: reusing live tunnel $URL"
  else
    echo "qr-tunnel: logged URL not reachable ($URL); starting a new tunnel" >&2
    URL=""
    : >"$LOG"
  fi
fi

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
