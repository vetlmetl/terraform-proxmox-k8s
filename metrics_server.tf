# ─── Cluster add-ons: metrics-server ────────────────────────────────────────
# Installed declaratively via a Talos inlineManifest so `kubectl top` and the
# Lens node/pod metrics bars work. The manifest is a pinned, vendored copy of
# the upstream metrics-server release with `--kubelet-insecure-tls` added
# (Talos kubelets serve self-signed certs). See manifests/metrics-server.yaml.
#
# This is a separate control-plane config patch, concat'd onto the network
# patch in main.tf. Talos merges the list in order, so the two stay decoupled.
# inlineManifests are cluster-level, so they only go on control nodes.

locals {
  cluster_addon_patches = [
    yamlencode({
      cluster = {
        inlineManifests = [{
          name     = "metrics-server"
          contents = file("${path.module}/manifests/metrics-server.yaml")
        }]
      }
    })
  ]
}
