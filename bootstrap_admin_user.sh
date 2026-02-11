#!/bin/bash

hostname=$(grep hostname user.yaml | awk '{print $2}' | sed 's/"//g')
url=https://"${hostname}"/api/v1/onboard

admin_email=$(grep admin user.yaml | awk '{print $2}' | sed 's/"//g')
admin_password=$(grep passwd user.yaml | awk '{print $2}' | sed 's/"//g')

api_key=$(grep api_key user.yaml | awk '{print $2}' | sed 's/"//g')

organization_name="${1}"

Usage()
{
    echo "$0: <organization_name>"
    exit 1
}

if [ "$#" -ne 1 ]; then
    echo "Should be only 1 input parameter"
    Usage
fi

header="api-key: $api_key"
payload="{\"admin_email\": \"$admin_email\", \
          \"admin_password\": \"$admin_password\",
          \"organization_name_pretty\": \"$organization_name\"}"

reponse_text_file=$(mktemp)
response=$(curl \
            -k \
            -X POST -d "$payload" \
            -H "$header" \
            -H "Content-Type: application/json" \
            --connect-timeout 10 \
            -o $reponse_text_file \
            -s -w "%{http_code}" "$url")

if [ "$response" -ne 200 ]; then
    echo "ERROR failed to onboard organization"
fi

cat $reponse_text_file | jq .