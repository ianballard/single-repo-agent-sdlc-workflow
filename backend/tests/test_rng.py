from datetime import datetime

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_happy_path_returns_value_in_range():
    response = client.get("/api/rng", params={"min": 5, "max": 10})
    assert response.status_code == 200
    body = response.json()
    assert set(body.keys()) == {"value", "min", "max", "timestamp"}
    assert body["min"] == 5
    assert body["max"] == 10
    assert 5 <= body["value"] <= 10
    # timestamp must parse as ISO-8601
    datetime.fromisoformat(body["timestamp"])


def test_defaults_when_params_omitted():
    response = client.get("/api/rng")
    assert response.status_code == 200
    body = response.json()
    assert body["min"] == 1
    assert body["max"] == 100
    assert 1 <= body["value"] <= 100


def test_min_equals_max_returns_that_value():
    response = client.get("/api/rng", params={"min": 7, "max": 7})
    assert response.status_code == 200
    body = response.json()
    assert body["value"] == 7


def test_min_greater_than_max_returns_422():
    response = client.get("/api/rng", params={"min": 10, "max": 5})
    assert response.status_code == 422


def test_non_integer_min_returns_422():
    response = client.get("/api/rng", params={"min": "abc", "max": 10})
    assert response.status_code == 422


def test_non_integer_max_returns_422():
    response = client.get("/api/rng", params={"min": 1, "max": "1.5"})
    assert response.status_code == 422
