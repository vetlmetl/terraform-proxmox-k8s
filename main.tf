terraform {
  # Remote state on an S3-compatible object store.
  # Partial config: `bucket` is supplied at init via -backend-config=backend.hcl.
  # Credentials, region, and the S3 endpoint are read from environment variables:
  #   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION, AWS_ENDPOINT_URL_S3
  backend "s3" {
    key          = "prox-terr-bpg/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # native S3 state locking (Terraform >= 1.10); no DynamoDB needed
    use_path_style = true # most non-AWS S3 gateways require path-style addressing

    # The following skips are required for non-AWS S3-compatible providers,
    # which don't implement AWS-specific validation/metadata endpoints.
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requester_charged      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }

  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.109.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.11.0"
    }
  }
}

# ─── Provider configuration ────────────────────────────────────────────────

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
  ssh {
    agent       = var.proxmox_ssh_agent
    private_key = file(var.proxmox_ssh_private_key)
    username    = var.proxmox_ssh_username
  }
}

# ─── Talos cluster module ──────────────────────────────────────────────────

module "talos" {
  source  = "bbtechsys/talos/proxmox"
  version = "0.1.5"

  talos_cluster_name = var.cluster_name
  talos_version      = var.talos_version
  control_nodes      = var.control_nodes
  worker_nodes       = var.worker_nodes

  proxmox_control_vm_disk_size = var.control_disk_size
  proxmox_worker_vm_disk_size  = var.worker_disk_size
  proxmox_image_datastore      = var.image_datastore
  proxmox_iso_datastore        = var.iso_datastore
}

# ─── Outputs ───────────────────────────────────────────────────────────────

output "talos_config" {
  description = "Talos configuration file"
  value       = module.talos.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubeconfig file"
  value       = module.talos.kubeconfig
  sensitive   = true
}
