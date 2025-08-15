# SSH rule - wide open
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-from-anywhere"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-allowed"]

  description = "ssh access from anywhere"
}

# mongo access from k8s
resource "google_compute_firewall" "allow_mongodb_from_gke" {
  name    = "allow-mongodb-from-gke"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }

  source_ranges = [var.gke_pods_cidr]
  target_tags   = ["mongodb-vm"]

  description = "mongodb from gke pods"
}

# allow internal comms
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.vpc_cidr]
  description   = "internal vpc communication"
}

# health check rule
resource "google_compute_firewall" "allow_health_checks" {
  name    = "allow-health-checks"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]

  target_tags = ["gke-node"]
  description = "gcp health checks"
}