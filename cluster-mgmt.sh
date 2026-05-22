#!/bin/bash
###############################################################################
# GKE Cluster Management Script
# Quick commands for creating and destroying the cluster
###############################################################################

set -euo pipefail

# Configuration
readonly PROJECT_ID="project-70f3c2b9-8f91-41f7-b5c"
readonly CLUSTER_NAME="cts-sample-dev-gke"
readonly ZONE="us-central1-a"
readonly GITHUB_REPO="mrls-dev/terraform-gcp-gke"

# Functions
print_header() {
    echo "========================================"
    echo "$1"
    echo "========================================"
}

print_info() {
    echo "INFO: $1"
}

print_success() {
    echo "SUCCESS: $1"
}

print_error() {
    echo "ERROR: $1" >&2
}

check_cluster_exists() {
    if gcloud container clusters describe $CLUSTER_NAME \
        --zone=$ZONE \
        --project=$PROJECT_ID &>/dev/null; then
        return 0
    else
        return 1
    fi
}

show_status() {
    print_header "GKE Cluster Status"
    
    if check_cluster_exists; then
        print_success "Cluster EXISTS and is RUNNING"
        echo ""
        
        # Cluster info
        echo "Cluster Details:"
        gcloud container clusters describe $CLUSTER_NAME \
            --zone=$ZONE \
            --project=$PROJECT_ID \
            --format="table(name,location,currentMasterVersion,currentNodeCount,status)"
        
        echo ""
        
        # Node pools
        echo "Node Pools:"
        gcloud container node-pools list \
            --cluster=$CLUSTER_NAME \
            --zone=$ZONE \
            --project=$PROJECT_ID \
            --format="table(name,config.machineType,initialNodeCount,autoscaling.minNodeCount,autoscaling.maxNodeCount,status)"
        
        echo ""
        print_info "Cluster is INCURRING COSTS (~\$100-460/month)"
        print_info "Run './cluster-mgmt.sh destroy' to save costs when done"
        
    else
        print_error "Cluster DOES NOT EXIST"
        echo ""
        print_info "No cluster costs - you're saving money!"
        print_info "Run './cluster-mgmt.sh create' to deploy cluster"
    fi
}

create_cluster() {
    print_header "Creating GKE Cluster"
    
    if check_cluster_exists; then
        print_error "Cluster already exists! Run 'status' to view details."
        exit 1
    fi
    
    print_info "Triggering GitHub Actions workflow to create cluster..."
    print_info "This will take 10-15 minutes"
    
    # Trigger GitHub Actions via gh CLI
    if command -v gh &> /dev/null; then
        gh workflow run terraform-gke.yml \
            -R $GITHUB_REPO \
            -f action=apply \
            -f environment=dev
        
        print_success "Workflow triggered! Monitor progress:"
        echo "  https://github.com/$GITHUB_REPO/actions"
        echo ""
        print_info "Or watch locally: gh run watch -R $GITHUB_REPO"
    else
        print_error "GitHub CLI (gh) not installed"
        print_info "Install: brew install gh"
        print_info "Or trigger manually at: https://github.com/$GITHUB_REPO/actions"
        exit 1
    fi
}

destroy_cluster() {
    print_header "Destroying GKE Cluster"
    
    if ! check_cluster_exists; then
        print_error "Cluster does not exist. Nothing to destroy."
        exit 0
    fi
    
    # Confirmation
    echo "WARNING: This will DELETE the cluster and all workloads!"
    echo ""
    echo "Cluster: $CLUSTER_NAME"
    echo "Location: $ZONE"
    echo ""
    read -p "Are you sure you want to destroy? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "Destruction cancelled"
        exit 0
    fi
    
    print_info "Triggering GitHub Actions workflow to destroy cluster..."
    
    # Trigger GitHub Actions via gh CLI
    if command -v gh &> /dev/null; then
        gh workflow run terraform-gke.yml \
            -R $GITHUB_REPO \
            -f action=destroy \
            -f environment=dev
        
        print_success "Destruction workflow triggered!"
        echo ""
        print_info "This will take 5-10 minutes"
        print_info "Monitor: https://github.com/$GITHUB_REPO/actions"
        print_info "Or watch: gh run watch -R $GITHUB_REPO"
        echo ""
        print_success "You'll save ~\$100-460/month after destruction"
    else
        print_error "GitHub CLI (gh) not installed"
        print_info "Install: brew install gh"
        print_info "Or trigger manually at: https://github.com/$GITHUB_REPO/actions"
        exit 1
    fi
}

kubectl_config() {
    print_header "Configuring kubectl"
    
    if ! check_cluster_exists; then
        print_error "Cluster does not exist. Create it first."
        exit 1
    fi
    
    print_info "Fetching cluster credentials..."
    gcloud container clusters get-credentials $CLUSTER_NAME \
        --zone=$ZONE \
        --project=$PROJECT_ID
    
    print_success "kubectl configured successfully!"
    echo ""
    
    # Test connection
    print_info "Testing connection..."
    kubectl cluster-info
    echo ""
    
    print_info "Nodes:"
    kubectl get nodes -L cloud.google.com/gke-nodepool
}

show_costs() {
    print_header "Cost Breakdown"
    
    if check_cluster_exists; then
        echo "STATUS: CLUSTER IS RUNNING - INCURRING COSTS"
    else
        echo "STATUS: CLUSTER IS DESTROYED - NO COSTS"
    fi
    
    echo ""
    echo "Cost Estimates (per month):"
    echo "========================================"
    echo "  Cluster Management:          FREE (zonal)"
    echo "  CPU Nodes (1-5 autoscaling): ~\$100-500"
    echo "  GPU Nodes (0-3 preemptible): ~\$0-360"
    echo "========================================"
    echo "  TOTAL (typical):             ~\$100-460/month"
    echo ""
    
    if check_cluster_exists; then
        print_info "TIP: Destroy cluster when not in use to save costs"
        print_info "    Run: ./cluster-mgmt.sh destroy"
    else
        print_success "Currently saving ~\$100-460/month"
    fi
}

show_usage() {
    cat << EOF
GKE Cluster Management Script

Usage: $0 <command>

Commands:
    status      Show cluster status and node pools
    create      Create cluster via GitHub Actions
    destroy     Destroy cluster to save costs
    kubectl     Configure kubectl for cluster access
    costs       Show cost breakdown and estimates
    help        Show this help message

Examples:
    $0 status       # Check if cluster exists
    $0 create       # Deploy cluster (costs start)
    $0 destroy      # Delete cluster (save money)
    $0 kubectl      # Setup kubectl access

Cost Management:
    - Cluster costs ~\$100-460/month when running
    - GPU nodes auto-scale to 0 when idle (saves money)
    - Destroy cluster when not in use to avoid all costs
    - Takes 10-15 min to create, 5-10 min to destroy

EOF
}

# Main
case "${1:-}" in
    status)
        show_status
        ;;
    create)
        create_cluster
        ;;
    destroy)
        destroy_cluster
        ;;
    kubectl)
        kubectl_config
        ;;
    costs)
        show_costs
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Invalid command: ${1:-}"
        echo ""
        show_usage
        exit 1
        ;;
esac
