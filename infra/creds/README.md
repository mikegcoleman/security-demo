# GCP Credentials

You will need a .json key for a project-specific service account with the following permissions:

```bash
roles/artifactregistry.admin 
roles/compute.admin 
roles/container.admin 
roles/iam.securityAdmin 
roles/iam.serviceAccountAdmin 
roles/logging.admin 
roles/storage.admin
```
If you are using gcloud you can run the following commands, be sure to specify your project ID for the ENV variable. Copy the resulting key into this directory and call it terraform-key.json:

```bash
# Set your project ID
export PROJECT_ID="<YOUR PROJECT ID>"

# Create the service account
gcloud iam service-accounts create terraform-sa \
  --project="$PROJECT_ID" \
  --display-name "Terraform Service Account"

# Define the service account email
export SA_EMAIL="terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com"

# Grant required roles
for ROLE in \
  roles/compute.admin \
  roles/container.admin \
  roles/storage.admin \
  roles/artifactregistry.admin \
  roles/logging.admin \
  roles/iam.securityAdmin \
  roles/iam.serviceAccountAdmin
do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="$ROLE"
done

# Grant service account user permissions for VM creation
gcloud iam service-accounts add-iam-policy-binding \
  "$SA_EMAIL" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.serviceAccountUser"

# Grant permission to use default compute service account
COMPUTE_SA="${PROJECT_ID//-/}@developer.gserviceaccount.com"
gcloud iam service-accounts add-iam-policy-binding \
  "$COMPUTE_SA" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.serviceAccountUser"

# Create and download a key for Terraform to use
gcloud iam service-accounts keys create terraform-key.json \
  --iam-account="$SA_EMAIL"
```