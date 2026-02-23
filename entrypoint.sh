#!/usr/bin/env bash
# ============================================================
# entrypoint.sh — Container entrypoint
#   1. Copies host SSH keys (mounted read-only) and fixes perms
#   2. Ensures the working directory is the persistent /build dir
# ============================================================

SSH_STAGING="/tmp/host-ssh"
SSH_DIR="$HOME/.ssh"

# ── Fix /build ownership for pre-existing root-owned volumes ─
if [ "$(stat -c '%U' /build 2>/dev/null)" != "builder" ]; then
    sudo chown builder:builder /build
fi

# ── Copy SSH keys from host if mounted ───────────────────────
if [ -d "$SSH_STAGING" ] && [ -n "$(ls -A "$SSH_STAGING" 2>/dev/null)" ]; then
    mkdir -p "$SSH_DIR"
    cp -r "$SSH_STAGING/." "$SSH_DIR/"
    chmod 700 "$SSH_DIR"
    # Public keys: 644, private keys: 600
    find "$SSH_DIR" -maxdepth 1 -type f -name "*.pub" -exec chmod 644 {} \;
    find "$SSH_DIR" -maxdepth 1 -type f ! -name "*.pub" -exec chmod 600 {} \;
fi

exec "$@"
