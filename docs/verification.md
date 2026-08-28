# Verification Source of Truth

**Status:** active SoT for even-deskless.  
**Audience:** humans and coding agents (local or Cursor Cloud).  
**Non-goal:** Even G2 + Even Hub + BLE fidelity inside managed cloud VMs.

When this doc conflicts with chat history, **this file wins** until a later commit revises it.

---

## 1. Goals

| Do | Do not (for now) |
|---|---|
| Catch layout, client, and boot regressions before a desk session | Run glasses / Even Hub account UI on Cursor-hosted cloud VMs |
| Make Hub Simulator automation reproducible | Treat the simulator as a hardware emulator |
| Keep real-device time for BLE, lock-screen, and packaging quirks | Require Android SDK or companion APKs in the default gate |

**Success:** a desk session mostly finds *fidelity gaps*, not failures that L0–L2a should have caught.

---

## 2. Layers

```text
L0   Unit / static
     examples/bare: tsc + vitest

L1   Artifacts (optional in consumers)
     evenhub pack → .ehpk

L2a  Hub Simulator automation (deskless)
     vite + evenhub-simulator --automation-port
     smoke: ping → ready marker → lit framebuffer → gestures

Desk QR / private / Beta + glasses
     Outside this kit’s default CI
```

**Optional strengthen (product repos only):** companion HTTP contract tests, Android WebView dogfood. Not part of `npm run verify:deskless` here.

---

## 3. Cursor Cloud vs desk

```text
Cursor Cloud / this kit              Desk (human)
───────────────────────────          ────────────────────────
L0 + L2a                             QR / private / Beta
.cursor + verify:deskless            BLE, lock screen, real mic
```

Hard limits of managed Cloud VMs: no USB devices, no Even Hub UI, no productized requirement for KVM Android emulator.

**Optional desk bridge from Cloud:** when a Cloud Agent already hosts Vite and you need a phone to Scan QR without a shared LAN IP, see [cloud-agent-qr.md](./cloud-agent-qr.md) (Cloudflare quick tunnel + `evenhub qr`). That path is **not** part of `verify:deskless`.

Hub Simulator does not emit IMU samples. Treat gesture classifiers as L0/unit (synthetic series); real IMU stays desk-only. This kit does not ship a mock-IMU hook — see the same note.

---

## 4. Ready marker contract

Deskless smoke waits for a console line containing:

```text
[even-deskless] ready
```

Consumer apps may set `READY_MARKER` when invoking `scripts/l2a-sim-smoke.mjs`. Log the marker only after `createStartUpPageContainer` (or equivalent) so input capture is live.

---

## 5. Commands

```bash
npm run verify:l0
npm run verify:l2a
npm run verify:deskless
```

Headless Linux needs `xvfb-run` (installed in `.cursor/Dockerfile`).
