#!/usr/bin/env bash
# ============================================================
# manage.sh — Container & volume management helpers
# ============================================================

VOLUME_NAME="aosp-yocto-build"
CONTAINER_NAME="aosp-builder"

usage() {
  echo ""
  echo "Usage: ./manage.sh <command>"
  echo ""
  echo "Commands:"
  echo "  status            Show container and volume status"
  echo "  stop              Gracefully stop the container"
  echo "  shell             Open a new shell in the running container"
  echo "  volume-info       Show disk usage of the build volume"
  echo "  rebuild           Rebuild the Docker image (keeps volume data)"
  echo "  reset             Stop and remove the container (volume data is KEPT)"
  echo "  purge             ⚠  Remove container AND volume (ALL BUILD DATA LOST)"
  echo "  autostart-enable  Install launchd agent: start container at macOS login"
  echo "  autostart-disable Remove the launchd agent"
  echo "  autostart-logs    Tail the autostart log"
  echo ""
}

cmd_status() {
  echo ""
  echo "── Container ────────────────────────────────────────"
  if docker container inspect "$CONTAINER_NAME" &>/dev/null; then
    STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")
    STARTED=$(docker inspect -f '{{.State.StartedAt}}' "$CONTAINER_NAME")
    echo "  Name   : $CONTAINER_NAME"
    echo "  Status : $STATUS"
    echo "  Started: $STARTED"
  else
    echo "  Container '$CONTAINER_NAME' does not exist yet."
    echo "  Run ./start.sh to create it."
  fi
  echo ""
  echo "── Volume ───────────────────────────────────────────"
  if docker volume inspect "$VOLUME_NAME" &>/dev/null; then
    MOUNT=$(docker volume inspect -f '{{.Mountpoint}}' "$VOLUME_NAME")
    echo "  Name      : $VOLUME_NAME"
    echo "  Mountpoint: $MOUNT"
    echo ""
    echo "  Disk usage inside Docker VM:"
    docker run --rm -v "${VOLUME_NAME}:/build" --entrypoint="" ubuntu:24.04 \
      df -h /build 2>/dev/null || echo "  (could not read — start the container first)"
  else
    echo "  Volume '$VOLUME_NAME' does not exist yet."
    echo "  Run ./setup.sh to create it."
  fi
  echo ""
}

cmd_stop() {
  echo "Stopping $CONTAINER_NAME..."
  docker stop "$CONTAINER_NAME" 2>/dev/null && echo "Stopped." || echo "Container not running."
}

cmd_shell() {
  echo "Opening new shell in $CONTAINER_NAME..."
  docker exec -it "$CONTAINER_NAME" /bin/bash
}

cmd_volume_info() {
  echo ""
  echo "── Volume disk usage ────────────────────────────────"
  docker run --rm \
    -v "${VOLUME_NAME}:/build" \
    --entrypoint="" \
    ubuntu:24.04 \
    bash -c "df -h /build && echo '' && du -sh /build/* 2>/dev/null | sort -rh | head -20"
  echo ""
}

cmd_rebuild() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "Rebuilding Docker image (volume data is preserved)..."
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  docker build -t build-env:latest "$SCRIPT_DIR"
  echo "Done. Run ./start.sh to start the new container."
}

cmd_reset() {
  echo "⚠  This will stop and remove the container."
  echo "   Your build data in '$VOLUME_NAME' will be PRESERVED."
  read -rp "   Continue? (y/N) " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  echo "Container removed. Volume data is safe. Run ./start.sh to start fresh."
}

cmd_purge() {
  echo "⚠  WARNING: This will DELETE the container AND the volume."
  echo "   ALL YOUR BUILD DATA WILL BE PERMANENTLY LOST."
  echo "   Type 'DELETE' to confirm:"
  read -r CONFIRM
  [[ "$CONFIRM" == "DELETE" ]] || { echo "Aborted."; exit 0; }
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  docker volume rm "$VOLUME_NAME" 2>/dev/null || true
  echo "Container and volume removed."
}

PLIST_LABEL="com.vickylinuxer.docker-build-env"
PLIST_FILE="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
LOG_DIR="$HOME/Library/Logs/docker-build-env"

cmd_autostart_enable() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  mkdir -p "$(dirname "$PLIST_FILE")" "$LOG_DIR"

  cat > "$PLIST_FILE" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SCRIPT_DIR}/autostart.sh</string>
    </array>

    <!-- Run once at login, do not restart if it exits normally -->
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>

    <!-- Explicit PATH so launchd can find docker -->
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>${HOME}</string>
    </dict>

    <key>StandardOutPath</key>
    <string>${LOG_DIR}/autostart.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/autostart.log</string>
</dict>
</plist>
PLIST

  launchctl load "$PLIST_FILE"
  echo ""
  echo "  ✓ Autostart enabled."
  echo "  Agent : $PLIST_FILE"
  echo "  Log   : $LOG_DIR/autostart.log"
  echo ""
  echo "  The container will start automatically at next login."
  echo "  To trigger it now without rebooting:"
  echo "    launchctl start $PLIST_LABEL"
  echo ""
}

cmd_autostart_disable() {
  if [ -f "$PLIST_FILE" ]; then
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    rm "$PLIST_FILE"
    echo "  ✓ Autostart disabled."
  else
    echo "  Autostart is not enabled (plist not found)."
  fi
}

cmd_autostart_logs() {
  LOG_FILE="$LOG_DIR/autostart.log"
  if [ -f "$LOG_FILE" ]; then
    tail -50 "$LOG_FILE"
  else
    echo "  No autostart log found at $LOG_FILE"
    echo "  Run './manage.sh autostart-enable' first."
  fi
}

case "${1:-}" in
  status)           cmd_status ;;
  stop)             cmd_stop ;;
  shell)            cmd_shell ;;
  volume-info)      cmd_volume_info ;;
  rebuild)          cmd_rebuild ;;
  reset)            cmd_reset ;;
  purge)            cmd_purge ;;
  autostart-enable) cmd_autostart_enable ;;
  autostart-disable)cmd_autostart_disable ;;
  autostart-logs)   cmd_autostart_logs ;;
  *)                usage ;;
esac
