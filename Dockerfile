# Multi-stage Docker build for the Redmine MCP Server
FROM python:3.13-slim@sha256:8d9d0b8bcf6506481eae4907c18f5e3e7902e629f5f6d684f9e7c32e85e3ddf0 AS builder

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_CACHE_DIR=/opt/uv-cache

# Install uv package manager
COPY --from=ghcr.io/astral-sh/uv@sha256:10787c682e4184e4f290de1171fd4703dc63de99221f10fe1c99002ce7fa9acc /uv /usr/local/bin/uv

# Create and set working directory
WORKDIR /app

# Copy dependency files and source code for installation
COPY pyproject.toml uv.lock ./
COPY src/ ./src/
COPY README.md ./

# Install dependencies and the project in a virtual environment
RUN uv venv /opt/venv && \
    uv pip install . --python=/opt/venv/bin/python

# Production stage
FROM python:3.13-slim@sha256:8d9d0b8bcf6506481eae4907c18f5e3e7902e629f5f6d684f9e7c32e85e3ddf0 AS runtime

ARG VCS_REF=unknown
LABEL org.opencontainers.image.revision="$VCS_REF"

# Set environment variables
# SERVER_HOST/SERVER_PORT default to a reachable binding so ad-hoc
# `docker run` works without a full env file; override via env_file or -e.
# FASTMCP_HOME points at /app/data so oauth-proxy state (client
# registrations, upstream tokens) lands on the mounted volume instead of
# the container filesystem, where a rebuild would discard it.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    SERVER_HOST=0.0.0.0 \
    SERVER_PORT=8000 \
    FASTMCP_HOME=/app/data/fastmcp

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid appuser --shell /bin/bash --create-home appuser

# Copy virtual environment from builder stage
COPY --from=builder --chown=appuser:appuser /opt/venv /opt/venv

# Set working directory
WORKDIR /app

# Copy application code
COPY --chown=appuser:appuser src/ ./src/
COPY --chown=appuser:appuser README.md ./

# Create directories for logs and data
RUN mkdir -p /app/logs /app/data /app/data/fastmcp && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://127.0.0.1:${SERVER_PORT:-8000}/health || exit 1

STOPSIGNAL SIGTERM

# Expose default port (informational only; override with SERVER_PORT env var)
EXPOSE 8000

# Default command
CMD ["redmine-mcp-server"]
