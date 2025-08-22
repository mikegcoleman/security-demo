# gcp credentials

#!/bin/bash

# env vars
export PROJECT_ID="YOUR PROJECT ID"
export SA_NAME="terraform-sa"
export SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Create tf service account
gcloud iam service-accounts create "$SA_NAME" \
  --project="$PROJECT_ID" \
  --display-name "Terraform Service Account"

# project-level IAM roles
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
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$ROLE"
done

# sa role for VM creation
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

# impersonate gce sa
COMPUTE_SA="${PROJECT_ID//-/}-compute@developer.gserviceaccount.com"
gcloud iam service-accounts add-iam-policy-binding "$COMPUTE_SA" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

# impersonate the node pool SA
GKE_NODE_SA="gke-service-account@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud iam service-accounts add-iam-policy-binding "$GKE_NODE_SA" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

#  download json key
gcloud iam service-accounts keys create terraform-key.json \
  --iam-account="$SA_EMAIL"

## ssh key setup

# put public ssh key in this directory:

```bash
# generate key if needed
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# copy public key here
cp ~/.ssh/id_rsa.pub ./id_rsa.pub
```

terraform adds key to mongodb vm authorized_keys

ssh keys excluded from git# SA permissions updated
# Cloud Run developer permission added
