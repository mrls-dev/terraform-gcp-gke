##########################
# IAM Configuration
##########################

# Get the default compute service account
data "google_compute_default_service_account" "default" {
  project = var.project_id
}

# Grant required permissions to GKE node service account
# These permissions enable logging, monitoring, and HPA functionality
resource "google_project_iam_member" "gke_node_permissions" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/stackdriver.resourceMetadata.writer"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}
