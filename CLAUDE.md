# claude.md

guidance for claude code when working with this repo

## repository overview

security demo repo with two directories:
- `app/` - application code
- `infra/` - infrastructure code

## current state

wiz security exercise implementation with:
- flask app connecting to mongodb
- terraform infrastructure on gcp
- kubernetes deployment
- intentional security misconfigurations

## development workflow

terraform commands:
```bash
cd infra
terraform plan
terraform apply
```

app deployment:
```bash
cd app
docker build -t <image> .
kubectl apply -f k8s-deployment.yaml
```

## architecture

separation between app and infrastructure code
app connects to mongodb with hardcoded credentials
mongodb vm has overly permissive permissions
storage bucket is publicly readable