from fastapi import FastAPI

from app.rng import router as rng_router

app = FastAPI(title="Backend API")
app.include_router(rng_router)
