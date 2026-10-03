#!/bin/bash
# CI driver: build the images listed in a JSON array (already in dependency order)
# one after another, so dependents find their parent built earlier in the same run.
#
#   ci-build.sh '["img-a","img-b"]'
#
# Expects GITHUB_REPOSITORY_OWNER, GITHUB_REF, GITHUB_RUN_NUMBER (set by Actions).
# Images are pushed on master and when the ref is the matching <dir>-<version> tag.

set -e

PATHS_JSON="${1:-[]}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export IMAGE_PREFIX="ghcr.io/${GITHUB_REPOSITORY_OWNER,,}"
export USE_CACHE=true
rm -f .build-refs

for dir in $(jq -r '.[]' <<< "$PATHS_JSON"); do
  out=$(mktemp)
  GITHUB_OUTPUT="$out" "$ROOT/scripts/calculate-version.sh" "$dir" "${GITHUB_RUN_NUMBER:-}"
  VERSION=$(sed -n 's/^version=//p' "$out")

  PUSH=false
  if [ "${GITHUB_REF:-}" == "refs/heads/master" ] || [ "${GITHUB_REF:-}" == "refs/tags/${dir}-${VERSION}" ]; then
    PUSH=true
  fi

  VERSION="$VERSION" PUSH="$PUSH" "$ROOT/scripts/build.sh" "$dir"

  if [ -f "$dir/structure-test.yaml" ]; then
    tar_file=$(mktemp --suffix=.tar)
    podman save -o "$tar_file" "${IMAGE_PREFIX}/${dir}:${VERSION}"
    container-structure-test test --driver tar --image "$tar_file" --config "$dir/structure-test.yaml"
    rm -f "$tar_file"
  fi

  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    status="built (not pushed)"; [ "$PUSH" == "true" ] && status="built and pushed"
    echo "- \`${IMAGE_PREFIX}/${dir}:${VERSION}\`: ${status}" >> "$GITHUB_STEP_SUMMARY"
  fi
done
