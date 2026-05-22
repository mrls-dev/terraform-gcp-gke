##########################
# Data Sources
##########################

# Fetch network configuration from remote state
data "terraform_remote_state" "network" {
  backend = "gcs"

  config = {
    bucket = var.network_state_bucket
    prefix = var.network_state_prefix
  }
}

# Get available GKE versions
data "google_container_engine_versions" "gke_version" {
  location       = var.zone
  version_prefix = var.kubernetes_version == "latest" ? "" : "${var.kubernetes_version}."
  project        = var.project_id
}

# Get project details
data "google_project" "project" {
  project_id = var.project_id
}
