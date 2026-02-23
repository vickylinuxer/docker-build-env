#!/usr/bin/env bash
# ============================================================
# autostart.sh — Start the build container at macOS login
#
# Called by the launchd LaunchAgent. Waits up to 120 s for
# Docker Desktop to become ready, then starts the container
# in detached mode. Safe to run multiple times (idempotent).
#
# Enable  : ./manage.sh autostart-enable
# Disable : ./manage.sh autostart-disable
# Logs    : ~/Library/Logs/docker-build-env/autostart.log
# ============================================================

VOLUME_NAME="aosp-yocto-build"
IMAGE_NAME="build-env:latest"
CONTAINER_NAME="aosp-builder"
DOCKER="/usr/local/bin/docker"   # launchd has a minimal PATH; use full path

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "autostart triggered."

# ── Wait for Docker Desktop (up to 120 s) ────────────────────
log "Waiting for Docker Desktop..."
for i in $(seq 1 24); do
    "$DOCKER" info &>/dev/null && break
    if [ "$i" -eq 24 ]; then
        log "ERROR: Docker not ready after 120 s — aborting."
        exit 1
    fi
    sleep 5
done
log "Docker is ready."

# ── Ensure the build image exists ────────────────────────────
if ! "$DOCKER" image inspect "$IMAGE_NAME" &>/dev/null; then
    log "ERROR: image '$IMAGE_NAME' not found. Run ./setup.sh first."
    exit 1
fi

# ── Ensure the named volume exists ───────────────────────────
if ! "$DOCKER" volume inspect "$VOLUME_NAME" &>/dev/null; then
    log "Creating volume $VOLUME_NAME..."
    "$DOCKER" volume create "$VOLUME_NAME"
fi

# ── Start or resume the container ────────────────────────────
if "$DOCKER" container inspect "$CONTAINER_NAME" &>/dev/null; then
    STATUS=$("$DOCKER" inspect -f '{{.State.Status}}' "$CONTAINER_NAME")
    if [ "$STATUS" = "running" ]; then
        log "Container already running. Nothing to do."
        exit 0
    fi
    log "Resuming stopped container..."
    "$DOCKER" start "$CONTAINER_NAME"
else
    CPU_COUNT=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
    TOTAL_RAM_GB=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 17179869184) / 1073741824 ))
    BUILD_RAM_GB=$(( TOTAL_RAM_GB * 3 / 4 ))
    BUILD_CPUS=$(( CPU_COUNT > 2 ? CPU_COUNT - 1 : CPU_COUNT ))

    log "Starting new container (${BUILD_CPUS} CPUs, ${BUILD_RAM_GB}g RAM)..."
    "$DOCKER" run -d \
        --name  "$CONTAINER_NAME" \
        --hostname build-box \
        \
        -v "${VOLUME_NAME}:/build" \
        -v "$HOME/.ssh:/tmp/host-ssh:ro" \
        \
        --cpus="$BUILD_CPUS" \
        --memory="${BUILD_RAM_GB}g" \
        --memory-swap="${BUILD_RAM_GB}g" \
        \
        --ulimit nofile=65536:65536 \
        --ulimit nproc=65536:65536 \
        \
        -e "TERM=xterm-256color" \
        -e "HISTFILE=/build/.bash_history" \
        \
        "$IMAGE_NAME" \
        sleep infinity          # keeps container alive; attach with docker exec
fi

log "Container is running. Autostart complete."
