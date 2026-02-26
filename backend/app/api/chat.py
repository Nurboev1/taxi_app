from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import ALGORITHM
from app.core.settings import settings
from app.db.session import SessionLocal, get_db
from app.models.chat import Chat, ChatMessage
from app.models.user import User
from app.schemas.chat import ChatMessageCreateIn, ChatMessageOut, ChatOut
from app.services.chat_manager import chat_manager

router = APIRouter(tags=["chat"])


def assert_chat_member(chat: Chat, user: User) -> None:
    if user.id not in (chat.driver_id, chat.passenger_id):
        raise HTTPException(status_code=403, detail="Bu chat sizga tegishli emas")


@router.get("/chats/{chat_id}")
def get_chat(
    chat_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    chat = db.scalar(select(Chat).where(Chat.id == chat_id))
    if not chat:
        raise HTTPException(status_code=404, detail="Chat topilmadi")
    assert_chat_member(chat, current_user)

    messages = db.scalars(
        select(ChatMessage).where(ChatMessage.chat_id == chat_id).order_by(ChatMessage.created_at.asc())
    ).all()
    return {
        "chat": ChatOut.model_validate(chat),
        "messages": [ChatMessageOut.model_validate(m) for m in messages],
    }


@router.post("/chats/{chat_id}/messages", response_model=ChatMessageOut)
async def send_message(
    chat_id: int,
    payload: ChatMessageCreateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    chat = db.scalar(select(Chat).where(Chat.id == chat_id))
    if not chat:
        raise HTTPException(status_code=404, detail="Chat topilmadi")
    assert_chat_member(chat, current_user)

    msg = ChatMessage(chat_id=chat_id, sender_id=current_user.id, body=payload.body)
    db.add(msg)
    db.commit()
    db.refresh(msg)

    payload_out = ChatMessageOut.model_validate(msg).model_dump(mode="json")
    await chat_manager.broadcast(chat_id, payload_out)
    return msg


@router.websocket("/ws/chats/{chat_id}")
async def ws_chat(websocket: WebSocket, chat_id: int):
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4401)
        return

    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[ALGORITHM])
        user_id = int(payload.get("sub"))
    except (JWTError, TypeError, ValueError):
        await websocket.close(code=4401)
        return

    db = SessionLocal()
    try:
        user = db.scalar(select(User).where(User.id == user_id))
        chat = db.scalar(select(Chat).where(Chat.id == chat_id))
        if not user or not chat or user.id not in (chat.driver_id, chat.passenger_id):
            await websocket.close(code=4403)
            return

        await chat_manager.connect(chat_id, websocket)
        while True:
            data = await websocket.receive_json()
            body = str(data.get("body", "")).strip()
            if not body:
                continue

            msg = ChatMessage(chat_id=chat_id, sender_id=user.id, body=body)
            db.add(msg)
            db.commit()
            db.refresh(msg)
            await chat_manager.broadcast(chat_id, ChatMessageOut.model_validate(msg).model_dump(mode="json"))
    except WebSocketDisconnect:
        chat_manager.disconnect(chat_id, websocket)
    finally:
        db.close()
