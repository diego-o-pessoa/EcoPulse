import asyncio
import aio_pika
import json
import logging
import httpx
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from shared.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("notification-worker")

API_BROADCAST_URL = os.getenv("API_BROADCAST_URL", "http://api:8000/broadcast")

async def process_message(message: aio_pika.IncomingMessage):
    async with message.process():
        body = json.loads(message.body.decode())
        logger.info(f"Received alert: {body.get('event')} for occurrence {body.get('occurrence_id')}")
        
        if body.get('event') == 'alert.created':
            try:
                # Trigger WebSocket broadcast via HTTP to the API gateway
                async with httpx.AsyncClient() as client:
                    response = await client.post(API_BROADCAST_URL, json=body)
                    if response.status_code == 200:
                        logger.info("Successfully triggered WebSocket broadcast")
                    else:
                        logger.warning(f"Failed to trigger broadcast: {response.status_code}")
                
                # TODO: Implement FCM Push Notifications here for offline users
            except Exception as e:
                logger.error(f"Error processing notification: {e}")

async def main():
    connection = await aio_pika.connect_robust(settings.RABBITMQ_URL)
    async with connection:
        channel = await connection.channel()
        
        exchange = await channel.declare_exchange("ecopulse.events", aio_pika.ExchangeType.TOPIC, durable=True)
        
        queue = await channel.declare_queue("notification.processing", durable=True)
        await queue.bind(exchange, routing_key="alert.created")
        
        logger.info("Notification Worker started. Waiting for messages...")
        await queue.consume(process_message)
        
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
