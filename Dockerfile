# syntax=docker/dockerfile:1

# #
#   @project              Docker Image › Alpine Base › Dockerfile
#   @repo                 https://github.com/aetherinox/docker-base-ubuntu
#   @file                 dockerfile
#   @usage                base image utilized for all docker images using Alpine with s6-overlay integration
#
#   @image:github         ghcr.io/aetherinox/ubuntu:latest
#                         ghcr.io/aetherinox/ubuntu:22.04
#                         ghcr.io/aetherinox/ubuntu:noble
#
#   @image:dockerhub      aetherinox/ubuntu:latest
#                         aetherinox/ubuntu:22.04
#                         aetherinox/ubuntu:noble
#
#                         AMD64
#                         Build the image with:
#                             docker buildx build \
#                               --build-arg IMAGE_NAME=ubuntu \
#                               --build-arg IMAGE_DISTRO=noble \
#                               --build-arg IMAGE_ARCH=amd64 \
#                               --build-arg IMAGE_BUILDDATE=20260812 \
#                               --build-arg IMAGE_VERSION=24.04 \
#                               --build-arg IMAGE_RELEASE=stable \
#                               --build-arg IMAGE_REGISTRY=github \
#                               --tag aetherinox/ubuntu:latest \
#                               --tag aetherinox/ubuntu:24.04 \
#                               --tag aetherinox/ubuntu:noble \
#                               --tag aetherinox/ubuntu:noble-XXXXXXXX \
#                               --attest type=provenance,disabled=true \
#                               --attest type=sbom,disabled=true \
#                               --output type=docker \
#                               --builder default \
#                               --file Dockerfile \
#                               --platform linux/amd64 \
#                               --allow network.host \
#                               --network host \
#                               --no-cache \
#                               --progress=plain \
#                               .
#
#                         ARM64
#                         For arm64, make sure you install QEMU first in docker; use the command:
#                             docker run --privileged --rm tonistiigi/binfmt --install all
#
#                         Build the image with:
#                             docker buildx build \
#                               --build-arg IMAGE_NAME=ubuntu \
#                               --build-arg IMAGE_DISTRO=noble \
#                               --build-arg IMAGE_ARCH=arm64 \
#                               --build-arg IMAGE_BUILDDATE=20260812 \
#                               --build-arg IMAGE_VERSION=24.04 \
#                               --build-arg IMAGE_RELEASE=stable \
#                               --build-arg IMAGE_REGISTRY=github \
#                               --tag aetherinox/ubuntu:latest \
#                               --tag aetherinox/ubuntu:24.04 \
#                               --tag aetherinox/ubuntu:noble \
#                               --tag aetherinox/ubuntu:noble-XXXXXXXX \
#                               --attest type=provenance,disabled=true \
#                               --attest type=sbom,disabled=true \
#                               --output type=docker \
#                               --builder default \
#                               --file Dockerfile \
#                               --platform linux/arm64 \
#                               --allow network.host \
#                               --network host \
#                               --no-cache \
#                               --progress=plain \
#                               .
# #

ARG ALPINE_VERSION=3.22
FROM alpine:${ALPINE_VERSION} AS rootfs-stage

# #
#   arguments
#
#   ARGs are the only thing you should provide in your buildx command
#   or Github workflow. ENVs are set by args, or hard-coded values
#
#   IMAGE_ARCH          amd64
#                       arm64
#
#   The args below will get their value depending on what you set for IMAGE_ARCH:
#
#   UBUNTU_ARCH         amd64
#                       arm64
#
#   S6_OVERLAY_ARCH     x86_64
#                       aarch64
# #

ARG IMAGE_REPO_AUTHOR="aetherinox"
ARG IMAGE_REPO_NAME="docker-base-ubuntu"
ARG IMAGE_NAME="ubuntu"
ARG IMAGE_DISTRO="noble"
ARG IMAGE_ARCH="amd64"
ARG IMAGE_SHA1="0000000000000000000000000000000000000000"
ARG IMAGE_REGISTRY="local"
ARG IMAGE_RELEASE="stable"
ARG IMAGE_BUILDDATE="20250101"
ARG IMAGE_VERSION="24.04"

ENV UBUNTU_ARCH="${IMAGE_ARCH}"
ENV UBUNTU_DISTRO="${IMAGE_DISTRO}"
ENV UBUNTU_VERSION="${IMAGE_VERSION}"
ENV S6_OVERLAY_VERSION="3.2.1.0"
ENV S6_OVERLAY_ARCH="x86_64"
ENV BASHIO_VERSION="0.16.2"

# #
#   ubuntu › environment
# #

ENV ROOTFS=/root-out

# #
#   detect ubuntu version from distro
# #

RUN \
    if [ "${UBUNTU_DISTRO}" = "plucky" ]; then \
        UBUNTU_VERSION="25.04"; \
    elif [ "${UBUNTU_DISTRO}" = "oracular" ]; then \
        UBUNTU_VERSION="24.10"; \
    elif [ "${UBUNTU_DISTRO}" = "noble" ]; then \
        UBUNTU_VERSION="24.04"; \
    elif [ "${UBUNTU_DISTRO}" = "jammy" ]; then \
        UBUNTU_VERSION="22.04"; \
    elif [ "${UBUNTU_DISTRO}" = "focal" ]; then \
        UBUNTU_VERSION="20.04"; \
    elif [ "${UBUNTU_DISTRO}" = "bionic" ]; then \
        UBUNTU_VERSION="18.04"; \
    else \
        UBUNTU_VERSION="24.04"; \
    fi

# #
#   install packages
# #

RUN \
    apk add --no-cache \
        bash \
        curl \
        git \
        jq \
        tzdata \
        xz

# #
#   get base tarball
# #

RUN \
    if [ "${IMAGE_ARCH}" = "armv7" ]; then \
        UBUNTU_ARCH="armv7"; \
    elif [ "${IMAGE_ARCH}" = "i386" ]; then \
        UBUNTU_ARCH="i386"; \
    elif [ "${IMAGE_ARCH}" = "amd64" ]; then \
        UBUNTU_ARCH="amd64"; \
    elif [ "${IMAGE_ARCH}" = "arm64" ]; then \
        UBUNTU_ARCH="arm64"; \
    else \
        UBUNTU_ARCH="${UBUNTU_ARCH}"; \
    fi \
    \
    && git clone --depth=1 https://git.launchpad.net/cloud-images/+oci/ubuntu-base -b oci-${UBUNTU_DISTRO}-${UBUNTU_VERSION} /build && \
    cd /build/oci && \
    DIGEST=$(jq -r '.manifests[0].digest[7:]' < index.json) && \
    cd /build/oci/blobs/sha256 && \
    if jq -e '.layers // empty' < "${DIGEST}" >/dev/null 2>&1; then \
        TARBALL=$(jq -r '.layers[0].digest[7:]' < ${DIGEST}); \
    else \
        MULTIDIGEST=$(jq -r ".manifests[] | select(.platform.architecture == \"${UBUNTU_ARCH}\") | .digest[7:]" < ${DIGEST}) && \
        TARBALL=$(jq -r '.layers[0].digest[7:]' < ${MULTIDIGEST}); \
    fi && \
    mkdir $ROOTFS && \
    tar xf \
        ${TARBALL} -C \
        $ROOTFS && \
    rm -rf \
        $ROOTFS/var/log/* \
        $ROOTFS/home/ubuntu \
        $ROOTFS/root/{.ssh,.bashrc,.profile} \
        /build

# #
#   Ubuntu › S6 > add overlay & optional symlinks
#
#   TAR         --xz, -J                      Use xz for compressing or decompressing the archives. See section Creating and Reading
#                                                 Compressed Archives.
#               --get, -x                     Same as ‘--extract’
#                                             Extracts members from the archive into the file system. See section How to Extract Members
#                                                 from an Archive.
#               --verbose, -v                 Specifies that tar should be more verbose about the operations it is performing. This
#                                                 option can be specified multiple times for some operations to increase the amount
#                                                 of information displayed. See section Checking tar progress.
#               --file=archive, -f archive    Tar will use the file archive as the tar archive it performs operations on, rather
#                                                 than tar’s compilation dependent default. See section The ‘--file’ Option.
#               --directory=dir, -C           Dir When this option is specified, tar will change its current directory to dir
#                                                 before performing any operations. When this option is used during archive creation,
#                                                 it is order sensitive. See section Changing the Working Directory.
# #

RUN \
    if [ "${IMAGE_ARCH}" = "armv7" ]; then \
        S6_OVERLAY_ARCH="arm"; \
    elif [ "${IMAGE_ARCH}" = "i386" ]; then \
        S6_OVERLAY_ARCH="i686"; \
    elif [ "${IMAGE_ARCH}" = "amd64" ]; then \
        S6_OVERLAY_ARCH="x86_64"; \
    elif [ "${IMAGE_ARCH}" = "arm64" ]; then \
        S6_OVERLAY_ARCH="aarch64"; \
    else \
        S6_OVERLAY_ARCH="${UBUNTU_ARCH}"; \
    fi \
    \
    && wget -P /tmp "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" && \
       tar -C $ROOTFS -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    wget -P /tmp "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz" && \
       tar -C $ROOTFS -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz && \
    wget -P /tmp "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz" && \
       tar -C $ROOTFS -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz && \
    wget -P /tmp "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz" && \
       tar -C $ROOTFS -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz && unlink $ROOTFS/usr/bin/with-contenv

# #
#   install bashio
# #

RUN \
    mkdir -p /usr/src/bashio \
    && curl -L -f -s "https://github.com/hassio-addons/bashio/archive/v${BASHIO_VERSION}.tar.gz" \
        | tar -xzf - --strip 1 -C /usr/src/bashio \
    && mv /usr/src/bashio/lib /usr/lib/bashio \
    && ln -s /usr/lib/bashio/bashio /usr/bin/bashio

# #
#   scratch
# #

FROM scratch
ENV ROOTFS=/root-out
COPY --from=rootfs-stage $ROOTFS/ /

# #
#   scratch › args
# #

ARG IMAGE_REPO_AUTHOR="aetherinox"
ARG IMAGE_REPO_NAME="docker-base-ubuntu"
ARG IMAGE_NAME="Ubuntu"
ARG IMAGE_DISTRO="noble"
ARG IMAGE_ARCH="amd64"
ARG IMAGE_SHA1="0000000000000000000000000000000000000000"
ARG IMAGE_REGISTRY="local"
ARG IMAGE_RELEASE="stable"
ARG IMAGE_BUILDDATE="20250101"
ARG IMAGE_VERSION="24.04"

ENV UBUNTU_ARCH="${IMAGE_ARCH}"
ENV UBUNTU_DISTRO="${IMAGE_DISTRO}"
ENV UBUNTU_VERSION="${IMAGE_VERSION}"

ENV S6_OVERLAY_VERSION="3.2.1.0"
ENV S6_OVERLAY_ARCH="x86_64"
ENV BASHIO_VERSION="0.16.2"

ENV MODS_VERSION="v3"
ENV PKG_INST_VERSION="v1"
ENV AETHERXOWN_VERSION="v1"
ENV WITHCONTENV_VERSION="v1"

# #
#   scratch › set labels
# #

LABEL org.opencontainers.image.authors="${IMAGE_REPO_AUTHOR}"
LABEL org.opencontainers.image.vendor="${IMAGE_REPO_AUTHOR}"
LABEL org.opencontainers.image.title="${IMAGE_NAME:-Ubuntu} (Base) ${UBUNTU_VERSION} (${UBUNTU_DISTRO})"
LABEL org.opencontainers.image.description="${IMAGE_NAME:-Ubuntu} base image with s6-overlay integration"
LABEL org.opencontainers.image.created=
LABEL org.opencontainers.image.source="https://github.com/${IMAGE_REPO_AUTHOR}/${IMAGE_REPO_NAME}"
LABEL org.opencontainers.image.documentation="https://github.com/${IMAGE_REPO_AUTHOR}/${IMAGE_REPO_NAME}/wiki"
LABEL org.opencontainers.image.issues="https://github.com/${IMAGE_REPO_AUTHOR}/${IMAGE_REPO_NAME}/issues"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${UBUNTU_VERSION}"
LABEL org.opencontainers.image.distro="${UBUNTU_DISTRO:-noble}"
LABEL org.opencontainers.image.branch="main"
LABEL org.opencontainers.image.registry="${IMAGE_REGISTRY:-local}"
LABEL org.opencontainers.image.release="${IMAGE_RELEASE:-stable}"
LABEL org.opencontainers.image.development="false"
LABEL org.opencontainers.image.sha="${IMAGE_SHA1:-0000000000000000000000000000000000000000}"
LABEL org.opencontainers.image.architecture="${UBUNTU_ARCH:-amd64}"
LABEL org.ubuntu.image.maintainers="${IMAGE_REPO_AUTHOR}"
LABEL org.ubuntu.image.version="Version: ${UBUNTU_VERSION} Date: ${IMAGE_BUILDDATE:-20250615}"
LABEL org.ubuntu.image.distro="${UBUNTU_DISTRO:-noble}"
LABEL org.ubuntu.image.release="${IMAGE_RELEASE:-stable}"
LABEL org.ubuntu.image.sha="${IMAGE_SHA1:-0000000000000000000000000000000000000000}"
LABEL org.ubuntu.image.architecture="${UBUNTU_ARCH:-amd64}"
LABEL org.s6overlay.image.version="${S6_OVERLAY_VERSION:-3.0.0.0}"
LABEL org.s6overlay.image.architecture="${S6_OVERLAY_ARCH:-x86_64}"

# #
#   scratch › add cdn > core
# #

ADD --chmod=755 "https://raw.githubusercontent.com/${IMAGE_REPO_AUTHOR}/${IMAGE_REPO_NAME}/docker/core/docker-images.${MODS_VERSION}" "/docker-images"
ADD --chmod=755 "https://raw.githubusercontent.com/${IMAGE_REPO_AUTHOR}/${IMAGE_REPO_NAME}/docker/core/package-install.${PKG_INST_VERSION}" "/etc/s6-overlay/s6-rc.d/init-mods-package-install/run"
ADD --chmod=755 "https://raw.githubusercontent.com/${IMAGE_REPO_AUTHOR}/${IMAGE_REPO_NAME}/docker/core/aetherxown.${AETHERXOWN_VERSION}" "/usr/bin/aetherxown"
ADD --chmod=755 "https://raw.githubusercontent.com/${IMAGE_REPO_AUTHOR}/${IMAGE_REPO_NAME}/docker/core/with-contenv.${WITHCONTENV_VERSION}" "/usr/bin/with-contenv"

# #
#   scratch › env vars
# #

ARG DEBIAN_FRONTEND="noninteractive"
ENV HOME="/root" \
    LANGUAGE="en_US.UTF-8" \
    LANG="en_US.UTF-8" \
    TERM="xterm" \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
    S6_VERBOSITY=1 \
    S6_STAGE2_HOOK=/docker-images \
    VIRTUAL_ENV=/aetherxpy \
    PATH="/aetherxpy/bin:$PATH"

# #
#   env variables
# #

ENV USER0="root"
ENV USER1="dockerx"
ENV UUID0=0
ENV UUID1=999
ENV GUID0=0
ENV GUID1=999

# #
#   scratch › copy sources to file
# #

COPY sources.list /tmp
COPY sources.list.arm /tmp

# #
#   scratch › copy sources to relative location
# #

RUN \
    if [ "${UBUNTU_ARCH}" = "amd64" ]; then \
        mv /tmp/sources.list /etc/apt ; \
    elif [ "${UBUNTU_ARCH}" = "arm64" ]; then \
        mv /tmp/sources.list.arm /etc/apt/sources.list ; \
    else \
        mv /tmp/sources.list /etc/apt ; \
    fi

# #
#   install packages
# #

RUN \
    echo "**** Ripped from Ubuntu Docker Logic ****" && \
    rm -f /etc/apt/sources.list.d/ubuntu.sources && \
    set -xe && \
    echo '#!/bin/sh' \
        > /usr/sbin/policy-rc.d && \
    echo 'exit 101' \
        >> /usr/sbin/policy-rc.d && \
    chmod +x \
        /usr/sbin/policy-rc.d && \
    dpkg-divert --local --rename --add /sbin/initctl && \
    cp -a \
        /usr/sbin/policy-rc.d \
        /sbin/initctl && \
    sed -i \
        's/^exit.*/exit 0/' \
        /sbin/initctl && \
    echo 'force-unsafe-io' \
        > /etc/dpkg/dpkg.cfg.d/docker-apt-speedup && \
    echo 'DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' \
        > /etc/apt/apt.conf.d/docker-clean && \
    echo 'APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' \
        >> /etc/apt/apt.conf.d/docker-clean && \
    echo 'Dir::Cache::pkgcache ""; Dir::Cache::srcpkgcache "";' \
        >> /etc/apt/apt.conf.d/docker-clean && \
    echo 'Acquire::Languages "none";' \
        > /etc/apt/apt.conf.d/docker-no-languages && \
    echo 'Acquire::GzipIndexes "true"; Acquire::CompressionTypes::Order:: "gz";' \
        > /etc/apt/apt.conf.d/docker-gzip-indexes && \
    echo 'Apt::AutoRemove::SuggestsImportant "false";' \
        > /etc/apt/apt.conf.d/docker-autoremove-suggests && \
    mkdir -p /run/systemd && \
    echo 'docker' \
        > /run/systemd/container && \
    echo "**** install apt-utils and locales ****" && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        apt-utils \
        locales && \
    echo "**** install packages ****" && \
    apt-get install -y \
        bash \
        sudo \
        nano \
        ca-certificates \
        catatonit \
        coreutils \
        cron \
        lsb-release \
        curl \
        findutils \
        iproute2 \
        git \
        gnupg \
        jq \
        netcat-openbsd \
        systemd-standalone-sysusers \
        tzdata && \
    echo "**** generate locale ****" && \
    locale-gen en_US.UTF-8 && \
    echo "**** create dockerx user and make our folders ****" && \
    useradd --uid ${UUID1} \
      --user-group \
      --home /config \
      --shell /bin/false \
      ${USER1} && \
    usermod -aG ${USER1} ${USER1} && \
        usermod -aG sudo ${USER1} && \
        usermod -aG users ${USER1} && \
    mkdir -p \
        /app \
        /config \
        /defaults \
        /aetherxpy && \
    echo "**** cleanup ****" && \
    userdel ubuntu && \
    mkdir -p /etc/sudoers.d/ && \
    echo ${USER1} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USER1} && \
    chmod 0440 /etc/sudoers.d/${USER1} && \
    update-ca-certificates -f && \
    apt-get autoremove -yq && \
    apt-get clean -yq && \
    rm -rf \
        /tmp/* \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /var/log/*

# #
#   scratch › add local files
# #

COPY root/ /

# #
#   scratch › add entrypoint
# #

ENTRYPOINT ["/init"]
