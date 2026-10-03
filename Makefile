# Local entry point. Uses podman (falls back to docker); see scripts/build.sh.
# Images are auto-discovered; dependencies come from "# depends-on:" in Dockerfiles.

IMAGES := $(shell scripts/graph.sh images)

.PHONY: help build-all test lint
help:
	@echo "make build-all     build every image, parents first"
	@echo "make build-<dir>   build one image (and its ancestors)"
	@echo "make lint          hadolint every Dockerfile"
	@echo "make test          run CI script tests (tests/run.sh)"
	@echo "Images: $(IMAGES)"

build-all:
	@rm -f .build-refs
	@for d in $(IMAGES); do scripts/build.sh $$d || exit 1; done

build-%:
	@rm -f .build-refs
	@for d in $$(scripts/graph.sh ancestors $*) $*; do scripts/build.sh $$d || exit 1; done

lint:
	@for d in $(IMAGES); do echo "hadolint $$d"; hadolint $$d/Dockerfile || exit 1; done

test:
	tests/run.sh
