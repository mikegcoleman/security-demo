# gcp credentials

need service account key with these permissions:

```bash
  roles/compute.admin 
  roles/container.admin 
  roles/storage.admin 
  roles/artifactregistry.admin 
  roles/logging.admin 
  roles/iam.securityAdmin 
  roles/iam.serviceAccountAdmin
```
create service account and save key as terraform-key.json:

```bash
# set project id
export PROJECT_ID="<YOUR PROJECT ID>"

# create service account
gcloud iam service-accounts create terraform-sa \
  --project="$PROJECT_ID" \
  --display-name "Terraform Service Account"

# set sa email
export SA_EMAIL="terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com"

# grant roles
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

# sa user permissions for vm creation
gcloud iam service-accounts add-iam-policy-binding \
  "$SA_EMAIL" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.serviceAccountUser"

# permission to use default compute sa
COMPUTE_SA="${PROJECT_ID//-/}@developer.gserviceaccount.com"
gcloud iam service-accounts add-iam-policy-binding \
  "$COMPUTE_SA" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.serviceAccountUser"

# create key
gcloud iam service-accounts keys create terraform-key.json \
  --iam-account="$SA_EMAIL"
```

## ssh key setup

put public ssh key in this directory:

```bash
# generate key if needed
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# copy public key here
cp ~/.ssh/id_rsa.pub ./id_rsa.pub
```

terraform adds key to mongodb vm authorized_keys

ssh keys excluded from git