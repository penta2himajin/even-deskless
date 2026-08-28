#!/usr/bin/env bash
# Optional harness for scripts/qr-tunnel.sh (not part of verify:deskless).
# Covers stale-vs-live trycloudflare URL reuse.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/qr-tunnel.sh"
FAIL=0

assert_contains() {
  local hay="$1" needle="$2" label="$3"
  if [[ "$hay" != *"$needle"* ]]; then
    echo "FAIL: $label — expected to contain: $needle" >&2
    echo "--- output ---" >&2
    echo "$hay" >&2
    FAIL=1
  else
    echo "ok: $label"
  fi
}

assert_not_contains() {
  local hay="$1" needle="$2" label="$3"
  if [[ "$hay" == *"$needle"* ]]; then
    echo "FAIL: $label — must not contain: $needle" >&2
    echo "--- output ---" >&2
    echo "$hay" >&2
    FAIL=1
  else
    echo "ok: $label"
  fi
}

run_case() {
  local name="$1" mode="$2" # mode: stale | live
  local tmp port log path out
  tmp="$(mktemp -d)"
  port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
  log="$tmp/cf.log"
  path="$tmp/bin"
  mkdir -p "$path"

  python3 - "$port" <<'PY' &
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
port = int(sys.argv[1])
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")
    def log_message(self, *a):
        pass
HTTPServer(("127.0.0.1", port), H).serve_forever()
PY
  local vite_pid=$!
  sleep 0.2

  cat >"$path/cloudflared" <<EOF
#!/usr/bin/env bash
echo "started" >"$tmp/cloudflared.started"
echo \$\$ >"$tmp/cloudflared.pid"
# Mimic quick-tunnel log line consumers grep for
echo "INF | https://fresh-example.trycloudflare.com"
sleep 30
EOF
  chmod +x "$path/cloudflared"

  # curl wrapper: localhost Vite checks use real curl; trycloudflare probe is mode-dependent.
  cat >"$path/curl" <<EOF
#!/usr/bin/env bash
if printf '%s\n' "\$*" | grep -q 'trycloudflare\\.com'; then
  if [[ "$mode" == live ]]; then
    exit 0
  fi
  echo "curl: stale tunnel probe failed" >&2
  exit 22
fi
exec /usr/bin/curl "\$@"
EOF
  chmod +x "$path/curl"

  # Prefer PATH evenhub so we do not depend on examples/bare install layout.
  cat >"$path/evenhub" <<'EOF'
#!/usr/bin/env bash
echo "EVENHUB_QR $*"
EOF
  chmod +x "$path/evenhub"

  # Force PATH evenhub: shadow repo bin by making a fake non-executable path unreachable —
  # script checks ROOT/examples/bare/node_modules/.bin/evenhub first. Temporarily rename if present.
  local bare_eh="$ROOT/examples/bare/node_modules/.bin/evenhub"
  local restored=0
  if [[ -e "$bare_eh" ]]; then
    mv "$bare_eh" "$bare_eh.__qr_tunnel_test__"
    restored=1
  fi

  echo "https://dead-example.trycloudflare.com" >"$log"

  set +e
  out="$(
    PATH="$path:/usr/bin:/bin" \
    PORT="$port" \
    CF_TUNNEL_LOG="$log" \
    CLOUDFLARED="$path/cloudflared" \
    bash "$SCRIPT" 2>&1
  )"
  local rc=$?
  set -e

  local started=0
  [[ -f "$tmp/cloudflared.started" ]] && started=1

  if [[ "$restored" -eq 1 ]]; then
    mv "$bare_eh.__qr_tunnel_test__" "$bare_eh"
  fi
  kill "$vite_pid" 2>/dev/null || true
  if [[ -f "$tmp/cloudflared.pid" ]]; then
    kill "$(cat "$tmp/cloudflared.pid")" 2>/dev/null || true
  fi
  rm -rf "$tmp"

  echo "=== case: $name (rc=$rc) ==="
  if [[ "$mode" == stale ]]; then
    if [[ "$started" -eq 1 ]]; then
      echo "ok: $name starts new tunnel"
    else
      echo "FAIL: $name starts new tunnel — cloudflared was not started" >&2
      echo "--- output ---" >&2
      echo "$out" >&2
      FAIL=1
    fi
    assert_contains "$out" "fresh-example.trycloudflare.com" "$name uses fresh URL"
    if [[ "$out" == *"EVENHUB_QR qr --url https://dead-example.trycloudflare.com"* ]]; then
      echo "FAIL: $name drops dead URL — evenhub still got dead URL" >&2
      FAIL=1
    else
      echo "ok: $name drops dead URL"
    fi
    assert_contains "$out" "EVENHUB_QR qr --url https://fresh-example.trycloudflare.com" "$name invokes evenhub with fresh URL"
  else
    if [[ "$started" -eq 0 ]]; then
      echo "ok: $name does not start tunnel"
    else
      echo "FAIL: $name does not start tunnel — cloudflared was started" >&2
      FAIL=1
    fi
    assert_contains "$out" "dead-example.trycloudflare.com" "$name reuses live logged URL"
    assert_contains "$out" "EVENHUB_QR" "$name invokes evenhub"
  fi
}

echo "qr-tunnel.test.sh"
run_case "stale log URL" stale
run_case "live log URL" live

if [[ "$FAIL" -ne 0 ]]; then
  echo "qr-tunnel.test.sh: FAILED" >&2
  exit 1
fi
echo "qr-tunnel.test.sh: all passed"
