# Source Code

Atrium's application source (`charm-cloud.git`) is hosted on a self-hosted [soft-serve](https://github.com/charmbracelet/soft-serve) git server, fronted by a Cloudflare Tunnel at `git-ssh.rjhon.net`. There's no plain SSH port open — every connection has to go through `cloudflared`. The same path is what `ATRIUM.sh` uses internally.

If you just want to **install** Atrium, you don't need any of this — the bootstrap handles the clone for you. This page is for people who want to **read** or **clone** the source directly.

---

## 1. Install `cloudflared`

You need Cloudflare's tunnel client on your machine.

### macOS

```bash
brew install cloudflared
```

### Linux (Debian / Ubuntu)

```bash
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
  | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] \
  https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/cloudflared.list

sudo apt-get update && sudo apt-get install -y cloudflared
```

> [!NOTE]
> On Debian 13 (`trixie`) Cloudflare doesn't publish a dedicated suite yet — replace `$(lsb_release -cs)` with `any`.

### Linux (RHEL / Fedora)

```bash
sudo rpm -i https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-x86_64.rpm
```

### Windows

Download the MSI from <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/> and run it.

Verify the install:

```bash
cloudflared --version
```

---

## 2. Browse (read-only TUI)

Connect to soft-serve's terminal UI through the tunnel. You get a browseable repo list with file viewer, diffs, and log — no clone needed.

```bash
ssh -o ProxyCommand="cloudflared access ssh --hostname %h" git@git-ssh.rjhon.net
```

Use <kbd>↑</kbd>/<kbd>↓</kbd> (or `j`/`k`) to navigate, <kbd>Enter</kbd> to open, <kbd>q</kbd> to quit.

---

## 3. Clone

One-shot clone:

```bash
GIT_SSH_COMMAND="ssh -o ProxyCommand='cloudflared access ssh --hostname %h'" \
  git clone git@git-ssh.rjhon.net:charm-cloud.git
```

For ongoing work, make `git pull` / `git fetch` Just Work by adding this once to `~/.ssh/config`:

```sshconfig
Host git-ssh.rjhon.net
  ProxyCommand cloudflared access ssh --hostname %h
  User git
```

After that the clone, fetch, and pull commands look completely normal:

```bash
git clone git@git-ssh.rjhon.net:charm-cloud.git
cd charm-cloud
git fetch origin
```

---

## What's in `charm-cloud`?

The Laravel 13 control-panel application, the privileged bash helpers under `deploy/sbin/`, and the `install.sh` / `update.sh` lifecycle scripts. It's the same tree that ends up at `/var/www/panel` on every installed host.

---

## Troubleshooting

<details>
<summary><b><code>cloudflared: command not found</code></b></summary>

Re-run the install step for your OS. On macOS make sure Homebrew's bin dir is on `PATH` (`echo $PATH | grep -q /opt/homebrew/bin || export PATH=/opt/homebrew/bin:$PATH`).
</details>

<details>
<summary><b>SSH says <code>Permission denied (publickey)</code></b></summary>

The tunnel is reachable but soft-serve rejected your key. Make sure your `~/.ssh/id_*.pub` is added to soft-serve's allow list, or use the key you registered when you set up access.
</details>

<details>
<summary><b><code>cloudflared access ssh</code> hangs or times out</b></summary>

Usually means the tunnel on the host side is down. Try `cloudflared --version` to confirm the client works, then test plain HTTPS to the hostname: `curl -sI https://git-ssh.rjhon.net` should at least respond.
</details>
