#!/bin/bash

# Get the current active Docker context name
current_context=$(docker context ls --format "{{.Name}}" --filter "Current=true")

# Inspect the current context and extract the 'Type' field
context_type=$(docker context inspect "$current_context" --format "{{.Type}}")

# Check the type and print whether it's local or remote
if [ "$context_type" == "moby" ]; then
  echo "Docker context '$current_context' is local."
elif [ "$context_type" == "kubernetes" ]; then
  echo "Docker context '$current_context' is a Kubernetes context."
else
  echo "Docker context '$current_context' is remote (type: $context_type)."
fi
