---
name: homelab
description: >
  Operate the user's Talos/Proxmox homelab and Flux GitOps repository: workloads, deployment issues, network policies, storage, 1Password/External Secrets, public routes and Talos maintenance.
---

# Homelab

## Environment and access

- GitOps repo: `~/Sites/homelab-gitops`. Read its `AGENTS.md`, branch and working-tree state before changes. Git and the live cluster are authoritative; discover service names, addresses and versions there.
- `master` is the source of truth. Flux is the only deployment reconciler. Bootstrap: `clusters/homelab/flux-system`; component definitions: `clusters/homelab/*.yaml`; workloads: `apps/<app>`; shared services: `infrastructure/<component>`; local charts: `charts/`.
- Kubernetes: global `~/.kube/config`, context `admin@homelab`. Talos: global `~/.talos/config`, context `homelab`. Use explicit contexts; keep files `0600`, outside the repo, and preserve other contexts when restoring. Check `KUBECONFIG`/`TALOSCONFIG` overrides if access differs from expectations.
- Recovery config attachments are in the Homelab 1Password vault. Never print or commit credentials. Use `op`; pass secret values through stdin or restricted temporary files, not command arguments. Remove temporary credential copies afterward.

```bash
kubectl --context admin@homelab get nodes
flux --context admin@homelab get kustomizations -A
flux --context admin@homelab get helmreleases -A
```

Read only the reference needed for the task:

- [1Password records](references/onepassword.md): creating, editing, consolidating or restoring vault items and changing ExternalSecret mappings.
- [Public workloads](references/public-workload-rollout.md): exposing a service, changing tunnel/DNS routes or diagnosing public access.
- [Talos upgrades](references/talos-upgrades.md): updating or recovering the node OS. Kubernetes upgrades are a separate operation.

## GitOps changes

1. Inspect the owning Kustomization/HelmRelease and its Git path. Use `flux --context admin@homelab get sources git` and `flux --context admin@homelab logs` for deployment diagnostics.
2. Put durable changes in Git. Keep one Kustomization per independently operated component, with `spec.dependsOn` for ordering. Prefer `flux create ... --export` for new Flux resources; use the existing installation rather than re-bootstrap it.
3. Pin exact versions and keep image registry/repository beside the tag. Follow `AGENTS.md` for Renovate, dependency review, merge gates and backup requirements.
4. Render from the repo root, setting `<manifest-path>` to the selected Kustomization's `spec.path`, not the directory holding its Flux definition:

   ```bash
   flux --context admin@homelab build kustomization <name> --path <manifest-path> \
     --kustomization-file ./clusters/homelab/<name>.yaml --dry-run --in-memory-build
   git diff --check
   ```

   Offline rendering skips Secret/ConfigMap-backed substitutions. A rendered HelmRelease is not a rendered chart: also render changed chart templates with the actual release name, namespace and values.

5. After publishing, reconcile and verify the expected Git revision:

   ```bash
   flux --context admin@homelab reconcile source git flux-system
   flux --context admin@homelab reconcile kustomization <name> --with-source
   ```

   Check the affected Kustomization/HelmRelease Ready conditions, workloads and the service's real behavior. For monitoring, verify data queries; for changed secrets, verify a fresh ExternalSecret sync and application reload. Unchanged consumer Secret data needs no restart.

Report committed/pushed, reconciled, runtime ready and endpoint verification as separate facts. Limit suspension to a bounded maintenance window, resume afterward, and record durable live changes in Git.

## Operational boundaries

- **Secrets:** Homelab vault → 1Password Connect → ESO `onepassword` ClusterSecretStore. Git stores ExternalSecret references only. One Secure Note per service, no tags; use the reference for field conventions. Keep CI credentials in their owning GitHub repository secrets.
- **Network:** Cilium enforces deny-by-default workload policies. Add only required DNS/API, app, database, backup, monitoring and tunnel traffic. Use ordinary NetworkPolicy for pod/namespace/port rules; CiliumNetworkPolicy for Cilium-specific features. Public egress excludes private ranges; LAN dependencies need a documented service-specific rule. Verify affected connections after shared-policy changes.
- **Data:** `local-path` volumes are node-bound. Before removing, renaming or moving stateful resources, inspect PVC/PV bindings and verify an off-node restorable backup. Preserve prune-disabled namespaces/PVCs/CNPG Clusters and `Retain` reclaim policies. Never reset an app by deleting its namespace.
- **Ownership:** Product repos publish portable images/charts. This repo owns homelab deployment wiring, secrets references, databases/backups, policies, routes and storage. Keep local domains and deployment choices out of portable charts.

Keep this reusable skill free of private addresses, secret values and copied inventory; deployment-specific details belong in the private GitOps repo.
