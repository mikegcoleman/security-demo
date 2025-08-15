# sa for mongodb
resource "google_service_account" "mongodb_service_account" {
  account_id   = "mongodb-vm-sa"
  display_name = "MongoDB VM Service Account"
}

# allow terraform service account to use mongodb service account
resource "google_service_account_iam_member" "terraform_sa_user" {
  service_account_id = google_service_account.mongodb_service_account.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:terraform-sa@${var.project_id}.iam.gserviceaccount.com"
}

# give mongodb service account write access to backup bucket
resource "google_storage_bucket_iam_member" "mongodb_sa_bucket_writer" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.mongodb_service_account.email}"
}

# startup script
locals {
  mongodb_startup_script = <<-EOF
    #!/bin/bash
    set -e
    
    # update packages
    apt-get update
    
    # install mongodb from ubuntu repos v3.6.3
    apt-get install -y mongodb
    
    # configure mongodb for external access with auth
    sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' /etc/mongodb.conf
    
    # start mongodb initially without auth to create users
    systemctl restart mongodb
    systemctl enable mongodb
    
    # wait for mongodb to start
    sleep 10
    
    # create admin user and app user
    mongo admin --eval '
    db.createUser({
      user: "admin",
      pwd: "password123",
      roles: [
        { role: "userAdminAnyDatabase", db: "admin" },
        { role: "readWriteAnyDatabase", db: "admin" },
        { role: "dbAdminAnyDatabase", db: "admin" }
      ]
    });'
    
    # Create application database and user
    mongo appdb --eval '
    db.createUser({
      user: "appuser", 
      pwd: "apppass123",
      roles: [
        { role: "readWrite", db: "appdb" }
      ]
    });' --username admin --password password123 --authenticationDatabase admin
    
    # enable auth and restart
    sed -i 's/#auth = true/auth = true/' /etc/mongodb.conf
    systemctl restart mongodb
    
    # wait for restart
    sleep 10
    
    # install google cloud sdk for backup script
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    apt-get update && apt-get install -y google-cloud-sdk
    
    # create backup script
    cat > /usr/local/bin/mongodb-backup.sh << 'EOL'
#!/bin/bash
BACKUP_DIR="/tmp/mongodb-backups"
BUCKET_NAME="${var.bucket_name}"
DATE=$(date +%Y%m%d_%H%M)   # include hour and minute
BACKUP_FILE="mongodb_backup_$DATE.tar.gz"

mkdir -p $BACKUP_DIR
cd $BACKUP_DIR

# create mongodb dump with authentication
mongodump --host localhost --port 27017 --username admin --password password123 --authenticationDatabase admin --out dump_$DATE

# create tar.gz archive
tar -czf $BACKUP_FILE dump_$DATE/

# upload to gcs bucket
gsutil cp $BACKUP_FILE gs://$BUCKET_NAME/backups/

# cleanup local files older than 1 day
find /tmp/mongodb-backups -name "*.tar.gz" -mtime +1 -delete
find /tmp/mongodb-backups -name "dump_*" -mtime +1 -exec rm -rf {} +

echo "backup completed: $BACKUP_FILE uploaded to gs://$BUCKET_NAME/backups/"
EOL
    
    chmod +x /usr/local/bin/mongodb-backup.sh
    
    # setup cron job for hourly backups
    echo "0 * * * * root /usr/local/bin/mongodb-backup.sh >> /var/log/mongodb-backup.log 2>&1" >> /etc/crontab
   
    echo "mongodb setup completed"
  EOF
}

# mongodb vm
resource "google_compute_instance" "mongodb_vm" {
  name         = var.mongodb_vm_name
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-pro-cloud/ubuntu-pro-1804-lts"
      size  = 50
    }
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.mongodb_subnet.id

    # public ip
    access_config {
      // auto ip
    }
  }

  # service account
  service_account {
    email  = google_service_account.mongodb_service_account.email
    scopes = ["cloud-platform"]
  }

  # ssh access and startup script
  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_file)}"
  }
  metadata_startup_script = local.mongodb_startup_script
  
  tags = ["ssh-allowed", "mongodb-vm"]

  # prevent vm replacement due to image drift
  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }
  
  depends_on = [
    google_project_service.apis,
    google_compute_subnetwork.mongodb_subnet,
    google_storage_bucket.backup_bucket,
    google_storage_bucket_iam_member.mongodb_sa_bucket_writer
  ]
}
