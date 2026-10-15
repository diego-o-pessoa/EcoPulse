import aio_pika
import json
import logging
from typing import Dict, Any
from .config import settings

logger = logging.getLogger(__name__)

async def get_rabbitmq_connection() -> aio_pika.RobustConnection:
    return await aio_pika.connect_robust(settings.RABBITMQ_URL)

async def publish_event(exchange_name: str, routing_key: str, message_body: Dict[str, Any]):
    try:
        connection = await get_rabbitmq_connection()
        async with connection:
            channel = await connection.channel()
            exchange = await channel.declare_exchange(
                exchange_name, aio_pika.ExchangeType.TOPIC, durable=True
            )
            
            message = aio_pika.Message(
                body=json.dumps(message_body).encode(),
                delivery_mode=aio_pika.DeliveryMode.PERSISTENT
            )
            
            await exchange.publish(message, routing_key=routing_key)
            logger.info(f"Published message to {exchange_name} with key {routing_key}")
    except Exception as e:
        logger.error(f"Failed to publish message: {e}")
        # Em um sistema real poderíamos tentar novamente ou lançar a exceção
