#!/usr/bin/env bash
# Build + push the Atrium systemd-base image to Docker Hub (multi-arch).
#
# Usage:
#   ./build-and-push.sh                                # uses defaults below
#   IMAGE=youruser/atrium-base ./build-and-push.sh
#   PLATFORMS=linux/amd64 ./build-and-push.sh          # single-arch
#   LATEST_TAG=0 ./build-and-push.sh                   # skip the :latest tag
#
# Requires: docker buildx (built into Docker Desktop / OrbStack) and a prior
# `docker login` against Docker Hub.
#
# Currently pins Ubuntu 24.04 only. To add another base later, change the
# FROM line in Dockerfile.

set -euo pipefail

IMAGE="${IMAGE:-yourjhay/atrium-base}"
TAG="${TAG:-24.04}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
LATEST_TAG="${LATEST_TAG:-1}"
BUILDER="${BUILDER:-atrium-builder}"

log()  { printf '\033[1;34m[build]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ ok ]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

# Sanity checks
command -v docker >/dev/null 2>&1 || die "docker not installed"
docker buildx version >/dev/null 2>&1 \
    || die "docker buildx unavailable (need Docker Desktop 19.03+ or OrbStack)"

# Need to be logged in to push. `docker info` doesn't reliably print the
# username when a credential helper (Docker Desktop / OrbStack on macOS) is
# in use — so look at ~/.docker/config.json instead, which has a docker.io
# entry under "auths" either way.
DOCKER_CONFIG_DIR="${DOCKER_CONFIG:-$HOME/.docker}"
if [[ ! -f "$DOCKER_CONFIG_DIR/config.json" ]] \
    || ! grep -q -E 'docker\.io|index\.docker\.io' "$DOCKER_CONFIG_DIR/config.json"; then
    warn "couldn't confirm Docker Hub login via $DOCKER_CONFIG_DIR/config.json"
    warn "if the push fails with auth errors, run: docker login"
fi

# Ensure a multi-platform buildx builder exists.
if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
    log "creating buildx builder '$BUILDER'"
    docker buildx create --name "$BUILDER" --use --bootstrap >/dev/null
else
    docker buildx use "$BUILDER"
fi

# Assemble tag args.
TAGS=("-t" "$IMAGE:$TAG")
[[ "$LATEST_TAG" == "1" ]] && TAGS+=("-t" "$IMAGE:latest")

log "building $IMAGE:$TAG for $PLATFORMS"
docker buildx build \
    --platform "$PLATFORMS" \
    "${TAGS[@]}" \
    --push \
    "$(dirname "$0")"

ok "image pushed:"
ok "  $IMAGE:$TAG"
[[ "$LATEST_TAG" == "1" ]] && ok "  $IMAGE:latest"
