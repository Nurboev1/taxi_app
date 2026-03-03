from datetime import datetime

from pydantic import BaseModel


class NotificationOut(BaseModel):
    id: int
    kind: str
    title: str
    body: str | None
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True
