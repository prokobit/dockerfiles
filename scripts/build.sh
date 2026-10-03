#!/bin/bash
# Build (and optionally push) one image with podman. Run from the repository root.
#
#   build.sh <dir>
#
# Environment:
#   CONTAINER_ENGINE  podman (default); falls back to docker if podman is missing
#   IMAGE_PREFIX      registry/owner prefix, e.g. ghcr.io/me (default: localhost)
#   VERSION           image tag (default: dev)
#   PUSH              "true" to push after building
#   USE_CACHE         "true" to use a registry layer cache at <prefix>/cache/<dir>
#   BUILD_REFS        file recording "<dir>=<ref>" for every image built so far
#                     (default: .build-refs); dependents read their parent's ref from it
#
# A dependent image declares "# depends-on: <parent>" in its Dockerfile and receives
# the parent's image reference as build arg BASE_IMAGE. If the parent was not built in
# this run, <prefix>/<parent>:<contents of parent/version.txt> is used.

set -e

DIR="${1:-}"
[ -n "$DIR" ] || { echo "Usage: $0 <dir>" >&2; exit 2; }
[ -f "$DIR/Dockerfile" ] || { echo "Error: $DIR/Dockerfile not found" >&2; exit 1; }

ENGINE="${CONTAINER_ENGINE:-}"
if [ -z "$ENGINE" ]; then
  if command -v podman >/dev/null 2>&1; then ENGINE=podman; else ENGINE=docker; fi
fi

PREFIX="${IMAGE_PREFIX:-localhost}"
VERSION="${VERSION:-dev}"
REFS="${BUILD_REFS:-.build-refs}"
GRAPH="$(cd "$(dirname "$0")" && pwd)/graph.sh"
REF="${PREFIX}/${DIR}:${VERSION}"

args=(--build-arg "VERSION=${VERSION}" -t "$REF")

mapfile -t PARENTS < <("$GRAPH" parents "$DIR")
if [ "${#PARENTS[@]}" -gt 1 ]; then
  echo "Error: $DIR has several parents (${PARENTS[*]}); only one is supported (BASE_IMAGE)" >&2
  exit 1
fi
if [ "${#PARENTS[@]}" -eq 1 ]; then
  PARENT="${PARENTS[0]}"
  PARENT_REF=""
  [ -f "$REFS" ] && PARENT_REF=$(grep "^${PARENT}=" "$REFS" | tail -1 | cut -d= -f2- || true)
  if [ -z "$PARENT_REF" ]; then
    PARENT_VERSION=$(tr -d '[:space:]' < "$PARENT/version.txt")
    PARENT_REF="${PREFIX}/${PARENT}:${PARENT_VERSION}"
  fi
  echo "Parent image: $PARENT_REF"
  args+=(--build-arg "BASE_IMAGE=${PARENT_REF}")
fi

if [ "${USE_CACHE:-}" == "true" ]; then
  CACHE="${PREFIX}/cache/${DIR}"
  args+=(--layers --cache-from "$CACHE" --cache-to "$CACHE")
fi

echo "Building $REF with $ENGINE"
"$ENGINE" build "${args[@]}" "$DIR"

echo "${DIR}=${REF}" >> "$REFS"

if [ "${PUSH:-}" == "true" ]; then
  echo "Pushing $REF"
  "$ENGINE" push "$REF"
fi
