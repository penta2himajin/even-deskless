#!/usr/bin/env node
/**
 * @penta2himajin/even-deskless CLI
 *
 * Usage (from an Even Hub plugin repo):
 *   even-deskless verify-l2a
 *   even-deskless verify-l0
 *   even-deskless verify
 *   even-deskless verify-l2a --ready '[my-app] ready'
 */
import { spawnSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const KIT_ROOT = resolve(__dirname, '..')

function usage() {
  console.log(`even-deskless — deskless verification for Even Hub plugins

Commands:
  verify-l0              Run typecheck + vitest in the current package
  verify-l2a [options]   Boot Vite + evenhub-simulator automation smoke
  verify                 verify-l0 then verify-l2a

Options (verify-l2a / verify):
  --ready <marker>       Console ready substring (default: env READY_MARKER or
                         package.json evenDeskless.readyMarker or
                         "[even-deskless] ready")
  --port <vitePort>      Vite port (default: 5173)
  --automation-port <n>  Simulator automation port (default: 9898)
  --help                 Show this help

Consumer setup:
  1. Log console.info("<marker>") after createStartUpPageContainer
  2. Dev-depend on @evenrealities/evenhub-simulator (and vite)
  3. npm i -D @penta2himajin/even-deskless
`)
}

function readConsumerReadyMarker(cwd) {
  try {
    const pkg = JSON.parse(readFileSync(join(cwd, 'package.json'), 'utf8'))
    const m = pkg.evenDeskless?.readyMarker
    if (typeof m === 'string' && m.trim()) return m.trim()
  } catch {
    /* ignore */
  }
  return null
}

function parseArgs(argv) {
  const out = {
    cmd: '',
    ready: process.env.READY_MARKER || '',
    vitePort: process.env.VITE_PORT || '5173',
    automationPort: process.env.AUTOMATION_PORT || '9898',
  }
  const rest = [...argv]
  if (rest[0] && !rest[0].startsWith('-')) {
    out.cmd = rest.shift()
  }
  for (let i = 0; i < rest.length; i++) {
    const a = rest[i]
    if (a === '--help' || a === '-h') out.cmd = 'help'
    else if (a === '--ready' && rest[i + 1]) out.ready = rest[++i]
    else if (a === '--port' && rest[i + 1]) out.vitePort = rest[++i]
    else if (a === '--automation-port' && rest[i + 1]) out.automationPort = rest[++i]
    else {
      console.error(`Unknown argument: ${a}`)
      process.exit(2)
    }
  }
  return out
}

function run(command, args, env = {}) {
  const r = spawnSync(command, args, {
    stdio: 'inherit',
    cwd: process.cwd(),
    env: { ...process.env, ...env },
    shell: false,
  })
  if (r.error) throw r.error
  if (r.status !== 0) process.exit(r.status ?? 1)
}

function verifyL0() {
  const cwd = process.cwd()
  const pkgPath = join(cwd, 'package.json')
  if (!existsSync(pkgPath)) {
    console.error('even-deskless verify-l0: no package.json in cwd')
    process.exit(1)
  }
  const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'))
  const scripts = pkg.scripts || {}
  if (scripts['verify:l0']) {
    run('npm', ['run', 'verify:l0'])
    return
  }
  if (scripts.typecheck && scripts.test) {
    run('npm', ['run', 'typecheck'])
    run('npm', ['test'])
    return
  }
  console.error(
    'even-deskless verify-l0: add script "verify:l0" or both "typecheck" and "test"',
  )
  process.exit(1)
}

function verifyL2a(opts) {
  const cwd = process.cwd()
  const script = join(KIT_ROOT, 'scripts', 'verify-l2a.sh')
  if (!existsSync(script)) {
    console.error(`missing ${script}`)
    process.exit(1)
  }
  const ready =
    opts.ready ||
    readConsumerReadyMarker(cwd) ||
    '[even-deskless] ready'

  // Prefer consumer app as EXAMPLE_DIR. Kit dogfood: if cwd is kit root, use examples/bare.
  let exampleDir = cwd
  if (
    existsSync(join(cwd, 'examples', 'bare', 'package.json')) &&
    existsSync(join(cwd, 'scripts', 'verify-l2a.sh'))
  ) {
    exampleDir = join(cwd, 'examples', 'bare')
  }

  run('bash', [script], {
    EXAMPLE_DIR: exampleDir,
    READY_MARKER: ready,
    VITE_PORT: String(opts.vitePort),
    AUTOMATION_PORT: String(opts.automationPort),
    EVEN_DESKLESS_ROOT: KIT_ROOT,
  })
}

function main() {
  const opts = parseArgs(process.argv.slice(2))
  if (!opts.cmd || opts.cmd === 'help') {
    usage()
    process.exit(opts.cmd ? 0 : 2)
  }
  if (opts.cmd === 'verify-l0') verifyL0()
  else if (opts.cmd === 'verify-l2a') verifyL2a(opts)
  else if (opts.cmd === 'verify') {
    verifyL0()
    verifyL2a(opts)
  } else {
    console.error(`Unknown command: ${opts.cmd}`)
    usage()
    process.exit(2)
  }
}

main()
