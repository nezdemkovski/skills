---
name: auth-platform
description: Use this when working on the user's shared Better Auth platform, auth monorepo, auth API, admin dashboard, login UI, realm/project configuration, OAuth/OIDC provider, passkeys, 2FA, social providers, Polar billing, email delivery, S3 media uploads, generated auth client, or the auth Helm chart/release flow. Trigger for requests mentioning auth service, auth-platform, Better Auth, realms, hosted login, login UI, admin UI, OAuth provider, MCP OAuth, passkeys, 2FA, billing, Polar, auth chart, or auth release.
---

# Auth Platform

This skill is the operating guide for the user's shared auth platform. It is intentionally public-safe: do not hardcode private domains, email addresses, registry names, secret record names, tokens, or local absolute paths. Discover current values from the local repo, Git remotes, private GitOps repo, 1Password CLI, or live cluster state.

## First Steps

Locate the auth repo and inspect current state before changing anything.

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

Install dependencies only when needed, then run the smallest verification that proves the change. If the task involves deployment, also locate the GitOps repo and use the homelab skill for cluster verification.

## Core Model

- The platform is a project-scoped Better Auth service.
- Each realm/project has its own user pool, Better Auth instance, Postgres schema, trusted origins, cookie prefix, issuer, and JWKS endpoint.
- The same email may register independently in different realms. Do not assume global identity across realms.
- Application databases should store application data separately and reference the realm-local Better Auth `user.id`.
- Realm configuration is primarily managed by the admin UI/database. Do not reintroduce duplicate source-of-truth config in Git/env unless it is deployment-level infrastructure.
- Persistent production changes ship through image/chart release and GitOps, then live verification.

## Repository Map

In the auth repo, expect this structure:

```text
apps/api                 Bun/Hono API and Better Auth runtime
apps/admin               Vite React admin dashboard
apps/login               Vite React login, reset password, consent, and auth handoff UI
packages/client          Generated TypeScript client from OpenAPI
packages/client-shared   Shared frontend theme/CSS/runtime helpers
packages/ui              Shared React UI primitives
charts/auth              Umbrella Helm chart for API, admin, login, router, DB/cache/object storage
dev/docker-compose.yml   Local full-stack dev runtime
turbo.json               Turborepo task graph
AGENTS.md                Repo-specific implementation rules
README.md                Human overview
TODO.md                  Product/security backlog
```

## Common Commands

Run from `<auth-repo>`:

```bash
bun install
bun run dev:compose:up
bun run dev:compose:down
bun run dev
bun run dev:admin
bun run dev:login
bun run email:dev
bun run build
bun run typecheck
bun run test
bun run test:integration
bun run client:generate
helm lint charts/auth
helm template auth charts/auth --namespace <namespace> >/tmp/auth-render.yaml
git diff --check
```

Local full-stack development should prefer the compose route so API, admin, login, Postgres, Redis, object storage, and router share one origin. Direct Vite dev servers are fine for UI-only iteration, but real cookie/OAuth/auth flows should be tested through a single local origin.

## Architecture Rules

- The API does not serve frontend assets. Admin and login are standalone static apps behind the router.
- Public route shape should stay simple and predictable:
  - `/admin/*` -> admin UI
  - `/login/*` -> login UI
  - `/api/*` -> auth API
- Keep the router as dumb routing glue. Do not move business logic into Caddy/router config.
- Use Turborepo tasks instead of ad-hoc per-package command chains when possible.
- Keep frontend shared pieces in `packages/ui` or `packages/client-shared`; do not copy components between admin and login.
- Use generated client code for admin/API integration when the endpoint is part of the public admin API. Regenerate after OpenAPI changes.

## Backend Module Rules

For new or refactored API domains, use domain-first modules:

```text
apps/api/src/modules/<domain>/
  http.ts
  core.ts
  validator.ts
  translator.ts
  store.ts
  __tests__/
```

Only create files that the domain actually needs.

Layer boundaries:

- `http.ts`: Hono routes, authz, request parsing, validation calls, response status/envelope.
- `validator.ts`: convert raw `unknown` input to typed input; return `null` for normal invalid input.
- `core.ts`: business orchestration and domain errors.
- `store.ts`: database reads/writes only; no business decisions.
- `translator.ts`: convert internal/SDK/database objects to public DTOs and hide secrets.

Implementation style:

- Prefer exported arrow functions for standalone helpers.
- Use TypeScript enums for closed domain values such as providers, feature modes, product types, entitlement types, storage folders, upload purposes, and page modes.
- Avoid `as` casts and workaround typing. Add typed boundaries, parsers, or guards instead.
- Do not compare against raw string literals for closed domain state.
- Security-sensitive fixes need regression tests for the failure mode.

## Realm And Auth Flow

Realm lifecycle:

1. Admin creates or updates a realm from the admin UI/API.
2. API stores realm metadata, trusted origins, feature flags, delivery/storage/billing settings, and provider settings.
3. API idempotently prepares the realm schema and Better Auth tables.
4. Login UI fetches runtime realm config from API.
5. Apps integrate with the realm-specific auth endpoints and JWKS.

Login handoff:

- Use short-lived authorization codes plus PKCE S256.
- Store the code verifier in an HttpOnly app cookie where applicable.
- Exchange the code only after validating project, redirect URI, and PKCE verifier.
- Hosted/login codes and rate limits must use Redis in multi-replica deployments.
- Do not reintroduce in-memory-only stores for cross-request auth state unless it is explicitly dev-only.

OAuth/OIDC provider:

- Realms may expose OAuth/OIDC for first-party apps and remote MCP clients.
- Dynamic Client Registration is optional per realm. It creates OAuth client metadata; users still approve access on the consent screen.
- Consent UI must show the requesting client/app, requested scope/resource, and approve/deny actions.
- OAuth access tokens must be audience-bound and validated against the realm JWKS.

## Security Invariants

- Do not print passwords, tokens, client secrets, private keys, session cookies, or generated secret values in logs, docs, Git, chat, or final answers.
- Use `op` for 1Password reads/writes and report only presence/status/key names, not values.
- Keep secrets in 1Password/External Secrets or deployment-managed env. Do not hardcode them in charts, docs, tests, or examples.
- Do not trust client-supplied forwarding headers unless the service is reachable only through a trusted proxy that strips and replaces them.
- Keep CSRF checks strict for state-changing admin requests.
- Keep CSP nonce-based for inline scripts; do not casually add `unsafe-inline` back to `script-src`.
- Keep hosted/login code storage single-use with TTL.
- Add `email_verified` or equivalent claims when downstream apps need to distinguish verified identity.
- Admin account recovery and email changes should require strong confirmation; do not add unauthenticated admin signup flows.
- Prefer Redis-backed rate limiting in production. In-memory limits are only acceptable for single-process local development.

## Features And Integrations

Delivery/email:

- Email delivery is configurable per deployment/realm through the platform settings.
- Support provider-specific settings without leaking API keys in responses.
- React Email templates should be previewable locally with the repo email dev command.
- Verification/reset links must use the correct public auth origin and realm path, not local dev callback URLs unless running locally.

Social providers:

- Store provider settings per realm.
- Encrypt provider secrets at rest.
- UI may show configured/not configured state, but never reveal secret values.
- Add provider support through typed enums and provider-specific validation, not raw string branches scattered through the codebase.

Passkeys and 2FA:

- Feature flags may be enabled per realm.
- If policy requires enrollment, the UI flow must enforce enrollment instead of only exposing optional setup.
- Login pages should not ask users to add a passkey when the account already has one for the relevant context.

Billing:

- Billing provider support is realm-scoped and optional.
- Product mapping, benefits, entitlements, one-time purchases, subscriptions, and lifetime purchases should be modeled as platform concepts, not one-off app hacks.
- The app should call the auth platform for checkout/entitlement state and keep business logic in the app.
- Provider tokens and webhook secrets stay secret; admin UI can validate configuration without displaying sensitive values.

Storage/media:

- Media storage is optional and can be deployment-managed or realm-managed.
- Prefer S3-compatible storage through Bun's S3 API.
- Realm images and user images should store object metadata in the realm database and blobs in object storage.
- Preserve original filenames in metadata for display; storage keys may be hashed or generated.
- If deployment-managed storage is configured, admin UI should avoid showing irrelevant endpoint/credential fields and expose only realm-level enable/disable or upload controls.

## Local Development

Use compose for end-to-end work:

```bash
cd <auth-repo>
bun run dev:compose:up
```

Then test through the local router origin, not separate production domains. Use direct app dev commands only when the task is isolated to visual/UI iteration.

Local checks before release:

```bash
bun run typecheck
bun run test
bun run build
```

For API contract changes:

```bash
bun run client:generate
```

For email template work:

```bash
bun run email:dev
```

## Release And Homelab Deployment

Release flow:

1. Make code/chart changes in `<auth-repo>`.
2. Run focused tests plus `typecheck` and `build` when relevant.
3. Commit and push auth repo changes.
4. Ensure CI publishes the API/admin/login images and the OCI Helm chart.
5. Update the auth chart version/appVersion in the GitOps repo.
6. Push GitOps changes.
7. Refresh Argo and verify live API, admin UI, login UI, pods, logs, Redis/Postgres connectivity, and real auth flows.

Do not assume a chart version bump changed runtime behavior. Verify deployed image tags and live responses.

## Testing Guidance

- Use module tests for validators, translators, core business rules, and stores.
- Use HTTP-boundary tests for critical auth, admin, login, OAuth, billing, delivery, and storage flows.
- Use neutral fixtures such as `demo`, `Demo App`, `demo.example.com`, and `user@example.com`.
- Do not use real project names, real user emails, real product names, or private domains in tests.
- For security regressions, test the blocked failure mode explicitly.
- Avoid tests that only mirror object shapes without protecting a real invariant.

## Public Safety Rules

This skill may live in a public repo. Keep it generic:

- Do not add actual root domains, private subdomains, registry paths, image names, email addresses, IPs, token names, client IDs, or exact secret record names.
- Do not add passwords, API keys, webhook secrets, generated admin passwords, OAuth client secrets, session cookies, private keys, or kubeconfig contents.
- Do not add private realm names, internal database names, service DNS names, or customer/project-specific examples.
- Prefer placeholders like `<auth-repo>`, `<homelab-gitops>`, `<root-domain>`, `<realm>`, `<app-domain>`, `<namespace>`, `<chart-version>`, and `<image-tag>`.
- If exact values are needed, discover them from local private files, 1Password, GitOps, or live state during the task, not from this public skill.

## Communication Style For This Platform

- Be direct and security-conscious.
- Explain whether a change affects realm behavior, platform behavior, deployment behavior, or downstream app integration.
- If something is broken, inspect logs/live state and the exact realm path before changing code.
- Do not expose hidden hostnames, secret item names, tokens, or secret values in final answers.
- If a shortcut would create a second source of truth, say so and choose the cleaner platform model.
