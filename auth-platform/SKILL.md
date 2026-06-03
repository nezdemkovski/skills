---
name: auth-platform
description: >
  Use this when working on the user's shared auth platform: auth service architecture, realm/project setup, Better Auth behavior, login/admin UI, OAuth/OIDC or MCP auth, passkeys/2FA, email delivery, billing, storage uploads, generated clients, local auth development, or auth release/deployment flow. Trigger for requests mentioning auth service, auth-platform, Better Auth, realms, hosted login, admin UI, OAuth provider, MCP OAuth, passkeys, 2FA, billing, Polar, auth chart, or auth release.
---

# Auth Platform

This skill is the operating guide for the user's shared auth platform. Keep it public-safe: do not hardcode private domains, emails, registry paths, secret record names, tokens, local absolute paths, or generated credentials. Discover exact values from the local repo, Git remotes, GitOps repo, 1Password CLI, or live cluster state.

## First Steps

Locate the auth repo and inspect it before changing anything.

Preferred repo location pattern:

```text
~/Sites/auth
```

If the path is missing, search under `~/Sites` or ask for the path. Do not invent paths.

Use repo state over memory:

```bash
cd <auth-repo>
git status --short
rg --files
```

Read the repo's current docs and rules before editing:

```text
README.md
AGENTS.md
TODO.md
package.json
turbo.json
charts/**
```

If the task affects deployment, also locate the GitOps repo and use the homelab skill for cluster verification.

## Core Model

- This is a shared auth platform for multiple apps, not a one-off app login form.
- Realms/projects are isolated identity spaces. Do not assume users, sessions, providers, settings, or entitlements are global unless the repo explicitly models them that way.
- The admin UI/database is the source of truth for user-facing realm configuration unless the setting is clearly deployment infrastructure.
- App business data belongs in the app database. The auth platform should expose identity, session, token, entitlement, and configuration surfaces; it should not absorb unrelated app domain logic.
- Prefer platform-level abstractions over one-off app hacks when a feature will likely be reused by multiple apps.

## Working Rules

For most tasks:

1. Inspect current repo structure and relevant docs.
2. Trace the live flow or failing request before changing behavior.
3. Make the smallest code/model change that preserves the platform boundaries.
4. Add or update tests for security-sensitive or cross-realm behavior.
5. Run focused verification first, then broader `typecheck`, `test`, or `build` when warranted.
6. If deploying, release the app/chart and verify through GitOps plus live runtime behavior.

Do not duplicate technical details in this skill when the repo already states them. Use the repo as the source of truth for exact package names, scripts, routes, chart values, image names, and directory layout.

## Security Invariants

- Never print passwords, tokens, client secrets, private keys, session cookies, generated admin passwords, or secret values in chat, logs, docs, Git, or final answers.
- Use `op` for 1Password reads/writes. Report only presence, key names, sync status, or validation status, not secret values.
- Do not hardcode secrets in charts, tests, examples, or local docs.
- Keep state-changing admin routes protected against CSRF.
- Keep browser-facing pages on a strict CSP model; do not weaken script policy casually.
- Treat forwarding headers as trusted only behind a trusted proxy that strips client-supplied versions.
- Auth codes, login handoff state, rate limits, and similar cross-request state must be safe for production topology. Avoid process-local state unless it is explicitly dev-only.
- Realm isolation is a security boundary. Test that cross-realm reads, writes, cookies, providers, tokens, and entitlements do not bleed across realms.

## Auth And Integration Principles

- Login, reset, consent, passkey, and 2FA flows should feel like part of the platform, not per-app custom screens.
- OAuth/OIDC and MCP auth should use standard discovery, consent, audience validation, and realm-local keys. Avoid compatibility hacks when the app has no legacy users to preserve.
- Social providers, delivery/email, billing, storage, and feature flags should be configurable per realm when that makes product sense.
- Provider secrets should be write-only from the UI perspective: allow setting/replacing/validating them, never revealing them.
- Billing should model products, benefits, entitlements, subscriptions, one-time purchases, and lifetime purchases as reusable platform concepts.
- Storage/media should preserve useful metadata such as original filename while allowing generated storage keys.

## Frontend Principles

- Admin UI is an operator product. Optimize for clear settings, inspection, validation actions, and low-confusion workflows.
- Login UI is user-facing. Keep it polished, mobile-safe, accessible, and consistent across realms.
- Avoid dumping every integration field onto one page. Prefer flows that reveal only relevant controls for the selected provider/mode.
- Use shared UI primitives from the repo rather than duplicating styling or components between frontends.
- When changing real auth flows, test through a same-origin local/proxy setup instead of only isolated Vite pages.

## Backend Principles

- Keep HTTP boundaries, validation, business logic, persistence, and response shaping separated according to the repo's current module rules.
- Use typed boundaries and domain enums for closed state. Avoid scattered raw string comparisons for provider names, feature modes, grant types, and similar platform concepts.
- Prefer idempotent bootstrap/migration behavior. Fresh installs and repeated deploys should converge without manual DB edits.
- Do not create a second source of truth between env/Git, database settings, admin UI, and external provider state.
- Generated clients and OpenAPI outputs should be updated when public API contracts change.

## Local Development

Prefer the repo's full local stack command for end-to-end auth work so API, admin UI, login UI, database, cache, storage, and router behave like one auth origin.

Use direct frontend dev commands only for UI-only iteration. Cookie, OAuth, redirect, passkey, and CSRF behavior should be tested through the realistic local routing setup.

Before release, run the smallest meaningful checks and then broaden as needed:

```bash
bun run typecheck
bun run test
bun run build
```

Use repo scripts, not hand-rolled command chains, unless a script is missing or broken.

## Release And Deployment

Release flow is source repo first, GitOps second:

1. Change the auth repo.
2. Run relevant verification.
3. Commit and push.
4. Confirm images/chart are published by CI.
5. Update the GitOps repo to the pinned released version.
6. Refresh Argo and verify live pods, logs, routes, and real auth flows.

Do not assume a chart bump changed runtime behavior. Verify deployed image tags and real responses.
