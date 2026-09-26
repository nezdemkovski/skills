---
name: homelab
description: >
  Operate the user's Talos/Proxmox Kubernetes homelab and its Flux GitOps repository. Use for homelab workloads, Flux, legacy Argo CD, Cilium/network policies, 1Password and External Secrets, Cloudflare Tunnel, storage, observability, and homelab domains.
---

# Homelab

Use the current private GitOps repository and live cluster as the source of truth. Keep this skill public-safe: discover domains, secret item names, cluster addresses, and local paths instead of copying them into the skill.

## Start with the current state

Locate the GitOps repository (usually `~/Sites/homelab-gitops`) and read its `AGENTS.md` before editing. Check branch, dirty state, and the relevant manifests. The current repository uses `master` and Flux; `clusters/homelab/flux-system` bootstraps the cluster and `clusters/homelab/*.yaml` declares component `Kustomization` objects. Application resources are in `apps/<app>/`, shared controllers and policies in `infrastructure/<component>/`, and local charts in `charts/`. Verify this layout again when working in the repo.

The user's main kubeconfig has context `admin@homelab`; another context may be active. Select it explicitly for homelab commands with `kubectl --context admin@homelab`, or use the ignored repo-local `kubeconfig` through `KUBECONFIG=<repo>/kubeconfig`. The ignored `talosconfig` is similarly available locally. Both files are also backed up as attachments in the Homelab 1Password vault. Never print their contents or commit them. Do not change the user's global current context just to run a check.

```bash
kubectl --context admin@homelab get nodes
flux --context admin@homelab get kustomizations -A
flux --context admin@homelab get helmreleases -A
```

The Flux CLI is installed. Prefer it to generate Flux manifests when possible; commit its output to Git. `flux install` and `flux bootstrap` are installation/bootstrap operations, not routine workload deployment commands. Check the existing controllers, Git source, and repository instructions before using them.

Argo CD may still be present for historical or transitional work, but do not assume it owns a resource. Check live ownership before touching Argo or pruning old resources. Do not remove Argo as part of unrelated Flux work. The old `scripts/argo-app-status.sh` is only for confirmed Argo-managed applications.

## GitOps workflow

1. Inspect the relevant Git path and live Flux resource. Use `flux get sources git`, `flux get kustomizations`, `flux get helmreleases`, and `flux logs` for diagnostics.
2. Make durable changes in Git. Keep a separate Flux `Kustomization` for an independently operated app/component and use `spec.dependsOn` for ordering.
3. Pin chart versions, OCI tags, and image tags. The repo's Renovate configuration proposes dependency updates; Flux reconciles the versions committed to Git.
4. Render the affected path before pushing, using the exact resource name and file:

   ```bash
   flux build kustomization <name> --path ./clusters/homelab \
     --kustomization-file ./clusters/homelab/<name>.yaml
   git diff --check
   ```

5. After pushing, reconcile and check the reported revision and Ready condition. Then verify the real workload, not only the controller status:

   ```bash
   flux reconcile source git flux-system
   flux reconcile kustomization <name> --with-source
   flux get kustomizations
   flux get helmreleases -A
   kubectl --context admin@homelab -n <namespace> get pods,svc
   ```

Use the repo's current `AGENTS.md` for any additional validation and commit rules. Avoid long-lived manual cluster changes; when a bootstrap exception is necessary, bring Git into agreement. Keep `flux suspend` limited to a maintenance window and resume afterward.

For public workloads, read [references/public-workload-rollout.md](references/public-workload-rollout.md). It covers storage, policies, tunnel/DNS routing, and endpoint verification.

## Secrets and access

- Runtime secrets are in the Homelab 1Password vault and reach the cluster via External Secrets Operator and the `onepassword` `ClusterSecretStore`. Commit `ExternalSecret` references, never secret values or generated Kubernetes Secrets.
- Use the official `op` CLI for 1Password. Check the active account/session; use `op signin` if needed. Do not put secret values in chat, Git, docs, or shell command arguments. Verify item fields and `ExternalSecret` Ready status without printing values.
- The repo-local kubeconfig and talosconfig are sensitive local credentials. Their 1Password attachments are backups, not Kubernetes runtime secrets. Do not wire them into External Secrets.
- Generate admin/UI tokens on demand with short practical durations. Prefer separate read-only credentials for observability.

## Network, DNS, and storage

Cilium enforces Kubernetes and Cilium network policies. Workload namespaces are deny-by-default. Prefer plain `NetworkPolicy` for pod/namespace/port rules; use `CiliumNetworkPolicy` only for Cilium-specific selectors, entities, FQDN, or L7. Account for DNS, same-namespace calls, databases, Kubernetes API, monitoring, backup traffic, and tunnel ingress. Validate both the intended connection and isolation before widening a policy.

Cloudflare Tunnel is the public ingress path. Its Git-managed routes live in the local cloudflared chart values; rendered Service names/ports and live endpoints are authoritative. The current chart rolls tunnel pods when its ConfigMap changes via a pod-template checksum, so verify the rollout rather than assuming a separate revision bump is needed. Use the configured official Cloudflare CLI for DNS changes and verify authoritative and local DNS plus the public HTTP response.

Treat `local-path` PVCs as node-bound. Check PV/PVC binding and a restorable backup before renaming, moving, or removing stateful resources. The repo protects namespaces, PVCs, and database clusters with Flux prune-disabled annotations where needed, and storage reclaim policy should be `Retain`. Moving an app between controllers or namespaces requires separate data extraction, restore, reconciliation, and runtime checks before removing the old owner.

## Service boundary and verification

Service repositories publish portable images/charts. Homelab GitOps owns local deployment wiring: `HelmRelease`/`Kustomization`, pinned versions, `ExternalSecret`, database and backup resources, Cloudflare routes, policies, and storage. Avoid embedding this homelab's domains, secret item names, or storage choices in a portable service chart.

For releases, verify the source tag/image exists, the manifest renders, Flux reports the expected revision and Ready status, pods use the intended image, logs are clean, and a real request works. For monitoring and analytics, also confirm datasources and panels return data. For secret changes, confirm `ExternalSecret` Ready status and the consumer rollout without reading Secret values.

Report Git committed/pushed, Flux reconciled, runtime ready, and public route verified as separate states. If a resource is actually Argo-managed, use its own reconciliation and status checks instead of Flux commands.
