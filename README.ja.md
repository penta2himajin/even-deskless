# even-deskless

> Source: README.md @ 5ecaa76

[Even Hub](https://hub.evenrealities.com/) プラグイン向けの **deskless（実機なし）検証キット**です。

**npm:** [`@penta2himajin/even-deskless`](https://www.npmjs.com/package/@penta2himajin/even-deskless)

```bash
npm i -D @penta2himajin/even-deskless @evenrealities/evenhub-simulator
# createStartUpPageContainer のあと console.info('[even-deskless] ready')
npx even-deskless verify-l2a
```

詳細は英語版 [README.md](./README.md) と [`docs/verification.md`](docs/verification.md) を参照してください。

**任意（`verify:deskless` 外）:** Cloud Agent 上の Vite を Cloudflare quick tunnel + `evenhub qr` でグラスへ sideload する手順は [`docs/cloud-agent-qr.md`](docs/cloud-agent-qr.md) / `npm run qr:tunnel`。

## ライセンス

MIT — [LICENSE](./LICENSE)。
