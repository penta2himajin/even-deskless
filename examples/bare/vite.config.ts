import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'node',
  },
  server: {
    port: 5173,
    strictPort: true,
    host: '127.0.0.1',
    // Allow Cloudflare / other tunnel Host headers when using scripts/qr-tunnel.sh
    allowedHosts: true,
  },
  build: {
    target: 'esnext',
  },
})
