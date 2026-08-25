# even-deskless

[日本語](./README.ja.md)

Deskless verification kit for [Even Hub](https://hub.evenrealities.com/) plugins — maximize what you can check **without glasses or a phone**.

## What this is

Even Realities publishes the SDK, CLI, simulator, and official templates. This repo sits **on top of that stack** as a verification layer:

| Official | This kit |
|---|---|
| `@evenrealities/even_hub_sdk` | Consumed, not reimplemented |
| `evenhub-templates` | Scaffold to *build* | `examples/bare` dogfoods deskless gates |
| Hub Simulator (manual) | Automated L2a smoke (boot → ready → gestures → framebuffer) |
| Desk / QR / Beta | Out of scope here (documented as desk-only) |

**Non-goal:** reproducing BLE timing, lock-screen Beta parity, or LiteRT GPU. Those stay on a desk.

## Layout

```
docs/verification.md     # SoT: layers + Cloud vs desk
examples/bare/           # Minimal plugin that logs [even-deskless] ready
scripts/verify-l2a.sh    # Vite + simulator + smoke
scripts/l2a-sim-smoke.mjs
scripts/cloud-install.sh
.cursor/                 # Cursor Cloud image (Node 20, xvfb, GTK/WebKit bits)
```

## Quick start

```bash
cd examples/bare
npm ci
npm run verify:l0          # typecheck + vitest

# From repo root (needs display or xvfb on Linux):
npm run verify:deskless    # L0 + L2a simulator automation
```

Manual simulator loop (same as upstream):

```bash
cd examples/bare
npm run dev                # terminal A
npx evenhub-simulator http://127.0.0.1:5173   # terminal B
```

## Verification layers (summary)

See [`docs/verification.md`](docs/verification.md).

- **L0** — unit / static (tsc, vitest)
- **L2a** — Hub Simulator automation (deskless)
- **Desk** — QR / private / Beta + glasses (not required for this kit’s CI)

Optional Android / companion WebView checks are **not** part of the default deskless gate. Add them in product repos that own a companion app.

## License

MIT — see [LICENSE](./LICENSE).

Even Hub SDK / simulator / CLI are separately MIT-licensed by Even Realities; this kit does not relicense them.
