from datetime import datetime

from pydantic import BaseModel


class ChatOut(BaseModel):
    id: int
    request_id: int
    passenger_id: int
    driver_id: int

    class Config:
        from_attributes = True


class ChatMessageCreateIn(BaseModel):
    body: str


class ChatMessageOut(BaseModel):
    id: int
    chat_id: int
    sender_id: int
    body: str
    created_at: datetime

    class Config:
        from_attributes = True
