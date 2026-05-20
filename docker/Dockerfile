# Atrium systemd-base image — multi-arch (linux/amd64, linux/arm64).
#
# Provides Ubuntu 24.04 with systemd running as PID 1, suitable for running
# the Atrium bootstrap installer (https://rjhon.net/ATRIUM.sh) inside a
# container so the install can do its `systemctl enable/restart` calls.
#
# Build (multi-arch, see ./build-and-push.sh for the wrapper):
#   docker buildx build --platform linux/amd64,linux/arm64 \
#       -t <user>/atrium-base:24.04 -t <user>/atrium-base:latest \
#       --push .
#
# Run:
#   docker run -d --name atrium --privileged --cgroupns=host \
#       --tmpfs /run --tmpfs /tmp --tmpfs /run/lock \
#       -p 80:80 -p 443:443 \
#       -e ATRIUM_NONINTERACTIVE=1 \
#       <user>/atrium-base:24.04
#
#   docker exec atrium bash -c '
#     curl -fsSL https://rjhon.net/ATRIUM.sh -o ATRIUM.sh && bash ATRIUM.sh
#   '

FROM ubuntu:24.04

ENV container=docker \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

# Install systemd as PID 1 + the bootstrap script's prerequisites.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        systemd systemd-sysv dbus \
        ca-certificates curl sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
              /var/cache/apt/archives/* \
              /var/log/*

# Mask units that don't work (or aren't useful) in a container — getty/console
# interactivity, FUSE/hugepages mounts that need real kernel privileges,
# display managers, and the graphical target.
RUN systemctl mask -- \
        dev-hugepages.mount \
        sys-fs-fuse-connections.mount \
        sys-kernel-config.mount \
        sys-kernel-debug.mount \
        display-manager.service \
        getty.target \
        graphical.target

# systemd uses SIGRTMIN+3 as the "shutdown cleanly" signal.
STOPSIGNAL SIGRTMIN+3

# Documentary — `docker run -p 80:80 -p 443:443` is still required to bind.
EXPOSE 80 443

# Real init. With --privileged, --cgroupns=host, and tmpfs mounts on
# /run + /tmp + /run/lock, systemd boots normally inside the container.
CMD ["/lib/systemd/systemd"]
