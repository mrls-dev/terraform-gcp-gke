##########################
# Project Variables
##########################
variable "project_id" {
  description = "The GCP project ID where the GKE cluster will be created"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "network_project_id" {
  description = "The GCP project ID where the Shared VPC network is hosted"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.network_project_id))
    error_message = "Network project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "Project name must be 3-20 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

##########################
# Location Variables
##########################
variable "region" {
  description = "GCP region for the GKE cluster"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for zonal cluster (e.g., us-central1-a). Leave empty for regional cluster."
  type        = string
  default     = ""
  validation {
    condition     = var.zone == "" || can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]$", var.zone))
    error_message = "Zone must be empty (for regional) or in format: region-zone (e.g., us-central1-a)."
  }
}

##########################
# Network Variables
##########################
variable "network_state_bucket" {
  description = "GCS bucket name where network Terraform state is stored"
  type        = string
}

variable "network_state_prefix" {
  description = "Prefix path to network state file in GCS bucket"
  type        = string
  default     = "network/vpc/dev"
}

##########################
# GKE Cluster Variables
##########################
variable "cluster_name" {
  description = "Name of the GKE cluster (optional, auto-generated if not provided)"
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster (e.g., '1.29'). Use 'latest' for most recent stable version"
  type        = string
  default     = "latest"
}

variable "enable_autopilot" {
  description = "Enable GKE Autopilot mode (fully managed)"
  type        = bool
  default     = false
}

variable "release_channel" {
  description = "GKE release channel (RAPID, REGULAR, STABLE, UNSPECIFIED)"
  type        = string
  default     = "REGULAR"
  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "UNSPECIFIED"], var.release_channel)
    error_message = "Release channel must be one of: RAPID, REGULAR, STABLE, UNSPECIFIED."
  }
}

variable "enable_private_cluster" {
  description = "Enable private GKE cluster (nodes have no public IPs)"
  type        = bool
  default     = true
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for GKE master (control plane) private endpoint"
  type        = string
  default     = "172.16.0.0/28"
  validation {
    condition     = can(cidrhost(var.master_ipv4_cidr_block, 0))
    error_message = "Master CIDR block must be a valid IPv4 CIDR notation."
  }
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity for pod-level IAM"
  type        = bool
  default     = true
}

variable "enable_network_policy" {
  description = "Enable network policy enforcement"
  type        = bool
  default     = true
}

##########################
# CPU Node Pool Variables
##########################
variable "cpu_node_pool_name" {
  description = "Name for the CPU node pool"
  type        = string
  default     = "cpu-pool"
}

variable "cpu_machine_type" {
  description = "Machine type for CPU nodes"
  type        = string
  default     = "n1-standard-4"
}

variable "cpu_node_count" {
  description = "Initial number of CPU nodes"
  type        = number
  default     = 1
  validation {
    condition     = var.cpu_node_count >= 1 && var.cpu_node_count <= 100
    error_message = "CPU node count must be between 1 and 100."
  }
}

variable "cpu_min_node_count" {
  description = "Minimum number of CPU nodes for autoscaling"
  type        = number
  default     = 1
}

variable "cpu_max_node_count" {
  description = "Maximum number of CPU nodes for autoscaling"
  type        = number
  default     = 10
}

variable "cpu_disk_size_gb" {
  description = "Disk size in GB for CPU nodes"
  type        = number
  default     = 100
}

variable "cpu_disk_type" {
  description = "Disk type for CPU nodes (pd-standard, pd-ssd, pd-balanced)"
  type        = string
  default     = "pd-balanced"
  validation {
    condition     = contains(["pd-standard", "pd-ssd", "pd-balanced"], var.cpu_disk_type)
    error_message = "CPU disk type must be one of: pd-standard, pd-ssd, pd-balanced."
  }
}

variable "cpu_preemptible" {
  description = "Use preemptible CPU nodes for cost savings"
  type        = bool
  default     = false
}

##########################
# GPU Node Pool Variables
##########################
variable "enable_gpu_node_pool" {
  description = "Enable GPU node pool for ML/AI workloads"
  type        = bool
  default     = false
}

variable "gpu_node_pool_name" {
  description = "Name for the GPU node pool"
  type        = string
  default     = "gpu-pool"
}

variable "gpu_machine_type" {
  description = "Machine type for GPU nodes (must be compatible with selected GPU)"
  type        = string
  default     = "n1-standard-4"
}

variable "gpu_type" {
  description = "GPU accelerator type (nvidia-tesla-t4, nvidia-tesla-v100, nvidia-tesla-a100, etc.)"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gpu_count_per_node" {
  description = "Number of GPUs to attach to each node"
  type        = number
  default     = 1
  validation {
    condition     = var.gpu_count_per_node >= 1 && var.gpu_count_per_node <= 8
    error_message = "GPU count per node must be between 1 and 8."
  }
}

variable "gpu_node_count" {
  description = "Initial number of GPU nodes"
  type        = number
  default     = 0
  validation {
    condition     = var.gpu_node_count >= 0 && var.gpu_node_count <= 50
    error_message = "GPU node count must be between 0 and 50."
  }
}

variable "gpu_min_node_count" {
  description = "Minimum number of GPU nodes for autoscaling"
  type        = number
  default     = 0
}

variable "gpu_max_node_count" {
  description = "Maximum number of GPU nodes for autoscaling"
  type        = number
  default     = 5
}

variable "gpu_disk_size_gb" {
  description = "Disk size in GB for GPU nodes"
  type        = number
  default     = 100
}

variable "gpu_disk_type" {
  description = "Disk type for GPU nodes (pd-standard, pd-ssd, pd-balanced)"
  type        = string
  default     = "pd-balanced"
  validation {
    condition     = contains(["pd-standard", "pd-ssd", "pd-balanced"], var.gpu_disk_type)
    error_message = "GPU disk type must be one of: pd-standard, pd-ssd, pd-balanced."
  }
}

variable "gpu_preemptible" {
  description = "Use preemptible GPU nodes for cost savings"
  type        = bool
  default     = true
}

variable "gpu_node_taints" {
  description = "Taints to apply to GPU nodes (to ensure only GPU workloads run on them)"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = [{
    key    = "nvidia.com/gpu"
    value  = "present"
    effect = "NO_SCHEDULE"
  }]
}

##########################
# Security & Maintenance Variables
##########################
variable "enable_shielded_nodes" {
  description = "Enable shielded GKE nodes for enhanced security"
  type        = bool
  default     = true
}

variable "enable_secure_boot" {
  description = "Enable secure boot for shielded nodes"
  type        = bool
  default     = true
}

variable "master_authorized_networks" {
  description = "List of CIDR blocks that can access the cluster master endpoint. REQUIRED: Must specify your IP addresses in tfvars file for security."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  # No default - forces explicit configuration in tfvars for security
}

variable "enable_binary_authorization" {
  description = "Enable Binary Authorization to only allow trusted container images. Recommended for production."
  type        = bool
  default     = false
}

variable "maintenance_window_start" {
  description = "Maintenance window start time (HH:MM format, UTC)"
  type        = string
  default     = "03:00"
  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_window_start))
    error_message = "Maintenance window must be in HH:MM format (24-hour, UTC)."
  }
}

variable "maintenance_window_duration" {
  description = "Maintenance window duration in hours"
  type        = number
  default     = 4
  validation {
    condition     = var.maintenance_window_duration >= 1 && var.maintenance_window_duration <= 24
    error_message = "Maintenance window duration must be between 1 and 24 hours."
  }
}

##########################
# Labels & Tags
##########################
variable "labels" {
  description = "Labels to apply to the GKE cluster and node pools"
  type        = map(string)
  default = {
    managed_by = "terraform"
  }
}

variable "deletion_protection" {
  description = "Enable deletion protection for the cluster"
  type        = bool
  default     = false
}
