---
lesson: true
category: FastAPI
short: Auth
api_app: app.main:app
api_db: true
description: Authentication and authorisation for AcmeHR — a user_accounts table with bcrypt password hashes, JWT access tokens with PyJWT, OAuth2 password login with the work email, the current-user dependency, and the BRD's roles (employee, manager, HR admin).
---

# Authentication with JWT

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain authentication vs authorisation, and how token-based login works
    - Hash and verify passwords with **bcrypt**, and never store plain text
    - Create and verify **JWT** access tokens with **PyJWT**
    - Build login (`/auth/token`) and `/auth/me` with OAuth2 password flow, backed by a MySQL `user_accounts` table
    - Enforce the BRD's access rules: employees see their own data, managers decide **their own team's** leave, HR admins manage employees

**Prerequisites:** [Dependency Injection & Settings](09-dependencies-and-settings.md)

## Authentication vs Authorisation

| | Question | AcmeHR example | Failure status |
|---|---|---|---|
| **Authentication** | *Who are you?* | Log in with your work email and password | **401 Unauthorized** |
| **Authorisation** | *Are you allowed to do this?* | Only Ananya's manager can approve her leave | **403 Forbidden** |

!!! example "Real-life analogy: the office ID card"
    On your first day at Acme, security checks your documents once and gives you an **ID card** (authentication → token). Every door reads the card, not your documents again, and the card decides which doors open: the server room only for IT, the HR records room only for HR (authorisation). Cards expire, and a lost card can be cancelled.

The BRD's security section defines four roles, already stored in the `employees.role` column:

| Role | Who in acmehr | Can |
|------|---------------|-----|
| `employee` | Ananya, Arjun, Priya… | See the directory, their own private profile, apply for leave |
| `manager` | Lakshmi, Karthik, Neha, Suresh, Swati | Everything above, plus approve or reject **their direct reports'** leave |
| `hr_admin` | Rahul, Imran | Manage employee records (status changes), see anyone's private profile, approve on behalf of a manager |
| `sys_admin` | Deepa | Technical administration (not used in this lesson) |

## How Token Login Works

```mermaid
sequenceDiagram
  participant C as Client (React / curl)
  participant A as AcmeHR API
  participant M as MySQL
  C->>A: POST /auth/token (work email + password)
  A->>M: find the employee and their account
  A->>A: verify the bcrypt hash
  A-->>C: {"access_token": "eyJ...", "token_type": "bearer"}
  Note over C: stores the token
  C->>A: POST /leave-requests/4/approve<br/>Authorization: Bearer eyJ...
  A->>A: verify signature + expiry
  A->>M: load the employee, check they manage the requester
  A-->>C: 200 approved, or 403 Forbidden
```

1. The employee logs in **once** with their work email and password.
2. The API returns a signed **token**.
3. The client sends the token in the `Authorization: Bearer <token>` header on every request.
4. The API verifies the token's **signature** and **expiry**, so nobody can fake a token or use an old one forever.

## Passwords: Hash, Never Store

Storing passwords in plain text means one database leak exposes every employee's password, and people reuse passwords across sites (including their bank). Store a **hash** instead: a one-way fingerprint.

| Approach | Safe? | Why |
|----------|-------|-----|
| Plain text | ❌ | Anyone who sees the table sees the passwords |
| Encryption | ❌ | Whoever has the key can decrypt everything |
| Fast hash (MD5, SHA-256) | ❌ | Billions of guesses per second on a GPU |
| **bcrypt / argon2** with a salt | ✅ | Deliberately slow, unique salt per password |

```bash
pip install bcrypt PyJWT
```

```python
import bcrypt

hashed = bcrypt.hashpw(b"Acme@2026", bcrypt.gensalt())
print(hashed[:7], "... length", len(hashed))
print(bcrypt.checkpw(b"Acme@2026", hashed))
print(bcrypt.checkpw(b"acme@2026", hashed))
print(bcrypt.hashpw(b"Acme@2026", bcrypt.gensalt()) == hashed)
```

```{ .text .output }
b'$2b$12$' ... length 60
True
False
False
```

The last line is `False`: hashing the **same** password twice gives **different** hashes, because each one has a random **salt**. You can't compare hashes directly; always use `checkpw`.

## JWT: JSON Web Tokens

A **JWT** has three Base64-encoded parts separated by dots: `header.payload.signature`.

```text
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9 . eyJzdWIiOiJFLTEwNDIiLCJyb2xlIjoiZW1wbG95ZWUifQ . 3kL9w...
└─────────── header ───────────────┘   └────────────── payload (claims) ─────────────┘   └ signature ┘
```

| Part | Contains |
|------|----------|
| Header | Algorithm (`HS256`) and type (`JWT`) |
| Payload | **Claims**: `sub` (subject: the employee code), `role`, `exp` (expiry time), `iat` (issued at) |
| Signature | HMAC of header + payload using your **secret key**. Any change breaks it |

!!! warning "JWTs are signed, not encrypted"
    Anyone can decode the payload and read it (you'll do it below). The signature only proves it wasn't **changed**. Never put passwords, PAN numbers or other personal data in a JWT.

## The Complete Example

```text title=".env"
DATABASE_URL=mysql+mysqlconnector://root:password@localhost:3306/acmehr
SECRET_KEY=change-this-to-a-long-random-string-at-least-32-chars
ACCESS_TOKEN_MINUTES=30
```

```python title="app/config.py"
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")

    database_url: str = "mysql+mysqlconnector://root:password@localhost:3306/acmehr"
    secret_key: str
    algorithm: str = "HS256"
    access_token_minutes: int = 30


@lru_cache
def get_settings() -> Settings:
    return Settings()
```

```python title="app/database.py"
from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import get_settings

engine = create_engine(get_settings().database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

### The accounts table

Not every employee record needs a login (exited employees must not have one), and login details are security data that should live apart from HR data. So accounts get their own table, linked one-to-one to `employees`:

??? info "app/models.py (expand to copy)"

    ```python title="app/models.py"
    from datetime import date, datetime
    from decimal import Decimal

    from sqlalchemy import ForeignKey, String, func
    from sqlalchemy.orm import Mapped, mapped_column, relationship

    from app.database import Base


    class Employee(Base):
        __tablename__ = "employees"
        id: Mapped[int] = mapped_column(primary_key=True)
        employee_code: Mapped[str] = mapped_column(String(10), unique=True)
        first_name: Mapped[str] = mapped_column(String(50))
        last_name: Mapped[str] = mapped_column(String(50))
        email: Mapped[str] = mapped_column(String(120), unique=True)
        phone: Mapped[str] = mapped_column(String(15))
        date_of_birth: Mapped[date]
        manager_id: Mapped[int | None] = mapped_column(ForeignKey("employees.id"))
        status: Mapped[str] = mapped_column(String(10))
        role: Mapped[str] = mapped_column(String(10))
        emergency_contact_name: Mapped[str] = mapped_column(String(100))
        emergency_contact_phone: Mapped[str] = mapped_column(String(15))

        account: Mapped["UserAccount | None"] = relationship(back_populates="employee")

        @property
        def full_name(self) -> str:
            return f"{self.first_name} {self.last_name}"


    class UserAccount(Base):
        __tablename__ = "user_accounts"
        id: Mapped[int] = mapped_column(primary_key=True)
        employee_id: Mapped[int] = mapped_column(ForeignKey("employees.id"), unique=True)
        password_hash: Mapped[str] = mapped_column(String(100))
        is_active: Mapped[bool] = mapped_column(default=True)
        created_at: Mapped[datetime] = mapped_column(server_default=func.now())

        employee: Mapped[Employee] = relationship(back_populates="account")


    class LeaveType(Base):
        __tablename__ = "leave_types"
        id: Mapped[int] = mapped_column(primary_key=True)
        code: Mapped[str] = mapped_column(String(5))
        days_per_year: Mapped[int | None]


    class LeaveRequest(Base):
        __tablename__ = "leave_requests"
        id: Mapped[int] = mapped_column(primary_key=True)
        employee_id: Mapped[int] = mapped_column(ForeignKey("employees.id"))
        leave_type_id: Mapped[int] = mapped_column(ForeignKey("leave_types.id"))
        start_date: Mapped[date]
        end_date: Mapped[date]
        days: Mapped[Decimal]
        status: Mapped[str] = mapped_column(String(10))
        approver_id: Mapped[int | None] = mapped_column(ForeignKey("employees.id"))
        decided_at: Mapped[datetime | None]

        employee: Mapped[Employee] = relationship(foreign_keys=[employee_id])
        leave_type: Mapped[LeaveType] = relationship()


    class LeaveBalance(Base):
        __tablename__ = "leave_balances"
        employee_id: Mapped[int] = mapped_column(ForeignKey("employees.id"), primary_key=True)
        leave_type_id: Mapped[int] = mapped_column(ForeignKey("leave_types.id"), primary_key=True)
        year: Mapped[int] = mapped_column(primary_key=True)
        allocated: Mapped[Decimal]
        used: Mapped[Decimal]
    ```

The `user_accounts` table doesn't exist in `acmehr.sql` yet. Because the model describes it completely, SQLAlchemy can **create** it: `Base.metadata.create_all()` issues `CREATE TABLE` for any table that doesn't exist yet. A small seed script creates the table and gives every current employee a practice password:

```python title="app/seed.py"
from sqlalchemy import select

from app.database import Base, SessionLocal, engine
from app.models import Employee, UserAccount
from app.security import hash_password

PRACTICE_PASSWORD = "Acme@2026"          # training data only: real accounts get a one-time reset link


def seed_accounts() -> int:
    Base.metadata.create_all(engine, tables=[UserAccount.__table__])
    created = 0
    with SessionLocal() as db:
        for employee in db.scalars(select(Employee).where(Employee.status != "exited")):
            if employee.account is None:
                db.add(UserAccount(employee_id=employee.id, password_hash=hash_password(PRACTICE_PASSWORD)))
                created += 1
        db.commit()
    return created


if __name__ == "__main__":
    print(f"Created {seed_accounts()} user accounts")
```

```python title="app/security.py"
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.config import get_settings


def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())


def create_access_token(employee_code: str, role: str) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": employee_code,
        "role": role,
        "iat": now,
        "exp": now + timedelta(minutes=settings.access_token_minutes),
    }
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)


def decode_access_token(token: str) -> dict:
    settings = get_settings()
    return jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
```

```python title="app/auth.py"
from typing import Annotated

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Employee
from app.security import create_access_token, decode_access_token, verify_password

router = APIRouter(prefix="/auth", tags=["Auth"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")
DB = Annotated[Session, Depends(get_db)]


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class Me(BaseModel):
    employee_code: str
    full_name: str
    email: str
    role: str


CREDENTIALS_ERROR = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Could not validate credentials",
    headers={"WWW-Authenticate": "Bearer"},
)


def can_log_in(employee: Employee | None) -> bool:
    return (employee is not None and employee.status != "exited"
            and employee.account is not None and employee.account.is_active)


def get_current_user(token: Annotated[str, Depends(oauth2_scheme)], db: DB) -> Employee:
    try:
        payload = decode_access_token(token)
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired", headers={"WWW-Authenticate": "Bearer"})
    except jwt.InvalidTokenError:
        raise CREDENTIALS_ERROR
    employee = db.scalars(select(Employee).where(Employee.employee_code == payload.get("sub"))).first()
    if not can_log_in(employee):                 # exited or disabled since the token was issued
        raise CREDENTIALS_ERROR
    return employee


CurrentUser = Annotated[Employee, Depends(get_current_user)]


def require_role(*roles: str):
    def checker(user: CurrentUser) -> Employee:
        if user.role not in roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                                detail=f"Requires one of these roles: {', '.join(roles)}")
        return user
    return checker


@router.post("/token", response_model=Token)
def login(form: Annotated[OAuth2PasswordRequestForm, Depends()], db: DB):
    employee = db.scalars(select(Employee).where(Employee.email == form.username.lower())).first()
    if not can_log_in(employee) or not verify_password(form.password, employee.account.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect email or password",
                            headers={"WWW-Authenticate": "Bearer"})
    return {"access_token": create_access_token(employee.employee_code, employee.role)}


@router.get("/me", response_model=Me)
def me(user: CurrentUser):
    return Me(employee_code=user.employee_code, full_name=user.full_name, email=user.email, role=user.role)
```

```python title="app/routers.py"
from datetime import date, datetime
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Path
from pydantic import BaseModel
from sqlalchemy import select

from app.auth import DB, CurrentUser, require_role
from app.models import Employee, LeaveBalance, LeaveRequest

router = APIRouter()
EmployeeCode = Annotated[str, Path(pattern=r"^E-\d{4}$")]


class Profile(BaseModel):
    employee_code: str
    full_name: str
    phone: str
    date_of_birth: date
    emergency_contact: str


class LeaveRequestBrief(BaseModel):
    id: int
    employee: str
    leave_type: str
    start_date: date
    end_date: date
    days: float
    status: str


class StatusChange(BaseModel):
    status: Literal["active", "on_notice", "exited"]


def get_employee_or_404(db: DB, code: str) -> Employee:
    employee = db.scalars(select(Employee).where(Employee.employee_code == code)).first()
    if employee is None:
        raise HTTPException(status_code=404, detail=f"Employee {code} not found")
    return employee


def brief(r: LeaveRequest) -> LeaveRequestBrief:
    return LeaveRequestBrief(id=r.id, employee=r.employee.full_name, leave_type=r.leave_type.code,
                             start_date=r.start_date, end_date=r.end_date, days=float(r.days), status=r.status)


@router.get("/employees/{code}/profile", response_model=Profile, tags=["Employees"])
def private_profile(code: EmployeeCode, user: CurrentUser, db: DB):
    """The employee themselves, or HR."""
    if user.employee_code != code and user.role != "hr_admin":
        raise HTTPException(status_code=403, detail="You can only view your own private profile")
    e = get_employee_or_404(db, code)
    return Profile(employee_code=e.employee_code, full_name=e.full_name, phone=e.phone,
                   date_of_birth=e.date_of_birth,
                   emergency_contact=f"{e.emergency_contact_name} ({e.emergency_contact_phone})")


@router.get("/leave-requests/pending-approvals", response_model=list[LeaveRequestBrief], tags=["Leave"])
def pending_approvals(user: CurrentUser, db: DB):
    """Pending requests from the current user's direct reports."""
    stmt = (select(LeaveRequest).join(LeaveRequest.employee)
            .where(Employee.manager_id == user.id, LeaveRequest.status == "pending")
            .order_by(LeaveRequest.start_date))
    return [brief(r) for r in db.scalars(stmt)]


@router.post("/leave-requests/{request_id}/approve", response_model=LeaveRequestBrief, tags=["Leave"])
def approve(request_id: int, user: CurrentUser, db: DB):
    """The requester's manager, or HR on the manager's behalf."""
    request = db.scalars(select(LeaveRequest).where(LeaveRequest.id == request_id).with_for_update()).first()
    if request is None:
        raise HTTPException(status_code=404, detail=f"Leave request {request_id} not found")
    if request.employee_id == user.id:
        raise HTTPException(status_code=403, detail="You can't approve your own leave")
    if request.employee.manager_id != user.id and user.role != "hr_admin":
        raise HTTPException(status_code=403, detail=f"Only {request.employee.full_name}'s manager or HR can approve this")
    if request.status != "pending":
        raise HTTPException(status_code=409, detail=f"Leave request {request_id} is already {request.status}")
    if request.leave_type.days_per_year is not None:
        balance = db.get(LeaveBalance, (request.employee_id, request.leave_type_id, request.start_date.year),
                         with_for_update=True)
        balance.used += request.days
    request.status = "approved"
    request.approver_id = user.id
    request.decided_at = datetime.now()
    db.commit()
    return brief(request)


@router.patch("/employees/{code}/status", tags=["Employees"])
def change_status(code: EmployeeCode, change: StatusChange, db: DB,
                  hr: Annotated[Employee, Depends(require_role("hr_admin"))]):
    employee = get_employee_or_404(db, code)
    employee.status = change.status
    db.commit()
    return {"employee": employee.full_name, "status": employee.status, "changed_by": hr.full_name}
```

```python title="app/main.py"
from fastapi import FastAPI

from app.auth import router as auth_router
from app.routers import router

app = FastAPI(title="AcmeHR API", version="4.0")
app.include_router(auth_router)
app.include_router(router)
```

(The approval here is a short version that changes the request and the balance in one commit. In your project, keep lesson 08's `LeaveService.approve()` with its audit row, and pass it the **current user** instead of an `approver_code` from the body.)

## The Pieces Explained

### OAuth2PasswordBearer

```{ .python .no-run }
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")
```

A dependency that reads the `Authorization: Bearer <token>` header and returns the token string, or responds **401** if it's missing. `tokenUrl` tells `/docs` where to log in, which adds the 🔒 **Authorize** button.

### Login with OAuth2PasswordRequestForm

The OAuth2 standard says the login request is **form data** (not JSON) with fields `username` and `password`. We use the work email as the username. That's why the curl below uses `-d "username=...&password=..."`.

!!! tip "Same error for every login failure"
    Wrong email, wrong password, an exited employee, a disabled account: all return *"Incorrect email or password"*. Saying *"No account with this email"* lets attackers discover which emails exist, and which employees have left.

### get_current_user

The dependency that turns a token into an employee: decode → verify signature and expiry → load the employee from MySQL → check they may still log in → or 401. Any endpoint that adds `user: CurrentUser` is now **login-only**, and gets the real `Employee` object to make decisions with.

It's the same idea as lesson 09's `current_employee`, which read an `X-Employee-Code` header that anyone could fake. Only the source changed: a signed token instead of a plain header.

!!! info "Why load the employee from the database every time?"
    The token says `"role": "manager"`, but the endpoints check `user.role` from MySQL. If HR changes someone's role, or marks them exited, it takes effect on their **next request**, not when their token expires. The `role` in the token is still useful to the frontend, for example to show or hide the "Approvals" menu.

### Two kinds of authorisation

| Check | Example | How |
|-------|---------|-----|
| **Role-based** | Only HR admins change an employee's status | `Depends(require_role("hr_admin"))` |
| **Relationship-based** | Only Ananya's manager approves Ananya's leave | Compare `request.employee.manager_id` with `user.id` inside the endpoint |

Role checks fit in a reusable dependency. Relationship checks need the data being accessed (which request? whose manager?), so they live in the endpoint or service. Real HR systems need both.

## Trying the Flow

### Create the accounts

```bash
python -m app.seed
```

```{ .text .output }
Created 19 user accounts
```

Nineteen accounts: everyone except Ritu, who has exited. Check MySQL Workbench: the new `user_accounts` table holds only 60-character bcrypt hashes, never the passwords.

### Logging in

A protected endpoint without a token:

```bash
curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1:8000/auth/me
```

```{ .text .output }
{
  "detail": "Not authenticated"
}
HTTP 401
```

Ananya logs in (form data, not JSON). We print just the start of the token:

```bash
curl -s -X POST http://127.0.0.1:8000/auth/token \
  -d "username=ananya.rao@acme.example&password=Acme@2026" \
  | python -c "import json,sys; t=json.load(sys.stdin); print(t['token_type'], t['access_token'][:36] + '...')"
```

```{ .text .output }
bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

A wrong password, and Ritu (exited, no account) get exactly the same answer:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/auth/token \
  -d "username=ananya.rao@acme.example&password=wrong"
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/auth/token \
  -d "username=ritu.kapoor@acme.example&password=Acme@2026"
```

```{ .text .output }
{"detail":"Incorrect email or password"}
HTTP 401
{"detail":"Incorrect email or password"}
HTTP 401
```

To keep the commands short, a small shell function logs someone in and prints their token:

```{ .bash .no-run }
login() {
  curl -s -X POST http://127.0.0.1:8000/auth/token -d "username=$1&password=Acme@2026" \
    | python -c "import json,sys; print(json.load(sys.stdin)['access_token'])"
}
```

### Employees see their own data

```bash
login() { curl -s -X POST http://127.0.0.1:8000/auth/token -d "username=$1&password=Acme@2026" | python -c "import json,sys; print(json.load(sys.stdin)['access_token'])"; }
ANANYA=$(login ananya.rao@acme.example)

curl -s -H "Authorization: Bearer $ANANYA" http://127.0.0.1:8000/auth/me; echo
curl -s -H "Authorization: Bearer $ANANYA" http://127.0.0.1:8000/employees/E-1042/profile; echo
curl -s -w "\nHTTP %{http_code}\n" -H "Authorization: Bearer $ANANYA" http://127.0.0.1:8000/employees/E-1002/profile
```

```{ .text .output }
{"employee_code":"E-1042","full_name":"Ananya Rao","email":"ananya.rao@acme.example","role":"employee"}
{"employee_code":"E-1042","full_name":"Ananya Rao","phone":"9000001042","date_of_birth":"1994-08-17","emergency_contact":"Ravi Rao (9000011111)"}
{"detail":"You can only view your own private profile"}
HTTP 403
```

Ananya sees her own date of birth and emergency contact, and gets a **403** for her manager's: she *is* logged in (so not 401), she's just not allowed.

### Managers decide their own team's leave

Ananya has earned leave pending for 16–20 November (request 4). She can't approve it herself:

```bash
login() { curl -s -X POST http://127.0.0.1:8000/auth/token -d "username=$1&password=Acme@2026" | python -c "import json,sys; print(json.load(sys.stdin)['access_token'])"; }
ANANYA=$(login ananya.rao@acme.example)

curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/leave-requests/4/approve \
  -H "Authorization: Bearer $ANANYA"
```

```{ .text .output }
{
  "detail": "You can't approve your own leave"
}
HTTP 403
```

Karthik logs in and sees his team's pending requests. The list is built from **who he is**, so nobody else's team appears:

```bash
login() { curl -s -X POST http://127.0.0.1:8000/auth/token -d "username=$1&password=Acme@2026" | python -c "import json,sys; print(json.load(sys.stdin)['access_token'])"; }
KARTHIK=$(login karthik.menon@acme.example)

curl -s -H "Authorization: Bearer $KARTHIK" http://127.0.0.1:8000/leave-requests/pending-approvals
```

```{ .text .output }
[
  {
    "id": 4,
    "employee": "Ananya Rao",
    "leave_type": "EL",
    "start_date": "2026-11-16",
    "end_date": "2026-11-20",
    "days": 5.0,
    "status": "pending"
  }
]
```

He approves Ananya's request, then tries Meera's (request 8). Meera reports to Suresh in Finance:

```bash
login() { curl -s -X POST http://127.0.0.1:8000/auth/token -d "username=$1&password=Acme@2026" | python -c "import json,sys; print(json.load(sys.stdin)['access_token'])"; }
KARTHIK=$(login karthik.menon@acme.example)

curl -s -X POST http://127.0.0.1:8000/leave-requests/4/approve -H "Authorization: Bearer $KARTHIK"; echo
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/leave-requests/8/approve \
  -H "Authorization: Bearer $KARTHIK"
```

```{ .text .output }
{"id":4,"employee":"Ananya Rao","leave_type":"EL","start_date":"2026-11-16","end_date":"2026-11-20","days":5.0,"status":"approved"}
{"detail":"Only Meera Iyer's manager or HR can approve this"}
HTTP 403
```

Compare this with lesson 08, where the approver's code came in the request body: anyone could have typed `"approver_code": "E-1005"` and approved as Suresh. Now the approver is whoever the **signed token** says, and the relationship check does the rest.

### HR admins manage employees

Rahul (HR Manager, `hr_admin`) can read any private profile, and marks Manoj, who is serving his notice period, as exited. Ananya can't:

```bash
login() { curl -s -X POST http://127.0.0.1:8000/auth/token -d "username=$1&password=Acme@2026" | python -c "import json,sys; print(json.load(sys.stdin)['access_token'])"; }
RAHUL=$(login rahul.sharma@acme.example)
ANANYA=$(login ananya.rao@acme.example)

curl -s -H "Authorization: Bearer $RAHUL" http://127.0.0.1:8000/employees/E-1042/profile; echo
curl -s -X PATCH http://127.0.0.1:8000/employees/E-1053/status -H "Authorization: Bearer $RAHUL" \
  -H "Content-Type: application/json" -d '{"status": "exited"}'; echo
curl -s -w "\nHTTP %{http_code}\n" -X PATCH http://127.0.0.1:8000/employees/E-1048/status \
  -H "Authorization: Bearer $ANANYA" -H "Content-Type: application/json" -d '{"status": "exited"}'
```

```{ .text .output }
{"employee_code":"E-1042","full_name":"Ananya Rao","phone":"9000001042","date_of_birth":"1994-08-17","emergency_contact":"Ravi Rao (9000011111)"}
{"employee":"Manoj Pillai","status":"exited","changed_by":"Rahul Sharma"}
{"detail":"Requires one of these roles: hr_admin"}
HTTP 403
```

Manoj is now exited, so he can't log in any more, with the same generic message:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/auth/token \
  -d "username=manoj.pillai@acme.example&password=Acme@2026"
```

```{ .text .output }
{
  "detail": "Incorrect email or password"
}
HTTP 401
```

### Tampered and readable tokens

A token with one character changed in the signature is rejected:

```bash
login() { curl -s -X POST http://127.0.0.1:8000/auth/token -d "username=$1&password=Acme@2026" | python -c "import json,sys; print(json.load(sys.stdin)['access_token'])"; }
TOKEN=$(login ananya.rao@acme.example)
BAD="${TOKEN%?}X"

curl -s -w "\nHTTP %{http_code}\n" -H "Authorization: Bearer $BAD" http://127.0.0.1:8000/auth/me
```

```{ .text .output }
{
  "detail": "Could not validate credentials"
}
HTTP 401
```

But anyone can **read** one:

```bash
login() { curl -s -X POST http://127.0.0.1:8000/auth/token -d "username=$1&password=Acme@2026" | python -c "import json,sys; print(json.load(sys.stdin)['access_token'])"; }
TOKEN=$(login ananya.rao@acme.example)

python -c "
import base64, json, sys
payload = sys.argv[1].split('.')[1]
payload += '=' * (-len(payload) % 4)
claims = json.loads(base64.urlsafe_b64decode(payload))
print({k: claims[k] for k in ('sub', 'role')}, '| expires in', claims['exp'] - claims['iat'], 'seconds')
" "$TOKEN"
```

```{ .text .output }
{'sub': 'E-1042', 'role': 'employee'} | expires in 1800 seconds
```

No secret key was needed to **read** it. The key is only needed to **create** or **verify** a token. That's why the payload holds only the employee code and role.

### In /docs

Open `/docs` and click **Authorize** 🔒. Enter `karthik.menon@acme.example` / `Acme@2026` and click Authorize. Swagger UI calls `/auth/token` and sends the token automatically with every request you try. Protected endpoints show a padlock.

!!! realworld "In Real Projects"
    - Keep access tokens **short-lived** (15–60 minutes) and add **refresh tokens** so people stay logged in.
    - Rate-limit the login endpoint and lock accounts after repeated failures.
    - Companies like Acme usually log in through their identity provider (Microsoft Entra ID or Google Workspace, the SSO the BRD lists for a later phase) via OAuth2 / OpenID Connect. Your API then only **verifies** the provider's JWTs, using exactly the `get_current_user` pattern from this lesson, and maps the email to an employee.
    - HR systems log every access to private data (who viewed whose profile, and when) in the audit log.

## Common Mistakes

| Mistake | Risk / Symptom | Fix |
|---------|----------------|-----|
| Storing plain-text passwords | Every account exposed in a leak | `bcrypt.hashpw` + `checkpw` |
| Comparing hashes with `==` | Always `False` (random salt) | `bcrypt.checkpw(plain, hashed)` |
| Hard-coded `SECRET_KEY` in code | Anyone with the repo can forge tokens | Load it from the environment; make it long and random |
| No `exp` claim | Stolen tokens work forever | Always set an expiry |
| Trusting the token's `role` for decisions | A demoted or exited employee keeps their powers until expiry | Load the employee and check the database |
| Taking the acting user from the request body | Anyone can act as anyone (`"approver_code": ...`) | Take it from the token: `user: CurrentUser` |
| Sending JSON to `/auth/token` | `422` "Field required: username" | Use form data: `-d "username=...&password=..."` |
| 403 for "not logged in" | Confusing for clients | 401 = not authenticated, 403 = not allowed |
| Only role checks | Any manager can approve any team's leave | Add relationship checks (is this *their* report?) |

## Practice Exercises

**Easy**

1. Add `GET /employees/me/leave-balances` that returns the current user's 2026 balances, with no code in the URL at all.
2. Change `ACCESS_TOKEN_MINUTES` to `1`, log in, wait over a minute, and call `/auth/me`. What's the response?
3. Make `GET /leave-requests/pending-approvals` return `403` for users with the `employee` role, using `require_role`.

**Medium**

4. Add `POST /auth/change-password` (logged-in users only) that checks the current password and requires the new one to have at least 8 characters, one digit and one uppercase letter.
5. Add `POST /leave-requests/{id}/reject` with the same rules as approve, and a required note.
6. Let managers see their **whole** reporting tree's pending requests, not just direct reports: Lakshmi should see Ananya's request (Ananya → Karthik → Lakshmi).

**Challenge**

7. Add an `is_active` toggle for accounts: `PATCH /accounts/{code}` for `sys_admin` only, which disables or enables a login without changing the employee's HR status. Then make `PATCH /employees/{code}/status` with `"exited"` also disable the account in the same transaction, and write a small script proving that a token issued **before** the change stops working **after** it.

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    import re

    # 1
    @router.get("/employees/me/leave-balances", tags=["Leave"])
    def my_balances(user: CurrentUser, db: DB):
        rows = db.scalars(select(LeaveBalance).where(LeaveBalance.employee_id == user.id, LeaveBalance.year == 2026))
        return [{"leave_type_id": b.leave_type_id, "remaining": float(b.allocated - b.used)} for b in rows]
    # Declare it before /employees/{code}/... routes if any could match "me".

    # 2: {"detail": "Token expired"} with 401

    # 3
    @router.get("/leave-requests/pending-approvals", ...)
    def pending_approvals(user: Annotated[Employee, Depends(require_role("manager", "hr_admin"))], db: DB):
        ...

    # 4
    class ChangePassword(BaseModel):
        current_password: str
        new_password: str = Field(min_length=8)

        @field_validator("new_password")
        @classmethod
        def strong(cls, value: str) -> str:
            if not re.search(r"\d", value) or not re.search(r"[A-Z]", value):
                raise ValueError("needs at least one digit and one uppercase letter")
            return value

    @router.post("/auth/change-password", status_code=204)
    def change_password(data: ChangePassword, user: CurrentUser, db: DB):
        if not verify_password(data.current_password, user.account.password_hash):
            raise HTTPException(status_code=400, detail="Current password is incorrect")
        user.account.password_hash = hash_password(data.new_password)
        db.commit()

    # 6 (collect the tree's ids first, then one query)
    def reporting_tree_ids(db, manager_id: int) -> list[int]:
        ids, frontier = [], [manager_id]
        while frontier:
            reports = list(db.scalars(select(Employee.id).where(Employee.manager_id.in_(frontier))))
            ids += reports
            frontier = reports
        return ids
    # .where(LeaveRequest.employee_id.in_(reporting_tree_ids(db, user.id)), LeaveRequest.status == "pending")

    # 7 (core idea): can_log_in() already checks account.is_active and employee.status,
    # and get_current_user() runs it on every request, so an old token fails right after the change:
    #   token = login(...); disable(...); requests.get("/auth/me", headers=...).status_code == 401
    ```

!!! note "Mini Assignment"
    Add authentication to your **AcmeHR API**: the `user_accounts` table and seed script, login and `/auth/me`, and replace every `employee_code` / `approver_code` that came from a request body or header with `CurrentUser`. Apply the BRD's rules: employees apply for and cancel only their own leave and see only their own private profile; managers decide only their direct reports' leave; HR admins manage employee status. Document the practice accounts in your README and confirm every protected endpoint shows a padlock in `/docs`.

## Interview Questions

!!! interview "1. What is the difference between authentication and authorisation?"
    Authentication verifies identity (who you are), for example by logging in and receiving a token; failure returns 401. Authorisation checks permissions (what you may do), such as approving only your own team's leave; failure returns 403.

!!! interview "2. What is a JWT and what are its parts?"
    A compact, URL-safe token with three Base64URL parts: a header (algorithm, type), a payload (claims such as `sub`, `role`, `exp`, `iat`) and a signature (HMAC or RSA over header and payload). The signature proves integrity and authenticity; the payload is readable by anyone, not encrypted.

!!! interview "3. Why use bcrypt instead of SHA-256 for passwords?"
    bcrypt is deliberately slow and has a tunable cost factor, plus a random salt per password, which makes brute-force and rainbow-table attacks impractical. SHA-256 is designed to be fast, so attackers can try billions of guesses per second.

!!! interview "4. What's the difference between role-based and relationship-based authorisation?"
    Role-based checks depend only on who the user is ("HR admins can change status"), so they fit in a reusable dependency like `require_role("hr_admin")`. Relationship-based checks depend on the data being accessed ("only this employee's manager can approve this request"), so they compare the user with the resource inside the endpoint or service. Most business systems need both.

!!! interview "5. How do you log a user out with JWTs, given that they're stateless?"
    Tokens can't be "deleted" server-side by default. Options: keep access tokens short-lived and delete them on the client; use refresh tokens stored server-side (revoke them on logout); maintain a denylist of revoked token ids (`jti`); or, as here, load the user on every request so disabling the account takes effect immediately.

!!! interview "Scenario: an employee resigned yesterday, but they could still approve leave this morning. What went wrong, and how do you fix it?"
    The API trusted the token alone (its `role` claim) and never rechecked the employee, so their still-valid token kept working. Load the employee from the database in `get_current_user` and reject exited employees and disabled accounts; disable the account in the same transaction as the exit; keep tokens short-lived; and review the audit log for actions taken after the exit date.

## Summary

| Concept | Code |
|---------|------|
| Install | `pip install bcrypt PyJWT` |
| Hash / verify | `bcrypt.hashpw(pw, bcrypt.gensalt())` · `bcrypt.checkpw(pw, hashed)` |
| Accounts table | `UserAccount` model + `Base.metadata.create_all(engine, tables=[...])` |
| Create token | `jwt.encode({"sub": code, "role": role, "exp": ...}, SECRET_KEY, algorithm="HS256")` |
| Verify token | `jwt.decode(token, SECRET_KEY, algorithms=["HS256"])` |
| Read the header | `OAuth2PasswordBearer(tokenUrl="/auth/token")` |
| Login form | `OAuth2PasswordRequestForm` (form data: `username`, `password`) |
| Protect | `user: Annotated[Employee, Depends(get_current_user)]` → 401 |
| Roles | `Depends(require_role("hr_admin"))` → 403 |
| Relationships | `request.employee.manager_id == user.id` → else 403 |
| Use a token | `Authorization: Bearer <token>` |

**Next lesson:** [Testing FastAPI](11-testing-fastapi.md), with automated tests for the leave rules and these permissions using pytest and TestClient.
