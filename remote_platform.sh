#!/bin/bash -e
# shellcheck disable=SC1091

source .pretty_print

print_bred "WARNING: This script will completely wipe out your RapidFort deployment."
print_bred "WARNING: All data will be will be deleted from your VM and will not be recoverable."

read -p "Do you want to remove the RapidFort platform and all data? (yes/no)" GO_AHEAD

# Convert input to lowercase
GO_AHEAD=$(echo "$GO_AHEAD" | tr '[:upper:]' '[:lower:]')

# Check the input
if [[ "$GO_AHEAD" == "yes" ]]; then
  print_bgreen "Proceeding with removal..."
  print_bgreen "Removing Helm Chart"
  if ! helm uninstall rapidfort --ignore-not-found; then
    print_bred "Removing Helm Chart failed"
  fi

  print_bgreen "Removing Kind Cluster"
  if ! kind delete cluster --name rapidfort-platform; then
    print_bred "Removing Kind cluster failed"
  fi
elif [[ "$GO_AHEAD" == "no" ]]; then
  print_bred "Aborting the removal."
else
  print_bred "Invalid input. Please enter 'yes' or 'no'."
fi