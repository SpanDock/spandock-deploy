#!/usr/bin/env bash
# Installs a SpanDock server on a Linux VM as a systemd service, then prints the activation link.
# Safe to run again: it upgrades the binary and keeps the data and settings.
#
#   curl -fsSL https://www.spandock.com/deploy/install-server.sh | sudo bash
#
# Optional environment:
#   SPANDOCK_VERSION    a release tag such as v0.14.0 (default: the latest release)
#   SPANDOCK_JOIN_CODE  join an existing hub as a satellite (a single-use code from the hub)
#   SPANDOCK_USER       the service account (default: spandock)
#
# Public endpoint with automatic HTTPS (v0.18 or later; first start only, then Settings → Public
# endpoint). It needs inbound TCP 443 and a DNS record <name>.<domain> pointing at this machine:
#   SPANDOCK_PUBLIC_LISTEN   e.g. 0.0.0.0:443
#   SPANDOCK_PUBLIC_NAME     e.g. edge
#   SPANDOCK_PUBLIC_DOMAIN   e.g. example.com (not on a satellite: it takes the hub's)
#   SPANDOCK_PUBLIC_TLS      acme (default), files or proxy
#   SPANDOCK_ACME_EMAIL      the certificate contact address
#
# Needs: a 64-bit x86 or ARM machine with glibc 2.38 or later (Ubuntu 24.04, Debian 13, RHEL 10,
# Fedora 39 or newer), systemd, curl, and outbound HTTPS. No inbound port is needed unless the
# public endpoint is on.
set -euo pipefail

VERSION="${SPANDOCK_VERSION:-latest}"
SVC_USER="${SPANDOCK_USER:-spandock}"
RELEASES="https://github.com/SpanDock/spandock-releases/releases"

say() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root (for example with sudo)"
command -v systemctl >/dev/null || die "systemd is required"
command -v curl >/dev/null || die "curl is required"

case "$(uname -m)" in
  x86_64 | amd64) ARCH=amd64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *) die "unsupported processor: $(uname -m) (x86-64 or ARM64 only)" ;;
esac

GLIBC="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')"
[ -n "$GLIBC" ] || die "glibc not found (musl-based systems such as Alpine aren't supported)"
if [ "$(printf '%s\n%s\n' 2.38 "$GLIBC" | sort -V | head -n1)" != "2.38" ]; then
  die "glibc $GLIBC is too old: 2.38 or later is needed (Ubuntu 24.04, Debian 13, RHEL 10 or newer)"
fi

if [ "$VERSION" = latest ]; then BASE="$RELEASES/latest/download"; else BASE="$RELEASES/download/$VERSION"; fi

if ! id -u "$SVC_USER" >/dev/null 2>&1; then
  say "Creating the $SVC_USER service account"
  useradd --system --create-home --home-dir /var/lib/spandock --shell /usr/sbin/nologin "$SVC_USER"
fi
HOME_DIR="$(getent passwd "$SVC_USER" | cut -d: -f6)"
BIN_DIR="$HOME_DIR/bin" # owned by the service account, so the server can update itself
install -d -o "$SVC_USER" -g "$SVC_USER" -m 0750 "$HOME_DIR" "$BIN_DIR"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
TARBALL="spandock-linux-$ARCH.tar.gz"
say "Downloading $TARBALL ($VERSION)"
curl -fsSL --retry 3 -o "$TMP/$TARBALL" "$BASE/$TARBALL"
curl -fsSL --retry 3 -o "$TMP/checksums.txt" "$BASE/checksums.txt"
(cd "$TMP" && sha256sum -c checksums.txt --ignore-missing --quiet) || die "checksum mismatch: the download is corrupt"
tar -xzf "$TMP/$TARBALL" -C "$TMP" spandock
install -o "$SVC_USER" -g "$SVC_USER" -m 0755 "$TMP/spandock" "$BIN_DIR/spandock"

ENV_FILE=/etc/spandock/server.env
install -d -m 0750 -g "$SVC_USER" /etc/spandock
if [ ! -f "$ENV_FILE" ]; then
  # Accept the EULA (https://www.spandock.com/legal/eula) and keep secrets in a 0600 file:
  # cloud VMs have no desktop keychain.
  printf 'SPANDOCK_ACCEPT_EULA=1\nSPANDOCK_SECRET_STORE=file\n' >"$ENV_FILE"
fi
if [ -n "${SPANDOCK_JOIN_CODE:-}" ]; then
  # The join code works once; the server ignores it after it has joined.
  { grep -v '^SPANDOCK_JOIN_CODE=' "$ENV_FILE" || true; printf 'SPANDOCK_JOIN_CODE=%s\n' "$SPANDOCK_JOIN_CODE"; } >"$ENV_FILE.new"
  mv "$ENV_FILE.new" "$ENV_FILE"
fi
# First-start settings for the public endpoint, kept in the env file (the server reads them once).
for var in SPANDOCK_PUBLIC_LISTEN SPANDOCK_PUBLIC_NAME SPANDOCK_PUBLIC_DOMAIN SPANDOCK_PUBLIC_TLS SPANDOCK_ACME_EMAIL; do
  val="${!var:-}"
  [ -n "$val" ] || continue
  case "$val" in *[[:space:]\'\"\$\`]*) die "$var has characters that aren't allowed" ;; esac
  { grep -v "^$var=" "$ENV_FILE" || true; printf '%s=%s\n' "$var" "$val"; } >"$ENV_FILE.new"
  mv "$ENV_FILE.new" "$ENV_FILE"
done
chown root:"$SVC_USER" "$ENV_FILE"
chmod 0640 "$ENV_FILE"

cat >/etc/systemd/system/spandock.service <<EOF
[Unit]
Description=SpanDock Server
Wants=network-online.target
After=network-online.target

[Service]
User=$SVC_USER
Group=$SVC_USER
EnvironmentFile=$ENV_FILE
WorkingDirectory=$HOME_DIR
ExecStart=$BIN_DIR/spandock -role=server -open=false -menubar=false
Restart=always
RestartSec=5
# Stopping the old process must not kill the self-update helper: it waits for the new version to
# answer and rolls back a broken update.
KillMode=process
# The activation link also goes to the serial console, which every cloud can show you.
StandardOutput=journal+console
StandardError=journal+console
# Lets the public endpoint listen on 443 without running as root.
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# The "spandock" command for this machine (root-owned): runs CLI commands as the service account
# with the service's settings, and refuses to start a second server.
cat >/usr/local/bin/spandock <<WRAPPER
#!/bin/sh
# SpanDock's command line on this server: runs SpanDock commands as the $SVC_USER service account,
# with the service's settings. The server itself runs as the "spandock" systemd service.
#   sudo spandock onboard     answer a few questions (hub or satellite, public endpoint)
# Generated from deploy/spandock-cli.sh.in by install-server.sh and the Ansible role.
SVC=$SVC_USER
SVC_HOME=$HOME_DIR
ENV_FILE=/etc/spandock/server.env

# ─── spandock onboard: set the server up by answering questions (as root) ─────
onboard() {
  [ "\$(id -u)" = 0 ] || { echo "Run it as root: sudo spandock onboard" >&2; exit 1; }
  [ -r /dev/tty ] || { echo "spandock onboard needs a terminal." >&2; exit 1; }
  ask() { printf '%s' "\$1" >/dev/tty; IFS= read -r REPLY </dev/tty || exit 1; }
  ask_secret() {
    printf '%s' "\$1" >/dev/tty
    stty -echo </dev/tty 2>/dev/null
    IFS= read -r REPLY </dev/tty
    stty echo </dev/tty 2>/dev/null
    printf '\\n' >/dev/tty
  }
  # Values go into an env file: letters, digits and . _ : @ + = / ~ - only.
  valid() { case "\$1" in "" | *[!A-Za-z0-9._:@+=/~-]*) return 1 ;; esac; }
  set_var() {
    tmp="\$(mktemp)"
    { grep -v "^\$1=" "\$ENV_FILE" || true; printf '%s=%s\\n' "\$1" "\$2"; } >"\$tmp"
    cat "\$tmp" >"\$ENV_FILE" # keeps the file's owner and mode (root:\$SVC 0640)
    rm -f "\$tmp"
  }

  echo "Set up this SpanDock server. Your answers are saved in \$ENV_FILE and used when the service starts."
  echo "Use it on a new server, before it's activated or joined; it doesn't change a server that's already set up."
  echo
  echo "  1) A new server (a hub). You'll approve it once on spandock.com."
  echo "  2) A satellite of an existing hub. You'll need a join code from the hub."
  ask "Which one? [1] "
  role="\${REPLY:-1}"
  join=""
  if [ "\$role" = 2 ]; then
    echo "On the hub: Settings → Scaling → Add server, then copy the join code (it works once, for 30 minutes)."
    ask_secret "Join code (hidden): "
    join="\$REPLY"
    valid "\$join" || { echo "That doesn't look like a join code." >&2; exit 1; }
  elif [ "\$role" != 1 ]; then
    echo "Choose 1 or 2." >&2
    exit 1
  fi

  echo
  echo "The public endpoint lets cloud tools and remote clients reach this server over HTTPS."
  echo "It needs inbound TCP 443 and a DNS record <name>.<domain> pointing at this machine."
  ask "Turn it on? [y/N] "
  public=""
  case "\$REPLY" in y | Y | yes | YES) public=1 ;; esac
  name="" domain="" email=""
  if [ -n "\$public" ]; then
    ask "Name (the first part of the address, e.g. edge): "
    name="\$REPLY"
    valid "\$name" || { echo "Use letters, digits and hyphens." >&2; exit 1; }
    if [ "\$role" = 1 ]; then
      ask "Domain (e.g. example.com): "
      domain="\$REPLY"
      valid "\$domain" || { echo "That doesn't look like a domain." >&2; exit 1; }
    fi
    ask "Email for the HTTPS certificate (optional): "
    email="\$REPLY"
    [ -z "\$email" ] || valid "\$email" || { echo "That doesn't look like an email address." >&2; exit 1; }
  fi

  echo
  echo "About to save:"
  [ "\$role" = 2 ] && echo "  satellite, with the join code you entered" || echo "  a new hub"
  shown_domain="\$domain"
  [ -n "\$shown_domain" ] || shown_domain="<the hub's domain>"
  [ -n "\$public" ] && echo "  public endpoint https://\$name.\$shown_domain"
  ask "Save and restart the service? [Y/n] "
  case "\$REPLY" in n | N | no | NO) echo "Nothing saved."; exit 1 ;; esac

  [ -n "\$join" ] && set_var SPANDOCK_JOIN_CODE "\$join"
  if [ -n "\$public" ]; then
    set_var SPANDOCK_PUBLIC_LISTEN 0.0.0.0:443
    set_var SPANDOCK_PUBLIC_NAME "\$name"
    [ -n "\$domain" ] && set_var SPANDOCK_PUBLIC_DOMAIN "\$domain"
    [ -n "\$email" ] && set_var SPANDOCK_ACME_EMAIL "\$email"
  fi
  systemctl restart spandock
  echo "Saved. The service is restarting."
  if [ "\$role" = 2 ]; then
    echo "It joins the hub on this start, then keeps its settings across restarts. Follow it with: journalctl -u spandock -f"
    exit 0
  fi
  i=0
  while [ "\$i" -lt 30 ]; do
    link="\$(journalctl -u spandock --no-pager -o cat --since '-2 min' 2>/dev/null | grep -oE 'https://[^[:space:]]*activate[^[:space:]]*' | tail -n1)"
    if [ -n "\$link" ]; then
      printf '\\nApprove this server (sign in, check the code matches, approve):\\n\\n    %s\\n\\n' "\$link"
      exit 0
    fi
    i=\$((i + 1))
    sleep 2
  done
  echo "No activation link yet (it may already be activated). Follow it with: journalctl -u spandock -f"
  exit 0
}

if [ "\${1:-}" = onboard ]; then
  onboard
fi

if [ "\$(id -un)" != "\$SVC" ]; then
  if [ "\$(id -u)" = 0 ] && command -v runuser >/dev/null 2>&1; then exec runuser -u "\$SVC" -- "\$0" "\$@"; fi
  exec sudo -u "\$SVC" -- "\$0" "\$@"
fi
case "\${1:-}" in
  "" | -role | -role=*)
    # A second server process would fight the service for its ports.
    echo "SpanDock runs as a service here: systemctl status spandock, journalctl -u spandock -f" >&2
    echo "Commands: sudo spandock onboard, spandock license status|login, spandock admin pair|clients|approve|management-token|reset-login, spandock service ..., spandock -version" >&2
    exit 2 ;;
esac
set -a
. "\$ENV_FILE"
set +a
unset SPANDOCK_JOIN_CODE XDG_CONFIG_HOME
export HOME="\$SVC_HOME"
exec "\$SVC_HOME/bin/spandock" "\$@"
WRAPPER
chown root:root /usr/local/bin/spandock
chmod 0755 /usr/local/bin/spandock

systemctl daemon-reload
systemctl enable spandock >/dev/null
systemctl restart spandock
say "SpanDock is running as the spandock service"

next_steps() {
  cat <<'STEPS'

Next steps:
  sudo spandock onboard            set it up by answering questions: hub or satellite, public endpoint
  spandock license status          the server's license
  spandock admin pair              add a client (prints a pairing code)
  journalctl -u spandock -f        follow the server's log
  Dashboard: ssh -L 8787:127.0.0.1:8787 <this machine>, then open http://127.0.0.1:8787
STEPS
}
trap next_steps EXIT

if [ -n "${SPANDOCK_JOIN_CODE:-}" ]; then
  say "Joining the hub as a satellite. Check its status with: journalctl -u spandock -f"
  exit 0
fi

# A new server waits for one approval on spandock.com. Show the link as soon as it's printed.
for _ in $(seq 1 45); do
  LINK="$(journalctl -u spandock --no-pager -o cat 2>/dev/null | grep -oE 'https://[^[:space:]]*activate[^[:space:]]*' | tail -n1 || true)"
  if [ -n "$LINK" ]; then
    say "Approve this server (sign in, check the code matches, approve):"
    printf '\n    %s\n\n' "$LINK"
    exit 0
  fi
  if curl -fsS -o /dev/null http://127.0.0.1:4318/healthz 2>/dev/null; then
    say "This server is already activated and healthy"
    exit 0
  fi
  sleep 2
done
say "No activation link yet. Watch for it with: journalctl -u spandock -f"
