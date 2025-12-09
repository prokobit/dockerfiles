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
    PATHS_JSON="[\"$DOCKERFILE_PATH\"]"
  else
    echo "Error: Dockerfile not found at $DOCKERFILE_PATH"
    exit 1
  fi
else
  # Detect any changed files in subfolders
  # Check what changed in the current commit (works for both push and PR)
  PARENT_SHA=$(git rev-parse HEAD~1 2>/dev/null || echo "")
  if [ -n "$PARENT_SHA" ]; then
    CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || true)
  else
    # First commit - show all files in the commit
    CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null || true)
  fi
  if [ -z "$CHANGED_FILES" ]; then
    # No changes detected, build nothing
    PATHS_JSON="[]"
  else
    # Get all directories with Dockerfiles
    ALL_DOCKERFILE_DIRS=$(find_all_dockerfiles)
    echo "All dockerfile directories:"
    echo "$ALL_DOCKERFILE_DIRS"
    echo "Changed files:"
    echo "$CHANGED_FILES"
    
    # Check which dockerfile directories have changes
    PATHS_TO_BUILD=""
    while IFS= read -r dir; do
      if [ -n "$dir" ]; then
        # Check if any changed file is in this directory (including subdirectories)
        # Match files like "img1/file" or "img1/subdir/file"
        if echo "$CHANGED_FILES" | grep -qE "^${dir}/|^${dir}$"; then
          echo "Found changes in directory: $dir"
          PATHS_TO_BUILD="${PATHS_TO_BUILD}${dir}"$'\n'
        fi
      fi
    done <<< "$ALL_DOCKERFILE_DIRS"
    
    if [ -z "$PATHS_TO_BUILD" ]; then
      PATHS_JSON="[]"
    else
      PATHS_JSON=$(echo "$PATHS_TO_BUILD" | grep -v '^$' | sort -u | create_json_array)
    fi
  fi
fi

echo "paths=$PATHS_JSON" >> $GITHUB_OUTPUT
echo "Paths to build: $PATHS_JSON"

