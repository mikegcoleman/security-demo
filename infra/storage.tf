# bucket for mongo backups
resource "google_storage_bucket" "backup_bucket" {
  name          = var.bucket_name
  location      = var.region
  force_destroy = true

  # enable versioning
  versioning {
    enabled = true
  }

  # auto delete after 30d
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  # allow public access
  public_access_prevention = "inherited"

  # uniform access
  uniform_bucket_level_access = true

  depends_on = [google_project_service.apis]
}

# make bucket public readable
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# public list access
resource "google_storage_bucket_iam_member" "public_list" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.legacyBucketReader"
  member = "allUsers"
}

# demo file
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