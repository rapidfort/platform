#!/bin/bash -e
# shellcheck disable=SC1091

source .pretty_print

# Define the file names
files=("secret.yaml" "user.yaml" "image.yaml")

# Check if each file exists
for file in "${files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "Error: $file does not exist."
    exit 1
  fi
done

QUAY_DOCKER_REGISTRY=quay.io/rapidfort

print_bgreen "Attempting login to quay.io automatically"
RF_QUAY_USERNAME=$(grep '\.dockerconfigjson' secret.yaml | awk '{print $2}' | sed 's/"//g' | base64 -d | jq -r '.auths["quay.io/rapidfort"].auth' | base64 -d | awk -F: '{print $1}')
RF_QUAY_PASSWORD=$(grep '\.dockerconfigjson' secret.yaml | awk '{print $2}' | sed 's/"//g' | base64 -d | jq -r '.auths["quay.io/rapidfort"].auth' | base64 -d | awk -F: '{print $2}')

if [ -z "$RF_QUAY_USERNAME" ] || [ -z "$RF_QUAY_PASSWORD" ]; then
  print_bred "Calculating Quay username or password failed, exiting..."
  exit 1
fi

print_bgreen "Logging in to Helm registry"
echo -n ${RF_QUAY_PASSWORD} | helm registry login -u ${RF_QUAY_USERNAME} --password-stdin ${QUAY_DOCKER_REGISTRY}

if ! kind get clusters | grep rapidfort-platform > /dev/null; then
  print_bgreen "Starting kind"
  kind create cluster --name rapidfort-platform --config kind-config.yaml --wait 8m

  print_bgreen "Deploying and starting Ingress"
  kubectl apply -f ingress-nginx.yaml

  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=200s

  print_bgreen "Remove admission controller"
  kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission
fi

print_bgreen "Installing Image Pull Secret"
kubectl apply -f secret.yaml

print_bgreen "Deploying RapidFort platform"
helm upgrade --install rapidfort-platform oci://quay.io/rapidfort/platform -f image.yaml -f user.yaml

print_bgreen "Waiting 5 minutes for platform to start..."
sleep 20
kubectl rollout status deployment --timeout=5m









