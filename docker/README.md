# Atrium systemd-base Docker image

A minimal Ubuntu 24.04 image with **systemd running as PID 1**, designed for running the [Atrium](../ATRIUM.md) bootstrap installer inside a container.

The Atrium installer calls `systemctl enable/restart` for panel-fpm, mariadb, apache2, php-fpm, etc. Vanilla `ubuntu` images don't have systemd as PID 1, so those calls fail with:

```
System has not been booted with systemd as init system (PID 1).
```

This image fixes that. Multi-arch: **linux/amd64** + **linux/arm64**.

---

## Usage

```bash
docker run -d --name atrium \
  --privileged \
  --cgroupns=host \
  --tmpfs /run --tmpfs /tmp --tmpfs /run/lock \
  -p 80:80 -p 443:443 \
  -e ATRIUM_NONINTERACTIVE=1 \
  yourjhay/atrium-base:24.04

sleep 5  # let systemd settle

docker exec atrium bash -c '
  curl -fsSL https://rjhon.net/ATRIUM.sh -o ATRIUM.sh && bash ATRIUM.sh
'
```

Login at <http://atrium.local> with `admin@atrium.local` / `password`.

> **Heads-up:** add `127.0.0.1 atrium.local` to your host's `/etc/hosts` so the browser can resolve the panel.

---

## Build + publish

Requires `docker buildx` (built into Docker Desktop / OrbStack) and a `docker login` against Docker Hub.

```bash
# Log in first (one-time)
docker login

# Build + push with defaults (yourjhay/atrium-base:24.04 + :latest, both archs)
./build-and-push.sh

# Customise
IMAGE=youruser/atrium-base ./build-and-push.sh
PLATFORMS=linux/amd64 ./build-and-push.sh         # single-arch
LATEST_TAG=0 ./build-and-push.sh                  # skip the :latest tag
```

The script:

1. Verifies `docker buildx` is available and you're logged in.
2. Creates a buildx builder (`atrium-builder`) if missing.
3. Builds for `linux/amd64,linux/arm64`.
4. Pushes both tags (`:$TAG` and `:latest` by default).

---

## What's installed

| Package | Purpose |
|---|---|
| `systemd`, `systemd-sysv`, `dbus` | PID 1 + service management |
| `ca-certificates` | TLS roots so `curl` can reach pkg.cloudflare.com etc. |
| `curl` | Download the bootstrap script |
| `sudo` | The bootstrap drops to the `panel` user via sudo |

Nothing Atrium-specific is baked in — the bootstrap downloads everything else (cloudflared, git, PHP, MariaDB, the source itself) at install time. This keeps the image small and lets you rebuild Atrium without rebuilding the base image.

---

## Image size

Roughly **80 MB compressed**. The `ubuntu:24.04` base layer (~30 MB) is shared with anything else you're pulling.

---

## Maintenance

- **Security updates** — rebuild + re-push periodically. `apt-get update` runs as part of every build, so each push picks up the latest patched packages.
- **Ubuntu version bump** — pinned to 24.04 for now. To add another base (e.g. 22.04 jammy), change the `FROM ubuntu:24.04` line in `Dockerfile` and adjust the tag.
- **Automated rebuilds** — Docker Hub's automated builds can be wired to a webhook on this repo if you want it hands-off.
