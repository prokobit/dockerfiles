# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Layout

Monorepo of container images. Each top-level directory (`img-a`, `img-b`, `img-c`) is one image: `Dockerfile`, `run.sh` (entrypoint, ends with `exec "$@"`), a **required** `version.txt`, and an optional `structure-test.yaml`. The build context is that directory only. Images are built with Podman (the scripts fall back to docker when podman is absent). There is no `bake`/buildx: everything must work with Podman.

Images that are built `FROM` another image of this repo declare `# depends-on: <dir>` in the Dockerfile header and take the parent via `ARG BASE_IMAGE`; only one parent is supported. `scripts/graph.sh` derives the dependency graph from those comments.

## Commands

```bash
make build-all        # all images, parents first
make build-img-a      # one image plus its ancestors
make lint             # hadolint (must be installed)
make test             # == tests/run.sh
```

`tests/run.sh` (plain bash, no dependencies) builds throwaway git repos and tests `graph.sh`, `detect-changes.sh`, `calculate-version.sh`, `build.sh` (with a fake container engine) and `prune-dev-tags.sh`. Add a case there when changing any of these scripts. It does not run real builds or the GitHub workflows.

## CI (`.github/workflows/` + `scripts/`)

`build.yml` runs on every push and manual dispatch: `detect-changes` -> (`lint`, `test-scripts`) -> `build`.

- `detect-changes.sh [path] [base_sha]` chooses what to build, in priority order:
  1. an explicit path (the `workflow_dispatch` input): only that dir
  2. a git tag `<dir>-<version>` on HEAD: only that dir (the longest matching dir name wins, `img-a` over `img`)
  3. otherwise, dirs with files changed since the base commit, plus all their transitive dependents. The base is `github.event.before`; for a new branch (zero SHA) the merge-base with master; otherwise `HEAD~1`.

  The result is a JSON array in build order (parents first).
- `calculate-version.sh` reads `<dir>/version.txt` (fails if missing or empty): `X.Y.Z` if tag `<dir>-X.Y.Z` is on HEAD, `X.Y.Z-dev.<run_number>` on master, `X.Y.Z` on other branches.
- `scripts/ci-build.sh` builds the array sequentially (so dependents find their parent), via `scripts/build.sh`, which passes `VERSION` and `BASE_IMAGE` build args and uses a registry cache at `<prefix>/cache/<dir>`. A parent not built in the same run resolves to `<prefix>/<parent>:<parent version.txt>`. Pushes to `ghcr.io/<lowercased owner>/<dir>` only on master or the matching tag. No `latest` and no SHA tags.
- `prune-dev-tags.yml` (weekly) deletes old `-dev.N` versions via `scripts/prune-dev-tags.sh`, keeping the newest 10 and never touching versions with a non-dev tag.

Release flow: bump `<dir>/version.txt`, merge to master (publishes `-dev.N`), then tag `<dir>-<version>` and push the tag to publish the clean version. Releasing a parent does not release its dependents.

## Gotchas

- Podman is not installed on every dev machine; docker is used as fallback, so the Podman code paths (`podman login`, `podman save`, `--cache-to`) are only exercised in CI.
- `.dockerignore` at the repo root is not used (build contexts are the subdirectories).
