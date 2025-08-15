# audit logging setup
resource "google_project_iam_audit_config" "project" {
  project = var.project_id
  service = "allServices"

  # admin logs
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



