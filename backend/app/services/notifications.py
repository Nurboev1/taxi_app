from sqlalchemy.orm import Session

from app.models.enums import AppLanguage
from app.models.notification import UserNotification
from app.models.user import User


def _msg(lang: AppLanguage, uz: str, ru: str, en: str) -> str:
    if lang == AppLanguage.ru:
        return ru
    if lang == AppLanguage.en:
        return en
    return uz


def create_notification(
    db: Session,
    *,
    user: User,
    kind: str,
    uz_title: str,
    ru_title: str,
    en_title: str,
    uz_body: str | None = None,
    ru_body: str | None = None,
    en_body: str | None = None,
) -> UserNotification:
    title = _msg(user.language, uz_title, ru_title, en_title)
    body = None
    if uz_body is not None or ru_body is not None or en_body is not None:
        body = _msg(user.language, uz_body or "", ru_body or "", en_body or "")

    n = UserNotification(user_id=user.id, kind=kind, title=title, body=body)
    db.add(n)
    return n
