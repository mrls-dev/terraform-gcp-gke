##########################
# Local Values
##########################
locals {
  # Naming convention: {project_name}-{environment}-{resource_type}
  cluster_name = var.cluster_name != "" ? var.cluster_name : "${var.project_name}-${var.environment}-gke"

  # Node pool names
  cpu_pool_name = "${local.cluster_name}-${var.cpu_node_pool_name}"
  gpu_pool_name = var.enable_gpu_node_pool ? "${local.cluster_name}-${var.gpu_node_pool_name}" : ""

  # Network data from remote state
  network_self_link = data.terraform_remote_state.network.outputs.vpc_self_link
  subnet_self_link  = data.terraform_remote_state.network.outputs.app_subnet_id

  # Pod and service IP ranges (secondary ranges in subnet)
  pods_ip_range_name     = "pods"
  services_ip_range_name = "services"

  # Common labels
  common_labels = merge(
    var.labels,
    {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
      component   = "gke"
    }
  )

  # Node pool labels
  cpu_node_labels = merge(
    local.common_labels,
    {
      node_pool = "cpu"
      workload  = "general"
    }
  )

  gpu_node_labels = merge(
    local.common_labels,
    {
      node_pool = "gpu"
      workload  = "ai-ml"
      gpu_type  = var.gpu_type
    }
  )
}
