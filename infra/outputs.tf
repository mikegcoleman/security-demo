# Output: GCE VM external IP
output "mongodb_vm_external_ip" {
  description = "External IP address of the MongoDB VM"
  value       = google_compute_instance.mongodb_vm.network_interface[0].access_config[0].nat_ip
}

# Output: MongoDB connection string
output "mongodb_connection_string" {
  description = "MongoDB connection string for application use"
  value       = "mongodb://appuser:apppass123@${google_compute_instance.mongodb_vm.network_interface[0].access_config[0].nat_ip}:27017/appdb"
  sensitive   = true
}

# Output: Public URL to backup file in GCS bucket
output "public_backup_file_url" {
  description = "Public URL to a sample backup file in the GCS bucket"
  value       = "https://storage.googleapis.com/${google_storage_bucket.backup_bucket.name}/${google_storage_bucket_object.sample_backup.name}"
}

# Additional useful outputs
output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "artifact_registry_url" {
  description = "Artifact Registry Docker repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}

output "gcs_bucket_name" {
  description = "Name of the GCS backup bucket"
  value       = google_storage_bucket.backup_bucket.name
}

output "vpc_network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "gke_subnet_name" {
  description = "Name of the GKE subnet"
  value       = google_compute_subnetwork.gke_subnet.name
}

output "mongodb_subnet_name" {
  description = "Name of the MongoDB subnet"
  value       = google_compute_subnetwork.mongodb_subnet.name
}