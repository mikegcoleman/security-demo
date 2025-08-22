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

# pub/sub topic for falco security alerts
resource "google_pubsub_topic" "falco_alerts" {
  name    = "falco-security-alerts"
  project = var.project_id

  depends_on = [google_project_service.pubsub]
}

# subscription for cloud function to process alerts
resource "google_pubsub_subscription" "falco_alerts_subscription" {
  name    = "falco-alerts-to-scc"
  topic   = google_pubsub_topic.falco_alerts.name
  project = var.project_id

  # configure for cloud function processing
  ack_deadline_seconds = 300
  
  # retry policy for failed deliveries
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  # dead letter policy for unprocessable messages
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.falco_alerts_dead_letter.id
    max_delivery_attempts = 5
  }

  depends_on = [google_pubsub_topic.falco_alerts]
}

# dead letter topic for failed alert processing
resource "google_pubsub_topic" "falco_alerts_dead_letter" {
  name    = "falco-alerts-dead-letter"
  project = var.project_id

  depends_on = [google_project_service.pubsub]
}

# notification channel for pub/sub alerts
resource "google_monitoring_notification_channel" "falco_pubsub_channel" {
  display_name = "Falco to Pub/Sub Channel"
  type         = "pubsub"
  project      = var.project_id
  
  labels = {
    topic = google_pubsub_topic.falco_alerts.id
  }

  depends_on = [google_pubsub_topic.falco_alerts]
}

# log-based alert policy for falco events
resource "google_monitoring_alert_policy" "falco_shell_notification" {
  display_name = "Falco Shell Notification"
  project      = var.project_id
  enabled      = true
  combiner     = "OR"
  
  conditions {
    display_name = "Log match condition"
    
    condition_matched_log {
      filter = <<-EOT
        resource.type="k8s_container"
        resource.labels.project_id="${var.project_id}"
        resource.labels.location="${var.region}-a"
        resource.labels.cluster_name="security-demo-cluster"
        resource.labels.namespace_name="falco"
        labels.k8s-pod/app_kubernetes_io/instance="falco"
        labels.k8s-pod/app_kubernetes_io/name="falco"
        severity>=DEFAULT
        severity="INFO"
      EOT
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.falco_pubsub_channel.name
  ]

  alert_strategy {
    auto_close = "604800s"
    
    notification_rate_limit {
      period = "300s"
    }
    
    notification_prompts = ["OPENED"]
  }

  severity = "CRITICAL"

  depends_on = [
    google_monitoring_notification_channel.falco_pubsub_channel,
    google_pubsub_topic.falco_alerts
  ]
}

# enable required apis for cloud function and scc
resource "google_project_service" "cloudfunctions" {
  project = var.project_id
  service = "cloudfunctions.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "securitycenter" {
  project = var.project_id
  service = "securitycenter.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "cloudbuild" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "cloudrun" {
  project = var.project_id
  service = "run.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}

# storage bucket for cloud function source code
resource "google_storage_bucket" "function_source" {
  name          = "${var.project_id}-falco-scc-function"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true
}

# service account for cloud function
resource "google_service_account" "falco_scc_function" {
  account_id   = "falco-scc-function"
  display_name = "Falco to SCC Function Service Account"
  description  = "Service account for Cloud Function that transforms Falco alerts to SCC findings"
}

# iam permissions for the function
resource "google_project_iam_member" "function_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.falco_scc_function.email}"
}

resource "google_project_iam_member" "function_scc_editor" {
  project = var.project_id
  role    = "roles/securitycenter.sourcesEditor"
  member  = "serviceAccount:${google_service_account.falco_scc_function.email}"
}

# cloud function source code archive
resource "google_storage_bucket_object" "function_source_zip" {
  name   = "falco-scc-function-source.zip"
  bucket = google_storage_bucket.function_source.name
  source = "${path.module}/falco-scc-function.zip"

  depends_on = [google_storage_bucket.function_source]
}

# cloud function for transforming alerts to scc findings (using v1 for simpler permissions)
resource "google_cloudfunctions_function" "falco_to_scc" {
  name        = "falco-to-scc-transformer"
  region      = var.region
  description = "Transforms Falco alerts from Pub/Sub into Security Command Center findings"

  runtime             = "python311"
  available_memory_mb = 256
  timeout             = 60
  entry_point         = "process_falco_alert"
  
  source_archive_bucket = google_storage_bucket.function_source.name
  source_archive_object = google_storage_bucket_object.function_source_zip.name
  
  environment_variables = {
    PROJECT_ID = var.project_id
  }
  
  service_account_email = google_service_account.falco_scc_function.email

  event_trigger {
    event_type = "providers/cloud.pubsub/eventTypes/topic.publish"
    resource   = google_pubsub_topic.falco_alerts.name
    
    failure_policy {
      retry = true
    }
  }

  depends_on = [
    google_project_service.cloudfunctions,
    google_project_service.securitycenter,
    google_project_service.cloudrun,
    google_storage_bucket_object.function_source_zip,
    google_service_account.falco_scc_function
  ]
}