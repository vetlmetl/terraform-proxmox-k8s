# ─── Network design: VIP + reserved (MAC-pinned) node IPs ───────────────────
# Predictable node IPs come from fixed MAC addresses + matching DHCP
# reservations on the router. Nodes stay on DHCP, which is robust with the
# module's guest-agent IP discovery (setting dhcp:false in Talos fights it and
# can strand a node). A shared Talos VIP provides an HA Kubernetes API endpoint.
#
# Before `terraform apply`, on the router/DHCP server:
#   - exclude 192.168.88.200–.220 from the DHCP dynamic pool
#   - add static DHCP mappings: each MAC below -> its IP (.201–.206)
#   - leave 192.168.88.200 free (managed by Talos as the floating VIP)

locals {
  cluster_vip = "192.168.88.200"

  # Subnet the nodes (and the VIP) live on; passed to the module so it can select
  # each node's primary IP by subnet match rather than a fixed interface index.
  node_ipv4_cidr = "192.168.88.0/24"

  # MAC last octet mirrors the IP last octet for an obvious reservation mapping.
  control_node_macs = {
    "test-control-0" = "bc:24:11:88:02:01" # -> 192.168.88.201
    "test-control-1" = "bc:24:11:88:02:02" # -> 192.168.88.202
    "test-control-2" = "bc:24:11:88:02:03" # -> 192.168.88.203
  }
  worker_node_macs = {
    "test-worker-0" = "bc:24:11:88:02:04" # -> 192.168.88.204
    "test-worker-1" = "bc:24:11:88:02:05" # -> 192.168.88.205
    "test-worker-2" = "bc:24:11:88:02:06" # -> 192.168.88.206
  }

  # Shared control-plane patch: install disk, the VIP (dhcp stays TRUE so the
  # node keeps its DHCP address), and the VIP in apiserver certSANs so the
  # serving cert is valid for the endpoint. DNS is left to DHCP.
  # NOTE: the install disk must be set here — passing this variable replaces the
  # module's default disk patch rather than merging with it.
  control_shared_patches = [
    yamlencode({
      machine = {
        install = { disk = "/dev/vda" }
        network = {
          interfaces = [{
            deviceSelector = { driver = "virtio_net" }
            dhcp           = true
            vip            = { ip = local.cluster_vip }
          }]
        }
      }
      cluster = {
        apiServer = { certSANs = [local.cluster_vip] }
      }
    })
  ]

  # Workers need no shared patch: the module's default already sets the install
  # disk (/dev/vda) and DNS comes from DHCP.
}
