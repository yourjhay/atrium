# Changelog

All notable changes to **Atrium** are documented here. This file lives in the public
[`atrium`](https://github.com/yourjhay/atrium) repo; the panel app itself stamps the
running version into `$PANEL_DIR/VERSION` on every install/update so the footer can
display it.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and Atrium adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_Nothing here yet._

---

## [1.4.0] — 2026-05-23

### Changed
- **Navbar redesign.** The topbar is now a floating glass pill that
  sits over a soft mauve/sapphire aurora wash, matching the rest of
  the panel's catppuccin theme. The current host shows next to the
  Atrium banner, the active tab is highlighted with a mauve pill,
  your email collapses into an avatar+name+email block that links to
  your profile, and the theme toggle and sign-out are now matching
  icon buttons. Mobile compresses the user text and host tag away so
  the row stays tidy on narrow screens.

---

## [1.3.1] — 2026-05-23

### Fixed
- Copy buttons across the panel (SSH connection string, database
  password, deploy public key) now work over plain HTTP — not just
  over HTTPS or localhost. Each button also gives visible "copied" /
  "copy failed" feedback for 1.5s instead of silently doing nothing.

---

## [1.3.0] — 2026-05-23

### Added
- **External SSH access per site.** Each site can now expose SSH login as
  its Linux user (`site_<name>`), locked to a per-site chroot jail at
  `/srv/jails/<u>/`. Pubkey-only authentication, multiple labeled keys
  managed via the new SSH Access tab. SFTP/SCP work alongside the shell.
  The browser terminal also runs inside the jail when SSH is enabled,
  giving consistent isolation across both access paths.

### Changed
- The "Terminal" tab is now "SSH Access". It contains the existing
  browser terminal on top and a new External SSH section below (toggle,
  copy-paste connection command, authorized-keys list, add-key form).
- Site delete now tears down any active SSH access and its chroot jail
  as part of the regular delete flow.

### Security
- Site users default to `/usr/sbin/nologin`. Enabling SSH temporarily
  flips the shell to `/bin/bash` and adds the user to a strictly-scoped
  `Match User` block in sshd config (chroot, no port-forwarding, no
  agent-forwarding, no TCP tunnel). Disabling restores nologin and
  truncates the user's `authorized_keys` so the next login attempt is
  refused before MOTD — no "account not available" theater, no leaked
  session.
- sshd config is always validated with `sshd -t` before reload, with
  automatic rollback to the previous drop-in on failure. A bad
  template cannot lock the host admin out.

---

## [1.2.1] — 2026-05-22

### Changed
- Dashboard poll interval simplified. The 10s/30s/60s selector has been
  removed and the dashboard now refreshes every 30 seconds. Faster polling
  fetched identical payloads between sampler ticks (metrics are written
  once per minute), so the choice was redundant.
- Dashboard health pill thresholds tightened. The pill now flips to
  "Attention" at **90% CPU** (was 95%), **80% RAM** (was 95%), or
  **80% disk** (was 95%) so capacity warnings appear before saturation
  rather than after.

---

## [1.2.0] — 2026-05-22

### Added
- **Server dashboard** at `/dashboard` — new live view showing host CPU, memory,
  and disk usage with KPI tiles and SVG line charts. Auto-polls fresh data via
  a vanilla-JS poller (no framework dependency). Replaces `/sites` as the
  default landing page for logged-in admins.
- **Per-minute metrics sampling** — new `panel-stats` privileged script reads
  `/proc` and `df` and emits JSON; the new `stats:sample` artisan command
  persists rows to the `server_metrics` table on a per-minute schedule.
- **Dashboard / Sites navigation** added to the top bar so the dashboard and
  the existing site list are both one click away from anywhere in the panel.
- `SERVER_METRICS.md` documentation covering the dashboard architecture, the
  sampler, and how to extend the metric set.

### Changed
- The root URL `/` now redirects logged-in users to `/dashboard` (previously
  `/sites`). The old route still works directly; only the redirect target
  changed.

### Fixed
- Dashboard SVG chart no longer emits a malformed `<path>` when a metric
  series has fewer than 2 samples — important on fresh installs before the
  first sampler tick lands.

---

## [1.1.3] — 2026-05-22

### Added
- **Footer on every panel page** showing the GitHub link (`yourjhay/atrium`) and the
  installed version, with an "update available: vX.Y.Z" pill when a newer release
  has been detected.
- **`$PANEL_DIR/VERSION`** stamped automatically by `install.sh` and `update.sh` from
  the source tree's git tag, so the panel app can render the version without shelling
  out to git on every request.

### Fixed
- Footer update-pill uses `version_compare` instead of plain string inequality, so a
  stale or manually-edited cache showing an older tag no longer triggers a false
  "update available" badge.

---

## [1.1.0] — 2026-05-22

### Added
- **`sudo atrium check`** subcommand — compares the local release tag against the
  remote (via cloudflared `ls-remote`) and reports whether a newer release is
  available. Supports `--quiet` (silent for cron) and `--refresh` (write the cache).
- **SSH login MOTD banner** at `/etc/update-motd.d/90-atrium` — prints
  `Atrium update available: vX → vY` on login when a newer tag is cached.
  Reads from cache only, so SSH never depends on the tunnel being up.
- **Daily refresh cron** at `/etc/cron.d/atrium-version-check` — runs `atrium check
  --quiet --refresh` at 04:17 to keep `/var/cache/atrium/latest-tag` current.
- `sudo atrium update` now writes the cache file post-pull so the MOTD banner clears
  immediately after an upgrade instead of lying until the next cron tick.

### Fixed
- `atrium check` and `atrium update` only wrap `git` in the cloudflared `ProxyCommand`
  when the remote URL is actually tunneled. Direct-SSH remotes (dev clones pointed at
  the soft-serve IP) no longer 502 on `ls-remote`/`pull`.
- `GIT_SSH_COMMAND=""` no longer overrides ssh with an empty string and breaks the
  call entirely — the wrapper now leaves the env var unset for non-tunneled remotes.
- `atrium check` survives an unreachable remote (tunnel down, auth failure) with a
  clear "no tags found on remote" message instead of an abrupt `set -e` exit 128.

---

## [1.0.1] — 2026-05-21

### Added
- **Version tag display** in `sudo atrium update` and `sudo atrium status`. `update`
  shows `version: vX → vY` on a bump (or `no change` otherwise); `status` gains a
  persistent `version:` line under the source path.

---

## [1.0.0] — 2026-05-21

Initial release.

### Highlights
- **Self-hosted multi-site control panel** for Ubuntu (22.04/24.04) and Debian (12/13)
  — provision PHP, Node.js, and static sites under their own Linux users, deploy from
  git, manage databases, run cron jobs and long-running workers, and get a browser
  shell from a single Laravel-driven web UI.
- **Apache + ModSecurity** as the frontend; **MariaDB** with per-site users and DBs;
  **PHP-FPM** with multiple versions (8.2 / 8.3 / 8.4) and per-site pools.
- **Privilege separation** — the Laravel app runs as an unprivileged `panel` user and
  performs every system change through `sudo panel-<verb>` scripts that validate
  their args against anchored regexes and `realpath -m`.
- **Per-site isolation** — each site gets a `site_<name>` Linux user, its own home
  under `/srv/sites/<user>/`, its own FPM pool, Apache vhost, optional Node systemd
  unit, worker units, cron entries, and MariaDB credentials.
- **Queue + scheduler** — `panel-queue.service` consumes Laravel jobs across
  `high,default,low` queues; `/etc/cron.d/panel-scheduler` fires `schedule:run`
  every minute. Long-running operations (deploys, DB imports) run as queued jobs
  with live UI progress.

### Installer / CLI
- **One-command install** via `curl -fsSL https://rjhon.net/ATRIUM.sh | sudo bash`.
- **`ATRIUM.sh` bootstrap** — provisions cloudflared + git, clones the source via the
  Cloudflare tunnel, installs `/usr/local/bin/atrium`, runs `install.sh`.
- **`install.sh` is idempotent** — re-running upgrades in place (apt updates, refreshes
  scripts/templates, runs new migrations).
- **`sudo atrium update`** — `git pull --ff-only` (via cloudflared) and run `update.sh`.
- **`sudo atrium status`** — source path, last commit, working tree, service status.
- **Service controls** — `restart [fpm|queue|apache|all]`, `logs <target>`, graceful
  `queue restart`, `queue failed|retry|monitor`, `password <email>` to reset/create
  admin credentials.
- **`atrium firewall show|install|refresh|remove`** — manage the panel-owned nftables
  table (default-deny inbound + SSH + 80/443). Enabled by default on fresh installs;
  opt out with `PANEL_NO_FIREWALL=1` at install time.
- **`sudo atrium artisan <args…>`** — run any artisan command as the `panel` user.

### UI
- **Catppuccin theme** (Latte light / Macchiato dark) with a per-device toggle that
  remembers the preference in `localStorage` and avoids a flash on page load.
- **Full UI redesign** — refactored site dashboard with a consistent header card on
  all tabs, themed scrollbars, animated modal entrances with proper focus traps and
  ARIA labelling, and a unified file editor capped at 90vh.
- **Workers tab** absorbs cron management — the legacy `/crons` route now redirects
  to `/workers#crons` so existing bookmarks keep working.
- **Per-site PHP shim** — `$SITE_HOME/bin/php` resolves to the version pinned to that
  site, so cron commands and shells get the right interpreter without `php8.X` calls.

### Distribution
- **Custom Docker base image** [`yourjhay/atrium-base:24.04`](https://hub.docker.com/r/yourjhay/atrium-base)
  with systemd as PID 1, multi-arch (amd64 + arm64), built for running the installer
  inside a container.
- **Three install methods** documented in the README — direct (`curl | sudo bash`),
  Docker container, virtual machine (OrbStack / Multipass).
- **Non-interactive mode** via `ATRIUM_NONINTERACTIVE=1` for fully-automated installs
  with sensible defaults.
