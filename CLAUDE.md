# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Layout

Monorepo of independent Docker images. Each top-level directory (`img-a`, `img-b`, `img-c`) is one image: `Dockerfile`, `run.sh` (entrypoint, ends with `exec "$@"`), and a **required** `version.txt`. The build context is that directory only. The images are currently Rocky Linux 10-minimal. There is no linter.

Test the CI scripts with `tests/run.sh` (plain bash, no dependencies). It builds throwaway git repos and runs `detect-changes.sh` and `calculate-version.sh` against them. Add a case there when changing either script.

Build locally:

```bash
cd img-a && docker build --build-arg VERSION=1.0.0 -t img-a . && docker run img-a <cmd>
```

## CI (`.github/workflows/build.yml` + `.github/scripts/`)

The workflow runs on every push and on manual dispatch. It has two stages, `detect-changes` and then a matrix `build` over the detected dirs. Any directory containing a `Dockerfile*` counts as an image.

- `detect-changes.sh` chooses what to build, in priority order:
  1. an explicit path (the `workflow_dispatch` input)
  2. a git tag `<dir>-<version>` on HEAD, which builds that dir
  3. otherwise, dirs with files changed in `HEAD~1..HEAD`

  Only the last commit is diffed, so changes in earlier commits of a multi-commit push are missed. When several dirs match a tag, the longest name wins (`img-a` over `img`).
- `calculate-version.sh` reads `<dir>/version.txt`. The script fails if the file is missing or empty, even though the README calls it optional. The resulting version is:
  - `X.Y.Z` if tag `<dir>-X.Y.Z` points at HEAD
  - `X.Y.Z-dev.<run_number>` on master
  - `X.Y.Z` on other branches
- The build is multi-arch (amd64/arm64) and passes `VERSION` as a build arg. It pushes to `ghcr.io/<owner>/<dir>` only on master or when the ref is the matching `<dir>-<version>` tag. Other branches build without pushing.

Release flow: bump `<dir>/version.txt`, merge to master (publishes `-dev.N`), then tag `<dir>-<version>` and push the tag to publish the clean version.

## Gotchas

- The README examples use `imgA`, but the real directory names are `img-a`, `img-b` and `img-c`.
- `.dockerignore` excludes `*.md` and `.github`, so don't rely on them in a build.
