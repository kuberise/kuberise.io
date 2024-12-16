docker build -t localhost:5001/minikube-base:v1 .
docker push localhost:5001/minikube-base:v1
minikube start --ports=80:30080,443:30443 --cpus=max --memory=max --network=platform --base-image=localhost:5001/minikube-base:v1
