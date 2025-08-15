# Artifact Registry Docker repository
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = "security-demo-docker"
  description   = "Docker repository for security demo applications"
  format        = "DOCKER"

  depends_on = [google_project_service.apis]
}

# IAM binding to allow GKE service account to pull images
resource "google_artifact_registry_repository_iam_member" "gke_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_service_account.email}"
}