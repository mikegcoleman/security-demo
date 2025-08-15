# Project-level audit logging configuration
resource "google_project_iam_audit_config" "project" {
  project = var.project_id
  service = "allServices"

  # Admin activity audit logs (always enabled by default, but explicit here)
  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }

  depends_on = [google_project_service.apis]
}

# Enable Security Command Center API
resource "google_project_service" "security_center" {
  project = var.project_id
  service = "securitycenter.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}

