from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from uuid import UUID
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from shared.database import get_db
from shared.models import User
from shared import schemas
from api.dependencies import get_current_user

router = APIRouter()

@router.get("/me", response_model=schemas.UserResponse)
async def read_user_me(current_user: User = Depends(get_current_user)):
    return current_user

# Future: update profile endpoint
