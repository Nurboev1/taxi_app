from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from jose import JWTError, jwt
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import ALGORITHM
from app.core.settings import settings
from app.db.session import SessionLocal, get_db
from app.models.chat import Chat, ChatMessage
from app.models.user import User
from app.schemas.chat import ChatListItemOut, ChatMessageCreateIn, ChatMessageOut, ChatOut
from app.services.chat_manager import chat_manager
from app.services.notifications import create_notification

router = APIRouter(tags=["chat"])


def assert_chat_member(chat: Chat, user: User) -> None:
    if user.id not in (chat.driver_id, chat.passenger_id):
        raise HTTPException(status_code=403, detail="Bu chat sizga tegishli emas")


@router.get("/chats/my", response_model=list[ChatListItemOut])
def my_chats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    chats = db.scalars(
        select(Chat).where((Chat.driver_id == current_user.id) | (Chat.passenger_id == current_user.id)).order_by(Chat.created_at.desc())
    ).all()

    items: list[ChatListItemOut] = []
    for chat in chats:
        passenger = db.scalar(select(User).where(User.id == chat.passenger_id))
        driver = db.scalar(select(User).where(User.id == chat.driver_id))
        last_message = db.scalar(
            select(ChatMessage)
            .where(ChatMessage.chat_id == chat.id)
            .order_by(ChatMessage.created_at.desc())
            .limit(1)
        )
        items.append(
            ChatListItemOut(
                chat_id=chat.id,
                request_id=chat.request_id,
                passenger_name=passenger.name if passenger else "Mijoz",
                driver_name=driver.name if driver else "Taxist",
                last_message=last_message.body if last_message else None,
                last_message_at=last_message.created_at if last_message else None,
            )
        )
    return items


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
    passenger = db.scalar(select(User).where(User.id == chat.passenger_id))
    driver = db.scalar(select(User).where(User.id == chat.driver_id))
    peer = driver if current_user.id == chat.passenger_id else passenger
    peer_phone = None
    if peer and peer.phone_visible:
        peer_phone = peer.phone
    return {
        "chat": ChatOut.model_validate(chat),
        "peer_name": peer.name if peer else None,
        "peer_phone": peer_phone,
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

    other_user_id = chat.passenger_id if current_user.id == chat.driver_id else chat.driver_id
    other_user = db.scalar(select(User).where(User.id == other_user_id))
    if other_user:
        create_notification(
            db,
            user=other_user,
            kind="chat_message",
            uz_title="Yangi xabar",
            ru_title="Новое сообщение",
            en_title="New message",
            uz_body=f"{current_user.name}: {payload.body[:80]}",
            ru_body=f"{current_user.name}: {payload.body[:80]}",
            en_body=f"{current_user.name}: {payload.body[:80]}",
        )

    db.commit()
    db.refresh(msg)

    payload_out = ChatMessageOut.model_validate(msg).model_dump(mode="json")
    await chat_manager.broadcast(chat_id, payload_out)
    return msg


@router.delete("/chats/{chat_id}")
def delete_chat(
    chat_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    chat = db.scalar(select(Chat).where(Chat.id == chat_id))
    if not chat:
        raise HTTPException(status_code=404, detail="Chat topilmadi")
    assert_chat_member(chat, current_user)

    db.query(ChatMessage).filter(ChatMessage.chat_id == chat_id).delete(synchronize_session=False)
    db.delete(chat)
    db.commit()
    return {"ok": True}


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
            other_user_id = chat.passenger_id if user.id == chat.driver_id else chat.driver_id
            other_user = db.scalar(select(User).where(User.id == other_user_id))
            if other_user:
                create_notification(
                    db,
                    user=other_user,
                    kind="chat_message",
                    uz_title="Yangi xabar",
                    ru_title="Новое сообщение",
                    en_title="New message",
                    uz_body=f"{user.name}: {body[:80]}",
                    ru_body=f"{user.name}: {body[:80]}",
                    en_body=f"{user.name}: {body[:80]}",
                )
            db.commit()
            db.refresh(msg)
            await chat_manager.broadcast(chat_id, ChatMessageOut.model_validate(msg).model_dump(mode="json"))
    except WebSocketDisconnect:
        chat_manager.disconnect(chat_id, websocket)
    finally:
        db.close()
