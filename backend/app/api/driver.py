from fastapi import APIRouter, Depends
from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import Session

from app.api.deps import require_role
from app.db.session import get_db
from app.models.enums import RequestStatus, UserRole
from app.models.request import PassengerRequest
from app.models.trip import DriverTrip
from app.models.user import User
from app.schemas.request import PassengerRequestOut
from app.schemas.trip import DriverTripCreateIn, DriverTripOut

router = APIRouter(prefix="/driver", tags=["driver"])


def _route_match(a_from: str, a_to: str, b_from: str, b_to: str) -> bool:
    af = a_from.strip().lower()
    at = a_to.strip().lower()
    bf = b_from.strip().lower()
    bt = b_to.strip().lower()
    return (af == bf or af in bf or bf in af) and (at == bt or at in bt or bt in at)


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
    trips = db.scalars(select(DriverTrip).where(DriverTrip.driver_id == current_user.id).order_by(DriverTrip.created_at.desc())).all()
    return list(trips)


@router.get("/requests/open", response_model=list[PassengerRequestOut])
def browse_open_requests(
    current_user: User = Depends(require_role(UserRole.driver)),
    db: Session = Depends(get_db),
):
    trips = db.scalars(select(DriverTrip).where(DriverTrip.driver_id == current_user.id)).all()
    if not trips:
        return []

    reqs = db.scalars(select(PassengerRequest).where(PassengerRequest.status == RequestStatus.open)).all()
    matched: list[PassengerRequest] = []

    for req in reqs:
        for trip in trips:
            overlap = trip.start_time <= req.end_time and trip.end_time >= req.start_time
            seats_ok = (trip.seats_total - trip.seats_taken) >= req.seats_needed
            route_ok = _route_match(req.from_location, req.to_location, trip.from_location, trip.to_location)
            if overlap and seats_ok and route_ok:
                matched.append(req)
                break

    unique_map = {m.id: m for m in matched}
    return list(unique_map.values())
