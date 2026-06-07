---
name: homelab
description: >
  Use this when working on the user's Talos/Proxmox homelab, Kubernetes GitOps repo, Argo CD apps, Cilium/network policies, 1Password/External Secrets, Cloudflare Tunnel ingress, observability/analytics, or services deployed through the homelab GitOps repository. Trigger for requests mentioning homelab, Talos, Proxmox, Argo, GitOps, Kubernetes services, Cilium, NetworkPolicy, Cloudflare Tunnel, 1Password Connect, Grafana MCP, analytics dashboards, or homelab domains.
---

# Homelab

This skill is the operating guide for the user's homelab. It is intentionally public-safe: do not rely on hardcoded private domains, secret item names, or local absolute paths. Discover the current values from the local machine, private GitOps repo, 1Password, or live cluster state.

## First Steps

Before making changes, locate the GitOps repo and kubeconfig.

Preferred repo location pattern:

```text
~/Sites/homelab-gitops
```

Preferred kubeconfig location pattern:

```text
<homelab-gitops>/kubeconfig
```

If either path is missing, search under `~/Sites` or ask for the path. Never invent cluster paths.

Use repo/live state over memory. For drift-prone facts, verify before answering or changing anything:

```bash
cd <homelab-gitops>
KUBECONFIG=<homelab-gitops>/kubeconfig kubectl get nodes
KUBECONFIG=<homelab-gitops>/kubeconfig kubectl -n argocd get applications
```

## Core Model

- The cluster runs Talos on Proxmox.
- GitOps is managed by Argo CD from a private/public Git repository, usually branch `master`.
- Persistent changes should be made in Git first, then pushed, then verified through Argo and live Kubernetes state.
- For most tasks, follow this order: inspect Git/live state, edit Git, render or lint when possible, commit, push, refresh Argo, then verify the real workload.
- Do not make lasting manual UI changes in Argo/Grafana/Kubernetes when the same state belongs in Git.
- Prefer pinned chart/image/plugin versions. Do not use `latest`, floating chart revisions, or branch names for external dependencies.
- Use conventional commit messages. The preferred Git history is linear/rebase-style.

## Repository Map

In the GitOps repo, expect this structure:

```text
bootstrap/project.yaml                 Argo AppProject
apps/infra/**                          cluster infrastructure apps and policies
apps/workloads/**                      workload Argo Applications and raw manifests
charts/**                              local Helm charts
AGENTS.md                              repo operating rules for agents
README.md                              human overview only, not agent instructions
renovate.json                          dependency update rules
```

Related application repos usually live next to the GitOps repo under `~/Sites`. Locate them with `rg --files`, `find`, or Git remotes instead of assuming exact private paths.

## Common Commands

Run from `<homelab-gitops>`:

```bash
KUBECONFIG=<homelab-gitops>/kubeconfig kubectl get nodes
KUBECONFIG=<homelab-gitops>/kubeconfig kubectl -n argocd get applications
helm lint charts/<chart>
helm template <release> charts/<chart> --namespace <namespace> >/tmp/<chart>-render.yaml
git diff --check
```

After pushing GitOps changes, force Argo refresh when useful:

```bash
KUBECONFIG=<homelab-gitops>/kubeconfig \
  kubectl -n argocd annotate application homelab-root argocd.argoproj.io/refresh=hard --overwrite
```

Then verify app state:

```bash
KUBECONFIG=<homelab-gitops>/kubeconfig \
  kubectl -n argocd get applications homelab-root <app> \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REV:.status.sync.revision
```

For runtime verification, inspect pods/logs/services directly:

```bash
KUBECONFIG=<homelab-gitops>/kubeconfig kubectl -n <namespace> get pods,svc,ingress
KUBECONFIG=<homelab-gitops>/kubeconfig kubectl -n <namespace> logs deploy/<deployment> --tail=200
```

## Secrets

- Runtime secrets live in 1Password and are synced by External Secrets / 1Password Connect.
- Use the official 1Password CLI, `op`, for secret reads and writes. Do not manually copy/paste secret values into chat, docs, shell history, or Git.
- Never reveal passwords, tokens, private keys, tunnel credentials, or generated secret values in final answers. Confirm presence, key names, sync status, or item fields without printing values.
- Do not commit secrets, raw tunnel credentials, kubeconfigs, tokens, passwords, or sensitive service contracts.
- If a secret must be added, create/update the relevant 1Password item with `op` and wire it through an `ExternalSecret`.
- Prefer separate read-only credentials for observability integrations.
- Avoid hardcoding 1Password item names in public docs. Discover them from `ExternalSecret` manifests or ask the user.

Secret workflow:

1. Find existing pattern in `apps/**/external-secret*.yaml` or chart templates.
2. Add the field to the 1Password item.
3. Add/update the `ExternalSecret` mapping.
4. Verify the synced Kubernetes Secret exists and has the expected key count, without revealing values.
5. Verify the consuming pod gets the env/volume and works.

## Cilium And Network Policies

Cilium is the cluster CNI and policy engine. Treat it as the default networking/security layer for pod traffic, not as an ingress replacement by itself.

Default model:

- Prefer Kubernetes `NetworkPolicy` for ordinary namespace, pod, and port allow rules.
- Use `CiliumNetworkPolicy` only when the rule needs Cilium-specific features such as entities, L7 matching, FQDN policies, or node/API-server semantics.
- Keep policies in GitOps. Do not debug by permanently loosening live policies without committing the intended final rule.
- Start from deny-by-default for workload namespaces, then add explicit ingress and egress allows.
- Avoid broad `namespaceSelector: {}` / `podSelector: {}` rules unless the goal is deliberately namespace-wide.

Typical namespace policy stack:

1. `default-deny` with both `Ingress` and `Egress` selected.
2. DNS egress to the cluster DNS pods on TCP/UDP 53.
3. Same-namespace ingress only when app components need to talk to each other.
4. Same-namespace egress only when app components need local DB/cache/service calls.
5. Public HTTP ingress from the tunnel/edge namespace to the exact service port.
6. Metrics ingress from the monitoring namespace to exact metrics ports.
7. Read-only datasource ingress from Grafana/monitoring to the exact database port when needed.
8. Kubernetes API egress only for controllers, operators, jobs, or agents that actually call the API.
9. Internet egress only for apps that need outbound web/API access; avoid internal/private CIDR egress unless it is explicitly required.

Cloudflare Tunnel pattern:

- Public traffic enters through tunnel pods inside the cluster.
- Workload namespaces should allow ingress from the tunnel namespace/pods to only the service ports that are published.
- The workload should not need a broad ingress rule from the whole cluster or the internet.

Monitoring pattern:

- Prometheus gets ingress to scrape selected metrics endpoints.
- Grafana gets egress to datasources and the datasource namespace gets matching ingress from Grafana.
- Observability credentials should still be least-privilege; network access is not a substitute for read-only database users.

Cilium-specific policy pattern:

- Use `toEntities`/Cilium entities for targets that Kubernetes `NetworkPolicy` cannot express cleanly, such as `kube-apiserver`.
- Use Cilium L7/FQDN policies only when they reduce real risk. They add debugging complexity, so document why the policy is not a plain `NetworkPolicy`.
- Avoid mixing many overlapping `NetworkPolicy`, `CiliumNetworkPolicy`, and cluster-wide policies without checking the combined allow set.

New service checklist:

1. Identify every required traffic path: public ingress, internal app calls, DB/cache, secret store, metrics, Kubernetes API, and outbound internet.
2. Add the smallest policies matching those paths using stable labels such as namespace labels and `app.kubernetes.io/*` labels.
3. Render/apply through GitOps and wait for Argo reconciliation.
4. Verify from both ends: source pod can connect, unrelated pods cannot, app logs are clean, and dashboards/health checks still work.
5. If a policy blocks something unexpected, inspect pod labels and Cilium/Kubernetes policy state before widening selectors.

Useful checks:

```bash
KUBECONFIG=<homelab-gitops>/kubeconfig kubectl get networkpolicy -A
KUBECONFIG=<homelab-gitops>/kubeconfig kubectl get ciliumnetworkpolicy -A
KUBECONFIG=<homelab-gitops>/kubeconfig kubectl -n <namespace> get pods --show-labels
KUBECONFIG=<homelab-gitops>/kubeconfig kubectl -n <namespace> describe networkpolicy <policy>
```

If Cilium/Hubble tooling is available, use it to inspect drops and flows. If it is not available, fall back to pod logs, app errors, and targeted connectivity tests from temporary debug pods.

## Networking And Domains

Stable public hostnames should describe the purpose, not the implementation. Public-safe examples:

```text
<root-domain>                          dashboard/home portal
status.<root-domain>                   status monitoring
analytics.<root-domain>                analytics
git.<root-domain>                      Git hosting
argo.<root-domain>                     Argo CD
automations.<root-domain>              automation runner
grafana.<root-domain>                  Grafana
auth.<root-domain>                     shared auth service
<app-domain>                           production app
```

Do not expose the user's actual domain list unless it is already in the user's prompt or required for the task.

Cloudflare Tunnel is the main public ingress path. Prefer Git-managed Kubernetes ingress/router config where it exists, but keep sensitive tunnel credentials and private operational details out of Git.

For DNS/Cloudflare operations, use the modern official Cloudflare CLI `cf` when available. Do not use the old `cloudflare` CLI unless the user explicitly asks for it or the current machine only has that legacy tool installed. Clean up stale DNS records when replacing hostnames. Verify DNS and route behavior with real requests.

## Storage And Backups

- Current storage may use `local-path` PVCs on a Talos VM node.
- Treat `local-path` as node-bound storage: pod migration and snapshots are not automatic.
- `reclaimPolicy` should be `Retain` for stateful data.
- Be careful with Argo prune, PVC name changes, namespace moves, and chart renames.
- For namespace/storage migrations, dump/restore stateful DBs first and verify before deleting old PVs.
- A VM-level backup helps, but it is not a replacement for app/database-aware recovery plans.

## Charts And Apps

- Prefer official upstream Helm charts for mature apps.
- For simple single-container apps, local charts are OK.
- If raw manifests become non-trivial, move them into a chart.
- Keep disable/enable behavior explicit in values or Argo app config.
- Renovate should see image/chart versions in `apps/**` and `charts/**`.
- New services should include resource requests/limits and NetworkPolicy updates.

## Service Chart Boundary

Service repos and homelab GitOps have different jobs. Keep that boundary clear.

Service repos should build and publish generic artifacts:

- container images for the app's runtime components;
- a Helm chart that can run outside this homelab;
- values for generic inputs such as image tag, hostnames, ports, environment variables, existing Secret names, external database/cache/storage endpoints, resource settings, and feature toggles.

Service charts should not assume this homelab's infrastructure. Avoid putting these in service charts:

- 1Password item names or `ClusterSecretStore` assumptions;
- CloudNativePG `Cluster`, `ScheduledBackup`, restore, or backup S3 wiring;
- Cloudflare Tunnel rules, public DNS records, private domains, or tunnel credentials;
- homelab-specific NetworkPolicies, Cilium policies, StorageClasses, backup destinations, or private IPs;
- hardcoded local service names unless they are defaults that callers can override.

Homelab GitOps owns the deployment wiring:

- pinned chart/image versions;
- Argo `Application` values;
- `ExternalSecret` resources and mappings from 1Password;
- CNPG clusters, backup secrets, scheduled backups, restore procedures, and `Prune=false` guards for stateful migrations;
- Cloudflare/ingress routing, domains, NetworkPolicies, Cilium policies, PVC/storage choices, observability integrations, and backup destinations.

Preferred pattern for app databases:

1. The service chart accepts an external database host/port/name and an existing credentials Secret.
2. Homelab GitOps creates or references the actual database infrastructure.
3. Homelab GitOps creates the credentials Secret via `ExternalSecret`.
4. Homelab GitOps configures CNPG backup/restore if the database is CNPG.
5. The service chart only consumes the connection details.

When moving infrastructure out of a service chart, preserve stateful resources carefully:

- add the new homelab-owned manifests first;
- use `Prune=false` on stateful resources during ownership migration;
- verify Argo tracking moved to the intended app before deleting old chart templates;
- run a real backup or smoke check before calling the migration done.

Typical app workflow:

1. Add or update app/chart/manifests in Git.
2. Add `ExternalSecret` wiring for secrets.
3. Add NetworkPolicies for required ingress/egress.
4. Run `helm lint`, `helm template`, `kubectl apply --dry-run=server` where possible.
5. Commit and push to the GitOps branch.
6. Refresh Argo and verify `Synced/Healthy`.
7. Verify live pods, logs, routes, and real HTTP/API/database behavior.

## Monitoring And Analytics

Monitoring chart pattern:

```text
charts/monitoring
```

It may deploy Grafana, Grafana MCP, kube-prometheus-stack, dashboards, and datasources.

Rules:

- Prometheus should usually remain internal-only. Do not expose it publicly unless explicitly asked.
- Grafana may be public behind the configured ingress/tunnel.
- Grafana MCP is intended for AI-assisted dashboard/query work.
- Dashboards should be useful for AI inspection: clear labels, useful units, current filters, and no mixed-service ambiguity.
- For analytics, split by project/hostname. Avoid dashboards that mix unrelated apps by default.

Analytics datasource pattern:

- Use read-only datasource credentials for analytics and observability.
- Keep a dashboard-level `Host`, `Project`, or equivalent tenant selector so metrics do not mix unrelated apps.
- If a provisioned datasource fails despite valid credentials, inspect datasource/plugin logs before widening permissions. Some plugins require narrowly scoped read-only compatibility settings.
- If derived fields depend on auxiliary database objects such as dictionaries, views, schemas, or functions, the reader may need explicit read access to those objects.

When building analytics dashboards for AI:

- Include traffic over time, top pages, sources/referrers, custom events, countries, devices/browsers, campaigns, and recent activity when the data source supports them.
- Make filters explicit and visible.
- Validate queries directly against the backing database and then validate through the dashboard tool when possible.
- Do not rely only on `Synced/Healthy`; check that panels return data.

## Empirical Lessons

These are recurring lessons from this homelab. Keep them generic in public docs, but apply them concretely from local repo/live state.

- If pods stay Pending on a single-node Talos control plane, check whether scheduling on control-plane nodes is intentionally enabled before debugging the app.
- If `kubectl` output does not match the expected cluster, assume the shell may be using the wrong context. Export the repo-local kubeconfig explicitly before continuing.
- If Argo shows an old image or old app state right after refresh, wait for reconciliation and verify the Deployment spec, rollout status, and live HTTP/API behavior.
- A release bump is not complete at commit time. Verify source release, image/tag existence, chart render, Argo sync, deployed image, pod readiness, logs, and a real app response.
- For apps with `local-path` storage, deletion is a two-part operation: remove GitOps/Argo resources and separately inspect retained PVs/data before deleting disk state.
- Teardown means more than disabling an app. Check GitOps manifests, Argo apps, network policies, public DNS/tunnel routing, secrets, and retained volumes.
- Kubernetes UI or admin access tokens should be generated on demand with short practical durations; do not store long-lived cluster tokens in Git.
- Renovate only updates what it can see. When adding local charts, ensure image tags and chart versions live in files matched by Renovate.
- Derived restart or incident metrics can be rounded, delayed, or fractional depending on the query. For incident truth, check raw counters, last termination reason, timestamps, logs, and resource usage.
- Dashboard provisioning can look correct while panels still fail. Check plugin installation, datasource provisioning, mounted dashboard files, and query logs.
- Provisioned datasources can require narrowly scoped read-only compatibility settings; check datasource/plugin logs before widening permissions, and keep write access blocked.
- Analytics dashboards must have an explicit project/host selector. Mixed-project analytics produces misleading output for both humans and AI.
- If a dashboard is backed by a ConfigMap or mounted file, verify both the Kubernetes object and the file mounted inside the consuming pod.
- If Cloudflare/DNS changes were part of the task, verify public route behavior and clean stale records.
- If External Secrets are involved, verify `SecretSynced=True`, expected keys exist, and consuming pods actually receive the updated values.

## Argo/GitOps Gotchas

- `homelab-root` is the root app; refresh it after changing app lists or shared infra.
- Workload apps may also need a direct refresh.
- Argo `Synced/Healthy` is necessary but not sufficient. Verify runtime behavior.
- Avoid manual Argo UI changes; if manual apply is needed to unblock bootstrap, make Git match and document why.
- If dashboards are provisioned from ConfigMaps or mounted files, check both the Kubernetes object and the mounted file inside the pod.
- If a chart deploys a plugin, datasource, or dashboard, verify the plugin is installed, the datasource is provisioned, and logs show no query errors.

## Proxmox/Talos Notes

- Talos has no traditional mutable Linux install flow; machine config and Kubernetes are the main operating surface.
- Proxmox access may exist through MCP or SSH, but verify live availability before assuming.
- Be careful resizing memory/disks or stopping legacy VMs; check current services first.
