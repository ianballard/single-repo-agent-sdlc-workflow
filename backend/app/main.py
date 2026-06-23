from fastapi import FastAPI

app = FastAPI(title="Backend API")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
