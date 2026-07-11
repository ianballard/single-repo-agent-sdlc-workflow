from fastapi import FastAPI

app = FastAPI(title="Backend API")


@app.get("/health")
def health() -> dict[str, str]:
    """Liveness probe. Returns a static status so callers can confirm the
    backend is reachable."""
    return {"status": "ok"}
