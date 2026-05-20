#!/usr/bin/env bash
# Build + push the Atrium systemd-base image to Docker Hub (multi-arch),
# then sync README.md to the repo's Docker Hub overview.
#
# Usage:
#   ./build-and-push.sh                                # uses defaults below
#   IMAGE=youruser/atrium-base ./build-and-push.sh
#   PLATFORMS=linux/amd64 ./build-and-push.sh          # single-arch
#   LATEST_TAG=0 ./build-and-push.sh                   # skip the :latest tag
#   PUSH_README=0 ./build-and-push.sh                  # skip the README sync
#   INSTALL_PUSHRM=0 ./build-and-push.sh               # don't auto-install docker-pushrm
#
# Requires: docker buildx (built into Docker Desktop / OrbStack) and a prior
# `docker login` against Docker Hub. The README sync uses docker-pushrm
# (https://github.com/christian-korneck/docker-pushrm), auto-installed on
# first run into ~/.docker/cli-plugins/ if not already present.
#
# Currently pins Ubuntu 24.04 only. To add another base later, change the
# FROM line in Dockerfile.

set -euo pipefail

IMAGE="${IMAGE:-yourjhay/atrium-base}"
TAG="${TAG:-24.04}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
LATEST_TAG="${LATEST_TAG:-1}"
BUILDER="${BUILDER:-atrium-builder}"
PUSH_README="${PUSH_README:-1}"
INSTALL_PUSHRM="${INSTALL_PUSHRM:-1}"
SHORT_DESCRIPTION="${SHORT_DESCRIPTION:-Ubuntu 24.04 + systemd as PID 1, for running the Atrium control panel installer.}"

log()  { printf '\033[1;34m[build]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ ok ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
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

# Push README.md to the Docker Hub repo description ("overview") so the page
# stops showing INCOMPLETE. Uses docker-pushrm, auto-installed if missing.
ensure_pushrm() {
    if docker pushrm --help >/dev/null 2>&1; then
        return 0
    fi
    if [[ "$INSTALL_PUSHRM" != "1" ]]; then
        warn "docker-pushrm not installed and INSTALL_PUSHRM=0 — skipping README sync"
        warn "  install manually from https://github.com/christian-korneck/docker-pushrm"
        return 1
    fi

    local os arch dest url
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$(uname -m)" in
        x86_64|amd64)   arch=amd64 ;;
        aarch64|arm64)  arch=arm64 ;;
        *) warn "unsupported arch '$(uname -m)' for docker-pushrm auto-install"; return 1 ;;
    esac

    dest="$DOCKER_CONFIG_DIR/cli-plugins/docker-pushrm"
    url="https://github.com/christian-korneck/docker-pushrm/releases/latest/download/docker-pushrm_${os}_${arch}"

    log "installing docker-pushrm (latest) to $dest"
    mkdir -p "$(dirname "$dest")"
    if ! curl -fsSL "$url" -o "$dest"; then
        warn "couldn't download docker-pushrm from $url — skipping README sync"
        rm -f "$dest"
        return 1
    fi
    chmod +x "$dest"
    if ! docker pushrm --help >/dev/null 2>&1; then
        warn "docker-pushrm installed at $dest but not callable — skipping README sync"
        return 1
    fi
}

push_readme() {
    if [[ "$PUSH_README" != "1" ]]; then
        log "PUSH_README=0 — skipping README sync"
        return 0
    fi

    local readme
    readme="$(dirname "$0")/README.md"
    if [[ ! -f "$readme" ]]; then
        warn "no README.md next to this script ($readme) — skipping README sync"
        return 0
    fi

    ensure_pushrm || return 0

    log "syncing $readme to Docker Hub overview for $IMAGE"
    if docker pushrm "$IMAGE" -f "$readme" -s "$SHORT_DESCRIPTION"; then
        ok "README synced to Docker Hub"
    else
        warn "README sync failed (image push already succeeded — overview will still say INCOMPLETE)"
    fi
}

push_readme
