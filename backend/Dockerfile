# syntax=docker/dockerfile:1.7

# ---------------------------------------------------------------------------
# Build stage: resolve our app's Poetry deps into /app/.venv
# ---------------------------------------------------------------------------
ARG PYTHON_VERSION=3.13
ARG POETRY_VERSION=2.4.1

FROM python:${PYTHON_VERSION}-slim AS builder

ARG POETRY_VERSION

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=true \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_CACHE_DIR=/tmp/poetry-cache

# build-essential needed only if a wheel falls back to source compile.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir "poetry==${POETRY_VERSION}"

WORKDIR /app

# Cache deps independently of app code: copy manifests first.
COPY pyproject.toml poetry.lock ./
RUN poetry install --no-root --only main


# ---------------------------------------------------------------------------
# Runtime stage: slim image + ffmpeg + isolated spotdl + our venv + app code
# ---------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:/opt/spotdl-venv/bin:$PATH" \
    SPOTDL_EXECUTABLE=/opt/spotdl-venv/bin/spotdl

# Runtime system deps. ffmpeg is required by spotdl/yt-dlp for transcoding.
# apt-get upgrade picks up any fixed CVEs in the base image (e.g. libssl3).
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install spotdl into its own isolated venv to keep its dependency closure
# (notably fastapi==0.103.x) out of our app's venv. See DECISIONLOG
# 2026-06-08 "spotdl install isolated" for the why.
RUN python3 -m venv /opt/spotdl-venv \
    && /opt/spotdl-venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/spotdl-venv/bin/pip install --no-cache-dir spotdl==4.5.0 \
    && /opt/spotdl-venv/bin/spotdl --version

# Non-root runtime user.
RUN groupadd --system --gid 1000 app \
    && useradd  --system --uid 1000 --gid app \
                --create-home --shell /usr/sbin/nologin app

WORKDIR /app

# Bring in our app's locked venv from the builder.
COPY --from=builder --chown=app:app /app/.venv /app/.venv

# Copy app code and Alembic migrations.
COPY --chown=app:app app/ ./app/
COPY --chown=app:app alembic/ ./alembic/
COPY --chown=app:app alembic.ini ./
COPY --chown=app:app pyproject.toml ./

USER app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
