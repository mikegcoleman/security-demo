# security center already enabled in audit-logging.tf

# note: advanced security center features require organization-level access
# for this demo we'll rely on default security center scanning and policy analyzer

# enable cloud asset inventory for compliance checks
resource "google_project_service" "asset_inventory" {
  project = var.project_id
  service = "cloudasset.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}

# pubsub for security center notifications
resource "google_project_service" "pubsub" {
  project = var.project_id
  service = "pubsub.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}