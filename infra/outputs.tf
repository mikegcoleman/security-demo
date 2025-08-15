# Output: GCE VM external IP
output "mongodb_vm_external_ip" {
  description = "External IP address of the MongoDB VM"
  value       = google_compute_instance.mongodb_vm.network_interface[0].access_config[0].nat_ip
}

# Output: MongoDB connection string
output "mongodb_connection_string" {
  description = "MongoDB connection string"
  value       = "mongodb://appuser:apppass123@${google_compute_instance.mongodb_vm.network_interface[0].network_ip}:27017/appdb"
  sensitive   = true
}

output "backup_bucket_https_url" {
  description = "Public HTTPS URL for the MongoDB backup bucket"
  value       = "https://storage.googleapis.com/${google_storage_bucket.backup_bucket.name}/backups"
}

# Additional useful outputs
output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}


output "artifact_registry_url" {
  description = "Artifact Registry Docker repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}
