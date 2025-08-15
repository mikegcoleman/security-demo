# GCS bucket for MongoDB backups (with intentional public access for demo)
resource "google_storage_bucket" "backup_bucket" {
  name     = var.bucket_name
  location = var.region

  # Versioning enabled
  versioning {
    enabled = true
  }

  # Lifecycle management
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  # Public access prevention disabled (insecure for demo)
  public_access_prevention = "inherited"

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  depends_on = [google_project_service.apis]
}

# IAM binding: Grant public read access to allUsers (insecure for demo)
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# IAM binding: Grant public list access to allUsers (insecure for demo)
resource "google_storage_bucket_iam_member" "public_list" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.legacyBucketReader"
  member = "allUsers"
}

# Create a sample backup file for demonstration
resource "google_storage_bucket_object" "sample_backup" {
  name   = "backups/sample_backup_demo.txt"
  bucket = google_storage_bucket.backup_bucket.name
  content = <<-EOF
    This is a sample backup file for security demonstration.
    Created at: ${timestamp()}
    
    WARNING: This bucket has public read access - this is intentionally insecure for demonstration purposes.
    
    In a real environment, this would contain sensitive database backup data.
  EOF

  depends_on = [google_storage_bucket.backup_bucket]
}