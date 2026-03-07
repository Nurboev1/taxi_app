from datetime import datetime

from pydantic import BaseModel, Field


class SupportContactIn(BaseModel):
    subject: str = Field(default="", max_length=120)
    message: str = Field(min_length=3, max_length=2000)


class SupportContactOut(BaseModel):
    message: str
    sent_at: datetime
