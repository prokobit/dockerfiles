#!/bin/bash
# Tests for the scripts in scripts/.
# Each test builds a throwaway git repo and runs the scripts inside it.
# Usage: tests/run.sh

set -u

TOOLS="$(cd "$(dirname "$0")/../scripts" && pwd)"
SCRIPTS="$TOOLS"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

new_repo() {
  rm -rf "$WORK/repo"
  mkdir "$WORK/repo"
  cd "$WORK/repo" || exit 1
  git init -q -b master
  git config user.email t@example.com
  git config user.name test
  export GITHUB_OUTPUT="$WORK/output"
  : > "$GITHUB_OUTPUT"
}

add_image() { # dir [version]
  mkdir -p "$1"
  echo "FROM scratch" > "$1/Dockerfile"
  [ -n "${2:-}" ] && echo "$2" > "$1/version.txt"
}

commit() {
  git add -A
  git commit -q --allow-empty -m "${1:-c}"
}

output() { # key
  grep "^$1=" "$GITHUB_OUTPUT" | tail -1 | cut -d= -f2-
}

check() { # name expected actual
  if [ "$2" == "$3" ]; then
    PASS=$((PASS + 1))
    echo "ok   - $1"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL - $1"
    echo "       expected: $2"
    echo "       actual:   $3"
  fi
}

detect() { "$SCRIPTS/detect-changes.sh" "$@" >/dev/null 2>&1; echo $?; }
version() { "$SCRIPTS/calculate-version.sh" "$@" >/dev/null 2>&1; echo $?; }

depends_on() { # dir parent...  (rewrites the dir's Dockerfile header)
  local dir="$1"; shift
  printf '# depends-on: %s\nFROM scratch\n' "$*" > "$dir/Dockerfile"
}
graph() { "$TOOLS/graph.sh" "$@" 2>/dev/null | tr '\n' ' ' | sed 's/ $//'; }

# ---------- graph.sh ----------

new_repo
add_image img-a 1.0.0; add_image img-b 1.0.0; add_image img-c 1.0.0
depends_on img-a img-c
depends_on img-b img-a
commit first
check "graph: images are listed parents first" "img-c img-a img-b" "$(graph images)"
check "graph: closure adds transitive dependents in order" "img-c img-a img-b" "$(graph closure img-c)"
check "graph: closure of a leaf is itself" "img-b" "$(graph closure img-b)"
check "graph: ancestors in build order" "img-c img-a" "$(graph ancestors img-b)"
check "graph: parents are direct only" "img-a" "$(graph parents img-b)"
check "graph: closure of several dirs has no duplicates" "img-c img-a img-b" "$(graph closure img-a img-c)"

new_repo
add_image img-a 1.0.0; add_image img-b 1.0.0
depends_on img-a img-b
depends_on img-b img-a
commit first
"$TOOLS/graph.sh" images >/dev/null 2>&1
check "graph: cycle fails" 1 "$?"

new_repo
add_image img-a 1.0.0
depends_on img-a nope
commit first
"$TOOLS/graph.sh" images >/dev/null 2>&1
check "graph: unknown parent fails" 1 "$?"

# ---------- detect-changes.sh ----------

new_repo
add_image img-a 1.0.0; add_image img-b 1.0.0
commit first
echo x > img-a/file; commit second
detect >/dev/null
check "detect: only changed dir is built" '["img-a"]' "$(output paths)"

new_repo
add_image img-a 1.0.0; add_image img-b 1.0.0
commit first
echo x > README.md; commit docs
detect >/dev/null
check "detect: root-only change builds nothing" '[]' "$(output paths)"

new_repo
add_image img-a 1.0.0; add_image img-b 1.0.0
commit first
echo x > img-a/f; echo x > img-b/f; commit both
detect >/dev/null
check "detect: multiple dirs produce JSON array" '["img-a","img-b"]' "$(output paths)"

new_repo
add_image img-a 1.0.0
commit first
detect >/dev/null
check "detect: first commit builds all its images" '["img-a"]' "$(output paths)"

new_repo
add_image img-a 1.0.0; add_image img-b 1.0.0
commit first
echo x > README.md; commit docs
detect img-b >/dev/null
check "detect: explicit path wins over diff" '["img-b"]' "$(output paths)"

new_repo
add_image img-a 1.0.0
commit first
check "detect: explicit path without Dockerfile fails" 1 "$(detect nope)"

new_repo
add_image img-a 1.0.0; add_image img-b 1.0.0
commit first
echo x > README.md; commit docs
git tag img-b-1.0.0
detect >/dev/null
check "detect: tag on HEAD selects its dir" '["img-b"]' "$(output paths)"

new_repo
add_image img-a 1.0.0
commit first
git tag unknown-1.0.0
check "detect: tag matching no dir fails" 1 "$(detect)"

new_repo
add_image img 1.0.0; add_image img-a 1.0.0
commit first
git tag img-a-1.0.0
detect >/dev/null
check "detect: tag for img-a must not resolve to img (prefix collision)" '["img-a"]' "$(output paths)"

new_repo
add_image base 1.0.0; add_image app 1.0.0; add_image other 1.0.0
depends_on app base
commit first
echo x > base/f; commit change-base
detect >/dev/null
check "detect: dependents of a changed image are added, parents first" '["base","app"]' "$(output paths)"

new_repo
add_image base 1.0.0; add_image app 1.0.0
depends_on app base
commit first
echo x > app/f; commit change-app
detect >/dev/null
check "detect: changing a dependent does not rebuild its parent" '["app"]' "$(output paths)"

new_repo
add_image base 1.0.0; add_image app 1.0.0
depends_on app base
commit first
git tag base-1.0.0
detect >/dev/null
check "detect: tag release of a parent does not release dependents" '["base"]' "$(output paths)"

new_repo
add_image img-a 1.0.0; add_image img-b 1.0.0
commit first
BASE=$(git rev-parse HEAD)
echo x > img-a/f; commit one
echo x > img-b/f; commit two
"$SCRIPTS/detect-changes.sh" "" "$BASE" >/dev/null 2>&1
check "detect: base SHA covers every commit of a push" '["img-a","img-b"]' "$(output paths)"

new_repo
add_image img-a 1.0.0; add_image img-b 1.0.0
commit first
git checkout -q -b feature/x
echo x > img-a/f; commit one
echo x > img-b/f; commit two
"$SCRIPTS/detect-changes.sh" "" "0000000000000000000000000000000000000000" >/dev/null 2>&1
check "detect: new branch (zero base) diffs against merge-base with master" '["img-a","img-b"]' "$(output paths)"

new_repo
add_image img-a 1.0.0; add_image img-b 1.0.0
commit first
echo x > img-a/f; commit one
echo x > img-b/f; commit two
"$SCRIPTS/detect-changes.sh" "" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" >/dev/null 2>&1
check "detect: unknown base SHA falls back to parent commit" '["img-b"]' "$(output paths)"

# ---------- build.sh ----------

# Fake engine that records its invocations
printf '#!/bin/bash\necho "$@" >> "$FAKE_LOG"\n' > "$WORK/fake-engine"
chmod +x "$WORK/fake-engine"
build() { FAKE_LOG="$WORK/engine.log" CONTAINER_ENGINE="$WORK/fake-engine" "$TOOLS/build.sh" "$@" >/dev/null 2>&1; }
base_image() { grep -o 'BASE_IMAGE=[^ ]*' "$WORK/engine.log" | cut -d= -f2; }

new_repo
add_image img-a 1.0.0
commit first
: > "$WORK/engine.log"
VERSION=1.0.0-dev.5 IMAGE_PREFIX=ghcr.io/me build img-a
check "build: tags image with prefix and version" "build --build-arg VERSION=1.0.0-dev.5 -t ghcr.io/me/img-a:1.0.0-dev.5 img-a" "$(cat "$WORK/engine.log")"

: > "$WORK/engine.log"
VERSION=1.0.0 IMAGE_PREFIX=ghcr.io/me build img-a
check "build: does not push by default" "" "$(grep '^push' "$WORK/engine.log")"

: > "$WORK/engine.log"
VERSION=1.0.0 PUSH=true IMAGE_PREFIX=ghcr.io/me build img-a
check "build: pushes when PUSH=true" "push ghcr.io/me/img-a:1.0.0" "$(grep '^push' "$WORK/engine.log")"

: > "$WORK/engine.log"
USE_CACHE=true IMAGE_PREFIX=ghcr.io/me build img-a
check "build: cache flags use <prefix>/cache/<dir>" "1" "$(grep -c -- '--cache-from ghcr.io/me/cache/img-a --cache-to ghcr.io/me/cache/img-a' "$WORK/engine.log")"

new_repo
add_image base 2.0.0; add_image app 1.0.0
depends_on app base
commit first
: > "$WORK/engine.log"
VERSION=1.0.0-dev.9 IMAGE_PREFIX=ghcr.io/me build app
check "build: unbuilt parent resolves to its version.txt" "ghcr.io/me/base:2.0.0" "$(base_image)"

: > "$WORK/engine.log"
rm -f .build-refs
VERSION=2.0.0-dev.9 IMAGE_PREFIX=ghcr.io/me build base
VERSION=1.0.0-dev.9 IMAGE_PREFIX=ghcr.io/me build app
check "build: parent built in the same run is used" "ghcr.io/me/base:2.0.0-dev.9" "$(base_image)"

new_repo
add_image p1 1.0.0; add_image p2 1.0.0; add_image app 1.0.0
depends_on app p1 p2
commit first
build app
check "build: several parents are rejected" 1 "$?"

# ---------- prune-dev-tags.sh ----------

cat > "$WORK/versions.json" <<'JSON'
[
  {"id": 1, "created_at": "2026-01-01T00:00:00Z", "metadata": {"container": {"tags": ["1.0.0-dev.1"]}}},
  {"id": 2, "created_at": "2026-01-02T00:00:00Z", "metadata": {"container": {"tags": ["1.0.0-dev.2"]}}},
  {"id": 3, "created_at": "2026-01-03T00:00:00Z", "metadata": {"container": {"tags": ["1.0.0-dev.3"]}}},
  {"id": 4, "created_at": "2026-01-04T00:00:00Z", "metadata": {"container": {"tags": ["1.0.0"]}}},
  {"id": 5, "created_at": "2026-01-05T00:00:00Z", "metadata": {"container": {"tags": ["1.0.1-dev.4", "1.0.1"]}}},
  {"id": 6, "created_at": "2026-01-06T00:00:00Z", "metadata": {"container": {"tags": []}}}
]
JSON
prune() { DRY_RUN=true VERSIONS_FILE="$WORK/versions.json" "$TOOLS/prune-dev-tags.sh" pkg 2>&1 | sed 's/.*version //' | tr '\n' ' ' | sed 's/ $//'; }
check "prune: oldest dev versions beyond KEEP are selected" "2 1" "$(KEEP=1 prune)"
check "prune: released and untagged versions are never selected" "" "$(KEEP=10 prune)"

# ---------- calculate-version.sh ----------

new_repo
add_image img-a 1.2.3
commit first
git checkout -q -b feature/x
version img-a 42 >/dev/null
check "version: feature branch uses version.txt as-is" "1.2.3" "$(output version)"

new_repo
add_image img-a 1.2.3
commit first
version img-a 42 >/dev/null
check "version: master gets -dev.<build id>" "1.2.3-dev.42" "$(output version)"

new_repo
add_image img-a 1.2.3
commit first
check "version: master without build id fails" 1 "$(version img-a)"

new_repo
add_image img-a 1.2.3
commit first
git tag img-a-1.2.3
version img-a 42 >/dev/null
check "version: tag on HEAD gives clean version" "1.2.3" "$(output version)"

new_repo
add_image img-a 1.2.3
commit first
git tag img-a-1.2.3
commit later
version img-a 42 >/dev/null
check "version: tag on an older commit is ignored" "1.2.3-dev.42" "$(output version)"

new_repo
add_image img-a 1.2.3
commit first
git tag img-b-1.2.3
version img-a 42 >/dev/null
check "version: tag for another dir is ignored" "1.2.3-dev.42" "$(output version)"

new_repo
add_image img-a "  1.2.3  "
commit first
version img-a 7 >/dev/null
check "version: whitespace in version.txt is trimmed" "1.2.3-dev.7" "$(output version)"

new_repo
add_image img-a
commit first
check "version: missing version.txt fails" 1 "$(version img-a 1)"

new_repo
add_image img-a ""
: > img-a/version.txt
commit first
check "version: empty version.txt fails" 1 "$(version img-a 1)"

new_repo
check "version: missing path argument fails" 1 "$(version)"

echo
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
