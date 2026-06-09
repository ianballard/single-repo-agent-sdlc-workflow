import random
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/api")


class RngResponse(BaseModel):
    value: int
    min: int
    max: int
    timestamp: datetime


@router.get("/rng", response_model=RngResponse)
def get_random_number(min: int = 1, max: int = 100) -> RngResponse:
    if min > max:
        raise HTTPException(
            status_code=422,
            detail=f"min ({min}) must be less than or equal to max ({max})",
        )
    return RngResponse(
        value=random.randint(min, max),
        min=min,
        max=max,
        timestamp=datetime.now(timezone.utc),
    )
