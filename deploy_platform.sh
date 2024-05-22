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
RF_QUAY_USER=$(grep '\.dockerconfigjson' secret.yaml | awk '{print $2}' | base64 -d | jq -r '.auths["quay.io"].auth' | base64 -d | awk -F: '{print $1}')
RF_QUAY_PASS=$(grep '\.dockerconfigjson' secret.yaml | awk '{print $2}' | base64 -d | jq -r '.auths["quay.io"].auth' | base64 -d | awk -F: '{print $2}')

if [ -z "$RF_QUAY_USER" ] || [ -z "$RF_QUAY_PASS" ]; then
  print_bred "Calculating Quay username or password failed, exiting..."
  exit 1
fi

echo -n ${RF_QUAY_PASSWORD} | helm registry login -u ${RF_QUAY_USERNAME} --password-stdin ${QUAY_DOCKER_REGISTRY}
# Function to pause and wait for user input
# pause(){
#     read -p "Did you complete quay.io registry login? (y/n): " choice
#     case "$choice" in
#         y|Y ) print_bgreen "Continuing...";;
#         * ) print_bred "Exiting..."; exit 1;;
#     esac
# }

# pause

print_bgreen "Starting kind"
kind create cluster --name rapidfort-platform --config kind-config.yaml --wait 8m

print_bgreen "Ingress start"
kubectl apply -f ingress-nginx.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=200s

print_bgreen "Remove admission controller"
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission

print_bgreen "Install Image Pull Secret"
kubectl apply -f secret.yaml

print_bgreen "Deploy RapidFort platform"
helm upgrade --install rapidfort oci://quay.io/rapidfort/rapidfort-platform -f image.yaml -f user.yaml










