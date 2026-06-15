# Kubernetes based on Talos on Proxmox via terraform 

Terraform configuration that provisions a highly available [Talos
Linux](https://www.talos.dev/) Kubernetes cluster on Proxmox VE, built on the
[`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox) and
[`siderolabs/talos`](https://registry.terraform.io/providers/siderolabs/talos)
providers.

The cluster runs in a home lab: Proxmox sits behind an OPNsense firewall with a
public IP, and the cluster is intended to host and expose small projects to the
internet.

## Architecture

- **3 control plane + 3 worker** VMs (etcd quorum, HA control plane).
- **HA API endpoint via a shared Talos VIP** (`192.168.88.200`). The Kubernetes
  API is reached through the floating VIP, not a single node, so losing the VIP
  holder does not take down API access.
- **Predictable node IPs** via fixed MAC addresses + OPNsense DHCP reservations.
  Nodes stay on DHCP (which keeps the module's guest-agent IP discovery stable);
  the reservations pin each MAC to a fixed address.
- **Remote state** on an S3-compatible object store with native locking and
  encryption.
- **Forked module** — the cluster consumes a local fork of
  [`bbtechsys/talos/proxmox`](https://registry.terraform.io/modules/bbtechsys/talos/proxmox)
  at `../git/terraform-proxmox-talos`, which adds a configurable
  `cluster_endpoint` (the change that enables the VIP). See [Module fork](#module-fork).

### Network layout

| Role      | VM name        | IP               | MAC                 |
| --------- | -------------- | ---------------- | ------------------- |
| VIP (API) | —              | `192.168.88.200` | managed by Talos    |
| control-0 | test-control-0 | `192.168.88.201` | `bc:24:11:88:02:01` |
| control-1 | test-control-1 | `192.168.88.202` | `bc:24:11:88:02:02` |
| control-2 | test-control-2 | `192.168.88.203` | `bc:24:11:88:02:03` |
| worker-0  | test-worker-0  | `192.168.88.204` | `bc:24:11:88:02:04` |
| worker-1  | test-worker-1  | `192.168.88.205` | `bc:24:11:88:02:05` |
| worker-2  | test-worker-2  | `192.168.88.206` | `bc:24:11:88:02:06` |

VM names are the keys of `control_nodes` / `worker_nodes` in `terraform.tfvars`;
Talos assigns its own node hostnames. Gateway `192.168.88.1`, DNS
`192.168.88.101`. Adjust in `cluster_network.tf`.

## Repository layout

| File                 | Purpose                                                                 |
| -------------------- | ----------------------------------------------------------------------- |
| `main.tf`            | Providers, S3 backend, and the Talos module call.                       |
| `variables.tf`       | Input variables with validation.                                        |
| `cluster_network.tf` | VIP, node MAC/IP maps, and the Talos config patches (DNS, VIP, certSANs).|
| `terraform.tfvars`   | Environment-specific values. **Gitignored** (see below).                |
| `backend.hcl`        | Partial backend config (bucket name). **Gitignored.**                   |
| `backend.hcl.example`| Template for `backend.hcl`.                                             |

`terraform.tfvars`, `backend.hcl`, all `*.tfstate`, and `.terraform/` are
gitignored — they hold secrets or infrastructure detail.

## Prerequisites

- Terraform **>= 1.10** (the S3 backend uses `use_lockfile`).
- A Proxmox VE cluster reachable over the API, plus an API token.
- An S3-compatible bucket for remote state (e.g. MinIO, Garage, Backblaze).
- `talosctl` and `kubectl` for operating the cluster.
- DHCP server configured with the reservations below.

### DHCP

Before `terraform apply`:

- Exclude `192.168.88.200–.220` from the DHCP dynamic pool.
- Add static mappings for each MAC in the [network table](#network-layout)
  (`bc:24:11:88:02:01` → `192.168.88.201`, etc.).
- Leave `192.168.88.200` unmapped — Talos manages it as the VIP.

## Configuration

### Secrets / environment variables

The Proxmox API token is **not** stored in `terraform.tfvars` (a `tfvars` value
would override the environment). Provide it via the environment:

```bash
export TF_VAR_proxmox_api_token='terraform@pam!provision=<uuid>'
```

S3 backend credentials (read by the backend at init time):

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=...
export AWS_ENDPOINT_URL_S3=...   # your S3-compatible endpoint
```

### Backend

```bash
cp backend.hcl.example backend.hcl   # then set: bucket = "<your-bucket>"
```

### Variables

Set cluster/connection values in `terraform.tfvars` (cluster name, Talos
version, node maps, disk sizes, datastores, Proxmox endpoint, SSH details). See
`variables.tf` for the full list and validation rules.

## Usage

```bash
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### Accessing the cluster

```bash
terraform output -raw kubeconfig  > kubeconfig
terraform output -raw talos_config > talosconfig

kubectl --kubeconfig kubeconfig get nodes -o wide
talosctl --talosconfig talosconfig -e 192.168.88.200 -n 192.168.88.200 etcd members
```

Both outputs are marked sensitive and point at the VIP (`192.168.88.200`).

### Verifying HA

Power off whichever control node currently holds the VIP; `kubectl` should keep
working within seconds as the VIP migrates to another control node.

## Module fork

`main.tf` points `module "talos"` at a **local path**
(`../git/terraform-proxmox-talos`) rather than the registry, because the cluster
relies on a `cluster_endpoint` override that is not yet released upstream. The
change is proposed as a backward-compatible PR. Once merged and released, switch
back to the registry source with a pinned `version`.

## Security notes

- Treat `terraform.tfstate`, `terraform.tfvars`, and `backend.hcl` as secrets;
  they are gitignored.
- Do not expose the Kubernetes API (`6443`) or Talos API (`50000`) to the
  internet. Expose workloads via an ingress controller and forward only `80/443`
  on OPNsense.

## License

Released under the [MIT License](LICENSE). Copyright (c) 2026 vetl.
