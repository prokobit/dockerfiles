# Dockerfiles Monorepo

A monorepo containing multiple Dockerfiles with automated builds via GitHub Actions.

## Structure

Each Dockerfile should be in its own directory with the following structure:

```
project-name/
├── Dockerfile
├── (other files needed for the build)
└── README.md (optional)
```

## GitHub Actions Workflows

### Build Workflow (`build.yml`)

Automatically builds Docker images when:
- Dockerfiles are changed in pull requests or pushes to main/master
- Manually triggered via workflow_dispatch

**Features:**
- Detects changed Dockerfiles automatically
- Builds multi-platform images (linux/amd64, linux/arm64)
- Uses GitHub Container Registry (ghcr.io)
- Implements build caching for faster builds
- Only builds changed Dockerfiles on PRs/pushes
- Can build all or specific dockerfiles via manual trigger

**Manual Trigger:**
You can manually trigger the workflow and optionally specify a single Dockerfile path:
- Leave empty to build all dockerfiles
- Specify a path like `example/python-app` to build only that one

### Build All Workflow (`build-all.yml`)

Builds all Docker images:
- Runs daily at 2 AM UTC (scheduled)
- Can be manually triggered

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

3. Commit and push:
   ```bash
   git add my-project/
   git commit -m "Add my-project dockerfile"
   git push
   ```

4. The GitHub Action will automatically detect and build your new Dockerfile.

### Image Naming Convention

Images are published to GitHub Container Registry with the following naming:
- Registry: `ghcr.io`
- Owner: Your GitHub username/organization
- Image name: Directory path (e.g., `example/python-app` becomes `ghcr.io/username/example/python-app`)

### Tags

Images are tagged with:
- `latest` - Latest build from default branch
- `branch-name` - Branch name
- `branch-name-<sha>` - Branch name with commit SHA
- Semantic version tags (if using version tags)

## Examples

This repository includes example dockerfiles:
- `example/python-app` - Python Flask application
- `example/node-app` - Node.js Express application

## Local Development

To build a dockerfile locally:

```bash
cd example/python-app
docker build -t my-python-app .
docker run -p 8000:8000 my-python-app
```

## CI/CD Features

- ✅ Automatic detection of changed Dockerfiles
- ✅ Multi-platform builds (AMD64 and ARM64)
- ✅ Build caching for faster builds
- ✅ GitHub Container Registry integration
- ✅ Manual workflow triggers
- ✅ Scheduled builds for all images

## Contributing

1. Create a new directory for your Dockerfile
2. Add your Dockerfile and necessary files
3. Optionally add a README.md in your directory explaining the image
4. Commit and push - the workflow will handle the rest!

