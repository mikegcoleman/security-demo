# security demo infrastructure

terraform config for vulnerable gcp infrastructure

## security warnings

intentional vulnerabilities:
- vm with owner permissions
- public gcs bucket
- ssh from anywhere
- old mongodb with weak auth
- old ubuntu

do not use in production

## prerequisites

1. gcloud sdk installed
2. terraform 1.5+
3. gcp project with billing

## quick start

1. configure:
   ```bash
   cd infra
   cp terraform.tfvars.example terraform.tfvars
   # edit with your project id
   ```

2. deploy:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. get k8s access:
   ```bash
   gcloud container clusters get-credentials security-demo-cluster --zone us-central1-a
   ```

## what gets created

- vpc network with two subnets
- gke cluster with e2-medium nodes
- gce vm running  mongodb 3.6.3
- firewall rules with ssh from anywhere to tagged resources
- gcs bucket with public read access
- artifact registry docker repo
- audit logging enabled

## outputs

after deployment:
- mongodb vm external ip
- mongodb connection string
- public url to backup file
- gke cluster details
- artifact registry url

## cleanup

```bash
terraform destroy
```