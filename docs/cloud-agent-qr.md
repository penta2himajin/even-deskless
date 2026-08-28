# Optional: Cloud Agent → glasses via tunnel QR

**Status:** optional recipe (not part of `verify:deskless`).  
**Audience:** humans and coding agents on Cursor Cloud / remote VMs.  
**Related SoT:** [verification.md](./verification.md) § Cursor Cloud vs desk.

Desk / QR / Beta remains out of the default gate. This note only records a practical path when a Cloud Agent already hosts the Vite app and you want a phone to sideload it without a shared LAN IP.

---

## Problem

Cursor Cloud Agent port forwarding maps the VM port to **your laptop** `localhost:5173`. That is enough for a local browser, but the Even Realities app on a phone cannot use `http://127.0.0.1:5173` (that is the phone itself).

Cloud VMs also usually lack a phone-reachable private LAN address. Public cloud IPs typically do not expose the Vite port.

## Recipe

1. Run Vite bound to loopback (or any interface) with **all hosts allowed** so tunnel hostnames are not rejected:

```ts
// vite.config.ts
export default defineConfig({
  server: {
    port: 5173,
    strictPort: true,
    host: '127.0.0.1',
    allowedHosts: true, // required for *.trycloudflare.com (and similar)
  },
})
```

Without `allowedHosts: true`, Vite returns **403** / “This host is not allowed” when the request Host is the tunnel hostname.

2. Start a quick HTTPS tunnel to the Vite port (Cloudflare quick tunnel is the path dogfooded here):

```bash
cloudflared tunnel --url http://127.0.0.1:5173
# → https://<random>.trycloudflare.com
```

3. Print an Even Hub QR for that URL:

```bash
evenhub qr --url "https://<random>.trycloudflare.com"
```

Or, from this repo’s bare example after install:

```bash
npm run qr:tunnel --prefix examples/bare
```

4. In the Even Realities app: Even Hub → **Scan QR**.

Quick Tunnel URLs change on every restart. Re-run steps 2–3 after reconnecting the tunnel.

`npm run qr:tunnel` backgrounds `cloudflared` and reuses the URL in `CF_TUNNEL_LOG` (default `/tmp/even-deskless-cf-tunnel.log`) only after a short HTTPS probe succeeds. If the probe fails, it clears the log and starts a new quick tunnel.

## What this does / does not cover

| Covered | Not covered |
|---|---|
| Phone can load the plugin WebView from a Cloud Agent | BLE timing, lock-screen Beta, packaging quirks |
| Vite Host-header rejection by tunnel hostname | Treating Hub Simulator as glasses fidelity |
| Optional desk bridge from Cloud → glasses | Required CI / `verify:deskless` |

## Simulator IMU gap (related deskless note)

Hub Simulator automation does **not** emit IMU samples (`imuData` stays null). Deskless gates should unit-test gesture classifiers on synthetic series (L0). Real IMU validation stays desk-only. This kit does **not** ship a WebView mock-IMU hook; product apps may add their own injection for L2a-style flows if needed.

## Logging caveat

`console.info` / ready markers from the phone WebView do **not** appear in the Vite terminal by default. They land in the Even app WebView console (or Hub Simulator `/api/console` when using L2a). For Cloud Agent + tunnel sideload, capture app logs from the phone developer console, or add an explicit remote log sink in the product app — do not assume Vite access logs equal app event logs.
