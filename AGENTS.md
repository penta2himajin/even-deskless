# even-deskless

## Overview

Deskless verification kit for Even Hub plugins. Maximize automated checks that run without glasses, USB phones, or Even Hub account UI. Complements official SDK / `evenhub-templates` / Hub Simulator — does not replace them.

SoT for layers: @docs/verification.md

## Project Structure

```
docs/                 # verification SoT, handoff, i18n, optional cloud-agent-qr
examples/bare/        # dogfood plugin (Vite + SDK + ready marker)
scripts/              # verify-l2a, smoke, cloud-install, optional qr-tunnel
.cursor/              # Cursor Cloud Dockerfile + environment.json
```

## Development Setup

```bash
cd examples/bare && npm ci

# Optional pre-push hook (from repo root):
cp git-hooks/pre-push .git/hooks/pre-push && chmod +x .git/hooks/pre-push
```

Cursor Cloud: `.cursor/environment.json` runs `scripts/cloud-install.sh` on Builds (Node 20, xvfb). **No USB / Even Hub / glasses in managed Cloud VMs.**

## Build & Test

```bash
npm run verify:l0          # examples/bare typecheck + vitest
npm run verify:l2a         # simulator automation smoke
npm run verify:deskless    # L0 + L2a
```

## Development Principles

- Follow TDD for kit scripts and the bare example.
- Keep the default deskless gate free of Android SDK / companion APK requirements.
- Document Cloud vs desk boundaries in `docs/verification.md`; do not paper over simulator limits.

## Architectural Boundaries

- Kit code must not vendor or fork `@evenrealities/*` packages.
- Product-specific companions (e.g. local LLM hosts) stay in product repos; optional recipes may be documented later, never required by `verify:deskless`.

## Prohibitions

1. Do not require USB devices or Even Hub login for Cloud / `verify:deskless`.
2. Do not treat Hub Simulator as L4 / glasses fidelity.
3. Do not commit credentials or `.env*` secrets.

## Git Conventions

- Conventional Commits.
- Branch prefix: `cursor/<topic>`, `claude/<topic>`, or `human/<topic>`.
- AI-authored commits: append agent trailer (no model name in trailer).

## Session Handoff

See `docs/handoff-protocol.md`. Label: `session-handoff`.

## Internationalisation

Follow `docs/i18n-policy.md`. User-facing: `README.md` + `README.ja.md`. Engineering docs stay English-only.

---

<!-- Common rules below this line apply to every project. -->

## Common Development Rules

### TDD (Red → Green → Refactor)

All implementation work proceeds in this cycle:

1. **Red**: write a failing test that captures the intended behaviour.
2. **Green**: write the minimum code that makes the test pass.
3. **Refactor**: tidy up while keeping tests green.

When a test fails, fix the production code — do not delete, skip, or weaken the test.

### Measure, Don't Conjecture

Base decisions on observed data, not assumptions.

### Git Conventions

- **Conventional Commits**: `feat:` `fix:` `docs:` `refactor:` `test:` `ci:` `chore:`.
- **Branch naming**: short prefix + topic, e.g. `cursor/<topic>`.
- **Trailer**: when an AI agent authors the commit, append a trailer crediting the agent. Do not embed model name or session info in the trailer.
- **Pre-push hook**: install via `cp git-hooks/pre-push .git/hooks/pre-push && chmod +x .git/hooks/pre-push` (or `git config core.hooksPath git-hooks`).

### Pull Requests

- Always ready for review (never draft-by-default).
- One PR per workstream; reference handoff issues with `Closes #N` when applicable.

### Common Prohibitions

1. Do not delete, skip, or comment out existing tests.
2. Do not modify CI configuration without explicit instruction.
3. Do not weaken production code merely to make tests pass.
4. Do not commit credentials, API keys, signed URLs, or anything in `.env*`.
