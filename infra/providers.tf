terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  
  backend "gcs" {
    bucket = "clgcporg10-172-terraform-state"
    prefix = "security-demo"
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
#  credentials = file("./creds/terraform-key.json") <-- uncomment for local execution
}