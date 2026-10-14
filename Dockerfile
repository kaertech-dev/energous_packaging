# Use official Python image
FROM python:3.11-slim

# Prevent Python from writing pyc files
ENV PYTHONDONTWRITEBYTECODE=1

# Prevent Python buffering stdout/stderr
ENV PYTHONUNBUFFERED=1

# Keep timestamps in local shop time
ENV TZ=Asia/Manila

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy project files
COPY . .

# Expose Flask port
EXPOSE 5052

# Run as a non-root user
RUN useradd --create-home --uid 10001 appuser
USER appuser

# Run the app with a production WSGI server
CMD ["gunicorn", "--workers", "2", "--timeout", "60", "--bind", "0.0.0.0:5052", "run:app"]
