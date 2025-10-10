#!/bin/bash

# Function to clean up containers, images, networks, and volumes by container name prefix
cleanup_containers_by_prefix() {
  local PREFIX="$1"

  if [ -z "$PREFIX" ]; then
    echo "Usage: cleanup_by_prefix <container_name_prefix>"
    return 1
  fi

  # Find containers whose names begin with the prefix
  local CONTAINERS
  CONTAINERS=$(docker ps -a --format "{{.ID}} {{.Names}}" | awk -v p="$PREFIX" '$2 ~ "^"p {print $1}')

  if [ -z "$CONTAINERS" ]; then
    echo "No containers found with names beginning with: $PREFIX"
    return 0
  fi

  # Stop running containers
  for CONTAINER in $CONTAINERS; do
    # Check if container still exists
    if ! docker ps -a --format '{{.ID}}' | grep -q "^$CONTAINER$"; then
      echo "Container $CONTAINER does not exist, skipping."
      continue
    fi

    # Stop the container if it is running
    if docker ps --format '{{.ID}}' | grep -q "^$CONTAINER$"; then
      echo "Stopping running container: $CONTAINER"
      docker stop "$CONTAINER"
    fi
  done

  # Remove containers, images, networks, and volumes
  for CONTAINER in $CONTAINERS; do
    # Check if container still exists
    if ! docker ps -a --format '{{.ID}}' | grep -q "^$CONTAINER$"; then
      echo "Container $CONTAINER does not exist, skipping."
      continue
    fi

    # Get image ID
    local IMAGE_ID
    IMAGE_ID=$(docker inspect --format='{{.Image}}' "$CONTAINER")
    # Get user-defined networks (skip default ones)
    local NETWORKS
    NETWORKS=$(docker inspect --format='{{range $k, $v := .NetworkSettings.Networks}}{{if not (or (eq $k "bridge") (eq $k "host") (eq $k "none"))}}{{$k}} {{end}}{{end}}' "$CONTAINER")
    # Get attached volumes
    local VOLUMES
    VOLUMES=$(docker inspect --format='{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}' "$CONTAINER")

    echo "Removing container: $CONTAINER"
    docker rm -f "$CONTAINER"

    # Check and remove image
    if [ -n "$IMAGE_ID" ] && docker images -a --no-trunc --format '{{.ID}}' | grep -q "^$IMAGE_ID$"; then
      echo "Removing image: $IMAGE_ID"
      docker rmi -f "$IMAGE_ID"
    else
      echo "Image $IMAGE_ID does not exist or already removed."
    fi

    # Check and remove networks
    for NET in $NETWORKS; do
      if docker network ls --format '{{.Name}}' | grep -q "^$NET$"; then
        echo "Removing network: $NET"
        docker network rm "$NET"
      else
        echo "Network $NET does not exist or already removed."
      fi
    done

    # Check and remove volumes
    for VOL in $VOLUMES; do
      if docker volume ls --format '{{.Name}}' | grep -q "^$VOL$"; then
        echo "Removing volume: $VOL"
        docker volume rm "$VOL"
      else
        echo "Volume $VOL does not exist or already removed."
      fi
    done
  done
}

# Call the function with the first argument
cleanup_containers_by_prefix "$(basename .)"
cleanup_containers_by_prefix "service_base"