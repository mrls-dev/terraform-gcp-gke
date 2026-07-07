#!/bin/bash
# Check and resolve Terraform state lock

set -e

LOCK_ID="1783452831944025"
BUCKET="mrlsmahesh-org-terraform-state-dev"
LOCK_PATH="infra/gke/dev/default.tflock"

echo "=== Terraform State Lock Checker ==="
echo ""
echo "Lock Details:"
echo "  ID: $LOCK_ID"
echo "  Holder: runner@runnervmkkn4f (GitHub Actions)"
echo "  Created: 2026-07-07 19:33:51 UTC"
echo ""

# Check if lock file exists
echo "1. Checking if lock file still exists..."
if gsutil ls "gs://${BUCKET}/${LOCK_PATH}" &>/dev/null; then
  echo "✗ Lock file still exists"
  echo ""
  echo "Lock file content:"
  gsutil cat "gs://${BUCKET}/${LOCK_PATH}" | jq . 2>/dev/null || gsutil cat "gs://${BUCKET}/${LOCK_PATH}"
  echo ""
  echo "=== ACTIONS ==="
  echo ""
  echo "Option 1: Check GitHub Actions"
  echo "  - Go to your repository's Actions tab"
  echo "  - Check if any workflow is running"
  echo "  - If workflow is stuck/failed, cancel it first"
  echo ""
  echo "Option 2: Force unlock (if workflow is done/stuck)"
  echo "  cd /Users/mrlscloud/Workspace/mc-infra/gcp/infra/terraform-gcp-gke"
  echo "  terraform force-unlock $LOCK_ID"
  echo ""
  echo "Option 3: Manual cleanup (use with caution)"
  echo "  gsutil rm gs://${BUCKET}/${LOCK_PATH}"
  echo ""
else
  echo "✓ Lock file does not exist (already unlocked)"
  echo "You can now run terraform apply"
fi
