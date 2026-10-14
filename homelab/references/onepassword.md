# 1Password records

Use the Homelab vault and official `op` CLI. Confirm the account/authentication mode before writes; do not assume `--vault` restricts the caller's permissions. Read existing fields and consumers without displaying values.

## Format

- One active **Secure Note per service, no tags**, named after the service. Group app, database, Redis, registry and frontend fields in clear sections. Shared dependency credentials stay in that dependency's item; consumers reference it instead of copying them.
- Labels must be unique across the entire item because External Secrets selects them. Keep descriptive app-specific key names and remove obsolete aliases. Database credentials use explicit DB labels rather than generic `username`/`password`.

| Section | Fields |
| --- | --- |
| PostgreSQL | `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_URL` |
| Local PostgreSQL access | `DB_PORT_FORWARD`, `DB_LOCAL_URL` |
| Read-only PostgreSQL | `DB_READER_USER`, `DB_READER_PASSWORD`, `DB_READER_URL` |
| Redis | `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, `REDIS_URL` |
| ClickHouse | `CLICKHOUSE_HOST`, `CLICKHOUSE_PORT`, `CLICKHOUSE_DATABASE`, `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_URL` |
| Registry | `GHCR_USER`, `GHCR_TOKEN` |

Conceal passwords, tokens, private keys and credential-bearing URLs. Keep host, port, database and user readable. URL-encode credentials and check that parsed connection strings match the separate fields.

Discover connection details from manifests/live resources. `DB_URL` uses cluster service DNS. For an active PostgreSQL service, provide a `kubectl --context admin@homelab -n <namespace> port-forward svc/<service> 15432:5432` command and matching `DB_LOCAL_URL`. Forwarding must remain running; local port `15432` can serve only one session at a time. Do not embed repo/config paths.

Mark endpoints for absent services as historical/unverified in `DB_STATUS`. Do not invent credentials for embedded databases without accounts. Config recovery files remain attachments in their respective service notes; restore to global client paths, never into runtime External Secrets.

## Consolidation and renaming

1. Map source fields/attachments to every consumer, including Helm values, registry pulls and database readers. Preserve credentials; organizing records does not authorize rotation.
2. Populate and verify the destination before switching references. CLI category changes require a replacement item. Preserve populated values and attachment identity/readability; keep item names unambiguous during the transition.
3. Update Git references, render, publish and reconcile through the main GitOps workflow. Force-refresh affected ExternalSecrets and check a new successful refresh, not just an existing Ready condition.
4. For reorganization without rotation, compare consumer Secret data before/after via hashes without printing values. Verify workloads still use the expected credentials.
5. Archive superseded records only after consumers succeed; preserve recoverability. Confirm one active Secure Note per service, no tags or obsolete aliases, and remove temporary credential copies.
