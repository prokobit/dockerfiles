#!/bin/bash
# Tests for .github/scripts/{detect-changes,calculate-version}.sh.
# Each test builds a throwaway git repo and runs the scripts inside it.
# Usage: tests/run.sh

set -u

SCRIPTS="$(cd "$(dirname "$0")/../.github/scripts" && pwd)"
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
