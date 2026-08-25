# even-deskless

[日本語](./README.ja.md)

Deskless verification kit for [Even Hub](https://hub.evenrealities.com/) plugins — maximize what you can check **without glasses or a phone**.

**npm:** [`@penta2himajin/even-deskless`](https://www.npmjs.com/package/@penta2himajin/even-deskless)

## What this is

Even Realities publishes the SDK, CLI, simulator, and official templates. This repo sits **on top of that stack** as a verification layer:

| Official | This kit |
|---|---|
| `@evenrealities/even_hub_sdk` | Consumed, not reimplemented |
| `evenhub-templates` | Scaffold to *build* |
| Hub Simulator (manual) | Automated L2a smoke via CLI |
| Desk / QR / Beta | Out of scope here (desk-only) |

`examples/bare` dogfoods the deskless gates. **Non-goal:** BLE timing, lock-screen Beta parity, or GPU inference on Cloud VMs.

## Use in your Even plugin

```bash
npm i -D @penta2himajin/even-deskless @evenrealities/evenhub-simulator
```

1. After `createStartUpPageContainer`, log a ready marker:

```ts
console.info('[even-deskless] ready')
// or your own string — pass --ready / package.json evenDeskless.readyMarker
```

2. Add scripts:

```json
{
  "scripts": {
    "verify:l0": "tsc -p tsconfig.json --noEmit && vitest run",
    "verify:l2a": "even-deskless verify-l2a",
    "verify:deskless": "npm run verify:l0 && npm run verify:l2a"
  },
  "evenDeskless": {
    "readyMarker": "[even-deskless] ready"
  }
}
```

Optional `evenDeskless.appUrl` when the plugin needs a query string (e.g. `http://127.0.0.1:5173/?companionProbe=0`). Override with env `APP_URL` if needed.

3. Run `npm run verify:deskless` (Linux CI needs `xvfb`; this repo’s workflow uses `ubuntu-latest` + the simulator’s headless path).

```bash
even-deskless verify-l2a --ready '[my-app] ready'
even-deskless verify
```

## Develop this kit

```bash
npm ci
npm ci --prefix examples/bare
npm run verify:deskless
```

```
docs/verification.md     # SoT: layers + Cloud vs desk
examples/bare/           # Minimal plugin
bin/even-deskless.mjs    # Published CLI
scripts/verify-l2a.sh
scripts/l2a-sim-smoke.mjs
.cursor/                 # Cursor Cloud image
```

## Publish

Uses **npm Trusted Publishing** (GitHub Actions OIDC) — no long-lived `NPM_TOKEN` in repo secrets.

1. On [npmjs.com](https://www.npmjs.com): create / open `@penta2himajin/even-deskless` → **Trusted Publisher**
   - Organization/user: `penta2himajin`
   - Repository: `even-deskless`
   - Workflow filename: `publish.yml` (filename only)
   - Allow: `npm publish`
2. Push a version tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

If the package does not exist yet, publish once from a trusted setup (or create the empty package on npm) so you can attach the Trusted Publisher, then rely on tags only.

## License

MIT — see [LICENSE](./LICENSE).
