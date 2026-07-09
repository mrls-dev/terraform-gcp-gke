##########################
# GKE Cluster
##########################
resource "google_container_cluster" "primary" {
  provider = google-beta

  name     = local.cluster_name
  location = var.zone != "" ? var.zone : var.region # Regional if zone is empty

  project = var.project_id

  # Remove default node pool - we'll create custom node pools
  remove_default_node_pool = true
  initial_node_count       = 1

  # GKE version
  min_master_version = data.google_container_engine_versions.gke_version.latest_master_version

  # Release channel for automatic upgrades
  release_channel {
    channel = var.release_channel
  }

  # Network configuration (Shared VPC)
  network    = local.network_self_link
  subnetwork = local.subnet_self_link

  # IP allocation policy for pods and services
  ip_allocation_policy {
    cluster_secondary_range_name  = local.pods_ip_range_name
    services_secondary_range_name = local.services_ip_range_name
  }

  # Private cluster configuration
  dynamic "private_cluster_config" {
    for_each = var.enable_private_cluster ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = false # Keep public endpoint for access
      master_ipv4_cidr_block  = var.master_ipv4_cidr_block
    }
  }

  # Master authorized networks - controls who can access the cluster API
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # Workload Identity
  dynamic "workload_identity_config" {
    for_each = var.enable_workload_identity ? [1] : []
    content {
      workload_pool = "${data.google_project.project.project_id}.svc.id.goog"
    }
  }

  # Network policy is handled by ADVANCED_DATAPATH (Dataplane V2/Cilium)
  # No need for legacy network_policy configuration

  # Add-ons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = true # Must be disabled when using ADVANCED_DATAPATH
    }
    gcp_filestore_csi_driver_config {
      enabled = false
    }
    gcs_fuse_csi_driver_config {
      enabled = false
    }
  }

  # Binary authorization - only allows signed/approved container images
  binary_authorization {
    evaluation_mode = var.enable_binary_authorization ? "PROJECT_SINGLETON_POLICY_ENFORCE" : "DISABLED"
  }

  # Maintenance window
  maintenance_policy {
    recurring_window {
      start_time = "${formatdate("YYYY-MM-DD", timestamp())}T${var.maintenance_window_start}:00Z"
      end_time   = "${formatdate("YYYY-MM-DD", timestamp())}T${format("%02d:%02d", tonumber(split(":", var.maintenance_window_start)[0]) + var.maintenance_window_duration, tonumber(split(":", var.maintenance_window_start)[1]))}:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }

  # Cluster autoscaling (separate from node pool autoscaling)
  cluster_autoscaling {
    enabled = false # Use node pool autoscaling instead
  }

  # Logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Enable dataplane V2 (Cilium)
  datapath_provider = "ADVANCED_DATAPATH"

  # Resource labels
  resource_labels = local.common_labels

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Enable shielded nodes
  dynamic "node_config" {
    for_each = []
    content {}
  }

  # Lifecycle
  lifecycle {
    ignore_changes = [
      initial_node_count,
      node_config,
    ]
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "15m"
  }

  depends_on = [
    data.terraform_remote_state.network
  ]
}

##########################
# CPU Node Pool
##########################
resource "google_container_node_pool" "cpu_pool" {
  provider = google-beta

  name     = var.cpu_node_pool_name
  location = var.zone != "" ? var.zone : var.region # Regional if zone is empty
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  # Node count and autoscaling
  initial_node_count = var.cpu_node_count

  autoscaling {
    min_node_count = var.cpu_min_node_count
    max_node_count = var.cpu_max_node_count
  }

  # Management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }

  # Node configuration
  node_config {
    machine_type = var.cpu_machine_type
    disk_size_gb = var.cpu_disk_size_gb
    disk_type    = var.cpu_disk_type

    # Service account
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Labels
    labels = local.cpu_node_labels

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Workload Identity
    dynamic "workload_metadata_config" {
      for_each = var.enable_workload_identity ? [1] : []
      content {
        mode = "GKE_METADATA"
      }
    }

    # Shielded instance config
    dynamic "shielded_instance_config" {
      for_each = var.enable_shielded_nodes ? [1] : []
      content {
        enable_secure_boot          = var.enable_secure_boot
        enable_integrity_monitoring = true
      }
    }

    # Preemptible
    preemptible = var.cpu_preemptible
    spot        = false

    # Tags
    tags = ["gke-node", "${local.cluster_name}-cpu"]
  }

  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }

  # Timeouts - fail fast on capacity issues
  timeouts {
    create = "30m"
    update = "30m"
    delete = "15m"
  }
}

##########################
# GPU Node Pool
##########################
resource "google_container_node_pool" "gpu_pool" {
  count = var.enable_gpu_node_pool ? 1 : 0

  provider = google-beta

  name     = var.gpu_node_pool_name
  location = var.zone != "" ? var.zone : var.region # Regional if zone is empty
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  # Node count and autoscaling
  initial_node_count = var.gpu_node_count

  autoscaling {
    min_node_count = var.gpu_min_node_count
    max_node_count = var.gpu_max_node_count
  }

  # Management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }

  # Node configuration
  node_config {
    machine_type = var.gpu_machine_type
    disk_size_gb = var.gpu_disk_size_gb
    disk_type    = var.gpu_disk_type

    # GPU configuration
    guest_accelerator {
      type  = var.gpu_type
      count = var.gpu_count_per_node

      # GPU driver installation
      gpu_driver_installation_config {
        gpu_driver_version = "DEFAULT"
      }
    }

    # Service account
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Labels
    labels = local.gpu_node_labels

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Taints (to ensure only GPU workloads run on GPU nodes)
    dynamic "taint" {
      for_each = var.gpu_node_taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    # Workload Identity
    dynamic "workload_metadata_config" {
      for_each = var.enable_workload_identity ? [1] : []
      content {
        mode = "GKE_METADATA"
      }
    }

    # Shielded instance config
    dynamic "shielded_instance_config" {
      for_each = var.enable_shielded_nodes ? [1] : []
      content {
        enable_secure_boot          = var.enable_secure_boot
        enable_integrity_monitoring = true
      }
    }

    # Preemptible/Spot
    preemptible = var.gpu_preemptible
    spot        = false

    # Tags
    tags = ["gke-node", "${local.cluster_name}-gpu"]
  }

  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "15m"
  }
}

##########################
# Service Account for GKE Nodes
##########################
resource "google_service_account" "gke_nodes" {
  account_id   = "${local.cluster_name}-nodes-sa"
  display_name = "GKE nodes service account for ${local.cluster_name}"
  project      = var.project_id
}

# IAM binding for GKE nodes
resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metric_writer" {
  project = var.project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}
