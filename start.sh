#!/usr/bin/env bash
# ============================================================
# start.sh — Start (or resume) the build container
# ============================================================
set -e

VOLUME_NAME="aosp-yocto-build"
IMAGE_NAME="build-env:latest"
CONTAINER_NAME="aosp-builder"

# Get CPU count and RAM (leave some for macOS)
CPU_COUNT=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
TOTAL_RAM_GB=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 17179869184) / 1073741824 ))
BUILD_RAM_GB=$(( TOTAL_RAM_GB * 3 / 4 ))   # Use 75% of RAM
BUILD_CPUS=$(( CPU_COUNT > 2 ? CPU_COUNT - 1 : CPU_COUNT ))  # Leave 1 CPU for macOS

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Starting AOSP / Yocto Build Container              ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  CPUs  : $BUILD_CPUS / $CPU_COUNT"
echo "  RAM   : ${BUILD_RAM_GB}g / ${TOTAL_RAM_GB}g"
echo "  Volume: $VOLUME_NAME → /build"
echo ""

# ── If container already exists, just attach to it ───────────
if docker container inspect "$CONTAINER_NAME" &>/dev/null; then
  STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")
  if [[ "$STATUS" == "running" ]]; then
    echo "  Container is already running — attaching..."
    docker exec -it "$CONTAINER_NAME" /bin/bash
    exit 0
  else
    echo "  Resuming stopped container..."
    docker start -ai "$CONTAINER_NAME"
    exit 0
  fi
fi

# ── Start a fresh container ───────────────────────────────────
echo "  Starting new container..."
docker run -it \
  --name "$CONTAINER_NAME" \
  --hostname build-box \
  \
  `# ── Volume: persistent build workspace ──` \
  -v "${VOLUME_NAME}:/build" \
  \
  `# ── SSH keys (read-only from host) ─────` \
  -v "$HOME/.ssh:/tmp/host-ssh:ro" \
  \
  `# ── Resources ──────────────────────────` \
  --cpus="$BUILD_CPUS" \
  --memory="${BUILD_RAM_GB}g" \
  --memory-swap="${BUILD_RAM_GB}g" \
  \
  `# ── File descriptor & process limits ───` \
  --ulimit nofile=65536:65536 \
  --ulimit nproc=65536:65536 \
  \
  `# ── Useful env vars ─────────────────────` \
  -e "TERM=xterm-256color" \
  -e "HISTFILE=/build/.bash_history" \
  \
  "$IMAGE_NAME"
