# ─── Persistent storage (CSI) ───────────────────────────────────────────────
# Two storage layers, one per physical tier of host `small`:
#   - Longhorn  -> default `longhorn` StorageClass: fast, replicated (x2) RWO
#     block on the local SSD. Requires the iscsi-tools/util-linux-tools image
#     extensions (baked into talos_schematic_id) and the kubelet mount below.
#   - csi-driver-nfs -> `nfs` StorageClass: big-capacity RWX/bulk on the 2 TB
#     NFS share. No image extension needed (in-kernel NFS client).
#
# Both drivers are vendored, pinned manifests under manifests/ and applied as
# Talos cluster inlineManifests (same pattern as metrics_server.tf). The
# env-specific NFS StorageClass is generated here so server/share come from
# variables rather than a vendored file.

locals {
  # Worker machine config. Overriding worker_machine_config_patches REPLACES the
  # module default (which only sets the install disk), so re-include the install
  # disk here — same gotcha as control_shared_patches in cluster_network.tf.
  # The extraMounts bind is Longhorn's data-path requirement on Talos.
  worker_machine_config_patches = [
    yamlencode({
      machine = {
        install = { disk = "/dev/vda" }
        kubelet = {
          extraMounts = [{
            destination = "/var/lib/longhorn"
            type        = "bind"
            source      = "/var/lib/longhorn"
            options     = ["bind", "rshared", "rw"]
          }]
        }
      }
    })
  ]

  # Cluster-level storage add-ons, concat'd onto the control-plane patches in
  # main.tf. inlineManifests are cluster-scoped, so they live on control nodes.
  storage_addon_patches = [
    yamlencode({
      cluster = {
        inlineManifests = [
          {
            name     = "longhorn"
            contents = file("${path.module}/manifests/longhorn.yaml")
          },
          {
            name     = "csi-driver-nfs"
            contents = file("${path.module}/manifests/csi-driver-nfs.yaml")
          },
          {
            # `nfs` StorageClass for csi-driver-nfs, parameterized by the NFS
            # export. Not marked default — Longhorn is the default class.
            name = "csi-driver-nfs-storageclass"
            contents = yamlencode({
              apiVersion  = "storage.k8s.io/v1"
              kind        = "StorageClass"
              metadata    = { name = "nfs" }
              provisioner = "nfs.csi.k8s.io"
              parameters = {
                server = var.nfs_server
                share  = var.nfs_share
                # chmod each provisioned subdir 0777 so non-root pods can write
                # (NFS ignores fsGroup; without this a runAsNonRoot workload hits
                # permission-denied on the root-owned 0755 dir the driver creates).
                mountPermissions = "0777"
              }
              reclaimPolicy     = "Delete"
              volumeBindingMode = "Immediate"
              mountOptions      = ["nfsvers=4.1"]
            })
          },
        ]
      }
    })
  ]
}
