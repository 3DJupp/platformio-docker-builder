# ---- Base Image: Python + PlatformIO ----
FROM python:3.11-slim AS pio-base

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      libffi-dev \
      libssl-dev \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install PlatformIO core via pip
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir platformio

# ---- Stage 1: Clone & Build ----
FROM pio-base AS builder

# Build arguments (override as needed)
ARG GIT_REPO=https://github.com/tbnobody/OpenDTU.git
ARG PIO_ENV=olimex_esp32_poe
ENV GIT_REPO=${GIT_REPO} \
    PIO_ENV=${PIO_ENV}

WORKDIR /workspace

# Clone the specified repository into workspace root
RUN git clone --depth=1 ${GIT_REPO} .

# Build firmware for the specified environment
RUN platformio run --environment $PIO_ENV

# ---- Stage 2: Extract Artifacts ----
FROM busybox:latest AS artifacts
WORKDIR /out

# Copy the compiled firmware binary
COPY --from=builder /workspace/.pio/build/$PIO_ENV/firmware.bin .

# Default command to list the extracted artifact
CMD ["ls", "-l", "/out"]
