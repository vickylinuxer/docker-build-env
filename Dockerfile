# ============================================================
# Ubuntu 24.04 Build Environment for AOSP & Yocto
# ============================================================
FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ── Core build tools ─────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Essentials
    sudo curl wget git git-lfs vim nano tmux htop \
    # Python
    python3 python3-pip python3-venv \
    # Build toolchain
    build-essential gcc g++ gperf bison flex \
    make cmake ninja-build ccache \
    # Archive / compression
    zip unzip tar xz-utils lz4 zstd \
    # Libraries needed by AOSP & Yocto
    libssl-dev libncurses-dev \
    libxml2-utils libreadline-dev \
    liblz4-tool zlib1g-dev \
    # AOSP specifics
    openjdk-11-jdk openjdk-17-jdk \
    libx11-dev libgl1-mesa-dev \
    rsync schedtool \
    # Yocto specifics
    chrpath diffstat socat cpio \
    xterm texinfo docbook-utils \
    file gawk \
    # Network tools
    openssh-client ca-certificates \
    # Misc utilities
    jq bc locales tzdata \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# ── Locale ───────────────────────────────────────────────────
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# ── repo tool (for AOSP) ─────────────────────────────────────
RUN curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo \
    && chmod +x /usr/local/bin/repo

# ── Create a non-root builder user ───────────────────────────
RUN groupadd -g 1001 builder \
    && useradd -m -u 1001 -g 1001 -s /bin/bash builder \
    && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ── ccache configuration ─────────────────────────────────────
ENV USE_CCACHE=1
ENV CCACHE_DIR=/build/.ccache
ENV CCACHE_MAXSIZE=50G

# ── Entrypoint script ────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ── Create /build owned by builder before declaring as volume ─
# VOLUME copies the image directory's ownership into new volumes.
# Must be done here (as root) before switching to USER builder.
RUN mkdir -p /build && chown builder:builder /build

# ── Persistent volume mount point ────────────────────────────
VOLUME ["/build"]

# ── Set working directory on the persistent volume ───────────
WORKDIR /build

# ── Convenience aliases & PS1 prompt ─────────────────────────
RUN echo 'alias ll="ls -lah --color=auto"' >> /home/builder/.bashrc \
    && echo 'export PS1="\[\033[1;32m\][build-env]\[\033[0m\] \w \$ "' >> /home/builder/.bashrc \
    && echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64' >> /home/builder/.bashrc \
    && echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /home/builder/.bashrc \
    && echo '# AOSP helpers' >> /home/builder/.bashrc \
    && echo 'alias aosp-setup="source build/envsetup.sh"' >> /home/builder/.bashrc

USER builder

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
