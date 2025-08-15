# turn on APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "artifactregistry.googleapis.com",
    "securitycenter.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  disable_dependent_services = true
  disable_on_destroy         = false
}
