FROM gcr.io/k8s-minikube/kicbase:v0.0.45

# Create the certificates directory if it doesn't exist
RUN mkdir -p /etc/docker/certs.d/registry:5000

# Copy the registry certificate
COPY registry.crt /etc/docker/certs.d/registry:5000/ca.crt
