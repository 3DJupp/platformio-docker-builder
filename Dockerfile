# ------------------------------------------------------------------------------
# Global build args (überschreibbar via Compose build.args oder .env)
# ------------------------------------------------------------------------------
ARG PROJECT_DIR=opendtu
ARG GIT_REPO=https://github.com/tbnobody/OpenDTU.git
ARG PIO_ENV=olimex_esp32_poe
ARG GIT_REF=latest_release            # <- "latest_release" = automatische Release-Erkennung
ARG GITHUB_OWNER=tbnobody
ARG GITHUB_REPO=OpenDTU

# ------------------------------------------------------------------------------
# Stage 1: Base mit Python + PlatformIO
# ------------------------------------------------------------------------------
FROM python:3.11-slim AS pio-base

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential git libffi-dev libssl-dev ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir platformio

# ------------------------------------------------------------------------------
# Stage 2: Bauen (mit Auto-Release-Erkennung)
# ------------------------------------------------------------------------------
FROM pio-base AS builder

# Args in Stage neu deklarieren
ARG PROJECT_DIR
ARG GIT_REPO
ARG PIO_ENV
ARG GIT_REF
ARG GITHUB_OWNER
ARG GITHUB_REPO

ENV PROJECT_DIR=${PROJECT_DIR} \
    GIT_REPO=${GIT_REPO} \
    PIO_ENV=${PIO_ENV} \
    GITHUB_OWNER=${GITHUB_OWNER} \
    GITHUB_REPO=${GITHUB_REPO} \
    GIT_REF=${GIT_REF}

WORKDIR /workspace

# Cache-Buster: ändert sich beim neuesten Release
# (unabhängig davon, ob du "latest_release" nutzt oder einen festen Ref)
ADD https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases.atom /tmp/releases.atom

# Ref ermitteln (neuester Release-Tag oder gegebener Ref), dann klonen & auschecken
RUN set -e; \
    if [ "${GIT_REF}" = "latest_release" ]; then \
      RESOLVED_REF="$(python - <<'PY'\nimport os, json, urllib.request\nu=urllib.request.urlopen(f\"https://api.github.com/repos/{os.environ['GITHUB_OWNER']}/{os.environ['GITHUB_REPO']}/releases/latest\")\nprint(json.load(u)['tag_name'])\nPY)"; \
    else \
      RESOLVED_REF="${GIT_REF}"; \
    fi; \
    echo "Using ref: ${RESOLVED_REF}"; \
    git clone --depth=1 "${GIT_REPO}" "${PROJECT_DIR}"; \
    cd "${PROJECT_DIR}"; \
    # Versuche Tag, sonst Branch/Commit
    git fetch --depth=1 origin "refs/tags/${RESOLVED_REF}:refs/tags/${RESOLVED_REF}" || true; \
    git checkout -q "refs/tags/${RESOLVED_REF}" 2>/dev/null || git checkout -q "${RESOLVED_REF}"

WORKDIR /workspace/${PROJECT_DIR}

# Gebaute Commit-SHA protokollieren
RUN git rev-parse HEAD | tee /tmp/commit.sha

# Build
RUN platformio run --environment ${PIO_ENV}

# ------------------------------------------------------------------------------
# Stage 3: Artefakte bereitstellen (zur Laufzeit ins Volume kopieren)
# ------------------------------------------------------------------------------
FROM busybox:latest AS artifacts

ARG PROJECT_DIR
ARG PIO_ENV

WORKDIR /image_out
COPY --from=builder /workspace/${PROJECT_DIR}/.pio/build/${PIO_ENV}/*.bin ./
COPY --from=builder /tmp/commit.sha ./commit.sha

# Beim Start ins gemountete /out kopieren (überschreibt alte Dateien)
CMD ["sh", "-c", "mkdir -p /out && cp -rf /image_out/. /out/ && echo '--- /out ---' && ls -l /out"]
