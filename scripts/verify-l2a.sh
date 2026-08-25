#!/usr/bin/env bash
# L2a: Vite + evenhub-simulator automation smoke (no USB / glasses).
set -euo pipefail

ROOT="${EVEN_DESKLESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
EXAMPLE="${EXAMPLE_DIR:-$ROOT/examples/bare}"
cd "$EXAMPLE"

AUTOMATION_PORT="${AUTOMATION_PORT:-9898}"
VITE_PORT="${VITE_PORT:-5173}"
APP_URL="http://127.0.0.1:${VITE_PORT}/"
READY_MARKER="${READY_MARKER:-[even-deskless] ready}"

PIDS=()

free_port() {
  local port="$1"
  local pids
  if command -v lsof >/dev/null 2>&1; then
    pids="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null || true)"
    if [[ -n "$pids" ]]; then
      echo "verify-l2a: freeing :$port (pids: $pids)"
      # shellcheck disable=SC2086
      kill $pids 2>/dev/null || true
      sleep 0.3
      # shellcheck disable=SC2086
      kill -9 $pids 2>/dev/null || true
    fi
  fi
}

kill_sim_leftovers() {
  pkill -f "evenhub-simulator.*--automation-port ${AUTOMATION_PORT}" 2>/dev/null || true
  pkill -f "sim-.*/bin/evenhub-simulator.*--automation-port ${AUTOMATION_PORT}" 2>/dev/null || true
}

cleanup() {
  local pid
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
    kill -- -"$pid" 2>/dev/null || true
  done
  kill_sim_leftovers
  free_port "$AUTOMATION_PORT"
  wait 2>/dev/null || true
}
trap cleanup EXIT

echo "verify-l2a: example=$EXAMPLE"
echo "verify-l2a: clearing leftover simulator / ports"
kill_sim_leftovers
free_port "$AUTOMATION_PORT"
free_port "$VITE_PORT"
sleep 0.2

if [[ ! -d node_modules ]]; then
  echo "verify-l2a: npm ci in example"
  npm ci
fi

echo "verify-l2a: starting Vite on :${VITE_PORT}"
npx vite --host 127.0.0.1 --port "$VITE_PORT" >/tmp/even-deskless-vite-l2a.log 2>&1 &
PIDS+=($!)

echo "verify-l2a: waiting for Vite…"
for _ in $(seq 1 90); do
  if curl -sf "http://127.0.0.1:${VITE_PORT}/" >/dev/null; then
    break
  fi
  sleep 0.5
done
curl -sf "http://127.0.0.1:${VITE_PORT}/" >/dev/null

SIM_BIN=()
PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "${PLATFORM}-${ARCH}" in
  darwin-arm64) SIM_PKG=sim-darwin-arm64 ;;
  darwin-x86_64|darwin-amd64) SIM_PKG=sim-darwin-x64 ;;
  linux-x86_64|linux-amd64) SIM_PKG=sim-linux-x64 ;;
  *) SIM_PKG="" ;;
esac
if [[ -n "$SIM_PKG" && -x "$EXAMPLE/node_modules/@evenrealities/${SIM_PKG}/bin/evenhub-simulator" ]]; then
  SIM_BIN=("$EXAMPLE/node_modules/@evenrealities/${SIM_PKG}/bin/evenhub-simulator")
else
  SIM_BIN=(npx --no-install evenhub-simulator)
fi
SIM_BIN+=("$APP_URL" --automation-port "$AUTOMATION_PORT")

if [[ "$(uname -s)" == "Linux" && -z "${DISPLAY:-}" ]]; then
  if ! command -v xvfb-run >/dev/null 2>&1; then
    echo "verify-l2a: xvfb-run required on headless Linux (apt install xvfb)" >&2
    exit 1
  fi
  echo "verify-l2a: launching simulator under xvfb-run"
  SIM_BIN=(xvfb-run -a "${SIM_BIN[@]}")
else
  echo "verify-l2a: launching simulator (${SIM_BIN[0]})"
fi

"${SIM_BIN[@]}" >/tmp/even-deskless-sim-l2a.log 2>&1 &
PIDS+=($!)

echo "verify-l2a: running smoke against :${AUTOMATION_PORT}"
# pngjs resolves from the published kit package (or local kit root).
export NODE_PATH="${ROOT}/node_modules${NODE_PATH:+:$NODE_PATH}"
READY_MARKER="$READY_MARKER" node "$ROOT/scripts/l2a-sim-smoke.mjs" --base "http://127.0.0.1:${AUTOMATION_PORT}"
echo "verify-l2a: OK"
