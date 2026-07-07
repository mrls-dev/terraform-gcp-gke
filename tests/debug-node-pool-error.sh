#!/bin/bash
# Debug script for GKE Node Pool ERROR state
# Run this to identify the root cause

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration from your tfvars
SERVICE_PROJECT="project-70f3c2b9-8f91-41f7-b5c"
HOST_PROJECT="mrls-dev-network"
CLUSTER_NAME="cts-sample-dev-gke"
ZONE="us-central1-a"
REGION="us-central1"

echo -e "${YELLOW}=== GKE Node Pool Error Debugger ===${NC}\n"

# 1. Check if the node pool exists and get detailed error
echo -e "${YELLOW}1. Checking node pool status...${NC}"
gcloud container node-pools describe cpu-pool \
  --cluster="$CLUSTER_NAME" \
  --zone="$ZONE" \
  --project="$SERVICE_PROJECT" \
  --format="json" > node_pool_status.json 2>&1 || true

if [ -f node_pool_status.json ]; then
  echo -e "${GREEN}✓ Node pool details saved to node_pool_status.json${NC}"
  # Check for status messages
  cat node_pool_status.json | jq -r '.status, .statusMessage, .conditions[]?' 2>/dev/null || echo "Parse error"
fi

# 2. Check recent operations for detailed error messages
echo -e "\n${YELLOW}2. Checking recent GKE operations for errors...${NC}"
gcloud container operations list \
  --project="$SERVICE_PROJECT" \
  --filter="targetLink:$CLUSTER_NAME AND status:DONE" \
  --limit=5 \
  --format="table(name,operationType,status,endTime)"

# Get the most recent operation details
LATEST_OP=$(gcloud container operations list \
  --project="$SERVICE_PROJECT" \
  --filter="targetLink:$CLUSTER_NAME" \
  --limit=1 \
  --format="value(name)")

if [ ! -z "$LATEST_OP" ]; then
  echo -e "\n${YELLOW}Getting details for operation: $LATEST_OP${NC}"
  gcloud container operations describe "$LATEST_OP" \
    --zone="$ZONE" \
    --project="$SERVICE_PROJECT"
fi

# 3. Check Shared VPC permissions
echo -e "\n${YELLOW}3. Checking Shared VPC permissions...${NC}"

# Get the GKE service account
GKE_SA="service-$(gcloud projects describe $SERVICE_PROJECT --format='value(projectNumber)')@container-engine-robot.iam.gserviceaccount.com"
echo "GKE Service Account: $GKE_SA"

# Check if GKE service account has required roles on host project
echo -e "\n${YELLOW}Checking if $GKE_SA has required roles on host project...${NC}"
gcloud projects get-iam-policy "$HOST_PROJECT" \
  --flatten="bindings[].members" \
  --filter="bindings.members:$GKE_SA" \
  --format="table(bindings.role)" || echo -e "${RED}✗ No roles found${NC}"

# Required roles for Shared VPC
echo -e "\n${YELLOW}Required roles for Shared VPC:${NC}"
echo "  - roles/compute.networkUser (on host project)"
echo "  - roles/container.hostServiceAgentUser (on host project)"

# 4. Check subnet IP address availability
echo -e "\n${YELLOW}4. Checking subnet IP availability...${NC}"
gcloud compute networks subnets describe cts-sample-dev-app-us-central1 \
  --project="$HOST_PROJECT" \
  --region="$REGION" \
  --format="json" | jq -r '.ipCidrRange, .secondaryIpRanges[]' || echo -e "${RED}✗ Subnet not found${NC}"

# 5. Check resource quotas
echo -e "\n${YELLOW}5. Checking compute quotas in service project...${NC}"
gcloud compute project-info describe \
  --project="$SERVICE_PROJECT" \
  --format="json" | jq -r '.quotas[] | select(.metric | contains("CPUS") or contains("IN_USE_ADDRESSES") or contains("N1_CPUS"))' || echo "Quota check failed"

# 6. Check if service account exists and has permissions
echo -e "\n${YELLOW}6. Checking GKE nodes service account...${NC}"
NODE_SA="${CLUSTER_NAME}-nodes-sa@${SERVICE_PROJECT}.iam.gserviceaccount.com"
echo "Node Service Account: $NODE_SA"

gcloud iam service-accounts describe "$NODE_SA" \
  --project="$SERVICE_PROJECT" 2>&1 || echo -e "${RED}✗ Service account not found${NC}"

# Check node SA roles
echo -e "\n${YELLOW}Checking roles for node service account...${NC}"
gcloud projects get-iam-policy "$SERVICE_PROJECT" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:$NODE_SA" \
  --format="table(bindings.role)"

# 7. Check Cloud Logging for detailed errors
echo -e "\n${YELLOW}7. Checking Cloud Logging for GKE errors (last 1 hour)...${NC}"
gcloud logging read "resource.type=gke_cluster
  AND resource.labels.cluster_name=$CLUSTER_NAME
  AND severity>=ERROR
  AND timestamp>=\"$(date -u -v-1H '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ')\"" \
  --project="$SERVICE_PROJECT" \
  --limit=10 \
  --format="table(timestamp,severity,jsonPayload.message)" 2>/dev/null || echo -e "${YELLOW}No recent errors in logs${NC}"

echo -e "\n${GREEN}=== Debug Complete ===${NC}"
echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. Review node_pool_status.json for status messages"
echo "2. Check the operation details above for specific error messages"
echo "3. Verify Shared VPC permissions are correctly set"
echo "4. Check subnet has enough IP addresses for pods and services"
echo "5. Review Cloud Console > Kubernetes Engine > Clusters > $CLUSTER_NAME for UI errors"
