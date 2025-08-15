# vpc network
resource "google_compute_network" "vpc" {
  name                    = "security-demo-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460

  depends_on = [google_project_service.apis]
}

# gke subnet
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "gke-subnet"
  ip_cidr_range = var.gke_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  # secondary ranges for pods and services
  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.gke_pods_cidr
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = var.gke_services_cidr
  }

  private_ip_google_access = true
}

# mongodb subnet
resource "google_compute_subnetwork" "mongodb_subnet" {
  name          = "mongodb-subnet"
  ip_cidr_range = var.mongodb_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true
}