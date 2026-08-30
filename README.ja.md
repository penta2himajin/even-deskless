# even-deskless

> Source: README.md @ 22790f9

[Even Hub](https://hub.evenrealities.com/) プラグイン向けの **deskless（実機なし）検証キット**です。

**npm:** [`@penta2himajin/even-deskless`](https://www.npmjs.com/package/@penta2himajin/even-deskless)

```bash
npm i -D @penta2himajin/even-deskless @evenrealities/evenhub-simulator
# createStartUpPageContainer のあと console.info('[even-deskless] ready')
npx even-deskless verify-l2a
```

詳細は英語版 [README.md](./README.md) と [`docs/verification.md`](docs/verification.md) を参照してください。

**任意（`verify:deskless` 外）:** Cloud Agent 上の Vite を Cloudflare quick tunnel + `evenhub qr` でグラスへ sideload する手順は [`docs/cloud-agent-qr.md`](docs/cloud-agent-qr.md)。このリポジトリでは `npm run qr:tunnel`。`npm i -D @penta2himajin/even-deskless` 後は `bash node_modules/@penta2himajin/even-deskless/scripts/qr-tunnel.sh`（Vite 起動済み、`cloudflared` と `evenhub` が PATH にあること）。

## ライセンス

MIT — [LICENSE](./LICENSE)。
