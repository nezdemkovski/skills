# Public workloads

Use the main skill's GitOps workflow. Discover service names, hostnames and tunnel identifiers from Git/live state.

## Deployment wiring

- Keep hostnames stable and named for the service. Cloudflare ingress routes are in `charts/cloudflared/values.yaml`; point them at the rendered Service FQDN and port.
- Include required tunnel egress, workload ingress, DNS, database and backup traffic in the policies. Follow `AGENTS.md` for persistent data protections and backups.
- Render changed charts with actual release name, namespace and values. Inspect Service names/ports, selectors, probes, resources, hooks and PVC references; do not infer them from the app name.
- After publishing/reconciling, verify the tunnel pod rolls when its config checksum changes. Re-check the template if rollout behavior differs.

## DNS and CLI choice

- `cf` and `cloudflare` are aliases for the same official Cloudflare API CLI. Use `cf` for zones and DNS records; check `cf auth whoami` and the intended account/zone before writes. Its authentication is separate from tunnel credentials.
- `cloudflared` runs and diagnoses Cloudflare Tunnel. Its `tunnel route dns` convenience command can create a tunnel CNAME, but use `cf` for normal DNS management. Keep this homelab's ingress routes in Git, not a second dashboard-managed configuration.
- A public hostname needs both a proxied DNS CNAME to `<tunnel-id>.cfargotunnel.com` and a matching ingress route in `charts/cloudflared/values.yaml`. Read the tunnel ID from the current chart values. Neither side creates the other automatically in this setup.
- Inspect the existing record before creating/updating it; preserve unrelated records. Discover current CLI syntax with anonymous task descriptions, then inspect the selected command's help:

  ```bash
  cf cli search "list and create DNS records"
  cf dns records list --zone <zone> --name <hostname>
  ```

  Keep private names, domains, IDs and credentials out of discovery queries. After a DNS change, verify authoritative/local resolution and the public route. Proxied DNS normally returns Cloudflare edge addresses, so use the API to inspect the underlying CNAME target.

See [CLI aliases and authentication](https://developers.cloudflare.com/cf/get-started/) and [Tunnel DNS](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/routing-to-tunnel/dns/) for current behavior.

## Verification and diagnosis

Check Ready conditions, pods, PVCs, fresh ExternalSecret sync, ready EndpointSlice backends, tunnel routing and an internal/public request. An unauthenticated `401` proves protected-route reachability, not upstream health. Do not retrieve/send credentials merely to turn a smoke test green.

For public `502` responses, inspect fresh cloudflared logs: `no such host` indicates Service/DNS naming; `connection refused` indicates ports, listeners or backends; timeouts suggest routing or policies. If config is correct but behavior is old, check the rollout.

Report deployment readiness, DNS changes and public endpoint verification separately.
