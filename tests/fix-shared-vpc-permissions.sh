#!/bin/bash
# Fix Shared VPC permissions for GKE cluster
# This script grants necessary permissions for GKE to work with Shared VPC

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SERVICE_PROJECT="project-70f3c2b9-8f91-41f7-b5c"
HOST_PROJECT="mrls-dev-network"

echo -e "${YELLOW}=== Fixing Shared VPC Permissions for GKE ===${NC}\n"

# Get project numbers
SERVICE_PROJECT_NUM=$(gcloud projects describe "$SERVICE_PROJECT" --format='value(projectNumber)')
HOST_PROJECT_NUM=$(gcloud projects describe "$HOST_PROJECT" --format='value(projectNumber)')

echo "Service Project: $SERVICE_PROJECT (Project #: $SERVICE_PROJECT_NUM)"
echo "Host Project: $HOST_PROJECT (Project #: $HOST_PROJECT_NUM)"

# GKE service accounts
GKE_SA="service-${SERVICE_PROJECT_NUM}@container-engine-robot.iam.gserviceaccount.com"
COMPUTE_SA="${SERVICE_PROJECT_NUM}-compute@developer.gserviceaccount.com"

echo -e "\n${YELLOW}1. Granting roles to GKE service account on HOST project...${NC}"

# Grant compute.networkUser role to GKE service account (required for Shared VPC)
echo "Granting compute.networkUser to $GKE_SA on $HOST_PROJECT"
gcloud projects add-iam-policy-binding "$HOST_PROJECT" \
  --member="serviceAccount:$GKE_SA" \
  --role="roles/compute.networkUser" \
  --condition=None

# Grant container.hostServiceAgentUser (required for GKE with Shared VPC)
echo "Granting container.hostServiceAgentUser to $GKE_SA on $HOST_PROJECT"
gcloud projects add-iam-policy-binding "$HOST_PROJECT" \
  --member="serviceAccount:$GKE_SA" \
  --role="roles/container.hostServiceAgentUser" \
  --condition=None

echo -e "\n${YELLOW}2. Granting roles to Compute service account on HOST project...${NC}"

# Grant compute.networkUser to default compute service account
echo "Granting compute.networkUser to $COMPUTE_SA on $HOST_PROJECT"
gcloud projects add-iam-policy-binding "$HOST_PROJECT" \
  --member="serviceAccount:$COMPUTE_SA" \
  --role="roles/compute.networkUser" \
  --condition=None

echo -e "\n${YELLOW}3. Enabling required APIs on SERVICE project...${NC}"
gcloud services enable container.googleapis.com --project="$SERVICE_PROJECT"
gcloud services enable compute.googleapis.com --project="$SERVICE_PROJECT"
gcloud services enable logging.googleapis.com --project="$SERVICE_PROJECT"
gcloud services enable monitoring.googleapis.com --project="$SERVICE_PROJECT"

echo -e "\n${GREEN}✓ Permissions configured successfully!${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Wait 1-2 minutes for IAM propagation"
echo "2. Destroy the failed node pool: terraform destroy -target=google_container_node_pool.cpu_pool"
echo "3. Re-apply: terraform apply"
