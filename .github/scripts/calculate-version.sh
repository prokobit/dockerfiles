#!/bin/bash

set -e

# Parameters
PATH_DIR="$1"
BUILD_ID="$2"

if [ -z "$PATH_DIR" ]; then
  echo "Error: Path directory is required"
  exit 1
fi

VERSION_FILE="./${PATH_DIR}/version.txt"
if [ -f "$VERSION_FILE" ]; then
  BASE_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
  if [ -z "$BASE_VERSION" ]; then
    echo "Error: version.txt is empty"
    exit 1
  fi
else
  echo "Error: version.txt not found in ${PATH_DIR}/"
  echo "Version file is required for tagging"
  exit 1
fi

# Check if there's a git tag matching path-version format
TAG_PATTERN="${PATH_DIR}-${BASE_VERSION}"
# Only consider tag as "active" if it points at the current commit (HEAD)
if git tag --points-at HEAD | grep -Fxq "${TAG_PATTERN}"; then
  # Tag exists on current commit, use the base version
  FINAL_VERSION="$BASE_VERSION"
  echo "Found git tag on current commit: ${TAG_PATTERN}, using version: $FINAL_VERSION"
elif [ "$(git rev-parse --abbrev-ref HEAD)" == "master" ]; then
  # On master branch, use version-dev.BUILD_ID format
  if [ -z "$BUILD_ID" ]; then
    echo "Error: BUILD_ID is required for master branch"
    exit 1
  fi
  FINAL_VERSION="${BASE_VERSION}-dev.${BUILD_ID}"
  echo "On master branch, using dev version: $FINAL_VERSION"
else
  # Use base version from file
  FINAL_VERSION="$BASE_VERSION"
  echo "Using version from file: $FINAL_VERSION"
fi

echo "version=$FINAL_VERSION" >> $GITHUB_OUTPUT
echo "Final version: $FINAL_VERSION"

