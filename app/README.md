# mongodb test app

flask app for testing mongodb connection

## what it does

- connects to mongodb at 10.0.2.11:27017
- inserts test docs and counts them
- rest api for checking connection status

## endpoints

- `GET /` - app info
- `GET /test-db` - test mongo connection
- `GET /health` - health check

## build and deploy

```bash
# build image
cd app
docker build -t us-west1-docker.pkg.dev/clgcporg10-172/security-demo-docker/mongodb-test-app:latest .

# push to registry
docker push us-west1-docker.pkg.dev/clgcporg10-172/security-demo-docker/mongodb-test-app:latest

# deploy to k8s
kubectl apply -f k8s-deployment.yaml

# check status
kubectl get pods
kubectl get svc

# test external access
curl -i http://<external-ip>/test-db

# test internal access
kubectl exec -it <pod-name> -- curl localhost:8080/test-db
```

## expected behavior

- external access: connection fails
- internal access: connection works