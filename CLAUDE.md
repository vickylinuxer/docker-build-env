# CLAUDE.md

> **Maintenance rules:**
> 1. Update this file as part of every change — Dockerfile additions, script changes, bug fixes, and new conventions all belong here.
> 2. After every change: commit with a descriptive message and push to `git@github.com:vickylinuxer/docker-build-env.git`.

## Project Overview

Docker-based AOSP (Android Open Source Project) and Yocto Linux build environment for macOS. Provides a persistent Ubuntu 24.04 container with all build dependencies pre-installed, working around macOS filesystem limitations (case-insensitive APFS/HFS+) that break large embedded Linux builds.

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Ubuntu 24.04 image with all build tools, Java, Python, ccache, repo tool |
| `entrypoint.sh` | Container entrypoint: copies host SSH keys into builder home and fixes permissions |
| `setup.sh` | One-time initialization: validates Docker, creates the `aosp-yocto-build` named volume, builds the image |
| `start.sh` | Daily driver: starts or resumes the container; attaches via `docker exec` |
| `autostart.sh` | Called by launchd at macOS login; waits for Docker then starts container detached |
| `manage.sh` | Container lifecycle: shell, stop, status, rebuild, reset, purge, autostart-enable/disable |
| `README.md` | Full user guide with AOSP and Yocto workflow examples |

## Architecture Decisions

- **Named volume** (`aosp-yocto-build`, 1 TB) mounted at `/build` — declared with `VOLUME ["/build"]` in the Dockerfile; provides a case-sensitive ext4 filesystem required by AOSP; bind-mounting macOS APFS would break builds
- **`/build` ownership** — `RUN mkdir -p /build && chown builder:builder /build` runs before `VOLUME` so new volumes initialise writable; `entrypoint.sh` also fixes ownership on pre-existing root-owned volumes at startup via `sudo chown`
- **SSH keys** — host `~/.ssh` is bind-mounted read-only at `/tmp/host-ssh`; `entrypoint.sh` copies the files to `/home/builder/.ssh` and sets correct permissions (700 dir, 600 private keys, 644 public keys) at container start
- **Non-root user** `builder` (UID 1001) with passwordless sudo — satisfies both security requirements and AOSP build system expectations
- **ccache** at `/build/.ccache` (50 GB cap) — drastically reduces incremental build times
- **Java 11 and 17** both installed — different Android branches require different JDK versions; `JAVA_HOME` defaults to Java 17
- **`repo` tool** downloaded from `storage.googleapis.com/git-repo-downloads/repo` (not `git-integration` — that URL is dead)
- **Persistent container** — main process is `sleep infinity`; the container stays alive across terminal disconnects and tmux sessions. Shells are always opened via `docker exec`, never as PID 1. This is required for autostart to work correctly.
- **Autostart (launchd)** — `manage.sh autostart-enable` installs a LaunchAgent plist at `~/Library/LaunchAgents/com.vickylinuxer.docker-build-env.plist`. `autostart.sh` polls for Docker Desktop readiness (up to 120 s) before starting the container. Logs at `~/Library/Logs/docker-build-env/autostart.log`.

## Common Commands

### Host (macOS)

```bash
# Initial one-time setup
chmod +x *.sh && ./setup.sh

# Daily workflow
./start.sh                  # Start or resume container
./manage.sh shell           # Open an additional shell in the running container
./manage.sh stop            # Graceful stop
./manage.sh status          # Container and volume status
./manage.sh volume-info     # Disk usage breakdown

# Maintenance
./manage.sh rebuild          # Rebuild image, preserves /build data
./manage.sh reset            # Remove container only, preserves /build data
./manage.sh purge            # Destroy everything (prompts for confirmation)

# Autostart (Mac Mini boot)
./manage.sh autostart-enable  # Install launchd agent
./manage.sh autostart-disable # Remove launchd agent
./manage.sh autostart-logs    # Tail the autostart log
```

### Inside Container — AOSP

```bash
mkdir -p /build/aosp && cd /build/aosp
repo init -u https://android.googlesource.com/platform/manifest -b android-14.0.0_r1
repo sync -j$(nproc) -c --no-tags
source build/envsetup.sh
lunch aosp_arm64-eng
make -j$(nproc)
```

### Inside Container — Yocto

```bash
mkdir -p /build/yocto && cd /build/yocto
git clone git://git.yoctoproject.org/poky -b scarthgap
source poky/oe-init-build-env build
bitbake core-image-minimal
```

## Host Requirements

- Docker Desktop with disk image expanded to **at least 1024 GB** (critical — AOSP alone needs ~300 GB, Yocto ~100 GB)
- macOS with bash

## Container Resource Allocation

`start.sh` computes these automatically:
- **CPUs**: total host CPUs − 1
- **RAM**: 75% of total host RAM
- **File descriptors / processes**: ulimit raised to 65536

## Shell Script Conventions

- `set -e` throughout — scripts exit on first error
- Destructive operations (`reset`, `purge`) prompt for explicit confirmation
- Output formatted with Unicode box-drawing characters for clarity
- Helper functions in `manage.sh` use `cmd_` prefix
- Container existence checked via `docker container inspect` before any operation

## Pre-installed Toolchain Summary

- **Build**: gcc, g++, make, cmake, ninja, bison, flex, gperf
- **Java**: OpenJDK 11 & 17
- **Python**: Python 3 + pip + venv
- **VCS**: git, git-lfs, Google `repo`
- **Yocto extras**: chrpath, diffstat, socat, cpio, texinfo, docbook-utils, file, gawk
- **Utilities**: tmux, htop, vim, nano, curl, wget, rsync, jq, bc, ccache

## Disk Sizing Notes

| Workload | Minimum Space |
|----------|--------------|
| AOSP source sync | ~300 GB |
| AOSP full build output | ~300 GB additional |
| Yocto source + build | ~100 GB |
| ccache (pre-configured cap) | 50 GB |
| Recommended volume size | 1 TB |
