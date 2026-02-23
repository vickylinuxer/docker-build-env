#!/usr/bin/env bash
# ============================================================
# setup.sh — One-time setup for AOSP/Yocto build environment
# Run this ONCE on your Mac to prepare everything.
# ============================================================
set -e

VOLUME_NAME="aosp-yocto-build"
IMAGE_NAME="build-env:latest"
CONTAINER_NAME="aosp-builder"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   AOSP / Yocto Docker Build Environment Setup        ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Check Docker is running ──────────────────────────
echo "▶ Checking Docker..."
if ! docker info &>/dev/null; then
  echo "✗ Docker Desktop is not running. Please start it and try again."
  exit 1
fi
echo "  ✓ Docker is running."
echo ""

# ── Step 2: Warn about disk image size ───────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ⚠  IMPORTANT: Docker Desktop disk image size"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Named volumes draw from Docker Desktop's virtual disk."
echo "  Default is ~64 GB — far too small for AOSP/Yocto."
echo ""
echo "  Before continuing, please:"
echo "    1. Open Docker Desktop"
echo "    2. Go to Settings → Resources → Disk image size"
echo "    3. Set it to at least 1024 GB (1 TB)"
echo "    4. Click 'Apply & Restart'"
echo ""
read -rp "  Have you done this? (y/N) " CONFIRMED
if [[ ! "$CONFIRMED" =~ ^[Yy]$ ]]; then
  echo ""
  echo "  Please update Docker Desktop disk size first, then re-run this script."
  exit 0
fi
echo ""

# ── Step 3: Create named volume ───────────────────────────────
echo "▶ Creating Docker named volume: $VOLUME_NAME ..."
if docker volume inspect "$VOLUME_NAME" &>/dev/null; then
  echo "  ✓ Volume '$VOLUME_NAME' already exists — skipping creation."
else
  docker volume create "$VOLUME_NAME"
  echo "  ✓ Volume '$VOLUME_NAME' created."
fi
echo ""

# ── Step 4: Build the Docker image ────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "▶ Building Docker image: $IMAGE_NAME ..."
echo "  (This may take a few minutes on first run)"
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
echo "  ✓ Image built successfully."
echo ""

# ── Step 5: Done ──────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  To start your build container, run:"
echo "    ./start.sh"
echo ""
echo "  Volume '$VOLUME_NAME' is mounted at /build inside the container."
echo "  It persists across container restarts."
echo ""
