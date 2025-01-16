#!/usr/bin/env bash

set -e

URL="http://localhost:4848"
HEADERS=$(cat <<EOF
Origin: http://localhost:9090
Type: system
EOF
)

IMAGE_NAME=$1
SETUP_NAME=$2
MAC=$3
PATH_TO_IMAGE=$4
IMAGE_UUID=$5

# Create new image
echo "Creating a new image: ${IMAGE_NAME}"
IMAGE_UUID=$(curl -X POST "${URL}/image" -H "$HEADERS" \
    -H "Content-Type: application/json" \
    -d "{\"Name\": \"${IMAGE_NAME}\", \"Username\": \"admin\"}" | jq -r '.UUID')
echo "Image created with UUID: ${IMAGE_UUID}"

# Create a new image setup
echo "Creating a new image setup: ${SETUP_NAME}"
SETUP_UUID=$(curl -X POST "${URL}/user/admin/image_setup" -H "$HEADERS" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${SETUP_NAME}\"}" | jq -r '.UUID')
echo "Image setup created with UUID: ${SETUP_UUID}"

# Upload the changed image
echo "Uploading image: ${PATH_TO_IMAGE} for image: ${IMAGE_UUID}"
curl -X POST "${URL}/image/${IMAGE_UUID}" -H "$HEADERS" \
    -H "Content-Type: multipart/form-data" \
    -H "X-BAAS-NewVersion: true" \
    -F "file=@${PATH_TO_IMAGE}"
echo "Image uploaded! New version: ${VERSION}"

# Add the image to the setup
echo "Adding image: ${IMAGE_UUID} to setup: ${SETUP_UUID}"
curl -X POST "${URL}/user/admin/image_setup/${SETUP_UUID}" -H "$HEADERS" \
    -H "Content-Type: application/json" \
    -d "{\"Uuid\": \"${IMAGE_UUID}\", \"Version\": ${VERSION}}"
echo "Image added!"


# Configure a new boot setup for the machine
echo "Configuring a new boot setup (${SETUP_UUID}) for the machine: ${MAC}"
curl -X POST "${URL}/machine/${MAC}/boot" -H "$HEADERS" \
    -H "Content-Type: application/json" \
    -d "{\"SetupUUID\": \"${SETUP_UUID}\", \"update\": false}"
echo "Boot setup configured!"