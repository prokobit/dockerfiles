#!/bin/bash

set -e

# Path parameter (optional)
INPUT_PATH="$1"

# Function to find all dockerfiles
find_all_dockerfiles() {
  find . -type f -name "Dockerfile*" \
    -not -path "./.git/*" \
    -not -path "./.github/*" \
    -exec dirname {} \; | \
    sort -u | \
    sed 's|^\./||' | \
    grep -v '^$'
}

# Function to create JSON array from list
create_json_array() {
  echo -n '['
  first=true
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      if [ "$first" = true ]; then
        first=false
      else
        echo -n ','
      fi
      echo -n "\"$line\""
    fi
  done
  echo -n ']'
}

# If path is provided, use it
if [ -n "$INPUT_PATH" ]; then
  DOCKERFILE_PATH="$INPUT_PATH"
  if [ -f "$DOCKERFILE_PATH/Dockerfile" ] || [ -f "$DOCKERFILE_PATH/dockerfile" ]; then
    DOCKERFILES_JSON="[\"$DOCKERFILE_PATH\"]"
  else
    echo "Error: Dockerfile not found at $DOCKERFILE_PATH"
    exit 1
  fi
else
  # Detect any changed files in subfolders
  # Check if it's a PR by checking if GITHUB_BASE_REF is set
  if [ -n "$GITHUB_BASE_REF" ]; then
    # Pull request
    CHANGED_FILES=$(git diff --name-only origin/$GITHUB_BASE_REF...HEAD 2>/dev/null || true)
  else
    # Push event
    BASE_SHA="$GITHUB_BEFORE"
    HEAD_SHA="$GITHUB_SHA"
    if [ -n "$BASE_SHA" ] && [ "$BASE_SHA" != "0000000000000000000000000000000000000000" ]; then
      CHANGED_FILES=$(git diff --name-only $BASE_SHA $HEAD_SHA 2>/dev/null || true)
    else
      # First commit or no base, no changes detected
      CHANGED_FILES=""
    fi
  fi
  
  if [ -z "$CHANGED_FILES" ]; then
    # No changes detected, build nothing
    DOCKERFILES_JSON="[]"
  else
    # Get all directories with Dockerfiles
    ALL_DOCKERFILE_DIRS=$(find_all_dockerfiles)
    
    # Check which dockerfile directories have changes
    DOCKERFILES_TO_BUILD=""
    while IFS= read -r dir; do
      if [ -n "$dir" ]; then
        # Check if any changed file is in this directory or its subdirectories
        if echo "$CHANGED_FILES" | grep -q "^${dir}/"; then
          DOCKERFILES_TO_BUILD="${DOCKERFILES_TO_BUILD}${dir}"$'\n'
        fi
      fi
    done <<< "$ALL_DOCKERFILE_DIRS"
    
    if [ -z "$DOCKERFILES_TO_BUILD" ]; then
      DOCKERFILES_JSON="[]"
    else
      DOCKERFILES_JSON=$(echo "$DOCKERFILES_TO_BUILD" | grep -v '^$' | sort -u | create_json_array)
    fi
  fi
fi

echo "dockerfiles=$DOCKERFILES_JSON" >> $GITHUB_OUTPUT
echo "Dockerfiles to build: $DOCKERFILES_JSON"

