#!/bin/bash
# Image dependency graph, derived from "# depends-on: <dir> [<dir>...]" comments
# in each Dockerfile. Run from the repository root.
#
#   graph.sh images               all image dirs, parents before dependents
#   graph.sh parents <dir>        direct parents of <dir>
#   graph.sh ancestors <dir>      all transitive parents of <dir>, in build order
#   graph.sh closure <dir>...     the dirs plus all transitive dependents, in build order

set -e

find_images() {
  find . -type f -name "Dockerfile*" \
    -not -path "./.git/*" \
    -not -path "./.github/*" \
    -exec dirname {} \; | sed 's|^\./||' | grep -v '^$' | sort -u
}

dockerfile_of() {
  if [ -f "$1/Dockerfile" ]; then echo "$1/Dockerfile"; else echo "$1/dockerfile"; fi
}

declare -A PARENTS
IMAGES=()

load() {
  local dir file deps
  mapfile -t IMAGES < <(find_images)
  for dir in "${IMAGES[@]}"; do
    file=$(dockerfile_of "$dir")
    deps=$(sed -nE 's/^#[[:space:]]*depends-on:[[:space:]]*(.*)$/\1/p' "$file" | tr -s ' \t' '\n\n' | grep -v '^$' | sort -u | tr '\n' ' ')
    PARENTS[$dir]="${deps% }"
    for dep in ${PARENTS[$dir]}; do
      if ! printf '%s\n' "${IMAGES[@]}" | grep -Fxq "$dep"; then
        echo "Error: $dir depends on unknown image '$dep'" >&2
        exit 1
      fi
    done
  done
}

# Kahn's algorithm; prints every image, parents first. Fails on cycles.
topo_order() {
  local dir dep placed=0 progress ready
  declare -A done_
  while [ "$placed" -lt "${#IMAGES[@]}" ]; do
    progress=0
    for dir in "${IMAGES[@]}"; do
      [ -n "${done_[$dir]:-}" ] && continue
      ready=1
      for dep in ${PARENTS[$dir]}; do
        [ -z "${done_[$dep]:-}" ] && ready=0
      done
      if [ "$ready" -eq 1 ]; then
        echo "$dir"
        done_[$dir]=1
        placed=$((placed + 1))
        progress=1
      fi
    done
    if [ "$progress" -eq 0 ]; then
      echo "Error: dependency cycle among: $(for dir in "${IMAGES[@]}"; do [ -z "${done_[$dir]:-}" ] && echo -n "$dir "; done)" >&2
      exit 1
    fi
  done
}

# Dirs reachable from the seeds by walking edges. Direction: "up" = parents, "down" = dependents.
reach() {
  local direction="$1"; shift
  declare -A seen
  local queue=("$@") dir cand dep
  for dir in "$@"; do seen[$dir]=1; done
  while [ "${#queue[@]}" -gt 0 ]; do
    dir="${queue[0]}"; queue=("${queue[@]:1}")
    if [ "$direction" == "up" ]; then
      for dep in ${PARENTS[$dir]}; do
        if [ -z "${seen[$dep]:-}" ]; then seen[$dep]=1; queue+=("$dep"); fi
      done
    else
      for cand in "${IMAGES[@]}"; do
        for dep in ${PARENTS[$cand]}; do
          if [ "$dep" == "$dir" ] && [ -z "${seen[$cand]:-}" ]; then seen[$cand]=1; queue+=("$cand"); fi
        done
      done
    fi
  done
  printf '%s\n' "${!seen[@]}"
}

require_image() {
  if ! printf '%s\n' "${IMAGES[@]}" | grep -Fxq "$1"; then
    echo "Error: unknown image '$1'" >&2
    exit 1
  fi
}

filter_in_order() { # reads wanted dirs on stdin, prints them in topological order
  local wanted
  wanted=$(cat)
  topo_order | grep -Fx -f <(echo "$wanted") || true
}

cmd="${1:-}"; shift || true
load

case "$cmd" in
  images)
    topo_order
    ;;
  parents)
    require_image "$1"
    tr ' ' '\n' <<< "${PARENTS[$1]}" | grep -v '^$' || true
    ;;
  ancestors)
    require_image "$1"
    reach up "$1" | grep -Fxv "$1" | filter_in_order
    ;;
  closure)
    for d in "$@"; do require_image "$d"; done
    reach down "$@" | filter_in_order
    ;;
  *)
    echo "Usage: $0 {images|parents <dir>|ancestors <dir>|closure <dir>...}" >&2
    exit 2
    ;;
esac
