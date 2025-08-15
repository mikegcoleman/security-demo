# SA for mongodb
resource "google_service_account" "mongodb_service_account" {
  account_id   = "mongodb-vm-sa"
  display_name = "MongoDB VM Service Account"
}

# give owner role
resource "google_project_iam_member" "mongodb_owner" {
  project = var.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.mongodb_service_account.email}"
}

# startup script
locals {
  mongodb_startup_script = <<-EOF
    #!/bin/bash
    set -e
    
    # update packages
    apt-get update
    
    # install old mongo version
    apt-get install -y gnupg curl
    curl -fsSL https://www.mongodb.org/static/pgp/server-4.0.asc | apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list
    apt-get update
    apt-get install -y mongodb-org=4.0.28 mongodb-org-server=4.0.28 mongodb-org-shell=4.0.28 mongodb-org-mongos=4.0.28 mongodb-org-tools=4.0.28
    
    # lock package versions
    echo "mongodb-org hold" | dpkg --set-selections
    echo "mongodb-org-server hold" | dpkg --set-selections
    echo "mongodb-org-shell hold" | dpkg --set-selections
    echo "mongodb-org-mongos hold" | dpkg --set-selections
    echo "mongodb-org-tools hold" | dpkg --set-selections
    
    # mongo config
    cat > /etc/mongod.conf << 'EOL'
# mongod.conf
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 0.0.0.0

processManagement:
  timeZoneInfo: /usr/share/zoneinfo

security:
  authorization: enabled
EOL
    
    # Start MongoDB
    systemctl enable mongod
    systemctl start mongod
    
    # Wait for MongoDB to start
    sleep 10
    
    # Create admin user
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
    mongo admin -u admin -p password123 --eval '
    use appdb;
    db.createUser({
      user: "appuser",
      pwd: "apppass123",
      roles: [
        { role: "readWrite", db: "appdb" }
      ]
    });'
    
    # Install Google Cloud SDK for backup script
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    apt-get update && apt-get install -y google-cloud-sdk
    
    # Create backup script
    cat > /usr/local/bin/mongodb-backup.sh << 'EOL'
#!/bin/bash
BACKUP_DIR="/tmp/mongodb-backups"
BUCKET_NAME="${var.bucket_name}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="mongodb_backup_$DATE.tar.gz"

mkdir -p $BACKUP_DIR
cd $BACKUP_DIR

# Create MongoDB dump
mongodump --host localhost --port 27017 --username admin --password password123 --authenticationDatabase admin --out dump_$DATE

# Create tar.gz archive
tar -czf $BACKUP_FILE dump_$DATE/

# Upload to GCS bucket
gsutil cp $BACKUP_FILE gs://$BUCKET_NAME/backups/

# Cleanup local files older than 1 day
find /tmp/mongodb-backups -name "*.tar.gz" -mtime +1 -delete
find /tmp/mongodb-backups -name "dump_*" -mtime +1 -exec rm -rf {} +

echo "Backup completed: $BACKUP_FILE uploaded to gs://$BUCKET_NAME/backups/"
EOL
    
    chmod +x /usr/local/bin/mongodb-backup.sh
    
    # Setup cron job for daily backups at noon
    echo "0 12 * * * root /usr/local/bin/mongodb-backup.sh >> /var/log/mongodb-backup.log 2>&1" >> /etc/crontab
   
    echo "MongoDB setup completed"
  EOF
}

# mongodb vm
resource "google_compute_instance" "mongodb_vm" {
  name         = var.mongodb_vm_name
  machine_type = "e2-medium"
  zone         = var.zone

  # old ubuntu image
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

  depends_on = [
    google_project_service.apis,
    google_compute_subnetwork.mongodb_subnet,
    google_storage_bucket.backup_bucket
  ]
}