##########################
# GKE Cluster Outputs
##########################
output "cluster_id" {
  description = "The unique identifier of the GKE cluster"
  value       = google_container_cluster.primary.id
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "The IP address of the cluster master"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64 encoded public certificate that is the root of trust for the cluster"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "The location (zone) of the cluster"
  value       = google_container_cluster.primary.location
}

output "cluster_self_link" {
  description = "The self link of the cluster"
  value       = google_container_cluster.primary.self_link
}

output "kubernetes_version" {
  description = "The Kubernetes version running on the cluster"
  value       = google_container_cluster.primary.master_version
}

##########################
# Node Pool Outputs
##########################
output "cpu_node_pool_name" {
  description = "The name of the CPU node pool"
  value       = google_container_node_pool.cpu_pool.name
}

output "cpu_node_pool_id" {
  description = "The ID of the CPU node pool"
  value       = google_container_node_pool.cpu_pool.id
}

output "gpu_node_pool_name" {
  description = "The name of the GPU node pool"
  value       = var.enable_gpu_node_pool ? google_container_node_pool.gpu_pool[0].name : null
}

output "gpu_node_pool_id" {
  description = "The ID of the GPU node pool"
  value       = var.enable_gpu_node_pool ? google_container_node_pool.gpu_pool[0].id : null
}

##########################
# Service Account Outputs
##########################
output "node_service_account_email" {
  description = "The email of the service account used by GKE nodes"
  value       = google_service_account.gke_nodes.email
}

output "node_service_account_id" {
  description = "The ID of the service account used by GKE nodes"
  value       = google_service_account.gke_nodes.id
}

##########################
# kubectl Command Outputs
##########################
output "kubectl_config_command" {
  description = "Command to configure kubectl to connect to the cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone=${google_container_cluster.primary.location} --project=${var.project_id}"
}

output "kubectl_test_command" {
  description = "Command to test kubectl connectivity"
  value       = "kubectl get nodes"
}

##########################
# GPU-specific Outputs
##########################
output "gpu_driver_installer_daemonset" {
  description = "Command to install NVIDIA GPU drivers via DaemonSet"
  value       = var.enable_gpu_node_pool ? "kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded.yaml" : "N/A - GPU node pool not enabled"
}

output "gpu_test_pod" {
  description = "Sample pod manifest to test GPU functionality"
  value       = <<-EOF
    apiVersion: v1
    kind: Pod
    metadata:
      name: gpu-test
    spec:
      restartPolicy: Never
      containers:
      - name: cuda-test
        image: nvidia/cuda:12.2.0-base-ubuntu22.04
        command: ["nvidia-smi"]
        resources:
          limits:
            nvidia.com/gpu: 1
      tolerations:
      - key: nvidia.com/gpu
        operator: Equal
        value: present
        effect: NoSchedule
  EOF
}

##########################
# Network Outputs
##########################
output "network_name" {
  description = "The name of the VPC network used by the cluster"
  value       = google_container_cluster.primary.network
}

output "subnetwork_name" {
  description = "The name of the subnet used by the cluster"
  value       = google_container_cluster.primary.subnetwork
}

output "pods_ip_range_name" {
  description = "The name of the secondary IP range used for pods"
  value       = local.pods_ip_range_name
}

output "services_ip_range_name" {
  description = "The name of the secondary IP range used for services"
  value       = local.services_ip_range_name
}

##########################
# Cost & Resource Outputs
##########################
output "cost_estimate_monthly" {
  description = "Estimated monthly cost (approximate)"
  value = {
    cluster_management = "Free for zonal clusters"
    cpu_nodes          = "~$${var.cpu_node_count * (var.cpu_preemptible ? 30 : 100)}/month (${var.cpu_machine_type})"
    gpu_nodes          = var.enable_gpu_node_pool ? "~$${var.gpu_node_count * (var.gpu_preemptible ? 120 : 400)}/month (${var.gpu_machine_type} + ${var.gpu_type})" : "N/A"
  }
}

output "resource_summary" {
  description = "Summary of deployed resources"
  value = {
    cluster_name       = local.cluster_name
    cluster_location   = var.zone
    cpu_nodes          = "${var.cpu_min_node_count}-${var.cpu_max_node_count} nodes (${var.cpu_machine_type})"
    gpu_nodes          = var.enable_gpu_node_pool ? "${var.gpu_min_node_count}-${var.gpu_max_node_count} nodes (${var.gpu_machine_type} with ${var.gpu_count_per_node}x ${var.gpu_type})" : "Disabled"
    kubernetes_version = data.google_container_engine_versions.gke_version.latest_master_version
    workload_identity  = var.enable_workload_identity
    network_policy     = var.enable_network_policy
    private_cluster    = var.enable_private_cluster
  }
}

##########################
# Quick Start Guide
##########################
output "quick_start_guide" {
  description = "Quick start commands to get started with the cluster"
  value       = <<-EOF
    # Configure kubectl
    ${local.cluster_name != "" ? "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone=${google_container_cluster.primary.location} --project=${var.project_id}" : ""}
    
    # Verify cluster access
    kubectl get nodes
    kubectl get namespaces
    
    # Check node pools
    kubectl get nodes -L cloud.google.com/gke-nodepool
    
    ${var.enable_gpu_node_pool ? "# Install NVIDIA GPU drivers (if not using Deep Learning containers)\nkubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded.yaml\n\n# Test GPU\nkubectl apply -f - <<GPU_TEST\napiVersion: v1\nkind: Pod\nmetadata:\n  name: gpu-test\nspec:\n  restartPolicy: Never\n  containers:\n  - name: cuda-test\n    image: nvidia/cuda:12.2.0-base-ubuntu22.04\n    command: [\"nvidia-smi\"]\n    resources:\n      limits:\n        nvidia.com/gpu: 1\n  tolerations:\n  - key: nvidia.com/gpu\n    operator: Equal\n    value: present\n    effect: NoSchedule\nGPU_TEST\n\n# Check GPU test pod logs\nkubectl logs gpu-test" : ""}
  EOF
}
