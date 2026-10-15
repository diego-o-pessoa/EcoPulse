from fastapi import APIRouter, Depends, status, Query
import uuid
import datetime
import json
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from shared.models import User, Occurrence
from shared import schemas
from api.dependencies import get_current_user
from shared.messaging import publish_event
from sqlalchemy.ext.asyncio import AsyncSession
from shared.database import get_db
from sqlalchemy.future import select
from geoalchemy2.functions import ST_DWithin
from geoalchemy2.elements import WKTElement
import redis.asyncio as redis
from shared.config import settings

router = APIRouter()
redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)

@router.post("", status_code=status.HTTP_202_ACCEPTED)
async def create_occurrence(
    occurrence: schemas.OccurrenceCreate, 
    current_user: User = Depends(get_current_user)
):
    """
    Recebe uma nova ocorrência e pública um evento para ser processado assincronamente.
    """
    event_id = str(uuid.uuid4())
    
    message_body = {
        "event": "occurrence.created",
        "event_id": event_id,
        "client_event_id": str(occurrence.client_event_id),
        "user_id": str(current_user.id),
        "category": occurrence.category,
        "severity": occurrence.severity.value,
        "description": occurrence.description,
        "latitude": occurrence.latitude,
        "longitude": occurrence.longitude,
        "created_at": datetime.datetime.utcnow().isoformat()
    }
    
    await publish_event(
        exchange_name="ecopulse.events",
        routing_key="occurrence.created",
        message_body=message_body
    )
    
    return {
        "status": "accepted",
        "event_id": event_id,
        "message": "Ocorrência recebida e será processada."
    }

@router.get("/nearby", response_model=list[schemas.OccurrenceResponse])
async def get_nearby_occurrences(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
    radius: int = Query(5000, description="Raio em metros"),
    db: AsyncSession = Depends(get_db)
):
    cache_key = f"occurrences:nearby:{lat}:{lng}:{radius}"
    cached_data = await redis_client.get(cache_key)
    if cached_data:
        return json.loads(cached_data)

    point = WKTElement(f"POINT({lng} {lat})", srid=4326)
    result = await db.execute(
        select(Occurrence)
        .filter(ST_DWithin(Occurrence.location, point, radius))
        .order_by(Occurrence.created_at.desc())
        .limit(100)
    )
    
    occurrences = result.scalars().all()
    # Serialize to save in cache (need dicts)
    # This could use pydantic json dump but we'll manually convert to dict for cache
    response_data = []
    for occ in occurrences:
        response_data.append({
            "id": str(occ.id),
            "category": occ.category,
            "severity": occ.severity.value,
            "description": occ.description,
            "latitude": occ.latitude,
            "longitude": occ.longitude,
            "status": occ.status.value,
            "created_at": occ.created_at.isoformat()
        })
    
    # Store in cache for 30s
    await redis_client.setex(cache_key, 30, json.dumps(response_data))
    return occurrences
