#!/usr/bin/env bash
# Atrium external bootstrap installer.
#
# Hand this single file to anyone who needs to install the panel on a fresh
# Ubuntu 22.04/24.04 or Debian 12/13 host. It will:
#
#   1. Install cloudflared (stable channel, from pkg.cloudflare.com) so the
#      host can reach the source repo behind the Cloudflare Tunnel at
#      git-ssh.rjhon.net.
#   2. Install git, if missing.
#   3. Prompt for the panel domain, admin email, and admin password.
#   4. Clone git@git-ssh.rjhon.net:charm-cloud.git via `cloudflared access ssh`.
#   5. cd into the cloned repo and run ./install.sh with the gathered values.
#
# Usage on the target machine (download first, then run — don't pipe to bash,
# the interactive prompts won't work in that case):
#
#   curl -fsSL https://rjhon.net/ATRIUM.sh -o ATRIUM.sh
#   chmod +x ATRIUM.sh
#   sudo ./ATRIUM.sh
#
# Or with wget:
#   wget https://rjhon.net/ATRIUM.sh && chmod +x ATRIUM.sh && sudo ./ATRIUM.sh

set -euo pipefail

log()  { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ ok ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

# apt-get update with retries. Mirror sync windows on ports.ubuntu.com (and
# regional mirrors) produce transient "File has unexpected size" errors that
# would otherwise kill the bootstrap under `set -e`. Falls through with a
# warning after the final attempt — apt's cached metadata is usually enough.
apt_update_retry() {
    local tries=3 delay=5 attempt=1
    while (( attempt <= tries )); do
        if apt-get update -qq; then return 0; fi
        if (( attempt < tries )); then
            warn "apt-get update attempt ${attempt}/${tries} failed — retrying in ${delay}s"
            sleep "$delay"
        fi
        attempt=$(( attempt + 1 ))
    done
    warn "apt-get update failed ${tries}× — proceeding with cached metadata"
    return 0
}

REPO_HOST="git-ssh.rjhon.net"
REPO_REMOTE="git@${REPO_HOST}:charm-cloud.git"
CLONE_DIR_NAME="charm-cloud"
CLONE_TARGET="${PWD}/${CLONE_DIR_NAME}"

# -----------------------------------------------------------------------------
# Banner + welcome menu
# -----------------------------------------------------------------------------
banner() {
    # Catppuccin Mocha palette — https://catppuccin.com/palette/
    local C_MAUVE=$'\033[38;2;203;166;247m'    # A — mauve  #cba6f7
    local C_PINK=$'\033[38;2;245;194;231m'     # T — pink   #f5c2e7
    local C_RED=$'\033[38;2;243;139;168m'      # R — red    #f38ba8
    local C_PEACH=$'\033[38;2;250;179;135m'    # I — peach  #fab387
    local C_YELLOW=$'\033[38;2;249;226;175m'   # U — yellow #f9e2af
    local C_GREEN=$'\033[38;2;166;227;161m'    # M — green  #a6e3a1
    local C_CLOUD=$'\033[38;2;137;220;235m'    # clouds — sky #89dceb
    local C_SUB=$'\033[38;2;166;173;200m'      # subtitle — subtext1 #a6adc8
    local C_OFF=$'\033[0m'

    # Each letter as a 6-row block. Coloring is applied per letter so the
    # whole word reads as a rainbow rather than a single hue.
    local -a LA=(' █████╗ ' '██╔══██╗' '███████║' '██╔══██║' '██║  ██║' '╚═╝  ╚═╝')
    local -a LT=('████████╗' '╚══██╔══╝' '   ██║   ' '   ██║   ' '   ██║   ' '   ╚═╝   ')
    local -a LR=('██████╗ ' '██╔══██╗' '██████╔╝' '██╔══██╗' '██║  ██║' '╚═╝  ╚═╝')
    local -a LI=('██╗' '██║' '██║' '██║' '██║' '╚═╝')
    local -a LU=('██╗   ██╗' '██║   ██║' '██║   ██║' '██║   ██║' '╚██████╔╝' ' ╚═════╝ ')
    local -a LM=('███╗   ███╗' '████╗ ████║' '██╔████╔██║' '██║╚██╔╝██║' '██║ ╚═╝ ██║' '╚═╝     ╚═╝')

    clear 2>/dev/null || true
    printf '\n'
    printf '%s              .--.            .--.           .-.%s\n'        "$C_CLOUD" "$C_OFF"
    printf '%s          .-(    ).      .-(    )-.      .-(    ).%s\n'      "$C_CLOUD" "$C_OFF"
    printf '%s         (___.__)__)    (___.__)___)    (___.____)%s\n'      "$C_CLOUD" "$C_OFF"
    printf '\n'
    local i
    for i in 0 1 2 3 4 5; do
        printf '     %s%s%s%s%s%s%s%s%s%s%s%s%s\n' \
            "$C_MAUVE"  "${LA[$i]}" \
            "$C_PINK"   "${LT[$i]}" \
            "$C_RED"    "${LR[$i]}" \
            "$C_PEACH"  "${LI[$i]}" \
            "$C_YELLOW" "${LU[$i]}" \
            "$C_GREEN"  "${LM[$i]}" \
            "$C_OFF"
    done
    printf '\n'
    printf '%s           self-hosted multi-site control panel%s\n' "$C_SUB" "$C_OFF"
    printf '%s                  bootstrap installer%s\n\n'         "$C_SUB" "$C_OFF"
}

welcome_menu() {
    local C_OK=$'\033[1;32m'
    local C_NO=$'\033[1;31m'
    local C_DIM=$'\033[0;37m'
    local C_OFF=$'\033[0m'
    local choice=""

    echo "  This will install cloudflared + git, clone Atrium from"
    echo "  ${REPO_REMOTE}, and run the panel installer."
    echo
    echo "    ${C_OK}[I]${C_OFF} INSTALL    ${C_DIM}— proceed with the bootstrap${C_OFF}"
    echo "    ${C_NO}[C]${C_OFF} CANCEL     ${C_DIM}— exit without changing anything${C_OFF}"
    echo
    while :; do
        read -r -p "  Choose [I/C]: " choice
        case "${choice,,}" in
            i|install) return 0 ;;
            c|cancel|q|quit|"") echo; warn "cancelled by user"; exit 0 ;;
            *) warn "type 'I' to install or 'C' to cancel" ;;
        esac
    done
}

# Defaults used by both modes when the corresponding env var isn't provided
# and (in interactive mode) the user hits Enter at the prompt.
DEFAULT_PANEL_DOMAIN="atrium.local"
DEFAULT_ADMIN_EMAIL="admin@atrium.local"
DEFAULT_ADMIN_PASSWORD="password"

# Non-interactive mode — set ATRIUM_NONINTERACTIVE=1 to skip the banner menu
# and every prompt. Any of PANEL_DOMAIN / ADMIN_EMAIL / ADMIN_PASSWORD that
# isn't set in env falls back to the DEFAULT_* values above. Intended for
# Docker / CI / unattended installs.
NONINTERACTIVE="${ATRIUM_NONINTERACTIVE:-0}"
if [[ "$NONINTERACTIVE" == "1" ]]; then
    PANEL_DOMAIN="${PANEL_DOMAIN:-$DEFAULT_PANEL_DOMAIN}"
    ADMIN_EMAIL="${ADMIN_EMAIL:-$DEFAULT_ADMIN_EMAIL}"
    ADMIN_PASSWORD="${ADMIN_PASSWORD:-$DEFAULT_ADMIN_PASSWORD}"
    [[ "$ADMIN_EMAIL" == *@*.* ]]  || die "ADMIN_EMAIL must look like name@domain.tld"
    [[ ${#ADMIN_PASSWORD} -ge 8 ]] || die "ADMIN_PASSWORD must be at least 8 characters"
    log "non-interactive mode — skipping menu + prompts"
    log "using PANEL_DOMAIN=$PANEL_DOMAIN, ADMIN_EMAIL=$ADMIN_EMAIL"
    [[ "$ADMIN_PASSWORD" == "$DEFAULT_ADMIN_PASSWORD" ]] \
        && warn "using default admin password — change it in the panel UI after login"
else
    banner
    welcome_menu
fi

# -----------------------------------------------------------------------------
# Preflight
# -----------------------------------------------------------------------------
[[ $EUID -eq 0 ]] || die "must run as root (try: sudo bash $0)"

[[ -f /etc/os-release ]] || die "/etc/os-release missing — cannot identify distro"
# shellcheck source=/dev/null
. /etc/os-release
case "${ID:-}" in
    ubuntu)
        case "${VERSION_ID:-}" in
            22.04|24.04) ;;
            *) die "unsupported Ubuntu ${VERSION_ID:-?} (need 22.04 or 24.04)" ;;
        esac
        ;;
    debian)
        case "${VERSION_ID:-}" in
            12|13) ;;
            *) die "unsupported Debian ${VERSION_ID:-?} (need 12 or 13)" ;;
        esac
        ;;
    *)
        die "unsupported distro: ${ID:-?} (need Ubuntu 22.04/24.04 or Debian 12/13)"
        ;;
esac
CODENAME="${VERSION_CODENAME:-}"
[[ -n "$CODENAME" ]] || die "VERSION_CODENAME not set in /etc/os-release"
ok "detected ${ID} ${VERSION_ID} (${CODENAME})"

export DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# 1. Base prerequisites
# -----------------------------------------------------------------------------
log "refreshing apt indexes"
apt_update_retry

log "installing prerequisites (curl, gnupg, ca-certificates)"
apt-get install -y -qq curl gnupg ca-certificates

# -----------------------------------------------------------------------------
# 2. git
# -----------------------------------------------------------------------------
if command -v git >/dev/null 2>&1; then
    ok "git already installed ($(git --version))"
else
    log "installing git"
    apt-get install -y -qq git
    ok "git installed ($(git --version))"
fi

# -----------------------------------------------------------------------------
# 3. cloudflared (stable, from pkg.cloudflare.com)
# -----------------------------------------------------------------------------
if command -v cloudflared >/dev/null 2>&1; then
    ok "cloudflared already installed ($(cloudflared --version 2>&1 | head -n1))"
else
    # Suite mapping per https://pkg.cloudflare.com/index.html
    # Distros with a dedicated suite get the codename; everything else falls
    # back to "any" (the universal suite Cloudflare publishes for releases
    # they don't have a per-codename build for, e.g. Debian 13 / trixie).
    case "${ID}:${VERSION_ID}" in
        ubuntu:22.04) CLOUDFLARED_SUITE="jammy" ;;
        ubuntu:24.04) CLOUDFLARED_SUITE="noble" ;;
        debian:12)    CLOUDFLARED_SUITE="bookworm" ;;
        *)            CLOUDFLARED_SUITE="any" ;;
    esac

    log "adding Cloudflare apt repo (stable / ${CLOUDFLARED_SUITE})"
    install -d -m 0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
        | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared ${CLOUDFLARED_SUITE} main" \
        > /etc/apt/sources.list.d/cloudflared.list
    apt_update_retry
    log "installing cloudflared"
    apt-get install -y -qq cloudflared
    ok "cloudflared installed ($(cloudflared --version 2>&1 | head -n1))"
fi

# -----------------------------------------------------------------------------
# 4. Gather install parameters
# -----------------------------------------------------------------------------
if [[ "$NONINTERACTIVE" != "1" ]]; then
    echo
    log "Atrium install parameters (press Enter to accept defaults)"

    read -r -p "Panel domain [${DEFAULT_PANEL_DOMAIN}]: " PANEL_DOMAIN
    PANEL_DOMAIN="${PANEL_DOMAIN:-$DEFAULT_PANEL_DOMAIN}"

    read -r -p "Admin email [${DEFAULT_ADMIN_EMAIL}]: " ADMIN_EMAIL
    ADMIN_EMAIL="${ADMIN_EMAIL:-$DEFAULT_ADMIN_EMAIL}"
    [[ "$ADMIN_EMAIL" == *@*.* ]] || die "admin email must look like name@domain.tld"

    read -r -s -p "Admin password [${DEFAULT_ADMIN_PASSWORD}]: " ADMIN_PASSWORD; echo
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        ADMIN_PASSWORD="$DEFAULT_ADMIN_PASSWORD"
        warn "using default admin password — change it in the panel UI after login"
    else
        # User typed something — enforce length + ask for confirmation.
        while :; do
            if [[ ${#ADMIN_PASSWORD} -lt 8 ]]; then
                warn "password must be at least 8 characters"
            else
                read -r -s -p "Confirm password: " ADMIN_PW2; echo
                if [[ "$ADMIN_PASSWORD" == "$ADMIN_PW2" ]]; then
                    break
                fi
                warn "passwords do not match — try again"
            fi
            read -r -s -p "Admin password (min 8 chars): " ADMIN_PASSWORD; echo
        done
        unset ADMIN_PW2
    fi
fi

# -----------------------------------------------------------------------------
# 5. Clone the repo via Cloudflare Access SSH
# -----------------------------------------------------------------------------
# StrictHostKeyChecking=accept-new: TOFU on first connection. The tunnel
# endpoint is authenticated by Cloudflare Access, so this is safe in practice
# and avoids an interactive yes/no prompt mid-clone.
SSH_VIA_CFD="ssh -o StrictHostKeyChecking=accept-new -o ProxyCommand='cloudflared access ssh --hostname %h'"

if [[ -d "$CLONE_TARGET/.git" ]]; then
    warn "$CLONE_TARGET already exists — pulling latest instead of cloning"
    GIT_SSH_COMMAND="$SSH_VIA_CFD" git -C "$CLONE_TARGET" pull --ff-only
else
    log "cloning ${REPO_REMOTE} → ${CLONE_TARGET}"
    GIT_SSH_COMMAND="$SSH_VIA_CFD" git clone "$REPO_REMOTE" "$CLONE_TARGET"
fi
ok "repo ready at $CLONE_TARGET"

# -----------------------------------------------------------------------------
# 6. Install the `atrium` control command
# -----------------------------------------------------------------------------
# Writes /usr/local/bin/atrium plus a tiny config file that records where the
# source tree lives. After this, `sudo atrium update` will pull and run
# ./update.sh from anywhere on the system.
log "installing /usr/local/bin/atrium control command"

install -d -m 0755 /etc/atrium
cat > /etc/atrium/source.conf <<EOF
# Written by ATRIUM.sh — do not hand-edit unless you move the source.
SOURCE_DIR="${CLONE_TARGET}"
REPO_REMOTE="${REPO_REMOTE}"
EOF
chmod 0644 /etc/atrium/source.conf

cat > /usr/local/bin/atrium <<'ATRIUM_EOF'
#!/usr/bin/env bash
# Atrium control wrapper — installed by ATRIUM.sh
set -euo pipefail

CONF=/etc/atrium/source.conf

log() { printf '\033[1;34matrium:\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32matrium:\033[0m %s\n' "$*"; }
die() { printf '\033[1;31matrium:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "must run as root (try: sudo atrium $*)"
[[ -f "$CONF" ]]  || die "$CONF not found — bootstrap installer hasn't run on this host"
# shellcheck source=/dev/null
. "$CONF"
[[ -n "${SOURCE_DIR:-}" && -d "$SOURCE_DIR/.git" ]] \
    || die "SOURCE_DIR=${SOURCE_DIR:-?} is not a git checkout"

SSH_VIA_CFD="ssh -o StrictHostKeyChecking=accept-new -o ProxyCommand='cloudflared access ssh --hostname %h'"

case "${1:-}" in
    update)
        log "pulling latest in $SOURCE_DIR"
        GIT_SSH_COMMAND="$SSH_VIA_CFD" git -C "$SOURCE_DIR" pull --ff-only
        ok "source updated"
        log "running ./update.sh"
        cd "$SOURCE_DIR"
        exec ./update.sh
        ;;
    status)
        log "source : $SOURCE_DIR"
        log "remote : ${REPO_REMOTE:-?}"
        git -C "$SOURCE_DIR" log -1 --oneline
        git -C "$SOURCE_DIR" status --short --branch
        ;;
    ""|-h|--help|help)
        cat <<USAGE
Usage: sudo atrium <command>

Commands:
  update    git pull (via cloudflared) and run ./update.sh
  status    show current commit and working-tree status
  help      this message

Source: $SOURCE_DIR
USAGE
        ;;
    *)
        die "unknown command: $1 (try: sudo atrium help)"
        ;;
esac
ATRIUM_EOF
chmod 0755 /usr/local/bin/atrium
ok "/usr/local/bin/atrium installed — try: sudo atrium help"

# -----------------------------------------------------------------------------
# 7. Hand off to install.sh
# -----------------------------------------------------------------------------
cd "$CLONE_TARGET"
[[ -f ./install.sh ]] || die "./install.sh not found in $CLONE_TARGET"
chmod +x ./install.sh

log "running ./install.sh"
# Password goes via env (install.sh picks up ADMIN_PASSWORD) so it doesn't
# show up in `ps`. Domain + email are non-sensitive and stay as flags for
# transparency in the install log.
export ADMIN_PASSWORD
./install.sh \
    --panel-domain  "$PANEL_DOMAIN" \
    --admin-email   "$ADMIN_EMAIL"

# -----------------------------------------------------------------------------
# 8. Next-time-around hint
# -----------------------------------------------------------------------------
C_HINT=$'\033[38;2;166;227;161m'   # Catppuccin green
C_DIM=$'\033[38;2;166;173;200m'    # Catppuccin subtext1
C_OFF=$'\033[0m'

cat <<EOF

  ${C_HINT}╭─ Atrium installed.${C_OFF}
  ${C_HINT}│${C_OFF}
  ${C_HINT}│${C_OFF}  To upgrade later, run from anywhere on this machine:
  ${C_HINT}│${C_OFF}
  ${C_HINT}│${C_OFF}      ${C_HINT}sudo atrium update${C_OFF}
  ${C_HINT}│${C_OFF}
  ${C_HINT}│${C_OFF}  Other commands:
  ${C_HINT}│${C_OFF}      ${C_DIM}sudo atrium status${C_OFF}   show current commit + working tree
  ${C_HINT}│${C_OFF}      ${C_DIM}sudo atrium help${C_OFF}     full usage
  ${C_HINT}│${C_OFF}
  ${C_HINT}╰─ Source tree: ${CLONE_TARGET}${C_OFF}

EOF
