# Transit Open Data → Separate API (Research Note)

[日本語](./transit-open-data.ja.md)

**Status:** research / design input (not an implementation SoT for even-deskless itself).  
**Audience:** humans deciding whether to spin a **standalone transit API** for Even Hub plugins (and other clients).  
**Date:** 2026-08 / 2026-09 consultation summary.

---

## 1. Verdict

| Question | Answer |
|---|---|
| Best **open-data** stack for Japan rail routing + delay? | **駅データ.jp + GTFS (per-operator zips) + OpenTripPlanner + GTFS-RT** |
| Put that stack inside an Even Hub plugin WebView? | **No — expose it as a separate backend API** |
| Nationwide open coverage + commercial fare accuracy? | **Not with open data alone** — hybrid or paid APIs for production |

**Recommendation:** build a small **Transit API** (HTTP/JSON) that owns feed ingest, OTP, ID mapping, and fare lookups. Even Hub plugins stay thin: GPS → nearest station → call API → summarize 2–3 lines on glasses.

---

## 2. Why a separate API

Even Hub plugins (`@evenrealities/even_hub_sdk`) already provide:

- Phone GPS (`getAppLocation`)
- Local storage (saved destinations)
- Glasses text UI (`createStartUpPageContainer` / `textContainerUpgrade`)
- Mic PCM (no built-in STT)

They do **not** provide transit graphs, feed pipelines, or API-key safe storage.

| Concern | In-plugin | Separate API |
|---|---|---|
| OTP graph memory / rebuild | Unsuitable | Required |
| ODPT / Ekispert keys | Leak risk in WebView | Proxy + secrets |
| Multi-client reuse | One plugin only | Glasses + phone + MCP |
| Deskless / Cloud verify | Heavy | Mock API in L0–L2a |
| Product boundary | Conflicts with even-deskless “no product companions in kit” | Correct place for product code |

```text
Even App WebView (plugin)
  ├─ getAppLocation → nearest station (via API or HeartRails/Ekidata)
  ├─ localStorage → home / office station ids
  └─ HTTPS → Transit API
                ├─ station resolve (ekidata ↔ GTFS stop_id)
                ├─ route (OpenTripPlanner)
                ├─ delay (GTFS-RT + ODPT TrainInformation fallback)
                └─ fare (ODPT RailwayFare and/or paid API)

Backend jobs
  ├─ GTFS zip fetch / validate / hash → rebuild OTP graph on change
  └─ GTFS-RT poll → OTP updaters (no full rebuild)
```

---

## 3. Four data layers (do not conflate)

| Layer | Role | Typical sources |
|---|---|---|
| **A. Station / line master** | Names, lat/lon, transfer groups, UX search | 駅データ.jp, HeartRails, ODPT Station |
| **B. Schedules** | Trips, stop times, calendars | Per-operator **GTFS** zips |
| **C. Journey planning** | Best path, transfers, walk legs | **OpenTripPlanner** (or paid Ekispert/NAVITIME) |
| **D. Realtime** | Delay seconds, cancellations, alerts | **GTFS-RT**, ODPT `Train` / `TrainInformation` |

Journey planning **truth** is GTFS `stop_id`. 駅データ.jp is for **UX and nearest-station**, not OTP input. You need an **ekidata ↔ GTFS ID map** (see [piuccio/open-data-jp-railway-stations](https://github.com/piuccio/open-data-jp-railway-stations) — incomplete but illustrative).

**“Diff updates”:** GTFS has no universal incremental-zip standard in practice.

| Change type | Mechanism |
|---|---|
| Timetable revision (static) | Full zip replace → **OTP graph rebuild** when hash changes |
| Same-day delay (realtime) | **GTFS-RT** TripUpdates / Alerts → OTP updater (no rebuild) |

---

## 4. Source catalog

### 4.1 Station / line (Layer A)

| Source | Key | Coverage | Notes |
|---|---|---|---|
| [駅データ.jp](https://ekidata.jp/) | None (CSV download) | Near-nationwide rail stations | De facto master; check license; kana/romaji extras may be paid |
| [ekidata.si-yuki.org](https://ekidata.si-yuki.org/) | None | Same base | Community REST + MCP (`nearest-station-groups`, lines, transfers) |
| [HeartRails Express](https://express.heartrails.com/api.html) | None | Nationwide names / nearest | Credit required; no routing / delay |
| ODPT `odpt:Station` / `places/...` | Free developer key | Participating operators | Official IDs; good for joining to realtime |
| [piuccio/open-data-jp-railway-stations](https://github.com/piuccio/open-data-jp-railway-stations) | None | Partial | ekidata + ODPT ID merge (not complete) |

### 4.2 Schedules (Layer B)

| Source | Notes |
|---|---|
| Per-operator GTFS / GTFS-JP zips | Input to OTP |
| [GTFS.JP](https://www.gtfs.jp/) | Portal; bus-oriented national push |
| ODPT files API | e.g. JR East GTFS in challenge / ODPT programs |
| [tshimada291/gtfs-jp-list](https://github.com/tshimada291/gtfs-jp-list) | Feed URL lists — **update paused**, quality not guaranteed |
| [Mobility Database](https://database.mobilitydata.org/) | Global GTFS catalog |

**Bus GTFS-JP is far more open than major rail.** Rail remains the bottleneck for door-to-door national routing.

### 4.3 Routing engine (Layer C)

| Option | Open? | Fit |
|---|---|---|
| [OpenTripPlanner](https://github.com/opentripplanner/OpenTripPlanner) | Yes | Best open stack; needs your GTFS + OSM |
| [takoyaki-3/odpt-challenge2024-jre-otp-docker](https://github.com/takoyaki-3/odpt-challenge2024-jre-otp-docker) | Yes | JR East GTFS + GTFS-RT + OTP Docker reference |
| [駅すぱあと API](https://api-info.ekispert.com/) | Paid (90-day trial) | National routing + fares; lowest effort |
| NAVITIME API | Paid | Routing + multimodal |

### 4.4 Realtime / delay (Layer D)

| Source | Shape | Use |
|---|---|---|
| GTFS-RT TripUpdates / Alerts / VehiclePositions | Structured delay | Feed into OTP for delay-aware itineraries |
| ODPT `odpt:Train` | `odpt:delay` (seconds), position | Per-train when published |
| ODPT `odpt:TrainInformation` | Status + free text | Line-level banner (“運転見合わせ”); weak for OTP |

Realtime coverage ≪ static GTFS. Prefer: **GTFS-RT when present**, else **TrainInformation text** on the glasses UI.

**SDK (TypeScript):** [Higashi-Masafumi/odpt-sdk-ts](https://github.com/Higashi-Masafumi/odpt-sdk-ts) · Spec: [sophie-app/odpt-openapi](https://github.com/sophie-app/odpt-openapi)

---

## 5. Fares — what you can (and cannot) get

| Source | What you get | Gap |
|---|---|---|
| ODPT `odpt:RailwayFare` | Ticket / IC between two stations **of one operator** | No JR↔Metro through-fare; no shinkansen surcharge |
| GTFS `fare_attributes` + `fare_rules` | Common on **bus** GTFS-JP; rare/incomplete on rail | OTP can read it; poor fit for Japanese rail complexity |
| 駅すぱあと / NAVITIME | Through-fare, limited express, passes | Paid |

Japanese rail fares are not a simple A→B matrix: kilometer / zone tables, company boundaries, contact transportation, IC vs ticket rounding, shinkansen/limited-express surcharges, transfer discounts, “Yamanote / Tokyo ward” specials, season tickets.

**API product policy options:**

1. **Omit fare** (MVP)  
2. **Single-operator IC only** via ODPT  
3. **Paid fare provider** for production through-fare  

Open-only + correct national IC through-fare ≈ **not achievable today**.

---

## 6. Why “nationwide” is hard (not an OTP limitation)

| Barrier | Detail |
|---|---|
| **Commercial data market first** | JR / major private rail already flow through timetable publishers → journey planners; little incentive to also publish free GTFS |
| **Policy push is bus-first** | MLIT GTFS-JP / COMmmmONS improved **bus**; rail open feeds lag |
| **Operator count** | Hundreds of JR / private / third-sector feeds; each URL, quality, revision date differs |
| **ID chaos** | No single national stop_id; ekidata ≠ GTFS ≠ ODPT without mapping |
| **Realtime narrower still** | GTFS-RT / ODPT RT mostly dense in capital-region participants |
| **Quality risk** | Public lists warn of expired feeds, bad coordinates, stale calendars |

**Nationwide station master (A):** mostly OK via 駅データ.jp.  
**Nationwide open rail schedules (B) + delay (D):** not ready for commercial “Yahoo Transit class” coverage.

```text
              Open only          + Paid API
Station master     ◎                  ◎
Nearest station    ◎                  ◎
Capital-region route ○ (OTP+GTFS)     ◎
Nationwide route   △–✗ (rail gap)     ◎
Single-op fare     ○ (ODPT)           ◎
Through / LEX fare ✗                  ◎
Nationwide delay   ✗                  △–○
```

---

## 7. Suggested Transit API surface (sketch)

Minimal JSON API for an Even plugin (and others):

| Endpoint | Purpose |
|---|---|
| `GET /v1/stations/nearest?lat=&lon=` | Resolve GPS → station group (ekidata / ODPT) |
| `GET /v1/stations?q=` | Name search for registration UI |
| `POST /v1/route` | `{ from, to, departAt? }` → itineraries (OTP) |
| `GET /v1/status?lines=` | Delay / disruption summary for lines on a route |
| `GET /v1/fare?from=&to=` | Optional; ODPT and/or paid backend |

Response for glasses should be **pre-summarized** (short lines, transfer steps), not raw OTP GraphQL.

**Ops:**

- Secret store for ODPT / paid keys  
- Cron: GTFS fetch → validate → S3 → rebuild OTP on hash change  
- Always-on: GTFS-RT updaters  
- Cache identical OD pairs 30–60s  
- Health: feed age, graph build time, RT lag

---

## 8. Phased roadmap

| Phase | Scope | Goal |
|---|---|---|
| **0** | Mock routes + ekidata nearest | Plugin UX without OTP |
| **1** | OTP + 1– few capital GTFS feeds | Real itineraries |
| **2** | JR East (etc.) GTFS-RT into OTP | Delay-aware paths |
| **3** | Feed pipeline + ID map DB + monitoring | Operable service |
| **4** | More feeds / ODPT status fallback / optional paid fare | Expand coverage |

Phase 1–2 answers “does the open stack work for our region?” Nationwide is an **ops** problem from Phase 3 onward.

---

## 9. Relation to even-deskless

This kit verifies plugins **without** glasses / USB / Hub login (`docs/verification.md`). Product transit backends belong in a **product repo**, not as a hard dependency of `verify:deskless`. Cloud Agents: mock the Transit API; do not require live ODPT keys in the default gate.

---

## 10. Decision checklist

- [ ] Region: capital only vs nationwide  
- [ ] Routing: OTP open stack vs Ekispert/NAVITIME  
- [ ] Fare: none / ODPT single-op / paid  
- [ ] Voice: later (STT outside Even SDK)  
- [ ] Hosting: Worker + managed OTP vs full VPS  
- [ ] License review: 駅データ.jp, HeartRails credit, ODPT terms, each GTFS publisher  

---

## 11. Key links

| Topic | URL |
|---|---|
| 駅データ.jp | https://ekidata.jp/ |
| Ekidata REST | https://ekidata.si-yuki.org/ |
| HeartRails | https://express.heartrails.com/api.html |
| ODPT overview | https://www.odpt.org/overview/ |
| ODPT developer | https://developer.odpt.org/ |
| GTFS.JP | https://www.gtfs.jp/ |
| OpenTripPlanner | https://github.com/opentripplanner/OpenTripPlanner |
| JR East OTP Docker example | https://github.com/takoyaki-3/odpt-challenge2024-jre-otp-docker |
| 駅すぱあと API | https://api-info.ekispert.com/ |
| Even Hub SDK (location, storage, UI) | `@evenrealities/even_hub_sdk` ≥ 0.0.14 |

---

## 12. One-line summary

**Ship routing/delay/fare as a separate Transit API; drive it with 駅データ.jp + GTFS + OTP + GTFS-RT for open capital-region PoCs; use paid APIs (or omit) for national through-fare and full coverage.**
