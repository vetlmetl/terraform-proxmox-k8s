# ─── Cluster variables ─────────────────────────────────────────────────────

variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,61}[a-z0-9]$", var.cluster_name))
    error_message = "Cluster name must be a valid DNS name (lowercase alphanumeric with hyphens, 3–63 characters)."
  }
}

variable "talos_version" {
  description = "Talos version to deploy"
  type        = string

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.talos_version))
    error_message = "Talos version must be in semver format (e.g., 1.9.5)."
  }
}

variable "control_nodes" {
  description = "Map of control node names to Proxmox node names"
  type        = map(string)

  validation {
    condition     = length(var.control_nodes) > 0
    error_message = "At least one control node must be defined."
  }
}

variable "worker_nodes" {
  description = "Map of worker node names to Proxmox node names"
  type        = map(string)
}

# ─── Storage variables ────────────────────────────────────────────────────

variable "control_disk_size" {
  description = "Disk size in GB for control plane VMs"
  type        = number

  validation {
    condition     = var.control_disk_size >= 10
    error_message = "Control node disk size must be at least 10 GB."
  }
}

variable "worker_disk_size" {
  description = "Disk size in GB for worker VMs"
  type        = number

  validation {
    condition     = var.worker_disk_size >= 5
    error_message = "Worker node disk size must be at least 5 GB."
  }
}

variable "image_datastore" {
  description = "Datastore for Talos image storage"
  type        = string
}

variable "iso_datastore" {
  description = "Datastore for ISO storage"
  type        = string
}

# ─── Proxmox connection variables ─────────────────────────────────────────

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL"
  type        = string

  validation {
    condition     = can(regex("^https?://[a-zA-Z0-9._-]+(:\\d+)?$", var.proxmox_endpoint))
    error_message = "Proxmox endpoint must be a valid URL (e.g., https://proxmox.example.com)."
  }
}

variable "proxmox_insecure" {
  description = "Skip TLS certificate verification for the Proxmox API"
  type        = bool
  default     = false
}

variable "proxmox_ssh_agent" {
  description = "Use SSH agent for Proxmox SSH connections"
  type        = bool
  default     = false
}

variable "proxmox_ssh_private_key" {
  description = "Path to the SSH private key for Proxmox connections"
  type        = string

  validation {
    condition     = can(file(var.proxmox_ssh_private_key))
    error_message = "The SSH private key file must exist at the specified path."
  }
}

variable "proxmox_ssh_username" {
  description = "SSH username for Proxmox connections"
  type        = string

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]*$", var.proxmox_ssh_username))
    error_message = "SSH username must be a valid Unix username."
  }
}

variable "proxmox_api_token" {
  description = "Proxmox API token (e.g. terraform@pam!provision=<uuid>). Pass via -var on the command line."
  type        = string
}
