#!/usr/bin/env bash
# Cursor Cloud / local bootstrap for even-deskless (L0 + optional L2a deps).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "cloud-install: npm ci (root + examples/bare)"
if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install
fi
npm ci --prefix examples/bare 2>/dev/null || npm install --prefix examples/bare

echo "cloud-install: verify:l0"
npm run verify:l0 --prefix examples/bare

if [[ "${SKIP_L2A:-0}" == "1" ]]; then
  echo "cloud-install: SKIP_L2A=1 — skipping simulator smoke"
  exit 0
fi

echo "cloud-install: verify:l2a"
bash scripts/verify-l2a.sh

echo "cloud-install: done"
