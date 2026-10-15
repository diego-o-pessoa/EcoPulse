from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from .models import SeverityEnum, OccurrenceStatusEnum

class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    city: str

class UserResponse(BaseModel):
    id: UUID
    name: str
    email: EmailStr
    city: Optional[str] = None
    created_at: datetime
    is_active: bool

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class OccurrenceCreate(BaseModel):
    client_event_id: UUID
    category: str
    severity: SeverityEnum
    description: Optional[str] = None
    latitude: float
    longitude: float

class OccurrenceResponse(BaseModel):
    id: UUID
    client_event_id: Optional[UUID] = None
    user_id: Optional[UUID] = None
    category: str
    severity: SeverityEnum
    description: Optional[str] = None
    latitude: str
    longitude: str
    status: OccurrenceStatusEnum
    created_at: datetime
    
    class Config:
        from_attributes = True
