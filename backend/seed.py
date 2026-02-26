from datetime import datetime, timedelta, timezone

from app.db.session import SessionLocal
from app.models.enums import TripStatus, UserRole
from app.models.trip import DriverTrip
from app.models.user import User


def run():
    db = SessionLocal()
    try:
        driver = db.query(User).filter(User.phone == "+998900000001").first()
        if not driver:
            driver = User(phone="+998900000001", name="Akmal", role=UserRole.driver)
            db.add(driver)
            db.flush()

        now = datetime.now(timezone.utc)
        trip = DriverTrip(
            driver_id=driver.id,
            from_location="Termiz",
            to_location="Denov",
            start_time=now + timedelta(hours=1),
            end_time=now + timedelta(hours=2),
            seats_total=4,
            seats_taken=1,
            price_per_seat=45000,
            status=TripStatus.open,
        )
        db.add(trip)
        db.commit()
        print("Seed yozildi")
    finally:
        db.close()


if __name__ == "__main__":
    run()
