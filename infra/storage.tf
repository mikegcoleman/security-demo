# bucket for mongo backups
resource "google_storage_bucket" "backup_bucket" {
  name          = var.bucket_name
  location      = var.region
  force_destroy = true

  # enable versioning for this thing
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

# Note: Real MongoDB backups are created by the backup script on the VM
# and uploaded to the backups/ folder in this bucket