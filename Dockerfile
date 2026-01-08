# Build stage
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder

ENV UV_COMPILE_BYTECODE=0 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0

WORKDIR /app

# Install dependencies without the project
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project --no-dev

# Copy application code
COPY pyproject.toml uv.lock /app/
COPY app/ /app/app/

# Install the project
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# Runtime stage
FROM python:3.13-slim-bookworm

WORKDIR /app

# Create non-root user
RUN groupadd --system --gid 999 appuser \
    && useradd --system --gid 999 --uid 999 --create-home appuser

# Copy environment and code
COPY --from=builder --chown=appuser:appuser /app/.venv /app/.venv
COPY --from=builder --chown=appuser:appuser /app/app /app/app

# Create required directories with proper permissions
# (Adjusted based on standard needs, removed temp/data/transcripts specific to reference)
RUN mkdir -p /app/temp \
    && chown -R appuser:appuser /app/temp

# Set environment variables
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONOPTIMIZE=2 \
    TZ=Asia/Bangkok

# Switch to non-root user
USER appuser

EXPOSE 8000

# Using python -m fastapi run as in reference (standard for new FastAPI)
CMD ["python", "-m", "fastapi", "run", "app/main.py", "--host", "0.0.0.0", "--port", "8000"]