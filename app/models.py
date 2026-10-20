from datetime import datetime
from enum import Enum
from pydantic import BaseModel, Field, field_validator


class Priority(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class TicketCreate(BaseModel):
    description: str = Field(max_length=2000)
    priority: Priority = Priority.medium

    @field_validator("description")
    @classmethod
    def not_blank(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 10:
            raise ValueError("description must be at least 10 characters")
        return v


class Ticket(TicketCreate):
    id: str
    status: str = "open"
    created_at: datetime