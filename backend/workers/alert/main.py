import asyncio
import aio_pika
import json
import logging
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from shared.config import settings
from shared.messaging import publish_event

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("alert-worker")

async def process_message(message: aio_pika.IncomingMessage):
    async with message.process():
        body = json.loads(message.body.decode())
        logger.info(f"Received event: {body.get('event')} for occurrence {body.get('occurrence_id')}")
        
        if body.get('event') == 'occurrence.processed':
            # Aqui poderíamos buscar os usuários próximos no banco
            # Ex: select(User).filter(ST_DWithin(User.location, occurrence_location, user.alert_radius))
            # Para fins didáticos e simplicidade sem um location tracker ativo, 
            # assumimos que todos conectados na mesma região ou globais devam ser notificados.
            
            alert_event = {
                "event": "alert.created",
                "occurrence_id": body.get("occurrence_id"),
                "message": f"Novo risco reportado: {body.get('category')} ({body.get('severity')})",
                "latitude": body.get("latitude"),
                "longitude": body.get("longitude")
            }
            
            logger.info("Publishing alert.created event")
            await publish_event("ecopulse.events", "alert.created", alert_event)

async def main():
    connection = await aio_pika.connect_robust(settings.RABBITMQ_URL)
    async with connection:
        channel = await connection.channel()
        
        exchange = await channel.declare_exchange("ecopulse.events", aio_pika.ExchangeType.TOPIC, durable=True)
        
        queue = await channel.declare_queue("alert.processing", durable=True)
        await queue.bind(exchange, routing_key="occurrence.processed")
        
        logger.info("Alert Worker started. Waiting for messages...")
        await queue.consume(process_message)
        
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
