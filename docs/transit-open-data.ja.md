# 乗換オープンデータ → 別API化（調査メモ）

[English](./transit-open-data.md)

> Source: transit-open-data.md @ 4166b87

**Status:** 調査／設計インプット（even-deskless 本体の実装 SoT ではない）  
**Audience:** Even Hub プラグイン等向けに **独立した乗換 API** を切るかどうか判断する人  
**Date:** 2026-08 / 2026-09 相談の整理

---

## 1. 結論

| 問い | 答え |
|---|---|
| 日本向け乗換＋遅延の **オープンデータ最良スタック** は？ | **駅データ.jp + GTFS（各社 zip）+ OpenTripPlanner + GTFS-RT** |
| それを Even Hub プラグイン WebView に内蔵？ | **しない — 別バックエンド API にする** |
| 全国網羅＋商用級の運賃までオープンのみ？ | **不可** — 本番はハイブリッドまたは有料 API |

**推奨:** feed 取得・OTP・ID マッピング・運賃照会を持つ小さな **Transit API**（HTTP/JSON）を別サービスにする。Even プラグインは薄い: GPS → 最寄り駅 → API → グラスに 2〜3 行要約。

---

## 2. なぜ別 API か

Even Hub SDK（`@evenrealities/even_hub_sdk`）が既に持つもの:

- スマホ GPS（`getAppLocation`）
- ローカルストレージ（登録目的地）
- グラス向けテキスト UI（`createStartUpPageContainer` / `textContainerUpgrade`）
- マイク PCM（**STT は非搭載**）

持たないもの: 乗換グラフ、feed パイプライン、API キーの安全保管。

| 観点 | プラグイン内 | 別 API |
|---|---|---|
| OTP のメモリ／graph 再ビルド | 不向き | 必須 |
| ODPT／駅すぱあと等のキー | WebView 漏洩リスク | プロキシ＋秘匿 |
| 複数クライアント | 1 プラグインのみ | グラス・スマホ・MCP |
| deskless／Cloud 検証 | 重い | L0–L2a では API モック |
| プロダクト境界 | kit に companion を載せない方針と衝突 | 正しい置き場 |

```text
Even App WebView（プラグイン）
  ├─ getAppLocation → 最寄り駅（API または HeartRails／Ekidata）
  ├─ localStorage → 自宅／会社の駅 ID
  └─ HTTPS → Transit API
                ├─ 駅解決（ekidata ↔ GTFS stop_id）
                ├─ 経路（OpenTripPlanner）
                ├─ 遅延（GTFS-RT + ODPT TrainInformation フォールバック）
                └─ 運賃（ODPT RailwayFare および／または有料 API）

バックエンド常駐
  ├─ GTFS zip 取得／検証／ハッシュ → 変更時のみ OTP graph 再ビルド
  └─ GTFS-RT poll → OTP updater（再ビルド不要）
```

---

## 3. データは 4 層（混ぜない）

| 層 | 役割 | 主なソース |
|---|---|---|
| **A. 駅・路線マスタ** | 名称・座標・乗換グループ・検索 UI | 駅データ.jp、HeartRails、ODPT Station |
| **B. ダイヤ** | 便・停車時刻・暦 | 事業者ごとの **GTFS** zip |
| **C. 経路探索** | 最適ルート・乗換・徒歩 | **OpenTripPlanner**（または駅すぱあと／NAVITIME） |
| **D. リアルタイム** | 遅延秒・運休・警報 | **GTFS-RT**、ODPT `Train` / `TrainInformation` |

経路の正は GTFS の `stop_id`。駅データ.jp は **UX・最寄り駅用** であり OTP 入力ではない。**ekidata ↔ GTFS の ID マップ**が必要（[piuccio/open-data-jp-railway-stations](https://github.com/piuccio/open-data-jp-railway-stations) は不完全だが参考になる）。

**「差分更新」について:** 実務上、GTFS に汎用の差分 zip 規格はほぼない。

| 変更 | 仕組み |
|---|---|
| ダイヤ改正（static） | zip 丸ごと差し替え → ハッシュ変化時に **OTP graph 再ビルド** |
| 当日遅延（realtime） | **GTFS-RT** TripUpdates / Alerts → OTP updater（再ビルドなし） |

---

## 4. ソース一覧

### 4.1 駅・路線（層 A）

| ソース | キー | カバー | 備考 |
|---|---|---|---|
| [駅データ.jp](https://ekidata.jp/) | 不要（CSV） | 鉄道駅はほぼ全国 | 事実上のマスタ。利用規約確認。カナ等は有料の場合あり |
| [ekidata.si-yuki.org](https://ekidata.si-yuki.org/) | 不要 | 同上ベース | コミュニティ REST + MCP（最寄り駅グループ等） |
| [HeartRails Express](https://express.heartrails.com/api.html) | 不要 | 全国の名称／最寄り | クレジット必須。経路・遅延なし |
| ODPT `odpt:Station` / `places/...` | 無料開発者キー | 参画事業者 | 公式 ID。リアルタイムと接続しやすい |
| [piuccio/open-data-jp-railway-stations](https://github.com/piuccio/open-data-jp-railway-stations) | 不要 | 部分 | ekidata + ODPT 突合（完全ではない） |

### 4.2 ダイヤ（層 B）

| ソース | 備考 |
|---|---|
| 各社 GTFS / GTFS-JP zip | OTP の入力 |
| [GTFS.JP](https://www.gtfs.jp/) | ポータル。国の推進はバス寄り |
| ODPT files API | 例: JR 東 GTFS（チャレンジ／ODPT 経由） |
| [tshimada291/gtfs-jp-list](https://github.com/tshimada291/gtfs-jp-list) | feed URL 一覧 — **更新休止**、品質非保証 |
| [Mobility Database](https://database.mobilitydata.org/) | 世界 GTFS カタログ |

**バス GTFS-JP は比較的オープン。大手鉄道のオープン GTFS がボトルネック。**

### 4.3 経路エンジン（層 C）

| 選択肢 | オープン | 向き |
|---|---|---|
| [OpenTripPlanner](https://github.com/opentripplanner/OpenTripPlanner) | ○ | オープン最良。自前 GTFS + OSM が必要 |
| [takoyaki-3/odpt-challenge2024-jre-otp-docker](https://github.com/takoyaki-3/odpt-challenge2024-jre-otp-docker) | ○ | JR 東 GTFS + GTFS-RT + OTP の Docker 参考実装 |
| [駅すぱあと API](https://api-info.ekispert.com/) | 有料（90 日評価） | 全国経路＋運賃。工数最小 |
| NAVITIME API | 有料 | 乗換＋マルチモーダル |

### 4.4 遅延・運行（層 D）

| ソース | 形 | 用途 |
|---|---|---|
| GTFS-RT TripUpdates / Alerts / VehiclePositions | 構造化遅延 | OTP に流し遅延考慮ルート |
| ODPT `odpt:Train` | `odpt:delay`（秒）、在線 | 配信がある列車単位 |
| ODPT `odpt:TrainInformation` | ステータス＋自由文 | 路線バナー（「運転見合わせ」）。OTP には弱い |

リアルタイムのカバー ≪ 静的 GTFS。方針: **GTFS-RT があれば優先**、なければ **TrainInformation をグラスにテキスト表示**。

**TS SDK:** [Higashi-Masafumi/odpt-sdk-ts](https://github.com/Higashi-Masafumi/odpt-sdk-ts) · 仕様: [sophie-app/odpt-openapi](https://github.com/sophie-app/odpt-openapi)

---

## 5. 運賃 — 取れるもの／取れないもの

| ソース | 取れるもの | 足りないもの |
|---|---|---|
| ODPT `odpt:RailwayFare` | **同一事業者** 2 駅の切符／IC | JR↔メトロ通し、新幹線特急料金なし |
| GTFS `fare_attributes` + `fare_rules` | **バス** GTFS-JP では多い。鉄道では希薄 | OTP は読めるが日本の鉄道運賃表現力は不足 |
| 駅すぱあと／NAVITIME | 通し・特急・定期まで | 有料 |

日本の鉄道運賃は単純な A→B 表ではない（対キロ／区間制、会社境界・連絡運輸、IC 端数、特急料金、乗継割引、山手線内・都区内、定期など）。

**API 製品としての運賃ポリシー案:**

1. **運賃なし**（MVP）  
2. **単一事業者 IC のみ**（ODPT）  
3. **有料運賃 API**（本番の通し運賃）  

オープンのみで全国正しい IC 通し運賃 ≈ **現状ほぼ不可能**。

---

## 6. 全国網羅が難しい理由（OTP の限界ではない）

| 障壁 | 内容 |
|---|---|
| **商用流通が先** | JR／大手私鉄は時刻表出版社→乗換案内へ既に流れており、無料 GTFS 公開の動機が弱い |
| **政策はバス先行** | 国交省 GTFS-JP／COMmmmONS は **バス** 改善が主。鉄道オープンは遅れ気味 |
| **事業者数** | JR＋私鉄＋第三セクターが膨大。URL・品質・改正日がバラバラ |
| **ID 不統一** | 全国単一の stop_id なし。ekidata ≠ GTFS ≠ ODPT |
| **RT はさらに狭い** | GTFS-RT／ODPT RT は首都圏参画が中心 |
| **品質リスク** | 公開リスト自身が期限切れ・座標ズレ・古いダイヤを警告 |

**駅マスタ全国（A）:** 駅データ.jp で概ね可。  
**鉄道ダイヤ全国オープン（B）＋遅延（D）:** Yahoo 乗換級のカバーには未達。

```text
                    オープンのみ          有料API併用
駅マスタ全国         ◎                   ◎
最寄り駅             ◎                   ◎
首都圏乗換           ○（OTP+GTFS）        ◎
全国乗換             △〜✗（鉄道不足）      ◎
単一事業者運賃       ○（ODPT）            ◎
通し・特急運賃       ✗                   ◎
全国遅延反映         ✗                   △〜○
```

---

## 7. Transit API 表面案（スケッチ）

Even プラグイン向け最小 JSON API:

| Endpoint | 用途 |
|---|---|
| `GET /v1/stations/nearest?lat=&lon=` | GPS → 駅グループ |
| `GET /v1/stations?q=` | 登録 UI 用駅名検索 |
| `POST /v1/route` | `{ from, to, departAt? }` → 経路（OTP） |
| `GET /v1/status?lines=` | ルート上路線の遅延要約 |
| `GET /v1/fare?from=&to=` | 任意。ODPT および／または有料 |

グラス向けレスポンスは **要約済み**（短い行・乗換ステップ）にし、生 OTP GraphQL は返さない。

**運用:**

- ODPT／有料キーのシークレット管理  
- Cron: GTFS 取得 → 検証 → 保管 → ハッシュ変化時のみ graph 再ビルド  
- 常駐: GTFS-RT updater  
- 同一 OD ペアを 30〜60 秒キャッシュ  
- ヘルス: feed 鮮度、graph ビルド時間、RT 遅延

---

## 8. 段階ロードマップ

| Phase | 範囲 | 目的 |
|---|---|---|
| **0** | モック経路 + ekidata 最寄り | OTP なしでプラグイン UX |
| **1** | OTP + 首都圏 GTFS 数本 | 実経路 |
| **2** | JR 東等の GTFS-RT を OTP へ | 遅延考慮ルート |
| **3** | feed パイプライン + ID マップ DB + 監視 | 運用可能 |
| **4** | feed 拡大／ODPT フォールバック／任意で有料運賃 | カバー拡大 |

Phase 1–2 で「オープンスタックが自地域で動くか」は判断できる。全国は Phase 3 以降の **運用問題**。

---

## 9. even-deskless との関係

本キットはグラス／USB／Hub ログインなしの検証（`docs/verification.md`）。乗換バックエンドは **プロダクトリポジトリ** に置き、`verify:deskless` の必須依存にしない。Cloud: Transit API はモックし、既定ゲートでライブ ODPT キーを要求しない。

---

## 10. 決定チェックリスト

- [ ] 対象地域: 首都圏のみ／全国  
- [ ] 経路: OTP オープン／駅すぱあと・NAVITIME  
- [ ] 運賃: なし／ODPT 単一事業者／有料  
- [ ] 音声: 後回し（STT は Even SDK 外）  
- [ ] ホスティング: Worker + 管理 OTP／自前 VPS  
- [ ] ライセンス確認: 駅データ.jp、HeartRails クレジット、ODPT、各 GTFS 提供元  

---

## 11. 主要リンク

| 題材 | URL |
|---|---|
| 駅データ.jp | https://ekidata.jp/ |
| Ekidata REST | https://ekidata.si-yuki.org/ |
| HeartRails | https://express.heartrails.com/api.html |
| ODPT 概要 | https://www.odpt.org/overview/ |
| ODPT 開発者 | https://developer.odpt.org/ |
| GTFS.JP | https://www.gtfs.jp/ |
| OpenTripPlanner | https://github.com/opentripplanner/OpenTripPlanner |
| JR 東 OTP Docker 例 | https://github.com/takoyaki-3/odpt-challenge2024-jre-otp-docker |
| 駅すぱあと API | https://api-info.ekispert.com/ |
| Even Hub SDK | `@evenrealities/even_hub_sdk` ≥ 0.0.14 |

---

## 12. 一行まとめ

**経路・遅延・運賃は別 Transit API に切り出し、オープン首都圏 PoC は 駅データ.jp + GTFS + OTP + GTFS-RT、全国通し運賃・完全カバーは有料 API（または運賃非表示）で補う。**
