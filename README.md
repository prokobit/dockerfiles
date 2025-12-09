# Dockerfiles Monorepo

A monorepo containing multiple Dockerfiles with automated builds via GitHub Actions.

## Structure

Each Dockerfile should be in its own directory with the following structure:

```
project-name/
├── Dockerfile
├── version.txt          # Optional: version for tagging (e.g., "1.0.0")
├── (other files needed for the build)
└── README.md            # Optional
```

## GitHub Actions Workflow

### Build Workflow (`build.yml`)

Automatically builds Docker images when files change in any subfolder directory.

**Features:**
- ✅ Detects ANY changes in subfolders (not just Dockerfile changes)
- ✅ Only builds directories that contain Dockerfiles and have changes
- ✅ Builds multi-platform images (linux/amd64, linux/arm64)
- ✅ Uses GitHub Container Registry (ghcr.io)
- ✅ Implements build caching for faster builds
- ✅ Automatic version tagging from `version.txt`
- ✅ Manual workflow triggers with optional path parameter

**How it works:**
1. Detects what changed in the current commit
2. Finds all directories containing Dockerfiles
3. Builds only directories that have changes
4. Extracts version from `version.txt` (if present) and tags the image
5. Pushes images to GitHub Container Registry (only on master branch)

**Manual Trigger:**
You can manually trigger the workflow and optionally specify a single directory path:
- Leave empty to detect and build all changed directories
- Specify a path like `img1` to build only that directory

## Usage

### Adding a New Dockerfile

1. Create a new directory for your project:
   ```bash
   mkdir -p my-project
   ```

2. Add your `Dockerfile` and any necessary files:
   ```bash
   cd my-project
   # Add Dockerfile and other files
   ```

3. (Optional) Add a `version.txt` file with your version:
   ```bash
   echo "1.0.0" > version.txt
   ```

4. Commit and push:
   ```bash
   git add my-project/
   git commit -m "Add my-project dockerfile"
   git push
   ```

5. The GitHub Action will automatically detect and build your new Dockerfile.

### Version Management

Each directory can have a `version.txt` file containing the version number (e.g., `1.0.0`). This version will be used to tag the Docker image.

**To update a version:**
```bash
echo "1.0.1" > imgA/version.txt
git add imgA/version.txt
git commit -m "Bump imgA to 1.0.1"
git push
```

The workflow will automatically detect the change and rebuild the image with the new version tag.

### Image Naming Convention

Images are published to GitHub Container Registry with the following naming:
- Registry: `ghcr.io`
- Owner: Your GitHub username/organization
- Image name: Directory path (e.g., `imgA` becomes `ghcr.io/username/imgA`)

### Tags

Images are tagged with:
- **Version tag** (from `version.txt`) - e.g., `1.0.0` (if version.txt exists)
- **Branch name** - e.g., `feature-branch`
- **Branch + SHA** - e.g., `feature-branch-a1b2c3d`
- **Latest** - Only on default branch (master)

Example: If `imgA/version.txt` contains `1.0.0`, the image will be tagged as:
- `ghcr.io/username/imgA:1.0.0`


### Using Version in Dockerfile

The version is passed as a build argument `VERSION` to your Dockerfile. You can use it like this:

```dockerfile
ARG VERSION
LABEL version="$VERSION"

# Your Dockerfile content...
```

## Local Development

To build a dockerfile locally:

```bash
cd imgA
docker build -t my-imgA .
docker run my-imgA
```

## CI/CD Features

- ✅ Automatic change detection (any file change in subfolder triggers build)
- ✅ Multi-platform builds (AMD64 and ARM64)
- ✅ Build caching for faster builds
- ✅ GitHub Container Registry integration
- ✅ Manual workflow triggers
- ✅ Version tagging from `version.txt`
- ✅ Version passed as build argument to Dockerfile

## How Change Detection Works

The workflow detects changes by:
1. Comparing the current commit (HEAD) with its parent (HEAD~1)
2. Finding all directories that contain Dockerfiles
3. Checking if any changed files are in those directories
4. Building only directories with changes

**Important:** If no changes are detected, nothing is built. The workflow will not build all images by default.

## Contributing

1. Create a new directory for your Dockerfile
2. Add your Dockerfile and necessary files
3. Optionally add a `version.txt` file with your version
4. Optionally add a README.md in your directory explaining the image
5. Commit and push - the workflow will automatically detect and build!
