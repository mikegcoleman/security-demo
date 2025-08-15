variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "us-west1-a"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "gke_subnet_cidr" {
  description = "CIDR block for GKE subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "gke_pods_cidr" {
  description = "CIDR block for GKE pods (secondary range)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "gke_services_cidr" {
  description = "CIDR block for GKE services (secondary range)"
  type        = string
  default     = "10.2.0.0/16"
}

variable "mongodb_subnet_cidr" {
  description = "CIDR block for MongoDB subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "security-demo-cluster"
}

variable "mongodb_vm_name" {
  description = "Name of the MongoDB VM"
  type        = string
  default     = "mongodb-vm"
}

variable "ssh_public_key_file" {
  description = "Path to SSH public key file for VM access"
  type        = string
  default     = "creds/id_rsa.pub"
}

variable "bucket_name" {
  description = "Name of the GCS bucket for backups"
  type        = string
}