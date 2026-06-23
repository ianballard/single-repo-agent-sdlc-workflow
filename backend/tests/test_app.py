from fastapi.testclient import TestClient

from app.main import app


def test_app_exists():
    assert app.title == "Backend API"


def test_health_returns_200():
    client = TestClient(app)
    response = client.get("/health")
    assert response.status_code == 200


def test_health_returns_ok_body():
    client = TestClient(app)
    response = client.get("/health")
    assert response.json() == {"status": "ok"}
