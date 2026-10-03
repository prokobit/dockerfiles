# Dockerfiles Monorepo

Container images built with Podman and published to GitHub Container Registry by GitHub Actions.

## Structure

Each image lives in its own top-level directory:

```
img-a/
├── Dockerfile
├── version.txt            # required: base version, e.g. "1.0.0"
├── structure-test.yaml    # optional: container-structure-test checks run in CI
└── (other files needed for the build)
```

### Images that depend on other images

If an image is built `FROM` another image of this repo, declare it in the Dockerfile header and take the parent through `BASE_IMAGE`:

```dockerfile
# depends-on: img-a
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
```

The build passes the parent's reference as `BASE_IMAGE`. Only one parent per image is supported. Cycles and unknown parents fail the build.
When a parent changes, its dependents are rebuilt too, in dependency order.

## Local development

Requires `podman` (falls back to `docker` if podman is missing).

```bash
make build-all        # every image, parents first
make build-img-a      # one image plus its ancestors
make lint             # hadolint
make test             # tests for the CI scripts
```

Images are tagged `localhost/<dir>:dev`.

## CI (`.github/workflows/build.yml`)

On every push (or manual dispatch with an optional `path`):

1. `detect-changes.sh` finds changed image directories by diffing from the push's base commit (`github.event.before`; for new branches the merge-base with master), adds all images that depend on them, and returns them in build order.
   A tag `<dir>-<version>` on HEAD builds only that directory.
2. `lint` (hadolint) and `test-scripts` (`tests/run.sh`) run in parallel.
3. `scripts/ci-build.sh` builds the images one after another with Podman, runs `structure-test.yaml` if present, and pushes when appropriate. Layer cache is stored in the registry under `ghcr.io/<owner>/cache/<dir>`.

Images are published as `ghcr.io/<owner>/<dir>`; the owner is lowercased.

## Versions and tags

`<dir>/version.txt` holds the base version (required). The pushed tag is:

| Situation | Tag | Pushed |
|---|---|---|
| Git tag `<dir>-X.Y.Z` on HEAD | `X.Y.Z` | yes |
| Push to `master` | `X.Y.Z-dev.<run number>` | yes |
| Any other branch | `X.Y.Z` | no |

There is no `latest` tag and no SHA tag. The version is also passed to the Dockerfile as `ARG VERSION` (the images set it as the `org.opencontainers.image.version` label).

A dependent image whose parent was not rebuilt in the same run uses `<parent>:<parent's version.txt>`, i.e. the released version of the parent.

### Release

```bash
echo "1.0.1" > img-a/version.txt
git commit -am "Bump img-a to 1.0.1" && git push   # merge to master: publishes 1.0.1-dev.N
git tag img-a-1.0.1 && git push origin img-a-1.0.1  # publishes 1.0.1
```

Releasing a parent does not release its dependents.

## Maintenance

- `prune-dev-tags.yml` runs weekly and deletes old `-dev.N` versions, keeping the newest 10 per image. Versions that have any non-dev tag are never deleted.
- `renovate.json` configures Renovate to update base images and GitHub Actions (requires the Renovate GitHub app).

## Adding an image

1. Create `my-image/` with a `Dockerfile` and `version.txt`.
2. Optionally add `# depends-on:` and `structure-test.yaml`.
3. Commit and push; CI picks it up automatically.
