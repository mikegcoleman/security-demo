# k8s cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  # network stuff
  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.gke_subnet.id

  # ip ranges
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  # no default nodes
  remove_default_node_pool = true
  initial_node_count       = 1

  # allow deletion
  deletion_protection = false

  # disable workload identity
  workload_identity_config {
    workload_pool = null
  }

  # network policy on
  network_policy {
    enabled = true
  }

  # public cluster
  private_cluster_config {
    enable_private_nodes    = false
    enable_private_endpoint = false
  }

  depends_on = [
    google_project_service.apis,
    google_compute_subnetwork.gke_subnet
  ]
}

# node pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    preemptible  = false
    machine_type = "e2-medium"
    image_type   = "UBUNTU_CONTAINERD"

    # use default SA
    # service_account = google_service_account.gke_service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring"
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

# gke service account
resource "google_service_account" "gke_service_account" {
  account_id   = "gke-service-account"
  display_name = "GKE Service Account"
}

# gke permissions
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