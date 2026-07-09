##########################
# Dev Environment GKE Configuration
##########################

##########################
# Project Configuration
##########################
project_id         = "project-70f3c2b9-8f91-41f7-b5c"
network_project_id = "mrls-dev-network"
project_name       = "cts-sample"
environment        = "dev"

##########################
# Location Configuration
##########################
region = "us-central1"
zone   = "us-central1-b"

##########################
# Network State Configuration
##########################
network_state_bucket = "mrlsmahesh-org-terraform-state-dev"
network_state_prefix = "network/vpc/dev"

##########################
# GKE Cluster Configuration
##########################
kubernetes_version       = "latest"        # Use latest stable GKE version
release_channel          = "REGULAR"       # RAPID, REGULAR, STABLE
enable_autopilot         = false           
enable_private_cluster   = true            
master_ipv4_cidr_block   = "172.16.0.0/28" 
enable_workload_identity = true
enable_network_policy    = false # Disabled - ADVANCED_DATAPATH (Dataplane V2) provides network policy enforcement

##########################
# CPU Node Pool Configuration
##########################
cpu_node_pool_name = "cpu-pool"
cpu_machine_type   = "e2-standard-4"
cpu_node_count     = 1               
cpu_min_node_count = 1               
cpu_max_node_count = 5               
cpu_disk_size_gb   = 100
cpu_disk_type      = "pd-balanced"
cpu_preemptible    = false # Use regular nodes for stability

##########################
# GPU Node Pool Configuration
##########################
enable_gpu_node_pool = true
gpu_node_pool_name   = "gpu-pool"
gpu_machine_type     = "n1-standard-4"
gpu_type             = "nvidia-tesla-t4" # 16 GB VRAM, cheapest GPU option
gpu_count_per_node   = 1                 

# Node count and autoscaling
gpu_node_count     = 0 
gpu_min_node_count = 0 
gpu_max_node_count = 3

# Disk configuration
gpu_disk_size_gb = 100
gpu_disk_type    = "pd-balanced"

# Cost optimization
gpu_preemptible = true # Use preemptible for 70% savings

# GPU node taints (ensures only GPU workloads run on GPU nodes)
gpu_node_taints = [{
  key    = "nvidia.com/gpu"
  value  = "present"
  effect = "NO_SCHEDULE"
}]

##########################
# Security Settings
##########################
enable_shielded_nodes = true
enable_secure_boot    = true

# Master authorized networks - Only these IPs can access the cluster API
# CRITICAL: This prevents unauthorized access to your cluster control plane
master_authorized_networks = [
  {
    cidr_block   = "99.6.77.224/32"
    display_name = "Restricted access"
  }
]

# Binary Authorization - Only allows approved container images
# Set to true in production to prevent untrusted images from running
enable_binary_authorization = false

##########################
# Maintenance Window
##########################
# Saturday and Sunday, 3:00 AM - 7:00 AM UTC
maintenance_window_start    = "03:00"
maintenance_window_duration = 4

##########################
# Resource Labels
##########################
labels = {
  environment = "dev"
  owner       = "devops"
  project     = "cts-sample"
  workload    = "multi-purpose"
  managed_by  = "terraform"
}

##########################
# Safety Settings
##########################
deletion_protection = false # Set to true for production
