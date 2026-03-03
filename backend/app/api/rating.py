from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_role
from app.db.session import get_db
from app.models.claim import RequestClaim
from app.models.enums import ClaimStatus, UserRole
from app.models.rating import TripRating
from app.models.request import PassengerRequest
from app.models.trip import DriverTrip
from app.models.user import User
from app.schemas.rating import (
    CreateRatingIn,
    GivenRatingOut,
    PendingRatingOut,
    RatingSummaryOut,
    ReceivedRatingOut,
    TripRatingOut,
)
from app.services.notifications import create_notification

router = APIRouter(prefix="/ratings", tags=["ratings"])


@router.get("/pending", response_model=list[PendingRatingOut])
def pending_ratings(
    current_user: User = Depends(require_role(UserRole.passenger)),
    db: Session = Depends(get_db),
):
    claims = db.scalars(
        select(RequestClaim).where(RequestClaim.status == ClaimStatus.completed).order_by(RequestClaim.created_at.desc())
    ).all()

    out: list[PendingRatingOut] = []
    for claim in claims:
        req = db.scalar(select(PassengerRequest).where(PassengerRequest.id == claim.request_id))
        if not req or req.passenger_id != current_user.id:
            continue

        trip = db.scalar(select(DriverTrip).where(DriverTrip.id == claim.trip_id))
        if not trip:
            continue
        existing = db.scalar(
            select(TripRating).where(TripRating.trip_id == trip.id, TripRating.passenger_id == current_user.id)
        )
        if existing:
            continue

        driver = db.scalar(select(User).where(User.id == claim.driver_id))
        out.append(
            PendingRatingOut(
                trip_id=trip.id,
                driver_id=claim.driver_id,
                driver_name=driver.name if driver else "Haydovchi",
                from_location=trip.from_location,
                to_location=trip.to_location,
                finished_at=trip.end_time,
            )
        )
    return out


@router.post("/trip/{trip_id}", response_model=TripRatingOut)
def rate_trip(
    trip_id: int,
    payload: CreateRatingIn,
    current_user: User = Depends(require_role(UserRole.passenger)),
    db: Session = Depends(get_db),
):
    trip = db.scalar(select(DriverTrip).where(DriverTrip.id == trip_id))
    if not trip:
        raise HTTPException(status_code=404, detail="Safar topilmadi")
    if claim := db.scalar(
        select(RequestClaim)
        .join(PassengerRequest, PassengerRequest.id == RequestClaim.request_id)
        .where(
            RequestClaim.trip_id == trip_id,
            RequestClaim.status == ClaimStatus.completed,
            PassengerRequest.passenger_id == current_user.id,
        )
    ):
        pass
    else:
        raise HTTPException(status_code=400, detail="Faqat yakunlangan safarni baholash mumkin")

    existing = db.scalar(select(TripRating).where(TripRating.trip_id == trip_id, TripRating.passenger_id == current_user.id))
    if existing:
        raise HTTPException(status_code=409, detail="Bu safar allaqachon baholangan")

    rating = TripRating(
        trip_id=trip_id,
        passenger_id=current_user.id,
        driver_id=claim.driver_id,
        stars=payload.stars,
        comment=payload.comment.strip() if payload.comment else None,
    )
    db.add(rating)
    driver = db.scalar(select(User).where(User.id == claim.driver_id))
    if driver:
        create_notification(
            db,
            user=driver,
            kind="rating_received",
            uz_title="Sizga yangi baho qo'yildi",
            ru_title="Вам поставили новую оценку",
            en_title="You received a new rating",
            uz_body=f"{payload.stars}/5 baho qoldirildi.",
            ru_body=f"Оценка: {payload.stars}/5.",
            en_body=f"Rating: {payload.stars}/5.",
        )
    db.commit()
    db.refresh(rating)
    return rating


@router.get("/mine/given", response_model=list[GivenRatingOut])
def my_given_ratings(
    current_user: User = Depends(require_role(UserRole.passenger)),
    db: Session = Depends(get_db),
):
    ratings = db.scalars(
        select(TripRating).where(TripRating.passenger_id == current_user.id).order_by(TripRating.created_at.desc())
    ).all()
    out: list[GivenRatingOut] = []
    for r in ratings:
        driver = db.scalar(select(User).where(User.id == r.driver_id))
        out.append(
            GivenRatingOut(
                rating_id=r.id,
                trip_id=r.trip_id,
                target_name=driver.name if driver else "Haydovchi",
                stars=r.stars,
                comment=r.comment,
                created_at=r.created_at,
            )
        )
    return out


@router.get("/mine/received", response_model=list[ReceivedRatingOut])
def my_received_ratings(
    current_user: User = Depends(require_role(UserRole.driver)),
    db: Session = Depends(get_db),
):
    ratings = db.scalars(
        select(TripRating).where(TripRating.driver_id == current_user.id).order_by(TripRating.created_at.desc())
    ).all()
    out: list[ReceivedRatingOut] = []
    for r in ratings:
        passenger = db.scalar(select(User).where(User.id == r.passenger_id))
        out.append(
            ReceivedRatingOut(
                rating_id=r.id,
                trip_id=r.trip_id,
                from_name=passenger.name if passenger else "Yo'lovchi",
                stars=r.stars,
                comment=r.comment,
                created_at=r.created_at,
            )
        )
    return out


@router.get("/summary/{user_id}", response_model=RatingSummaryOut)
def rating_summary(user_id: int, db: Session = Depends(get_db)):
    ratings = db.scalars(select(TripRating).where(TripRating.driver_id == user_id)).all()
    total = len(ratings)
    if total == 0:
        return RatingSummaryOut(average=0, total=0, five=0, four=0, three=0, two=0, one=0)
    five = len([r for r in ratings if r.stars == 5])
    four = len([r for r in ratings if r.stars == 4])
    three = len([r for r in ratings if r.stars == 3])
    two = len([r for r in ratings if r.stars == 2])
    one = len([r for r in ratings if r.stars == 1])
    average = sum(r.stars for r in ratings) / total
    return RatingSummaryOut(
        average=round(average, 2),
        total=total,
        five=five,
        four=four,
        three=three,
        two=two,
        one=one,
    )
