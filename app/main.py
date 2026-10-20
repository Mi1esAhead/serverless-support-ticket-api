import logging
import os
import uuid
from datetime import datetime, timezone
from functools import lru_cache

from fastapi import Depends, FastAPI, HTTPException
from fastapi.responses import JSONResponse, Response
from mangum import Mangum

from .models import Ticket, TicketCreate
from .storage import StorageError, TicketNotFound, TicketStore

logger = logging.getLogger("ticket-api")
logger.setLevel(logging.INFO)

# Interactive docs are off by default: less public attack surface.
# Set ENABLE_DOCS=1 for local development.
_docs = os.environ.get("ENABLE_DOCS") == "1"
app = FastAPI(
    title="Support Ticket API",
    docs_url="/docs" if _docs else None,
    redoc_url=None,
    openapi_url="/openapi.json" if _docs else None,
)


@lru_cache
def get_store() -> TicketStore:
    return TicketStore()


@app.exception_handler(StorageError)
async def storage_error_handler(_, exc: StorageError):
    logger.error("storage failure: %s", exc)  # detail stays in our logs
    return JSONResponse(status_code=502, content={"error": "storage_unavailable"})


@app.get("/health")
def health():
    return {"status": "ok"}


@app.options("/tickets", include_in_schema=False)
def tickets_preflight():
    return Response(status_code=204)


@app.post("/tickets", response_model=Ticket, status_code=201)
def create_ticket(body: TicketCreate, store: TicketStore = Depends(get_store)):
    ticket = Ticket(
        id=str(uuid.uuid4()),
        created_at=datetime.now(timezone.utc),
        **body.model_dump(),
    )
    store.put(ticket)
    return ticket


@app.get("/tickets/{ticket_id}", response_model=Ticket)
def get_ticket(ticket_id: uuid.UUID, store: TicketStore = Depends(get_store)):
    try:
        return store.get(str(ticket_id))
    except TicketNotFound:
        raise HTTPException(status_code=404, detail="ticket not found")


# AWS Lambda entry point: translates API Gateway events into ASGI calls.
handler = Mangum(app, lifespan="off")