# GCP GKE Infrastructure - Terraform Module

Production-ready Terraform module for deploying Google Kubernetes Engine (GKE) clusters on Google Cloud Platform with mixed CPU and GPU node pools for multi-purpose development and AI/ML workloads.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  GKE Cluster (cts-sample-dev-gke)                          │
│  ┌──────────────────────┐  ┌──────────────────────────┐   │
│  │  CPU Node Pool       │  │  GPU Node Pool           │   │
│  │  ├─ n1-standard-4    │  │  ├─ n1-standard-4        │   │
│  │  ├─ 1-5 nodes        │  │  │  + Tesla T4 GPU       │   │
│  │  ├─ Auto-scaling     │  │  ├─ 0-3 nodes            │   │
│  │  └─ General workloads│  │  ├─ Auto-scaling (0-N)   │   │
│  │                      │  │  ├─ Preemptible          │   │
│  │                      │  │  └─ AI/ML workloads      │   │
│  └──────────────────────┘  └──────────────────────────┘   │
│                                                             │
│  Shared VPC: mrls-dev-network                              │
│  Subnet: 10.0.48.0/20                                      │
│  Pod CIDR: Secondary range                                 │
│  Service CIDR: Secondary range                             │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
terraform-gcp-gke/
├── main.tf                        # GKE cluster and node pools
├── variables.tf                   # Input variables with validation
├── outputs.tf                     # Output values
├── data.tf                        # Data sources (remote state)
├── locals.tf                      # Local values
├── versions.tf                    # Terraform and provider versions
├── providers.tf                   # Provider configuration
├── backend-dev.hcl                # GCS backend config
├── dev.tfvars                     # Dev environment variables
├── cluster-mgmt.sh                # Cluster management script
├── .gitignore                     # Git ignore patterns
├── README.md                      # This file
└── .github/
    └── workflows/
        └── terraform-gke.yml      # GitHub Actions workflow
```
## Prerequisites

1. **Network Infrastructure**: Shared VPC deployed in `mrls-dev-network` project
   - VPC with subnet that has secondary ranges for pods and services
2. **GCS Backend**: Terraform state bucket configured
3. **IAM Permissions**:
   - On service project: `roles/container.admin`, `roles/iam.serviceAccountAdmin`
   - On host project: `roles/compute.networkUser`
4. **GPU Quota**: Request `GPUS_ALL_REGIONS` quota if using GPU nodes

## Cost Management

**Tip**: GPU nodes scale to 0 when idle, so you only pay when using them!

```bash
# Create cluster (start incurring costs)
./cluster-mgmt.sh create

# Check status and costs
./cluster-mgmt.sh status

# Destroy cluster (stop costs)
./cluster-mgmt.sh destroy
```

## Overview

This module creates a production-grade GKE cluster with:
- **CPU node pool** for general workloads
- **GPU node pool** for AI/ML workloads (Tesla T4)
- **Shared VPC** integration
- **Workload Identity** for pod-level IAM
- **Private cluster** configuration for security
- **Auto-scaling** node pools
- **CI/CD ready** with GitHub Actions
- **Destroy/recreate workflows** for cost optimization

## Features

- **Multi-Purpose Design**: CPU pool for general workloads + optional GPU pool for AI/ML
- **GPU Support**: NVIDIA Tesla T4 GPUs (16GB VRAM, 2560 CUDA cores)
- **Private Cluster**: Nodes have no public IPs, enhanced security
- **Workload Identity**: Pod-level IAM without service account keys
- **Auto-Scaling**: Node pools scale 0-N based on demand
- **Cost-Optimized**: Preemptible GPU nodes (~70% savings), scale to zero
- **Shared VPC**: Network isolation with service/host project architecture
- **Network Policy**: Built-in network segmentation
- **CI/CD Ready**: GitHub Actions with Workload Identity Federation
- **Production-Ready**: Comprehensive validation, best practices, documentation


### Local Deployment

```bash
# 1. Initialize Terraform
terraform init -backend-config=backend-dev.hcl

# 2. Review the plan
terraform plan -var-file=dev.tfvars

# 3. Deploy
terraform apply -var-file=dev.tfvars

# 4. Configure kubectl
gcloud container clusters get-credentials cts-sample-dev-gke \
  --zone=us-central1-a \
  --project=project-70f3c2b9-8f91-41f7-b5c

# 5. Verify
kubectl get nodes

# 6. IMPORTANT: Destroy when done to save costs!
terraform destroy -var-file=dev.tfvars
```

## Deploy AI/ML Workloads

### Install NVIDIA GPU Drivers

```bash
# Install NVIDIA device plugin DaemonSet
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded.yaml

# Verify drivers are installed
kubectl get pods -n kube-system | grep nvidia
```

### Test GPU Functionality

```yaml
# gpu-test-pod.yaml
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
```

```bash
# Apply the test pod
kubectl apply -f gpu-test-pod.yaml

# Check logs (should show nvidia-smi output)
kubectl logs gpu-test
```

### Deploy PyTorch Training Job

```yaml
# pytorch-training.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pytorch-gpu-training
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: pytorch
        image: pytorch/pytorch:latest
        command:
          - python3
          - -c
          - |
            import torch
            print(f"CUDA available: {torch.cuda.is_available()}")
            print(f"CUDA devices: {torch.cuda.device_count()}")
            print(f"Device name: {torch.cuda.get_device_name(0)}")
            # Your training code here
        resources:
          limits:
            nvidia.com/gpu: 1
      tolerations:
      - key: nvidia.com/gpu
        operator: Equal
        value: present
        effect: NoSchedule
      nodeSelector:
        cloud.google.com/gke-nodepool: gpu-pool
```

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_id` | GCP project ID for GKE cluster | `project-70f3c2b9-8f91-41f7-b5c` |
| `network_project_id` | GCP project ID for Shared VPC | `mrls-dev-network` |
| `project_name` | Project name prefix | `cts-sample` |
| `environment` | Environment name | `dev`, `staging`, `prod` |
| `region` | GCP region | `us-central1` |
| `zone` | GCP zone for cluster | `us-central1-a` |
| `network_state_bucket` | GCS bucket for network state | `my-terraform-state` |

### CPU Node Pool Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `cpu_machine_type` | Machine type for CPU nodes | `n1-standard-4` |
| `cpu_min_node_count` | Minimum CPU nodes | `1` |
| `cpu_max_node_count` | Maximum CPU nodes | `10` |
| `cpu_disk_size_gb` | Disk size for CPU nodes | `100` |
| `cpu_preemptible` | Use preemptible CPU nodes | `false` |

### GPU Node Pool Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_gpu_node_pool` | Enable GPU node pool | `false` |
| `gpu_machine_type` | Machine type for GPU nodes | `n1-standard-4` |
| `gpu_type` | GPU accelerator type | `nvidia-tesla-t4` |
| `gpu_count_per_node` | GPUs per node | `1` |
| `gpu_min_node_count` | Minimum GPU nodes | `0` |
| `gpu_max_node_count` | Maximum GPU nodes | `5` |
| `gpu_preemptible` | Use preemptible GPU nodes | `true` |



## Management Tools

### Cluster Management Script

Quick commands for day-to-day cluster management:

```bash
# Check cluster status and costs
./cluster-mgmt.sh status

# Create cluster (via GitHub Actions)
./cluster-mgmt.sh create

# Destroy cluster to save costs
./cluster-mgmt.sh destroy

# Configure kubectl
./cluster-mgmt.sh kubectl

# View cost breakdown
./cluster-mgmt.sh costs

# Show help
./cluster-mgmt.sh help
```

## Network Requirements

The GKE cluster requires a subnet with **secondary IP ranges** for pods and services:

```hcl
# Network module should create subnet with:
secondary_ip_ranges = [
  {
    range_name    = "pods"
    ip_cidr_range = "10.4.0.0/14"  # Example: /14 for pods
  },
  {
    range_name    = "services"
    ip_cidr_range = "10.0.32.0/20" # Example: /20 for services
  }
]
```

## Security Best Practices

- **Private cluster** - Nodes have no public IPs  
- **Workload Identity** - No service account keys needed  
- **Network policy** - Pod-to-pod traffic control  
- **Shielded nodes** - Secure boot and integrity monitoring  
- **GPU node taints** - GPU nodes only for GPU workloads  
- **Auto-repair** - Automatic node health checks  
- **Auto-upgrade** - Automatic security patches  

## GPU Node Taints & Tolerations

GPU nodes have a taint to ensure only GPU workloads run on them:

```yaml
# Taint (applied automatically)
key: nvidia.com/gpu
value: present
effect: NoSchedule

# Toleration (add to your GPU pods)
tolerations:
- key: nvidia.com/gpu
  operator: Equal
  value: present
  effect: NoSchedule
```

## Troubleshooting

### GPU pods not scheduling?

1. Check GPU drivers are installed:
```bash
kubectl get pods -n kube-system | grep nvidia
```

2. Verify GPU nodes exist:
```bash
kubectl get nodes -L cloud.google.com/gke-accelerator
```
