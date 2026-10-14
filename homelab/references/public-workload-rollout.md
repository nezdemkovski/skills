# Public workloads

Use the main skill's GitOps workflow. Discover service names, hostnames and tunnel identifiers from Git/live state.

## Deployment wiring

- Keep hostnames stable and named for the service. Cloudflare ingress routes are in `charts/cloudflared/values.yaml`; point them at the rendered Service FQDN and port.
- Include required tunnel egress, workload ingress, DNS, database and backup traffic in the policies. Follow `AGENTS.md` for persistent data protections and backups.
- Render changed charts with actual release name, namespace and values. Inspect Service names/ports, selectors, probes, resources, hooks and PVC references; do not infer them from the app name.
- After publishing/reconciling, verify the tunnel pod rolls when its config checksum changes. Re-check the template if rollout behavior differs.
- Use the configured official Cloudflare CLI for requested DNS changes; verify authoritative and local resolution.

## Verification and diagnosis

Check Ready conditions, pods, PVCs, fresh ExternalSecret sync, ready EndpointSlice backends, tunnel routing and an internal/public request. An unauthenticated `401` proves protected-route reachability, not upstream health. Do not retrieve/send credentials merely to turn a smoke test green.

For public `502` responses, inspect fresh cloudflared logs: `no such host` indicates Service/DNS naming; `connection refused` indicates ports, listeners or backends; timeouts suggest routing or policies. If config is correct but behavior is old, check the rollout.

Report deployment readiness, DNS changes and public endpoint verification separately.
