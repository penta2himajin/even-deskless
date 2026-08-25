# even-deskless

> Source: README.md @ 4239e6d

[Even Hub](https://hub.evenrealities.com/) プラグイン向けの **deskless（実機なし）検証キット**です。グラスやスマホなしで確認できる範囲を最大化します。

## これは何か

Even 公式が SDK・CLI・シミュレータ・テンプレートを公開しています。このリポはその上に乗る **検証レイヤ**です。

| 公式 | このキット |
|---|---|
| SDK / templates | 作る入口 |
| 手動シミュ | 自動 L2a スモーク |
| QR / Beta | desk 専用（ここでは必須にしない） |

**非目標:** BLE タイミング、ロック画面の Beta 忠実度、端末 GPU 推論の再現。

## 使い方

```bash
cd examples/bare
npm ci
npm run verify:l0

# リポルートから
npm run verify:deskless
```

詳細は [`docs/verification.md`](docs/verification.md) と英語版 [README.md](./README.md) を参照してください。

## ライセンス

MIT — [LICENSE](./LICENSE)。
