import asyncio
import aio_pika
import json
import logging
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from shared.config import settings
from shared.database import AsyncSessionLocal
from shared.models import Occurrence, OccurrenceStatusEnum
from sqlalchemy.future import select

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("occurrence-worker")

async def process_message(message: aio_pika.IncomingMessage):
    async with message.process():
        body = json.loads(message.body.decode())
        logger.info(f"Received event: {body.get('event')} with ID {body.get('event_id')}")
        
        if body.get('event') == 'occurrence.created':
            try:
                client_event_id = body.get('client_event_id')
                
                async with AsyncSessionLocal() as session:
                    # Check Idempotency
                    result = await session.execute(
                        select(Occurrence).filter(Occurrence.client_event_id == client_event_id)
                    )
                    existing = result.scalars().first()
                    
                    if existing:
                        logger.warning(f"Occurrence with client_event_id {client_event_id} already processed. Skipping.")
                        return

                    new_occurrence = Occurrence(
                        client_event_id=client_event_id,
                        user_id=body.get('user_id'),
                        category=body.get('category'),
                        severity=body.get('severity'),
                        description=body.get('description'),
                        latitude=str(body.get('latitude')),
                        longitude=str(body.get('longitude')),
                        # Location will be built using PostGIS ST_MakePoint logic later or triggers.
                        # For now, let's use a WKT string.
                        location=f"SRID=4326;POINT({body.get('longitude')} {body.get('latitude')})",
                        status=OccurrenceStatusEnum.ACTIVE
                    )
                    
                    session.add(new_occurrence)
                    await session.commit()
                    logger.info(f"Occurrence {client_event_id} saved to DB.")
                    
                    # Invalidate cache
                    import redis.asyncio as redis
                    redis_client = redis.from_url(settings.REDIS_URL)
                    # Apagar chaves baseadas em raio pode ser complexo sem KEYS, simplificamos apagando padrão ou no get.
                    # Numa versão real, usaríamos H3 para limpar áreas específicas.
                    
                    # Publish occurrence.processed
                    from shared.messaging import publish_event
                    await publish_event(
                        "ecopulse.events",
                        "occurrence.processed",
                        {
                            "event": "occurrence.processed",
                            "occurrence_id": str(new_occurrence.id),
                            "category": new_occurrence.category,
                            "severity": new_occurrence.severity.value,
                            "latitude": new_occurrence.latitude,
                            "longitude": new_occurrence.longitude,
                            "description": new_occurrence.description
                        }
                    )
                    
            except Exception as e:
                logger.error(f"Error processing occurrence: {e}")
                raise e # Nack the message so it returns to queue or goes to DLQ

async def main():
    connection = await aio_pika.connect_robust(settings.RABBITMQ_URL)
    async with connection:
        channel = await connection.channel()
        
        # DLQ setup
        dlx_exchange = await channel.declare_exchange("ecopulse.dlx", aio_pika.ExchangeType.DIRECT)
        dlq = await channel.declare_queue("ecopulse.dlq", durable=True)
        await dlq.bind(dlx_exchange, routing_key="dlq")
        
        exchange = await channel.declare_exchange("ecopulse.events", aio_pika.ExchangeType.TOPIC, durable=True)
        
        queue = await channel.declare_queue(
            "occurrence.processing", 
            durable=True,
            arguments={
                "x-dead-letter-exchange": "ecopulse.dlx",
                "x-dead-letter-routing-key": "dlq"
            }
        )
        await queue.bind(exchange, routing_key="occurrence.created")
        
        logger.info("Occurrence Worker started. Waiting for messages...")
        await queue.consume(process_message)
        
        await asyncio.Future() # Run forever

if __name__ == "__main__":
    asyncio.run(main())
