# Talos OS upgrades

Talos OS updates use `talosctl`; Flux/Renovate manage GitOps dependencies. Keep Kubernetes upgrades separate from OS upgrades.

1. Read target release notes and the current [upgrade guide](https://docs.siderolabs.com/talos/latest/configure-your-talos-cluster/lifecycle-management/upgrading-talos). Check Kubernetes compatibility and the supported minor-version path; discover versions instead of copying a previous target.
2. Inspect the live node before choosing the image:

   ```bash
   talosctl --context homelab version
   talosctl --context homelab get extensions
   talosctl --context homelab etcd status
   kubectl --context admin@homelab get nodes -o wide
   kubectl --context admin@homelab get pdb -A
   ```

3. Verify a restorable off-node backup. An etcd snapshot does not cover application volumes. If the user has already confirmed Proxmox VM backups suffice for this operation, use that confirmation without requesting it again.
4. Select an Image Factory installer matching target version, architecture, boot mode and the existing schematic/extensions. Discover the running schematic from extension metadata; do not replace a customized recipe with the empty schematic. Check target release instructions for the installer image format.
5. Explain the reboot outage on a single-node cluster. If its singleton PDBs prevent eviction and the outage is authorized, use `--drain=false`. Otherwise normally drain, upgrading multi-node clusters one node at a time. Inspect installed CLI help before running:

   ```bash
   talosctl --context homelab -n <node-ip> upgrade \
     --image <verified-installer-image> --progress plain --timeout 15m
   ```

   Add `--drain=false` only for the verified maintenance case above. Monitor through reboot and recovery.
6. Verify running OS version, `talosctl --context homelab health --wait-timeout 5m`, node Ready, etcd, deployments/StatefulSets/CNPG, DNS/networking, Flux/Helm readiness and representative public routes. Report OS and Kubernetes versions separately; installer completion alone is insufficient.

If recovery fails, inspect Talos services, kubelet logs and Kubernetes events. Check release/data compatibility before `talosctl --context homelab rollback`. Update Git OS provisioning pins only if this repo owns them. Do not print machine configuration while discovering image parameters.
