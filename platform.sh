#!/bin/bash -e
# shellcheck disable=SC1091

source .pretty_print

# Function to pause and wait for user input
pause(){
    read -p "Did you complete quay.io registry login? (y/n): " choice
    case "$choice" in
        y|Y ) print_bgreen "Continuing...";;
        * ) print_bred "Exiting..."; exit 1;;
    esac
}

pause

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

print_bgreen "Deploy RapidFort platform"
helm upgrade --install rapidfort oci://quay.io/rapidfort/rapidfort-platform -f image.yaml -f user.yaml










