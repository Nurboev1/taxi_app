from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.api.deps import require_role
from app.db.session import get_db
from app.models.chat import Chat
from app.models.claim import RequestClaim
from app.models.enums import ClaimStatus, RequestStatus, TripStatus, UserRole
from app.models.request import PassengerRequest
from app.models.trip import DriverTrip
from app.models.user import User
from app.schemas.request import (
    ChooseDriverIn,
    ChooseDriverOut,
    ClaimCreateIn,
    ClaimOut,
    MatchTripOut,
    PassengerRequestCreateIn,
    PassengerRequestOut,
)

router = APIRouter(tags=["requests"])


def route_match(a_from: str, a_to: str, b_from: str, b_to: str) -> bool:
    af = a_from.strip().lower()
    at = a_to.strip().lower()
    bf = b_from.strip().lower()
    bt = b_to.strip().lower()
    return (af == bf or af in bf or bf in af) and (at == bt or at in bt or bt in at)


@router.post("/passenger/requests", response_model=PassengerRequestOut)
def create_request(
    payload: PassengerRequestCreateIn,
    current_user: User = Depends(require_role(UserRole.passenger)),
    db: Session = Depends(get_db),
):
    req = PassengerRequest(
        passenger_id=current_user.id,
        from_location=payload.from_location,
        to_location=payload.to_location,
        start_time=payload.start_time,
        end_time=payload.end_time,
        seats_needed=payload.seats_needed,
    )
    db.add(req)
    db.commit()
    db.refresh(req)
    return req


@router.get("/passenger/requests/{request_id}", response_model=PassengerRequestOut)
def get_request(
    request_id: int,
    current_user: User = Depends(require_role(UserRole.passenger)),
    db: Session = Depends(get_db),
):
    req = db.scalar(select(PassengerRequest).where(PassengerRequest.id == request_id, PassengerRequest.passenger_id == current_user.id))
    if not req:
        raise HTTPException(status_code=404, detail="So'rov topilmadi")
    return req


@router.get("/requests/{request_id}/matches", response_model=list[MatchTripOut])
def get_matches(
    request_id: int,
    current_user: User = Depends(require_role(UserRole.passenger)),
    db: Session = Depends(get_db),
):
    req = db.scalar(select(PassengerRequest).where(PassengerRequest.id == request_id, PassengerRequest.passenger_id == current_user.id))
    if not req:
        raise HTTPException(status_code=404, detail="So'rov topilmadi")

    trips = db.scalars(
        select(DriverTrip)
        .options(joinedload(DriverTrip.driver))
        .where(
            DriverTrip.status == TripStatus.open,
            DriverTrip.start_time <= req.end_time,
            DriverTrip.end_time >= req.start_time,
        )
    ).all()

    out: list[MatchTripOut] = []
    for trip in trips:
        seats_available = trip.seats_total - trip.seats_taken
        if seats_available < req.seats_needed:
            continue
        if not route_match(req.from_location, req.to_location, trip.from_location, trip.to_location):
            continue
        out.append(
            MatchTripOut(
                id=trip.id,
                driver_id=trip.driver_id,
                driver_name=trip.driver.name,
                from_location=trip.from_location,
                to_location=trip.to_location,
                start_time=trip.start_time,
                end_time=trip.end_time,
                seats_total=trip.seats_total,
                seats_taken=trip.seats_taken,
                price_per_seat=trip.price_per_seat,
            )
        )
    return out


@router.post("/requests/{request_id}/claim", response_model=ClaimOut)
def claim_request(
    request_id: int,
    payload: ClaimCreateIn,
    current_user: User = Depends(require_role(UserRole.driver)),
    db: Session = Depends(get_db),
):
    limit_reached = False
    created_claim_id: int | None = None
    try:
        req = db.scalar(
            select(PassengerRequest)
            .where(PassengerRequest.id == request_id)
            .with_for_update()
        )
        if not req:
            raise HTTPException(status_code=404, detail="So'rov topilmadi")
        if req.status != RequestStatus.open:
            raise HTTPException(status_code=400, detail="Bu so'rovga claim berib bo'lmaydi")

        claim_count = db.scalar(select(func.count(RequestClaim.id)).where(RequestClaim.request_id == request_id)) or 0
        if claim_count >= 10:
            req.status = RequestStatus.locked
            db.add(req)
            limit_reached = True
        else:
            trip = db.scalar(
                select(DriverTrip)
                .where(DriverTrip.id == payload.trip_id, DriverTrip.driver_id == current_user.id)
                .with_for_update()
            )
            if not trip:
                raise HTTPException(status_code=404, detail="Haydovchi safari topilmadi")
            if trip.status != TripStatus.open:
                raise HTTPException(status_code=400, detail="Safar holati claim uchun mos emas")

            overlap = trip.start_time <= req.end_time and trip.end_time >= req.start_time
            seats_ok = (trip.seats_total - trip.seats_taken) >= req.seats_needed
            route_ok = route_match(req.from_location, req.to_location, trip.from_location, trip.to_location)
            if not (overlap and seats_ok and route_ok):
                raise HTTPException(status_code=400, detail="Safar bu so'rovga mos emas")

            claim = RequestClaim(request_id=request_id, driver_id=current_user.id, trip_id=trip.id)
            db.add(claim)
            db.flush()

            updated_count = claim_count + 1
            if updated_count >= 10:
                req.status = RequestStatus.locked
                db.add(req)

            created_claim_id = claim.id

        db.commit()

        if limit_reached:
            raise HTTPException(status_code=409, detail="Claim limiti to'lgan")
        if created_claim_id is None:
            raise HTTPException(status_code=500, detail="Claim saqlanmadi")

        claim = db.scalar(
            select(RequestClaim)
            .options(joinedload(RequestClaim.driver), joinedload(RequestClaim.trip))
            .where(RequestClaim.id == created_claim_id)
        )
        return ClaimOut(
            id=claim.id,
            request_id=claim.request_id,
            driver_id=claim.driver_id,
            driver_name=claim.driver.name,
            trip_id=claim.trip_id,
            from_location=claim.trip.from_location,
            to_location=claim.trip.to_location,
            start_time=claim.trip.start_time,
            end_time=claim.trip.end_time,
            seats_total=claim.trip.seats_total,
            seats_taken=claim.trip.seats_taken,
            price_per_seat=claim.trip.price_per_seat,
            status=claim.status,
        )
    except HTTPException:
        db.rollback()
        raise
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Bu so'rovga allaqachon claim bergansiz")
    except Exception:
        db.rollback()
        raise


@router.get("/requests/{request_id}/claims", response_model=list[ClaimOut])
def list_claims(
    request_id: int,
    current_user: User = Depends(require_role(UserRole.passenger)),
    db: Session = Depends(get_db),
):
    req = db.scalar(select(PassengerRequest).where(PassengerRequest.id == request_id, PassengerRequest.passenger_id == current_user.id))
    if not req:
        raise HTTPException(status_code=404, detail="So'rov topilmadi")

    claims = db.scalars(
        select(RequestClaim)
        .options(joinedload(RequestClaim.driver), joinedload(RequestClaim.trip))
        .where(RequestClaim.request_id == request_id)
        .order_by(RequestClaim.created_at.asc())
        .limit(10)
    ).all()

    return [
        ClaimOut(
            id=claim.id,
            request_id=claim.request_id,
            driver_id=claim.driver_id,
            driver_name=claim.driver.name,
            trip_id=claim.trip_id,
            from_location=claim.trip.from_location,
            to_location=claim.trip.to_location,
            start_time=claim.trip.start_time,
            end_time=claim.trip.end_time,
            seats_total=claim.trip.seats_total,
            seats_taken=claim.trip.seats_taken,
            price_per_seat=claim.trip.price_per_seat,
            status=claim.status,
        )
        for claim in claims
    ]


@router.post("/requests/{request_id}/choose", response_model=ChooseDriverOut)
def choose_driver(
    request_id: int,
    payload: ChooseDriverIn,
    current_user: User = Depends(require_role(UserRole.passenger)),
    db: Session = Depends(get_db),
):
    try:
        req = db.scalar(
            select(PassengerRequest)
            .where(PassengerRequest.id == request_id, PassengerRequest.passenger_id == current_user.id)
            .with_for_update()
        )
        if not req:
            raise HTTPException(status_code=404, detail="So'rov topilmadi")
        if req.status == RequestStatus.chosen:
            raise HTTPException(status_code=400, detail="Haydovchi allaqachon tanlangan")

        chosen_claim = db.scalar(
            select(RequestClaim)
            .where(RequestClaim.id == payload.claim_id, RequestClaim.request_id == request_id)
            .with_for_update()
        )
        if not chosen_claim:
            raise HTTPException(status_code=404, detail="Claim topilmadi")

        trip = db.scalar(select(DriverTrip).where(DriverTrip.id == chosen_claim.trip_id).with_for_update())
        available = trip.seats_total - trip.seats_taken
        if available < req.seats_needed:
            raise HTTPException(status_code=400, detail="Tanlangan safarda bo'sh joy yetarli emas")

        trip.seats_taken += req.seats_needed
        if trip.seats_taken >= trip.seats_total:
            trip.status = TripStatus.full
        db.add(trip)

        all_claims = db.scalars(select(RequestClaim).where(RequestClaim.request_id == request_id).with_for_update()).all()
        for claim in all_claims:
            claim.status = ClaimStatus.accepted if claim.id == chosen_claim.id else ClaimStatus.rejected
            db.add(claim)

        req.status = RequestStatus.chosen
        req.chosen_claim_id = chosen_claim.id
        req.chosen_driver_id = chosen_claim.driver_id
        db.add(req)

        chat = db.scalar(
            select(Chat).where(
                Chat.request_id == request_id,
                Chat.passenger_id == req.passenger_id,
                Chat.driver_id == chosen_claim.driver_id,
            )
        )
        if not chat:
            chat = Chat(request_id=request_id, passenger_id=req.passenger_id, driver_id=chosen_claim.driver_id)
            db.add(chat)
            db.flush()

        db.commit()
        db.refresh(req)
        db.refresh(chat)

        # Load relations after commit without FOR UPDATE to avoid outer join lock issues.
        chosen_claim_view = db.scalar(
            select(RequestClaim)
            .options(joinedload(RequestClaim.driver), joinedload(RequestClaim.trip))
            .where(RequestClaim.id == chosen_claim.id)
        )
        if not chosen_claim_view:
            raise HTTPException(status_code=404, detail="Tanlangan claim topilmadi")

        return ChooseDriverOut(
            request_id=req.id,
            chosen_claim_id=chosen_claim_view.id,
            driver_id=chosen_claim_view.driver_id,
            driver_name=chosen_claim_view.driver.name,
            driver_phone=chosen_claim_view.driver.phone,
            chat_id=chat.id,
            status=req.status,
        )
    except HTTPException:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        raise
