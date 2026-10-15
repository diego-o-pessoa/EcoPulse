import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from geoalchemy2 import Geography
import enum

from .database import Base

class SeverityEnum(str, enum.Enum):
    LOW = "Baixa"
    MEDIUM = "Média"
    HIGH = "Alta"
    CRITICAL = "Crítica"

class OccurrenceStatusEnum(str, enum.Enum):
    PENDING = "pending"
    ACTIVE = "active"
    RESOLVED = "resolved"
    REJECTED = "rejected"
    EXPIRED = "expired"

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    city = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_active = Column(Boolean, default=True)

    occurrences = relationship("Occurrence", back_populates="user")
    # notification_preferences = relationship("NotificationPreference", back_populates="user", uselist=False)

class Occurrence(Base):
    __tablename__ = "occurrences"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    client_event_id = Column(UUID(as_uuid=True), unique=True, nullable=True, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    category = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)
    severity = Column(SQLEnum(SeverityEnum), nullable=False)
    latitude = Column(String, nullable=False) # Helper column if geography not easy to parse on client
    longitude = Column(String, nullable=False)
    location = Column(Geography(geometry_type='POINT', srid=4326), nullable=False, index=True)
    address = Column(String, nullable=True)
    city = Column(String, nullable=True)
    state = Column(String, nullable=True)
    status = Column(SQLEnum(OccurrenceStatusEnum), default=OccurrenceStatusEnum.PENDING)
    photo_url = Column(String, nullable=True)
    h3_index = Column(String, nullable=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="occurrences")

