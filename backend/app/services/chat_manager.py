from collections import defaultdict

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self._rooms: dict[int, set[WebSocket]] = defaultdict(set)

    async def connect(self, chat_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        self._rooms[chat_id].add(websocket)

    def disconnect(self, chat_id: int, websocket: WebSocket) -> None:
        if chat_id in self._rooms and websocket in self._rooms[chat_id]:
            self._rooms[chat_id].remove(websocket)

    async def broadcast(self, chat_id: int, payload: dict) -> None:
        for ws in list(self._rooms.get(chat_id, set())):
            await ws.send_json(payload)


chat_manager = ConnectionManager()
