# Security Demo Infrastructure

This Terraform configuration provisions intentionally vulnerable infrastructure on Google Cloud Platform for security demonstration and training purposes.

## ⚠️ Security Warnings

**This infrastructure contains intentional security vulnerabilities and misconfigurations:**

- VM with excessive IAM permissions (`roles/owner`)
- Publicly accessible GCS bucket with `allUsers` access
- SSH access from `0.0.0.0/0`
- Outdated MongoDB version (4.0) with weak authentication
- Ubuntu 16.04 (EOL) operating system

**DO NOT use this configuration in production environments.**

## Prerequisites

1. Google Cloud SDK installed and authenticated
2. Terraform 1.5+ installed
3. A GCP project with billing enabled
4. Required APIs will be enabled automatically

## Quick Start

1. **Clone and configure:**
   ```bash
   cd infra
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your project ID and bucket name
   ```

2. **Initialize and apply:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Get cluster credentials:**
   ```bash
   gcloud container clusters get-credentials security-demo-cluster --zone us-central1-a
   ```

## What Gets Created

- **VPC Network** with two subnets (GKE and MongoDB)
- **GKE Standard Cluster** with e2-small nodes, VPC-native networking
- **GCE VM** running outdated MongoDB with excessive permissions
- **Firewall Rules** including overly permissive SSH access
- **GCS Bucket** with public read access for backups
- **Artifact Registry** Docker repository
- **Audit Logging** enabled for security monitoring

## Outputs

After deployment, you'll get:
- MongoDB VM external IP
- MongoDB connection string (sensitive)
- Public URL to backup file in GCS bucket
- GKE cluster details
- Artifact Registry URL

## Cleanup

```bash
terraform destroy
```

## Security Testing Scenarios

This infrastructure supports testing:
- IAM privilege escalation
- Network segmentation bypass attempts
- Data exposure through public storage
- Container security in GKE
- MongoDB authentication weaknesses
- SSH hardening validation