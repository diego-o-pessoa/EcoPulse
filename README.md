# EcoPulse - Sistema Distribuído Mobile

EcoPulse é uma plataforma distribuída mobile para monitoramento colaborativo de riscos ambientais urbanos e qualidade do ar. O projeto foi construído para a disciplina de Desenvolvimento de Sistemas Distribuídos (DSD) do curso de Ciência da Computação.

## 🏛️ Arquitetura

O EcoPulse demonstra os seguintes conceitos de Sistemas Distribuídos:
- **Microsserviços & Orientação a Eventos**: O processamento pesado não ocorre na API principal. Requisições geram eventos publicados num Message Broker.
- **Mensageria Assíncrona**: Utilização de `RabbitMQ` para comunicação entre serviços (`Occurrence Worker`, `Alert Worker`, `Notification Worker`).
- **Tolerância a Falhas & DLQ**: Filas resilientes com Dead Letter Queue (DLQ) para mensagens que falham o processamento.
- **Cache Distribuído e Consistência Eventual**: O Redis armazena os dados mais recentes das regiões, sendo invalidado quando novas ocorrências são reportadas.
- **Consultas Geoespaciais**: Utilização de `PostgreSQL` + `PostGIS` (`ST_DWithin`) para consultar riscos próximos.
- **Comunicação em Tempo Real**: `WebSockets` para enviar notificações assíncronas de volta aos clientes.
- **Offline-First (Sincronização)**: O aplicativo mobile (`Flutter` + `SQLite`) salva ocorrências localmente sem rede, e sincroniza via background service.

## 🛠️ Tecnologias

- **Backend**: Python 3.11, FastAPI, SQLAlchemy, Alembic, Pydantic, aio_pika
- **Mobile**: Flutter, Riverpod, flutter_map, sqflite
- **Infraestrutura (Docker)**: PostgreSQL (PostGIS), RabbitMQ, Redis, MinIO

## 🚀 Como Executar

### 1. Iniciar Infraestrutura e Backend (Docker)
Crie o arquivo `.env` baseado no `.env.example`:
```bash
cp .env.example .env
```

Suba os contêineres:
```bash
docker compose up -d --build
```
Isso iniciará:
- Banco de Dados (Porta 5432)
- RabbitMQ (Painel: http://localhost:15672)
- Redis (Porta 6379)
- MinIO (Painel: http://localhost:9001)
- API FastAPI (Documentação: http://localhost:8000/docs)
- Occurrence Worker
- Alert Worker
- Notification Worker

As migrações do banco (Alembic) serão aplicadas automaticamente pelo script `entrypoint.sh` da API.

### 2. Executar o Aplicativo Flutter
```bash
cd mobile
flutter pub get
flutter run
```

## 📚 Diagrama de Arquitetura Conceitual

```mermaid
graph TD;
    Mobile[Flutter App] -->|REST /occurrences| API[FastAPI Gateway]
    API -->|Publish| RMQ[RabbitMQ (ecopulse.events)]
    RMQ -->|Consume| OW[Occurrence Worker]
    OW -->|Write| DB[(PostgreSQL/PostGIS)]
    OW -->|Invalidate/Write| Cache[(Redis)]
    OW -->|Publish processed| RMQ
    RMQ -->|Consume| AW[Alert Worker]
    AW -->|Publish alert| RMQ
    RMQ -->|Consume| NW[Notification Worker]
    NW -->|Trigger Broadcast| API
    API -->|WebSocket| Mobile
```

## 🧪 Roteiro de Demonstração Acadêmica
1. **Tempo Real**: Crie uma ocorrência no Swagger (API) ou App e veja outro cliente recebendo via WebSocket.
2. **Tolerância a Falhas**: Pare o contêiner `ecopulse-occurrence-worker`, envie uma requisição. O HTTP retorna `202 Accepted` imediatamente. A mensagem fica no RabbitMQ. Reinicie o worker e ele processará a mensagem pendente.
3. **Cache**: A rota `/occurrences/nearby` consulta o Redis antes do PostGIS.
4. **Idempotência**: Requisições repetidas com o mesmo `client_event_id` são descartadas no Worker, essencial para a resiliência Mobile.
