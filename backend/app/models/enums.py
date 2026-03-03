from enum import Enum


class UserRole(str, Enum):
    none = "none"
    driver = "driver"
    passenger = "passenger"


class TripStatus(str, Enum):
    open = "open"
    full = "full"
    cancelled = "cancelled"
    done = "done"


class RequestStatus(str, Enum):
    open = "open"
    locked = "locked"
    chosen = "chosen"
    cancelled = "cancelled"
    expired = "expired"


class ClaimStatus(str, Enum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"
    completed = "completed"


class Gender(str, Enum):
    male = "male"
    female = "female"


class AppLanguage(str, Enum):
    uz = "uz"
    ru = "ru"
    en = "en"
