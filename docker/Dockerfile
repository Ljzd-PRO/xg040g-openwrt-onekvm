FROM ubuntu:24.04

ARG TARGETARCH
ARG GO_VERSION=1.24.13
ARG NODE_VERSION=24.10.0
ARG RUSTUP_VERSION=1.28.2
ARG RUST_VERSION=1.96.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    bc \
    binutils \
    bison \
    build-essential \
    ca-certificates \
    ccache \
    clang \
    cmake \
    curl \
    device-tree-compiler \
    file \
    flex \
    g++ \
    gawk \
    gcc \
    gcc-multilib \
    gettext \
    git \
    jq \
    libclang-dev \
    libelf-dev \
    libncurses-dev \
    liblzma-dev \
    libssl-dev \
    make \
    patch \
    perl \
    pkg-config \
    python3 \
    python3-dev \
    python3-setuptools \
    rsync \
    shellcheck \
    swig \
    time \
    unzip \
    wget \
    xz-utils \
    zlib1g-dev \
    zstd \
  && rm -rf /var/lib/apt/lists/*

RUN case "$TARGETARCH" in \
      amd64) go_sha="1fc94b57134d51669c72173ad5d49fd62afb0f1db9bf3f798fd98ee423f8d730" ;; \
      arm64) go_sha="74d97be1cc3a474129590c67ebf748a96e72d9f3a2b6fef3ed3275de591d49b3" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
  && curl -fsSLo /tmp/go.tar.gz "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" \
  && echo "$go_sha  /tmp/go.tar.gz" | sha256sum -c - \
  && tar -C /usr/local -xzf /tmp/go.tar.gz \
  && rm /tmp/go.tar.gz

RUN case "$TARGETARCH" in \
      amd64) node_arch="x64"; node_sha="2642f4428869aca32443660fd71b3918e2be1277a899bdcaeb64c93b54b5af17" ;; \
      arm64) node_arch="arm64"; node_sha="07f0558316ebb8977dd6fb29b4de8d369a639d3d8cef544293852a6f5eea6af8" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
  && curl -fsSLo /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
  && echo "$node_sha  /tmp/node.tar.xz" | sha256sum -c - \
  && tar -C /usr/local --strip-components=1 -xJf /tmp/node.tar.xz \
  && rm /tmp/node.tar.xz

ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo

RUN case "$TARGETARCH" in \
      amd64) rust_arch="x86_64"; rustup_sha="20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c" ;; \
      arm64) rust_arch="aarch64"; rustup_sha="e3853c5a252fca15252d07cb23a1bdd9377a8c6f3efa01531109281ae47f841c" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
  && curl -fsSLo /tmp/rustup-init "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${rust_arch}-unknown-linux-gnu/rustup-init" \
  && echo "$rustup_sha  /tmp/rustup-init" | sha256sum -c - \
  && chmod +x /tmp/rustup-init \
  && /tmp/rustup-init -y --profile minimal --default-toolchain "$RUST_VERSION" \
  && /usr/local/cargo/bin/rustup target add aarch64-unknown-linux-musl \
  && /usr/local/cargo/bin/rustup component add rustfmt \
  && rm /tmp/rustup-init

ENV PATH="/usr/local/go/bin:/usr/local/cargo/bin:${PATH}"
WORKDIR /work
