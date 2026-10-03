#!/bin/bash
# Delete old "-dev.N" versions of ghcr.io container packages, keeping the newest N per package.
# A version is only pruned if ALL its tags look like X.Y.Z-dev.N, so released versions are safe.
#
#   prune-dev-tags.sh <package>...
#
# Environment:
#   OWNER        package owner (user or org)
#   OWNER_TYPE   "User" or "Organization" (default: User)
#   KEEP         dev versions to keep per package (default: 10)
#   DRY_RUN      "true" to only print what would be deleted
#   VERSIONS_FILE  read the versions JSON from this file instead of the API (for tests)
# Needs the gh CLI authenticated with a token that can delete packages.

set -e

KEEP="${KEEP:-10}"
case "${OWNER_TYPE:-User}" in
  Organization|organization|org) BASE="orgs" ;;
  *) BASE="users" ;;
esac

# stdin: versions JSON array from the packages API; prints ids to delete (oldest beyond KEEP)
select_ids() {
  jq -r --argjson keep "$KEEP" '
    [ .[]
      | select((.metadata.container.tags | length) > 0)
      | select(.metadata.container.tags | all(test("-dev\\.[0-9]+$")))
    ]
    | sort_by(.created_at) | reverse
    | .[$keep:][]
    | .id'
}

for pkg in "$@"; do
  if [ -n "${VERSIONS_FILE:-}" ]; then
    ids=$(select_ids < "$VERSIONS_FILE")
  else
    ids=$(gh api --paginate "/${BASE}/${OWNER}/packages/container/${pkg}/versions" | jq -s 'add // []' | select_ids)
  fi
  for id in $ids; do
    if [ "${DRY_RUN:-}" == "true" ]; then
      echo "would delete ${pkg} version ${id}"
    else
      echo "deleting ${pkg} version ${id}"
      gh api -X DELETE "/${BASE}/${OWNER}/packages/container/${pkg}/versions/${id}"
    fi
  done
done
