# AOSP / Yocto Docker Build Environment

Ubuntu 22.04 container with a persistent 1 TB Docker named volume, tuned for AOSP and Yocto builds on a Mac Mini with Docker Desktop.

---

## Quick Start

### Step 1 — Expand Docker Desktop's disk image (do this first!)

1. Open **Docker Desktop**
2. Go to **Settings → Resources → Disk image size**
3. Drag the slider to **1024 GB** (or type it in)
4. Click **Apply & Restart**

> Named volumes live inside Docker Desktop's virtual disk. The default ~64 GB is far too small for AOSP (needs ~300 GB) or Yocto (~100 GB).

---

### Step 2 — Run setup (one time only)

```bash
cd docker-build-env
chmod +x *.sh
./setup.sh
```

This will:
- Confirm Docker is running and the disk has been expanded
- Create a Docker named volume called `aosp-yocto-build`
- Build the Ubuntu 22.04 image with all AOSP/Yocto dependencies

---

### Step 3 — Start the container

```bash
./start.sh
```

You'll land inside an Ubuntu 22.04 shell. Your build workspace is at `/build` — everything you put there is persisted on the named volume.

---

## Daily Workflow

| Task | Command |
|------|---------|
| Start / resume container | `./start.sh` |
| Open extra shell in running container | `./manage.sh shell` |
| Stop the container | `./manage.sh stop` |
| Check status & disk usage | `./manage.sh status` |
| Show /build disk breakdown | `./manage.sh volume-info` |
| Rebuild image (keeps data) | `./manage.sh rebuild` |
| Remove container only (keeps data) | `./manage.sh reset` |
| ⚠ Delete everything | `./manage.sh purge` |

---

## AOSP Quick Start (inside the container)

```bash
# Configure git (required by repo)
git config --global user.email "you@example.com"
git config --global user.name "Your Name"

# Create a project directory
mkdir -p /build/aosp && cd /build/aosp

# Initialize a repo (example: Android 14)
repo init -u https://android.googlesource.com/platform/manifest -b android-14.0.0_r1

# Sync (use -j to match your CPU count)
repo sync -j$(nproc) -c --no-tags

# Set up build environment
source build/envsetup.sh
lunch aosp_arm64-eng        # or your target

# Build
make -j$(nproc)
```

---

## Yocto Quick Start (inside the container)

```bash
mkdir -p /build/yocto && cd /build/yocto

# Clone Poky
git clone git://git.yoctoproject.org/poky -b scarthgap

# Set up environment
source poky/oe-init-build-env build

# Build a minimal image
bitbake core-image-minimal
```

---

## What's Pre-installed

- **Toolchain**: gcc, g++, make, cmake, ninja, gperf, bison, flex
- **Java**: OpenJDK 11 & 17 (AOSP needs both depending on branch)
- **Python**: Python 3 + pip
- **repo**: Google's repo tool for AOSP manifests
- **ccache**: Compiler cache pre-configured at `/build/.ccache` (50 GB)
- **Yocto deps**: chrpath, diffstat, socat, cpio, texinfo, etc.
- **Utilities**: tmux, htop, vim, nano, git, git-lfs, curl, wget, rsync

---

## Volume Details

| Property | Value |
|----------|-------|
| Volume name | `aosp-yocto-build` |
| Mount point in container | `/build` |
| Filesystem | Linux ext4 (case-sensitive — required for AOSP) |
| Max size | Limited by Docker Desktop disk image (set to 1 TB) |
| ccache location | `/build/.ccache` |

### Why a named volume (not a bind mount)?

- Docker named volumes use Linux's ext4 filesystem — **case-sensitive by default**, which AOSP requires
- macOS's default APFS/HFS+ is case-insensitive, which breaks AOSP builds if you use a bind mount to your Mac filesystem
- Named volumes also have better I/O performance than bind mounts on macOS

---

## Tips for Large Builds

- **ccache** is pre-configured. After the first build, subsequent builds will be significantly faster.
- **tmux** is installed. Run builds inside a tmux session so you can detach and reattach without losing progress.
- **nproc** inside the container returns the number of CPUs allocated by `start.sh` (all available minus one).
- If a build runs out of space, check `./manage.sh volume-info` and consider increasing Docker Desktop's disk image size.
