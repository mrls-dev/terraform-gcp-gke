#!/bin/bash
# Check what network resources actually exist in the host project
# This helps identify missing subnets or naming mismatches

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

HOST_PROJECT="mrls-dev-network"
REGION="us-central1"

echo -e "${YELLOW}=== Checking Network Resources in Host Project ===${NC}\n"

echo -e "${YELLOW}1. Listing all VPCs in host project...${NC}"
gcloud compute networks list \
  --project="$HOST_PROJECT" \
  --format="table(name,autoCreateSubnetworks,routingConfig.routingMode)"

echo -e "\n${YELLOW}2. Listing all subnets in us-central1 region...${NC}"
gcloud compute networks subnets list \
  --project="$HOST_PROJECT" \
  --filter="region:$REGION" \
  --format="table(name,network.basename(),ipCidrRange,secondaryIpRanges[].rangeName:label='Secondary Ranges')"

echo -e "\n${YELLOW}3. Detailed subnet information...${NC}"
for subnet in $(gcloud compute networks subnets list --project="$HOST_PROJECT" --filter="region:$REGION" --format="value(name)"); do
  echo -e "\n${GREEN}Subnet: $subnet${NC}"
  gcloud compute networks subnets describe "$subnet" \
    --project="$HOST_PROJECT" \
    --region="$REGION" \
    --format="yaml(name,ipCidrRange,secondaryIpRanges)"
  echo "---"
done

echo -e "\n${YELLOW}4. Checking Terraform remote state outputs...${NC}"
echo "Attempting to read network state from GCS..."

BUCKET="mrlsmahesh-org-terraform-state-dev"
PREFIX="network/vpc/dev"

# Try to download and read the state file
if gsutil ls "gs://${BUCKET}/${PREFIX}/default.tfstate" &>/dev/null; then
  echo -e "${GREEN}✓ State file exists${NC}"
  
  # Download and parse outputs
  gsutil cp "gs://${BUCKET}/${PREFIX}/default.tfstate" /tmp/network-state.json 2>/dev/null
  
  if [ -f /tmp/network-state.json ]; then
    echo -e "\n${YELLOW}Network State Outputs:${NC}"
    cat /tmp/network-state.json | jq -r '.outputs' 2>/dev/null || echo "Failed to parse outputs"
    
    echo -e "\n${YELLOW}Looking for GKE-related outputs:${NC}"
    cat /tmp/network-state.json | jq -r '.outputs | with_entries(select(.key | contains("subnet") or contains("vpc")))' 2>/dev/null || echo "No subnet/vpc outputs found"
    
    rm /tmp/network-state.json
  fi
else
  echo -e "${RED}✗ State file not found at: gs://${BUCKET}/${PREFIX}/default.tfstate${NC}"
  echo -e "${YELLOW}This means the network infrastructure hasn't been deployed yet!${NC}"
fi

echo -e "\n${YELLOW}=== Summary ===${NC}"
echo "Based on the subnet list above, you need to either:"
echo "1. Create the missing subnet in the network Terraform, OR"
echo "2. Update GKE Terraform to reference an existing subnet"
echo ""
echo "The GKE cluster expects these from remote state:"
echo "  - vpc_self_link"
echo "  - app_subnet_id"
echo ""
echo "The subnet must have secondary IP ranges for:"
echo "  - gke-pods-dev (for pod IPs)"
echo "  - gke-services-dev (for service IPs)"
