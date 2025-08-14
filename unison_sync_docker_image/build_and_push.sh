#!/bin/bash

# # Prompt for GitHub username
# read -p "Enter your GitHub username: " GITHUB_USERNAME

# # Prompt for GitHub Personal Access Token (input hidden)
# read -s -p "Enter your GitHub Personal Access Token (GHCR_PAT): " GHCR_PAT
clear
echo ""

source .env

docker images ghcr.io/tonydail/unison-sync

# Prompt for image tag
read -p "Enter the image tag (e.g., v1.0.0): " IMAGE_TAG

# Variables
IMAGE_NAME="ghcr.io/$GITHUB_USERNAME/unison-sync"
DOCKERFILE_PATH="."  # Adjust if your Dockerfile is in a subdirectory

# Authenticate with GitHub Container Registry
echo $GHCR_PAT | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Build the Docker image
docker build -t $IMAGE_NAME:$IMAGE_TAG -t $IMAGE_NAME:latest $DOCKERFILE_PATH

# Push the image to GHCR
docker push $IMAGE_NAME:$IMAGE_TAG
echo "✅ Image $IMAGE_NAME:$IMAGE_TAG pushed to GHCR successfully."
docker push $IMAGE_NAME:latest
echo "✅ Image $IMAGE_NAME:latest pushed to GHCR successfully."


echo "Current images:"
docker images $IMAGE_NAME
