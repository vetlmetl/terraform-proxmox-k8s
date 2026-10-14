# ─── Network design: VIP + reserved (MAC-pinned) node IPs ───────────────────
# Predictable node IPs come from fixed MAC addresses + matching DHCP
# reservations on the router. Nodes stay on DHCP, which is robust with the
# module's guest-agent IP discovery (setting dhcp:false in Talos fights it and
# can strand a node). A shared Talos VIP provides an HA Kubernetes API endpoint.
#
# The nodes live on the servers VLAN (20). Their NICs are tagged by Proxmox via
# network_vlan_id, so the VLAN is a VM setting here, not something Talos knows
# about.
#
# Before `terraform apply`, on the router/DHCP server:
#   - exclude 10.10.20.200–.220 from the VLAN 20 DHCP dynamic pool
#   - add static DHCP mappings: each MAC below -> its IP (.201–.206)
#   - leave 10.10.20.200 free (managed by Talos as the floating VIP)
#   - hand out 10.10.20.1 for DNS and NTP (the nodes take both from DHCP)

locals {
  cluster_vip = "10.10.20.200"

  # Subnet the nodes (and the VIP) live on; passed to the module so it can select
  # each node's primary IP by subnet match rather than a fixed interface index.
  node_ipv4_cidr = "10.10.20.0/24"

  # MAC last octet mirrors the IP last octet for an obvious reservation mapping.
  #
  # The keys MUST match the keys of control_nodes / worker_nodes in
  # terraform.tfvars. The module looks the MAC up by node name and falls back to
  # null, so a typo here doesn't fail the plan — the VM just gets a random MAC,
  # misses its DHCP reservation, and lands on a dynamic address.
  control_node_macs = {
    "devops-control-0" = "bc:24:11:88:02:01" # -> 10.10.20.201
    "devops-control-1" = "bc:24:11:88:02:02" # -> 10.10.20.202
    "devops-control-2" = "bc:24:11:88:02:03" # -> 10.10.20.203
  }
  worker_node_macs = {
    "devops-worker-0" = "bc:24:11:88:02:04" # -> 10.10.20.204
    "devops-worker-1" = "bc:24:11:88:02:05" # -> 10.10.20.205
    "devops-worker-2" = "bc:24:11:88:02:06" # -> 10.10.20.206
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
