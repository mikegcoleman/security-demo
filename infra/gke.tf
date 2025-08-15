# GKE Standard cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  # VPC-native networking
  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.gke_subnet.id

  # IP aliasing (VPC-native) configuration
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Workload Identity disabled as requested
  workload_identity_config {
    workload_pool = null
  }

  # Network policy disabled for simplicity
  network_policy {
    enabled = false
  }

  # Private cluster configuration (optional - allows external access via LoadBalancer)
  private_cluster_config {
    enable_private_nodes    = false
    enable_private_endpoint = false
  }

  depends_on = [
    google_project_service.apis,
    google_compute_subnetwork.gke_subnet
  ]
}

# Node pool with e2-small machines
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    preemptible  = false
    machine_type = "e2-small"

    # Google recommends custom service accounts with minimal permissions
    service_account = google_service_account.gke_service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      env = "security-demo"
    }

    tags = ["gke-node", "security-demo"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Service account for GKE nodes
resource "google_service_account" "gke_service_account" {
  account_id   = "gke-service-account"
  display_name = "GKE Service Account"
}

# IAM binding for GKE service account
resource "google_project_iam_member" "gke_service_account_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_service_account.email}"
}