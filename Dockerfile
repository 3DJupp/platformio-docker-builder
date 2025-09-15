# --------------------------------------------------------------------------------
# Global build arguments (override via Compose build.args or CLI)
# --------------------------------------------------------------------------------
ARG PROJECT_DIR=opendtu
ARG GIT_REPO=https://github.com/tbnobody/OpenDTU.git
ARG PIO_ENV=olimex_esp32_poe
ARG GIT_REF=master
ARG GITHUB_OWNER=tbnobody
ARG GITHUB_REPO=OpenDTU

# --------------------------------------------------------------------------------
# Stage 1: Base with Python + PlatformIO
# --------------------------------------------------------------------------------
FROM python:3.11-slim AS pio-base

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      libffi-dev \
      libssl-dev \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir platformio

# --------------------------------------------------------------------------------
# Stage 2: Build firmware
# --------------------------------------------------------------------------------
FROM pio-base AS builder

# Redeclare args for this stage
ARG PROJECT_DIR
ARG GIT_REPO
ARG PIO_ENV
ARG GIT_REF
ARG GITHUB_OWNER
ARG GITHUB_REPO

ENV PROJECT_DIR=${PROJECT_DIR} \
    GIT_REPO=${GIT_REPO} \
    PIO_ENV=${PIO_ENV}

WORKDIR /workspace

# Cache-Buster: Tarball ändert sich bei jedem neuen Commit auf ${GIT_REF}
# Für Tags: .../refs/tags/${GIT_REF}
# Für Commit-SHA: .../tar.gz/${GIT_REF} (ohne refs/...)
ADD https://codeload.github.com/${GITHUB_OWNER}/${GITHUB_REPO}/tar.gz/refs/heads/${GIT_REF} /tmp/gitref.tgz

# Clone gezielt auf den gewünschten Branch/Ref
RUN git clone --depth=1 --branch ${GIT_REF} ${GIT_REPO} ${PROJECT_DIR}

WORKDIR /workspace/${PROJECT_DIR}

# Protokolliere die tatsächlich gebaute Commit-SHA
RUN git rev-parse HEAD | tee /tmp/commit.sha

# Build
RUN platformio run --environment ${PIO_ENV}

# --------------------------------------------------------------------------------
# Stage 3: Package artifacts (copy to volume at runtime)
# --------------------------------------------------------------------------------
FROM busybox:latest AS artifacts

ARG PROJECT_DIR
ARG PIO_ENV

# Artefakte erst im Image ablegen (nicht direkt /out, das wird übermountet)
WORKDIR /image_out
COPY --from=builder /workspace/${PROJECT_DIR}/.pio/build/${PIO_ENV}/*.bin ./
COPY --from=builder /tmp/commit.sha ./commit.sha

# Beim Containerstart ins gemountete /out kopieren (überschreibt alte Dateien)
CMD ["sh", "-c", "mkdir -p /out && cp -rf /image_out/. /out/ && echo '--- /out ---' && ls -l /out"]
