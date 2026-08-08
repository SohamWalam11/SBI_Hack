# ═══════════════════════════════════════════════════════════════════
#  VeriTrust AI — Backend Proxy Dockerfile
# ═══════════════════════════════════════════════════════════════════
#  Multi-stage build for the deterministic verifier gateway.
#  Optimized for minimal image size and security.
# ═══════════════════════════════════════════════════════════════════

FROM python:3.12-slim AS base

# Security: run as non-root
RUN groupadd -r veritrust && useradd -r -g veritrust veritrust

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ── Install Python dependencies ──────────────────────────────────
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip "setuptools<70.0.0" wheel && \
    pip install --no-cache-dir --no-build-isolation -r requirements.txt

# ── Copy application code ────────────────────────────────────────
COPY app/ ./app/
COPY data/ ./data/

# ── Create runtime directories ───────────────────────────────────
RUN mkdir -p /app/chroma_db /app/audit_logs && \
    chown -R veritrust:veritrust /app

# Switch to non-root user
USER veritrust

# ── Expose & Run ─────────────────────────────────────────────────
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD python -c "import httpx; httpx.get('http://localhost:8000/api/v1/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
