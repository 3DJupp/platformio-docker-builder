# platformio-docker-builder

A reusable, multi-stage Docker template to clone any PlatformIO project, build its firmware, and extract binaries—ideal for CI pipelines, local development, or deployment.

This repository is structured to work with any project folder and Git repository URL. You only need to set the project folder name (e.g., `opendtu`) and the Git repository (e.g., `https://github.com/tbnobody/OpenDTU.git`).

---

## Files

### Dockerfile

```dockerfile
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
ARG PROJECT_DIR=opendtu
ARG GIT_REPO=https://github.com/tbnobody/OpenDTU.git
ARG PIO_ENV=olimex_esp32_poe
ENV PROJECT_DIR=${PROJECT_DIR} \
    GIT_REPO=${GIT_REPO} \
    PIO_ENV=${PIO_ENV}

WORKDIR /workspace

# Clone the specified repository into the project folder
RUN git clone --depth=1 ${GIT_REPO} ${PROJECT_DIR}
WORKDIR /workspace/${PROJECT_DIR}

# Build firmware for the specified environment
RUN platformio run --environment $PIO_ENV

# ---- Stage 2: Extract Artifacts ----
FROM busybox:latest AS artifacts
WORKDIR /out

# Copy the compiled firmware binary
COPY --from=builder /workspace/${PROJECT_DIR}/.pio/build/$PIO_ENV/firmware.bin .

# Default command to list the extracted artifact
CMD ["ls", "-l", "/out"]
```

### docker-compose.yml

```yaml
version: "3.8"

services:
  firmware-builder:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        PROJECT_DIR: ${PROJECT_DIR:-opendtu}
        GIT_REPO: ${GIT_REPO:-https://github.com/tbnobody/OpenDTU.git}
        PIO_ENV:    ${PIO_ENV:-olimex_esp32_poe}
    container_name: pio_firmware_builder
    restart: "no"
    volumes:
      - ./artifacts:/out
```

---

## Usage

1. **Clone this repo** and adjust `.env` (optional):
   ```bash
   git clone https://github.com/3DJupp/platformio-docker-builder.git
   cd platformio-docker-builder
   ```
   Create a `.env` file to override build arguments:
   ```dotenv
   PROJECT_DIR=my_project
   GIT_REPO=https://github.com/youruser/yourrepo.git
   PIO_ENV=esp32dev
   ```

2. **Run with Docker Compose**:
   ```bash
   docker-compose up --build --abort-on-container-exit
   ```

3. **Find your firmware**:
   After the build finishes, the binary `firmware.bin` will be in the `./artifacts` folder.

---

### Example for OpenDTU

Using the defaults builds the OpenDTU firmware for the Olimex ESP32-POE board:
```bash
PROJECT_DIR=opendtu \
GIT_REPO=https://github.com/tbnobody/OpenDTU.git \
PIO_ENV=olimex_esp32_poe \
  docker-compose up --build --abort-on-container-exit
```

You can now use this template for **any** PlatformIO project by changing the above variables.
