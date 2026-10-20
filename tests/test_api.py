import boto3
import pytest
from botocore.stub import Stubber
from fastapi.testclient import TestClient
from moto import mock_aws

from app.main import app, get_store
from app.storage import TicketStore

BUCKET = "test-tickets"
FAKE_ID = "123e4567-e89b-12d3-a456-426614174000"


@pytest.fixture
def client():
    with mock_aws():
        s3 = boto3.client("s3", region_name="us-east-1")
        s3.create_bucket(Bucket=BUCKET)
        store = TicketStore(bucket=BUCKET, client=s3)
        app.dependency_overrides[get_store] = lambda: store
        yield TestClient(app)
        app.dependency_overrides.clear()


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_docs_disabled_by_default(client):
    assert client.get("/docs").status_code == 404
    assert client.get("/openapi.json").status_code == 404


def test_create_and_retrieve(client):
    r = client.post("/tickets", json={"description": "VPN drops every 10 minutes", "priority": "high"})
    assert r.status_code == 201
    body = r.json()
    assert body["status"] == "open" and body["priority"] == "high"

    r2 = client.get(f"/tickets/{body['id']}")
    assert r2.status_code == 200
    assert r2.json() == body


def test_client_cannot_set_server_fields(client):
    r = client.post("/tickets", json={
        "description": "Trying to choose my own id", "id": "custom", "status": "closed",
    })
    assert r.status_code == 201
    assert r.json()["id"] != "custom" and r.json()["status"] == "open"


@pytest.mark.parametrize("payload", [
    {},
    {"description": ""},
    {"description": "short"},
    {"description": "x" * 2001},
    {"description": "valid description here", "priority": "urgent"},
])
def test_invalid_input_returns_422(client, payload):
    assert client.post("/tickets", json=payload).status_code == 422


def test_bad_id_format_returns_422(client):
    assert client.get("/tickets/not-a-uuid").status_code == 422


def test_missing_ticket_returns_404(client):
    assert client.get(f"/tickets/{FAKE_ID}").status_code == 404


def _stubbed_client(method, code, status):
    s3 = boto3.client("s3", region_name="us-east-1",
                      aws_access_key_id="x", aws_secret_access_key="x")
    stub = Stubber(s3)
    stub.add_client_error(method, service_error_code=code, http_status_code=status)
    stub.activate()
    return s3


def test_s3_put_failure_returns_502():
    store = TicketStore(bucket=BUCKET, client=_stubbed_client("put_object", "AccessDenied", 403))
    app.dependency_overrides[get_store] = lambda: store
    r = TestClient(app).post("/tickets", json={"description": "Printer offline on floor 3"})
    app.dependency_overrides.clear()
    assert r.status_code == 502
    assert r.json() == {"error": "storage_unavailable"}


def test_s3_get_failure_returns_502():
    store = TicketStore(bucket=BUCKET, client=_stubbed_client("get_object", "InternalError", 500))
    app.dependency_overrides[get_store] = lambda: store
    r = TestClient(app).get(f"/tickets/{FAKE_ID}")
    app.dependency_overrides.clear()
    assert r.status_code == 502


def test_lambda_handler_end_to_end(client):
    """Send a real API Gateway v2 event through the Mangum handler."""
    from app.main import handler
    event = {
        "version": "2.0", "routeKey": "$default", "rawPath": "/health", "rawQueryString": "",
        "headers": {"host": "example.com"},
        "requestContext": {
            "http": {"method": "GET", "path": "/health", "protocol": "HTTP/1.1",
                     "sourceIp": "1.2.3.4", "userAgent": "test"},
            "stage": "$default",
        },
        "isBase64Encoded": False,
    }
    resp = handler(event, None)
    assert resp["statusCode"] == 200
    assert '"ok"' in resp["body"]


def test_ticket_preflight_returns_204(client):
    response = client.options(
        "/tickets",
        headers={
            "Origin": "https://m1portfolio.com",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "content-type",
        },
    )
    assert response.status_code == 204
    assert response.content == b""