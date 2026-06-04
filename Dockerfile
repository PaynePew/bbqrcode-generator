# syntax=docker/dockerfile:1
#
# Multi-stage production image for qr_code_generator.
#   Stage 1 builds the Vite/React/TS frontend.
#   Stage 2 is the FastAPI app that serves SPA + /api + /r as ONE upstream
#   (same-origin behind the shared edge Caddy — see platform/docs/tenant-deploy-contract.md).
#
# SEEDED by the platform layer (see platform/docs/requests/qrcode-onboarding-handoff.md).
# qrcode's agent owns and tunes this file.

# ---- Stage 1: build frontend -> /frontend/dist ----
FROM node:22-alpine AS frontend
WORKDIR /frontend
# Install deps first (cached until the lockfile changes).
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build                 # tsc && vite build  ->  /frontend/dist

# ---- Stage 2: Python runtime ----
FROM python:3.12-slim AS app
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1
WORKDIR /app

# psycopg2-binary + Pillow (qrcode[pil]) ship manylinux wheels → no apt build deps needed.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Application code + migrations.
COPY backend/ ./backend/
COPY alembic/ ./alembic/
COPY alembic.ini ./

# Frontend build output, served by backend/main.py via SPAStaticFiles (mounted
# after the routers so /api and /r win; falls back to index.html for client-side
# deep routes). The mount is gated on SERVE_SPA, set below.
COPY --from=frontend /frontend/dist ./frontend/dist

# Serve the SPA from this container in production (main.py gates the mount on this).
ENV SERVE_SPA=true

# Run as non-root.
RUN useradd --create-home --uid 10001 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
# 1 uvicorn worker at launch: the in-memory rate limiter (ADR 0007) multiplies its
# effective limit by worker count, so >1 worker is unsafe until a Redis-backed
# limiter lands (qrcode Phase 8). Do NOT add --workers before then.
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
