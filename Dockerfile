FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies first so code changes don't invalidate this layer
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

# Run as an unprivileged user
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 9123

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:9123/healthz', timeout=2)"

CMD ["gunicorn", "--bind", "0.0.0.0:9123", "--workers", "2", "--access-logfile", "-", "app:app"]
