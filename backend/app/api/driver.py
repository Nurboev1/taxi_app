from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_role
from app.db.session import get_db
from app.models.chat import Chat
from app.models.claim import RequestClaim
from app.models.enums import ClaimStatus, RequestStatus, TripStatus, UserRole
from app.models.request import PassengerRequest
from app.models.trip import DriverTrip
from app.models.user import User
from app.schemas.request import PassengerRequestOut, TripPassengerOut
from app.schemas.trip import DriverTripCreateIn, DriverTripOut
from app.services.notifications import create_notification

router = APIRouter(prefix="/driver", tags=["driver"])


def _route_match(a_from: str, a_to: str, b_from: str, b_to: str) -> bool:
    af = a_from.strip().lower()
    at = a_to.strip().lower()
    bf = b_from.strip().lower()
    bt = b_to.strip().lower()
    return (af == bf or af in bf or bf in af) and (at == bt or at in bt or bt in at)


def _time_match_level(preferred_time, start_time, end_time) -> tuple[str, int]:
    if preferred_time is None:
        return "low", 1440
    if start_time <= preferred_time <= end_time:
        return "high", 0
    if preferred_time < start_time:
        gap = int((start_time - preferred_time).total_seconds() // 60)
    else:
        gap = int((preferred_time - end_time).total_seconds() // 60)
    if gap <= 60:
        return "medium", gap
    return "low", gap


def _match_order(level: str) -> int:
    return {"high": 0, "medium": 1, "low": 2}.get(level, 3)


def _driver_specific_order_key(driver_id: int, request_id: int) -> int:
    # Deterministic per-driver shuffling so each driver sees a different order.
    return ((request_id * 1103515245) ^ (driver_id * 12345)) & 0x7FFFFFFF


@router.post("/trips", response_model=DriverTripOut)
def create_trip(
    payload: DriverTripCreateIn,
    current_user: User = Depends(require_role(UserRole.driver)),
    db: Session = Depends(get_db),
):
    trip = DriverTrip(
        driver_id=current_user.id,
        from_location=payload.from_location,
        to_location=payload.to_location,
        start_time=payload.start_time,
        end_time=payload.end_time,
        seats_total=payload.seats_total,
        price_per_seat=payload.price_per_seat,
    )
    db.add(trip)
    db.commit()
    db.refresh(trip)
    return trip


@router.get("/trips/my", response_model=list[DriverTripOut])
def my_trips(
    current_user: User = Depends(require_role(UserRole.driver)),
    db: Session = Depends(get_db),
):
    trips = db.scalars(
        select(DriverTrip)
        .where(
            DriverTrip.driver_id == current_user.id,
            DriverTrip.status.in_([TripStatus.open, TripStatus.full]),
        )
        .order_by(DriverTrip.created_at.desc())
    ).all()
    return list(trips)


@router.post("/trips/{trip_id}/finish", response_model=DriverTripOut)
def finish_trip(
    trip_id: int,
    current_user: User = Depends(require_role(UserRole.driver)),
    db: Session = Depends(get_db),
):
    trip = db.scalar(select(DriverTrip).where(DriverTrip.id == trip_id, DriverTrip.driver_id == current_user.id))
    if not trip:
        raise HTTPException(status_code=404, detail="Safar topilmadi")
    if trip.status == TripStatus.done:
        return trip
    if trip.status == TripStatus.cancelled:
        raise HTTPException(status_code=400, detail="Bekor qilingan safarni tugatib bo'lmaydi")

    accepted_claims = db.scalars(
        select(RequestClaim).where(
            RequestClaim.trip_id == trip_id,
            RequestClaim.status == ClaimStatus.accepted,
        )
    ).all()

    for claim in accepted_claims:
        claim.status = ClaimStatus.completed
        db.add(claim)
        req = db.scalar(select(PassengerRequest).where(PassengerRequest.id == claim.request_id))
        if req:
            passenger = db.scalar(select(User).where(User.id == req.passenger_id))
            if passenger:
                create_notification(
                    db,
                    user=passenger,
                    kind="trip_finished_rate",
                    uz_title="Safaringiz yakunlandi",
                    ru_title="Поездка завершена",
                    en_title="Your trip has finished",
                    uz_body="Haydovchini baholashni unutmang.",
                    ru_body="Не забудьте оценить водителя.",
                    en_body="Please don't forget to rate your driver.",
                )

    trip.seats_taken = 0
    trip.status = TripStatus.done
    db.add(trip)
    db.commit()
    db.refresh(trip)
    return trip


@router.get("/trips/{trip_id}/passengers", response_model=list[TripPassengerOut])
def trip_passengers(
    trip_id: int,
    current_user: User = Depends(require_role(UserRole.driver)),
    db: Session = Depends(get_db),
):
    trip = db.scalar(select(DriverTrip).where(DriverTrip.id == trip_id, DriverTrip.driver_id == current_user.id))
    if not trip:
        raise HTTPException(status_code=404, detail="Safar topilmadi")

    claims = db.scalars(
        select(RequestClaim).where(RequestClaim.trip_id == trip_id, RequestClaim.status == ClaimStatus.accepted)
    ).all()
    if not claims:
        return []

    out: list[TripPassengerOut] = []
    for claim in claims:
        req = db.scalar(select(PassengerRequest).where(PassengerRequest.id == claim.request_id))
        if not req:
            continue
        passenger = db.scalar(select(User).where(User.id == req.passenger_id))
        if not passenger:
            continue
        passenger_trips_count = (
            db.scalar(
                select(RequestClaim.id)
                .join(PassengerRequest, PassengerRequest.id == RequestClaim.request_id)
                .where(
                    PassengerRequest.passenger_id == passenger.id,
                    RequestClaim.status == ClaimStatus.completed,
                )
            )
            is not None
        )
        completed_count = (
            db.query(RequestClaim)
            .join(PassengerRequest, PassengerRequest.id == RequestClaim.request_id)
            .filter(
                PassengerRequest.passenger_id == passenger.id,
                RequestClaim.status == ClaimStatus.completed,
            )
            .count()
        )
        out.append(
            TripPassengerOut(
                request_id=req.id,
                passenger_id=passenger.id,
                chat_id=(
                    db.scalar(
                        select(Chat.id).where(
                            Chat.request_id == req.id,
                            Chat.passenger_id == passenger.id,
                            Chat.driver_id == current_user.id,
                        )
                    )
                ),
                passenger_name=passenger.name,
                passenger_first_name=passenger.first_name,
                passenger_last_name=passenger.last_name,
                passenger_gender=passenger.gender.value if passenger.gender else None,
                passenger_phone=passenger.phone if passenger.phone_visible else None,
                passenger_trips_count=completed_count if passenger_trips_count else 0,
                seats_needed=req.seats_needed,
                from_location=req.from_location,
                to_location=req.to_location,
            )
        )
    return out


@router.post("/trips/{trip_id}/passengers/{request_id}/finish", response_model=DriverTripOut | None)
def finish_trip_for_passenger(
    trip_id: int,
    request_id: int,
    current_user: User = Depends(require_role(UserRole.driver)),
    db: Session = Depends(get_db),
):
    trip = db.scalar(select(DriverTrip).where(DriverTrip.id == trip_id, DriverTrip.driver_id == current_user.id))
    if not trip:
        raise HTTPException(status_code=404, detail="Safar topilmadi")

    claim = db.scalar(
        select(RequestClaim).where(
            RequestClaim.trip_id == trip_id,
            RequestClaim.request_id == request_id,
            RequestClaim.status == ClaimStatus.accepted,
        )
    )
    if not claim:
        raise HTTPException(status_code=404, detail="Faol yo'lovchi topilmadi")

    req = db.scalar(select(PassengerRequest).where(PassengerRequest.id == request_id))
    if not req:
        raise HTTPException(status_code=404, detail="So'rov topilmadi")

    claim.status = ClaimStatus.completed
    db.add(claim)

    passenger = db.scalar(select(User).where(User.id == req.passenger_id))
    if passenger:
        create_notification(
            db,
            user=passenger,
            kind="trip_finished_rate",
            uz_title="Safaringiz yakunlandi",
            ru_title="Поездка завершена",
            en_title="Your trip has finished",
            uz_body="Haydovchini baholashni unutmang.",
            ru_body="Не забудьте оценить водителя.",
            en_body="Please don't forget to rate your driver.",
        )

    trip.seats_taken = max(0, trip.seats_taken - req.seats_needed)
    db.add(trip)

    remaining = db.query(RequestClaim).filter(
        RequestClaim.trip_id == trip_id,
        RequestClaim.status == ClaimStatus.accepted,
    ).count()
    if remaining == 0:
        trip.status = TripStatus.done
        db.add(trip)

    db.commit()
    db.refresh(trip)
    if trip.status == TripStatus.done:
        return None
    return trip


@router.get("/requests/open", response_model=list[PassengerRequestOut])
def browse_open_requests(
    current_user: User = Depends(require_role(UserRole.driver)),
    db: Session = Depends(get_db),
):
    trips = db.scalars(select(DriverTrip).where(DriverTrip.driver_id == current_user.id)).all()
    reqs = db.scalars(select(PassengerRequest).where(PassengerRequest.status == RequestStatus.open)).all()
    passenger_ids = {r.passenger_id for r in reqs}
    passengers = db.scalars(select(User).where(User.id.in_(passenger_ids))).all() if passenger_ids else []
    passenger_gender_map = {u.id: (u.gender.value if u.gender else None) for u in passengers}

    if not reqs:
        return []
    if not trips:
        fallback = [
            PassengerRequestOut(
                id=req.id,
                passenger_id=req.passenger_id,
                passenger_gender=passenger_gender_map.get(req.passenger_id),
                from_location=req.from_location,
                to_location=req.to_location,
                start_time=req.start_time,
                end_time=req.end_time,
                preferred_time=req.preferred_time,
                seats_needed=req.seats_needed,
                status=req.status,
                chosen_claim_id=req.chosen_claim_id,
                chosen_driver_id=req.chosen_driver_id,
                match_level="low",
                time_gap_minutes=1440,
            )
            for req in reqs
        ]
        fallback.sort(key=lambda r: _driver_specific_order_key(current_user.id, r.id))
        return fallback

    scored: list[tuple[PassengerRequestOut, int, int]] = []
    for req in reqs:
        best_level = "low"
        best_gap = 10**9
        has_route_and_seats = False
        passenger_gender = passenger_gender_map.get(req.passenger_id)
        for trip in trips:
            seats_ok = (trip.seats_total - trip.seats_taken) >= req.seats_needed
            route_ok = _route_match(req.from_location, req.to_location, trip.from_location, trip.to_location)
            if not (seats_ok and route_ok):
                continue
            has_route_and_seats = True
            preferred = req.preferred_time or req.start_time
            level, gap = _time_match_level(preferred, trip.start_time, trip.end_time)
            if _match_order(level) < _match_order(best_level) or (
                _match_order(level) == _match_order(best_level) and gap < best_gap
            ):
                best_level = level
                best_gap = gap

        if not has_route_and_seats:
            continue
        scored.append(
            (
                PassengerRequestOut(
                    id=req.id,
                    passenger_id=req.passenger_id,
                    passenger_gender=passenger_gender,
                    from_location=req.from_location,
                    to_location=req.to_location,
                    start_time=req.start_time,
                    end_time=req.end_time,
                    preferred_time=req.preferred_time,
                    seats_needed=req.seats_needed,
                    status=req.status,
                    chosen_claim_id=req.chosen_claim_id,
                    chosen_driver_id=req.chosen_driver_id,
                    match_level=best_level,
                    time_gap_minutes=best_gap,
                ),
                _match_order(best_level),
                _driver_specific_order_key(current_user.id, req.id),
            )
        )

    scored.sort(key=lambda x: (x[1], x[2], x[0].id))
    if scored:
        return [row[0] for row in scored]

    # Fallback: if no route/seats matches, show all open requests.
    fallback = [
        PassengerRequestOut(
            id=req.id,
            passenger_id=req.passenger_id,
            passenger_gender=passenger_gender_map.get(req.passenger_id),
            from_location=req.from_location,
            to_location=req.to_location,
            start_time=req.start_time,
            end_time=req.end_time,
            preferred_time=req.preferred_time,
            seats_needed=req.seats_needed,
            status=req.status,
            chosen_claim_id=req.chosen_claim_id,
            chosen_driver_id=req.chosen_driver_id,
            match_level="low",
            time_gap_minutes=1440,
        )
        for req in reqs
    ]
    fallback.sort(key=lambda r: _driver_specific_order_key(current_user.id, r.id))
    return fallback
