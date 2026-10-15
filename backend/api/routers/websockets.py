from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import List, Dict

router = APIRouter()

class ConnectionManager:
    def __init__(self):
        # Em um sistema distribuído real, as conexões ficariam em Redis Pub/Sub ou similar
        # para que múltiplos pods da API pudessem se comunicar.
        # Aqui, estamos criando uma lista na memória do uvicorn worker para simplificação da demo.
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except Exception:
                pass

manager = ConnectionManager()

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # We don't really expect clients to send text, they just listen.
    except WebSocketDisconnect:
        manager.disconnect(websocket)

# Rota interna para o Notification Worker avisar a API para dar broadcast
# Em uma arquitetura real, o worker publicaria no Redis PubSub e a API assinaria.
@router.post("/broadcast")
async def broadcast_message(message: dict):
    import json
    await manager.broadcast(json.dumps(message))
    return {"status": "broadcasted"}
