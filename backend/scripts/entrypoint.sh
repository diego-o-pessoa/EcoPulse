#!/bin/bash
echo "Waiting for PostgreSQL to start..."
sleep 5

echo "Applying migrations..."
alembic upgrade head

echo "Starting FastAPI..."
uvicorn api.main:app --host 0.0.0.0 --port 8000
