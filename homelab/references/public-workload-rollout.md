# Public Workload Rollout

Use this runbook when adding or changing an Argo-managed workload exposed
through Cloudflare Tunnel. Keep all examples public-safe: discover repositories,
hostnames, tunnel identifiers, Secret item names, and private addresses from the
current Git/live state.

## 1. Establish The Operating Surface

1. Work from the GitOps repo and read its `AGENTS.md`.
2. Use `<gitops-repo>/kubeconfig`; do not rely on or mutate the global context.
3. Connect over the local LAN. Do not start Tailscale/VPN or use browser
   automation for Argo or 1Password unless the user explicitly requests it.
4. Use `op` CLI only. Check the existing session before signing in again, and
   never print or persist secret values.
5. Inspect the current Git branch, dirty state, AppProject, workload patterns,
   network policies, Cloudflare chart, storage class, and Renovate rules.

If `kubectl` reports `no route to host` while `ping`, `nc`, or HTTPS to the same
API endpoint succeeds, suspect a local binary/macOS Local Network permission
problem before changing the network. Use `scripts/argo-app-status.sh` for a
narrow read-only status check. Do not retrieve `argocd-initial-admin-secret` or
mint an Argo admin session without explicit approval.

## 2. Stage AppProject Changes

When a new namespace or external chart repository is not yet permitted:

1. Change only the canonical AppProject and any required bootstrap mirror.
2. Commit and push that allowlist change separately.
3. Hard-refresh `homelab-root` through CLI/API.
4. Wait until the root Application is `Synced/Healthy` at that commit.
5. Only then commit workload resources.

Never combine the allowlist and first workload commit when repo instructions
require two phases. Argo evaluates destination/repository permissions before it
can create the child Application.

## 3. Build And Render The Workload

- Pin the chart version and every configurable image tag. Avoid `latest` and
  floating external revisions.
- Render with the exact Argo `releaseName`, namespace, and values. Treat rendered
  Service names, ports, labels, hooks, and PVC names as authoritative.
- Do not guess a Service FQDN from the chart name. Helm fullname helpers often
  prepend both release and chart names.
- Inspect test hooks too. If an external chart's tests use unpinned or unsuitable
  images, use Argo's supported Helm test-skip option only after documenting why.
- Add resources, persistence, Renovate coverage, and `Prune=false` guards where
  loss of state would be unacceptable.
- Create the 1Password item through `op` without displaying generated values;
  map it through `ExternalSecret` and verify `Ready=True/SecretSynced` rather
  than reading the resulting Secret data.
- Add deny-by-default, DNS, same-namespace, required internet egress, and the
  exact tunnel ingress rule. Verify rendered/live pod labels before writing
  selectors.

Run at minimum:

```bash
git diff --check
helm lint <chart-or-package> -f <values>
helm template <release> <chart-or-package> --namespace <namespace> -f <values>
```

## 4. Wire Cloudflare Tunnel And DNS

1. Point the tunnel rule at the rendered Kubernetes Service FQDN and port.
2. Allow cloudflared egress to the workload namespace and matching workload
   ingress from the tunnel pods.
3. Bump the Cloudflare chart's explicit `configRevision` whenever its ConfigMap
   changes; cloudflared reads ingress rules at startup.
4. Commit, push, refresh root and child Applications, and wait for new
   cloudflared pods before testing the route.
5. Create the DNS route with the configured official CLI. For an existing named
   tunnel, `cloudflared tunnel route dns <discovered-tunnel> <hostname>` is the
   appropriate operation.
6. Verify authoritative DNS (for example `dig @1.1.1.1`) and the local resolver.
   If only the local resolver has a negative cache, use `curl --resolve` against
   the authoritative edge IP for diagnosis; do not change DNS again.

For public `502` responses, read the fresh cloudflared logs:

- `no such host`: the Service FQDN is wrong or stale;
- `connection refused`: the Service port/target or workload readiness is wrong;
- timeout: inspect NetworkPolicies, endpoints, and routing;
- correct ConfigMap but old behavior: tunnel pods probably did not roll.

## 5. Verify Without Exposing Secrets

Require all of these before calling the deployment complete:

- root and child Applications are `Synced/Healthy` at the expected revisions;
- all required pods are ready and PVCs are bound;
- `ExternalSecret` reports `Ready=True/SecretSynced`;
- Service EndpointSlices contain ready endpoints;
- cloudflared pods are from the expected rollout and logs show the new route;
- authoritative and local DNS resolve;
- a public request reaches the intended gateway/application;
- an internal health request succeeds.

An unauthenticated `401` can be the correct public result for an API-key or
Basic-Auth protected route: it proves DNS, Cloudflare, tunnel, Service, and
gateway reachability. Verify the upstream health separately through a
non-secret health route or Kubernetes pod/service proxy. Do not read credentials
from 1Password merely for a smoke test or transmit them to a public endpoint
without explicit authorization for those exact credentials and destination.

Report committed, pushed, Argo-synced, runtime-ready, DNS-created, and publicly
verified states separately. Include any remaining limitation instead of treating
`Synced/Healthy` as sufficient.
