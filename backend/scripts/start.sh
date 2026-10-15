#!/bin/bash
echo "Iniciando infraestrutura do EcoPulse..."
docker compose -f ../compose.yaml up -d

echo "Aguardando banco de dados..."
sleep 10

echo "Infraestrutura rodando!"
echo "RabbitMQ UI: http://localhost:15672 (guest/guest)"
echo "MinIO UI: http://localhost:9001 (admin/admin123)"

echo "Iniciando FastAPI Gateway (Desenvolvimento)..."
cd ../backend
source venv/Scripts/activate 2>/dev/null || source venv/bin/activate 2>/dev/null
uvicorn api.main:app --reload --port 8000
