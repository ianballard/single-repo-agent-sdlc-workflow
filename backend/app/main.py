from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="Backend API")


class HealthResponse(BaseModel):
    status: str


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    """Liveness probe consumed by the frontend to display backend status."""
    return HealthResponse(status="ok")
