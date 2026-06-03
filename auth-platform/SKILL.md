---
name: auth-platform
description: >
  Use this when working on the user's shared auth platform for product apps: realm setup, Better Auth behavior, app login integration, admin-managed app configuration, OAuth/OIDC or MCP auth, passkeys/2FA, email delivery, billing, storage uploads, local auth development, or auth release/deployment flow. Trigger for requests mentioning auth service, auth-platform, Better Auth, realms, app login, admin UI, OAuth provider, MCP OAuth, passkeys, 2FA, billing, Polar, auth chart, or auth release.
---

# Auth Platform

This is the user's shared auth platform for product apps they build and host. It is not the homelab SSO layer for admin tools. Use it when an app needs real user registration, login, sessions, OAuth/MCP auth, billing entitlements, email flows, or user-uploaded identity/media features.

Keep exact private values out of this public skill. Discover domains, secret record names, registry paths, and runtime values from the local repo, GitOps repo, 1Password CLI, or live cluster.

## What It Is For

The platform exists so new apps do not reimplement auth from scratch.

It provides shared building blocks:

- user signup/login/session handling through Better Auth;
- hosted login/reset/consent/passkey/2FA flows;
- app-specific realms with isolated users and settings;
- OAuth/OIDC provider behavior for first-party apps and MCP clients;
- email verification and password reset delivery;
- social provider configuration;
- billing product/entitlement integration;
- optional S3-compatible media storage for avatars, realm icons, and similar user-facing files;
- admin UI for managing realms and integrations.

Apps should use the auth platform for identity and entitlement surfaces, while keeping their own business data and business rules in their own app/database.

## Mental Model

A realm is an app's auth boundary.

- Each app gets its own realm.
- Users are realm-local. The same email in two realms means two separate accounts unless the platform is intentionally redesigned.
- Realm settings, trusted origins, providers, feature flags, billing, delivery, and storage behavior are managed through the platform admin surface.
- Deployment infrastructure still belongs in env/GitOps/chart values. User-facing realm configuration should not be duplicated into Git when the admin database owns it.

The auth platform should stay generic. If a feature is only business logic for one app, it belongs in that app. If it is reusable across multiple apps, it may belong in auth as a platform capability.

## How Apps Use It

Typical app integration:

1. Create a realm for the app in the auth admin UI.
2. Configure the app's public URL/trusted origins and enabled features.
3. Configure delivery, social providers, billing, storage, or OAuth only when the app needs them.
4. App redirects users to the platform login flow for that realm.
5. App receives/validates the auth result using the platform's documented realm endpoints, client library, JWT/JWKS, or OAuth/OIDC discovery as appropriate.
6. App stores its own domain data keyed to the realm-local auth user id.

Do not make apps share a global user table by accident. Do not make the auth service store app-specific domain records just because it already has the user id.

## Where Truth Lives

Use the current repo as the source of truth for exact commands, paths, routes, package names, chart values, and implementation details.

Start here in the auth repo:

```text
README.md       current product/architecture overview
AGENTS.md       repo coding rules and module boundaries
TODO.md         known product/security backlog
package.json    current scripts
turbo.json      task graph
charts/**       deployment chart
```

Use the admin UI/database as the source of truth for realm configuration. Use GitOps as the source of truth for deployed versions and infrastructure wiring. Use 1Password through `op` as the source of truth for secrets.

## Important Boundaries

Keep these boundaries intact:

- Auth platform: users, sessions, accounts, passkeys, 2FA, OAuth clients/tokens, email auth flows, provider config, billing entitlements, reusable media upload plumbing.
- App: product data, app-specific permissions, app-specific workflows, app-specific analytics, app-specific business limits beyond generic entitlement checks.
- GitOps/chart/env: deployment URL, database/cache/storage infrastructure, replicas, resources, External Secrets wiring, image/chart versions.
- Admin UI/database: realm display metadata, trusted origins, enabled auth features, provider settings, product mappings, user-facing integration settings.

If a proposed change creates two sources of truth, stop and decide which boundary owns it before coding.

## Security Rules That Matter Here

- Never print passwords, tokens, client secrets, private keys, session cookies, generated admin passwords, or secret values in chat, logs, docs, Git, or final answers.
- Use `op` for 1Password reads/writes. Report status and key names, not values.
- Realm isolation is a security boundary. Cross-realm user/session/provider/token/entitlement bleed is a bug.
- Login handoff, OAuth consent, password reset, email verification, passkeys, and 2FA are security-sensitive flows. Changes need focused verification and usually regression tests.
- Auth codes, login state, rate limits, and OAuth state must work in production topology, not only in one local process.
- Do not weaken CSRF, CSP, redirect origin checks, audience checks, or trusted proxy assumptions to make a flow pass.

## Common Task Patterns

Adding a new app:

1. Create a realm in admin UI.
2. Set display metadata and trusted origins.
3. Enable only features the app needs.
4. Wire the app to the realm login/session/token flow.
5. Verify signup, login, logout, session refresh, and app-side user mapping.

Adding OAuth/MCP support:

1. Confirm the app really needs OAuth/OIDC instead of ordinary browser login.
2. Enable provider/client behavior for that realm.
3. Keep consent explicit: client name, requested scope/resource, approve, deny.
4. Verify discovery, authorization, token exchange, audience, JWKS validation, and repeated approvals.

Adding billing:

1. Configure provider settings without exposing secrets.
2. Map provider products to platform benefits/entitlements.
3. Let the app query entitlement state instead of duplicating billing provider logic.
4. Verify checkout, webhook/update path, entitlement visibility, and app behavior after purchase.

Adding media storage:

1. Decide whether storage is deployment-managed or realm-managed.
2. Keep credentials secret and UI write-only where applicable.
3. Store metadata that is useful to users, especially original filenames.
4. Verify upload, preview/open URL, replacement, and disabled-storage behavior.

## Local Development And Release

For auth-flow work, prefer the repo's full local stack so API, admin UI, login UI, database, cache, storage, and router behave like one origin. Direct frontend dev is fine for visual-only work, but cookie/OAuth/redirect/passkey/CSRF behavior should be tested through realistic routing.

Release source repo first, GitOps second:

1. Change auth repo.
2. Run relevant focused checks from repo scripts.
3. Push and confirm image/chart publishing.
4. Bump the pinned auth version in GitOps.
5. Refresh Argo and verify live pods, logs, routes, and real auth flows.

Do not assume a chart bump changed runtime behavior. Verify deployed image tags and real responses.
