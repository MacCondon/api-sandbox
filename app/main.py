"""FastAPI application that returns a JSON payload with timestamp and message."""

import time

from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(
    title="API Sandbox",
    description="Simple REST API that returns a message with timestamp",
    version="1.0.0",
)


class MessageResponse(BaseModel):
    """Response model for the message endpoint."""

    message: str
    timestamp: int


@app.get("/", response_model=MessageResponse)
async def get_message() -> MessageResponse:
    """Return a JSON payload with a static message and current timestamp."""
    return MessageResponse(
        message="Automate all the things!",
        timestamp=int(time.time()),
    )


@app.get("/health")
async def health_check() -> dict:
    """Health check endpoint for Kubernetes probes."""
    return {"status": "healthy"}
