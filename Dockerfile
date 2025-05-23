# --------------------------------------------------------------------------------
# Global build arguments (can be overridden via CLI or Compose)
# --------------------------------------------------------------------------------
ARG PROJECT_DIR=opendtu
ARG GIT_REPO=https://github.com/tbnobody/OpenDTU.git
ARG PIO_ENV=olimex_esp32_poe

# --------------------------------------------------------------------------------
# Stage 1: Prepare a Python + PlatformIO base image
# --------------------------------------------------------------------------------
FROM python:3.11-slim AS pio-base

# Install system dependencies required by PlatformIO
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      libffi-dev \
      libssl-dev \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install PlatformIO core via pip
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir platformio

# --------------------------------------------------------------------------------
# Stage 2: Clone the project and build firmware
# --------------------------------------------------------------------------------
FROM pio-base AS builder

# Redeclare build arguments for this stage
ARG PROJECT_DIR
ARG GIT_REPO
ARG PIO_ENV

# Expose them as environment variables
ENV PROJECT_DIR=${PROJECT_DIR} \
    GIT_REPO=${GIT_REPO} \
    PIO_ENV=${PIO_ENV}

# Set working directory for cloning/build
WORKDIR /workspace

# Clone the specified repository (depth=1 for caching)
RUN git clone --depth=1 ${GIT_REPO} ${PROJECT_DIR}

# Change into the project directory
WORKDIR /workspace/${PROJECT_DIR}

# Run the PlatformIO build for the given environment
RUN platformio run --environment ${PIO_ENV}

# --------------------------------------------------------------------------------
# Stage 3: Extract the built firmware binary
# --------------------------------------------------------------------------------
FROM busybox:latest AS artifacts

# Redeclare build arguments here too
ARG PROJECT_DIR
ARG PIO_ENV

# Prepare output directory
WORKDIR /out

# Copy the generated firmware binary from the builder stage,
# renaming it to a consistent filename.
COPY --from=builder /workspace/${PROJECT_DIR}/.pio/build/${PIO_ENV}/*.bin ./

# Default command: list the output files
CMD ["ls", "-l", "/out"]
