# Public Workload Rollout

Read this for a new or changed public workload in the Flux homelab. Discover hostnames, tunnel identifiers, addresses, and secret item names from current Git/live state. Read the GitOps repo's `AGENTS.md` first.

## Inspect and build

1. Confirm the current branch, dirty state, target `clusters/homelab/<name>.yaml`, app path, dependencies, policies, cloudflared chart, storage, and Renovate patterns.
2. Check the active Kubernetes context. Use `kubectl --context admin@homelab` or the ignored repo-local kubeconfig; do not silently change the global context.
3. Generate Flux resources with `flux create ... --export` where supported. Keep the generated YAML in Git. Put the workload under `apps/<app>/` and its reconciling `Kustomization` under `clusters/homelab/`.
4. Pin the chart version, OCI tag, and images. Render the chart with the exact `HelmRelease` release name, namespace, and values. Inspect generated Service names, ports, labels, hooks, and PVC names rather than guessing.
5. Add resource settings, `ExternalSecret` mappings, deny-by-default and required network allows. For stateful resources, follow `AGENTS.md` prune-disabled annotation and backup rules before changing ownership or deleting anything.

Useful checks:

```bash
flux build kustomization <name> --path ./clusters/homelab \
  --kustomization-file ./clusters/homelab/<name>.yaml
helm lint <chart> -f <values>
helm template <release> <chart> --namespace <namespace> -f <values>
git diff --check
```

Use the checks relevant to the manifest type; do not run Helm commands for a raw Kustomize-only workload.

## Cloudflare and DNS

1. Point the tunnel ingress rule at the rendered Service FQDN and port. Add corresponding cloudflared egress and workload ingress policies.
2. Commit and push the Git change. Reconcile the relevant Flux source/Kustomizations/HelmReleases, then verify cloudflared pods rolled to the new ConfigMap checksum. The current chart handles this automatically; re-check the template if it changes.
3. Create or update DNS with the configured official CLI, using the discovered tunnel. Verify authoritative and local DNS and the HTTPS response.

For a public `502`, inspect fresh cloudflared logs: `no such host` points to the Service name; `connection refused` to Service port/endpoints/readiness; timeout to routing or policies. If the ConfigMap is correct but behavior is old, inspect the pod rollout.

## Verify the result

Before calling the deployment complete, check the expected Git revision is reconciled and Flux resources are Ready; required pods are ready; PVCs are bound; `ExternalSecret` reports Ready; EndpointSlices have ready backends; cloudflared has the route; authoritative and local DNS resolve; and an internal and public request reach the intended service.

An unauthenticated `401` can prove route reachability for a protected endpoint, but verify upstream health separately. Do not retrieve credentials solely for a smoke test or send them to a public endpoint without authorization for that destination.

Report committed, pushed, Flux reconciled, runtime ready, DNS created, and public endpoint verified separately. If the workload is actually still Argo-managed, follow its live ownership and reconciliation model instead.
