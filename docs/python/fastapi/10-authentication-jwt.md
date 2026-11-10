---
lesson: true
category: FastAPI
short: Auth
api_app: app.main:app
api_db: true
description: Authentication and authorisation for AcmeHR, built in six small steps — bcrypt password hashes, JWT access tokens with PyJWT, a user_accounts table, OAuth2 password login with the work email, the current-user dependency, and the BRD's roles (employee, manager, HR admin).
---

# Authentication with JWT

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain authentication vs authorisation, and how token login works
    - Hash and check passwords with **bcrypt**
    - Create and verify **JWT** access tokens with **PyJWT**
    - Build a login endpoint and protect other endpoints with a `CurrentUser` dependency
    - Enforce AcmeHR's rules: employees see their own data, managers decide **their own team's** leave, HR admins manage employees

**Prerequisites:** [Dependency Injection & Settings](09-dependencies-and-settings.md)

## The Problem

In lesson 09, the API knew who was calling from a header:

```{ .bash .no-run }
curl -X POST http://127.0.0.1:8000/attendance/check-in -H "X-Employee-Code: E-1005"
```

Anyone can type `E-1005`. Ananya could check in as Suresh, and in lesson 08 she could even approve leave as him, by putting his code in the request body. The API **trusted whatever the caller said**.

This lesson fixes that. Employees prove who they are **once**, with their work email and password, and get back a **token** the API signed. After that, the API reads the caller from the token, which nobody can fake.

## Authentication vs Authorisation

| | Question | AcmeHR example | When it fails |
|---|---|---|---|
| **Authentication** | *Who are you?* | Log in with your work email and password | **401 Unauthorized** |
| **Authorisation** | *Are you allowed to do this?* | Only Ananya's manager can approve her leave | **403 Forbidden** |

!!! example "Real-life analogy: the office ID card"
    On your first day at Acme, security checks your documents **once** and gives you an **ID card** (authentication → token). After that, every door just reads the card, and the card decides which doors open: the server room only for IT, the HR records room only for HR (authorisation). Cards expire, and a lost card can be cancelled.

The roles come from the BRD and are already in the `employees.role` column:

| Role | Who in acmehr | Can |
|------|---------------|-----|
| `employee` | Ananya, Arjun, Priya… | See the directory and their own private profile, apply for leave |
| `manager` | Lakshmi, Karthik, Neha, Suresh, Swati | Everything above, plus approve **their direct reports'** leave |
| `hr_admin` | Rahul, Imran | Change employee status, see anyone's private profile, approve on behalf of a manager |
| `sys_admin` | Deepa | Technical administration (not used in this lesson) |

## The Big Picture

```mermaid
sequenceDiagram
  participant C as Client (browser / curl)
  participant A as AcmeHR API
  C->>A: 1. POST /auth/token (work email + password)
  A-->>C: 2. a signed token: "eyJhbGci..."
  C->>A: 3. GET /auth/me with header Authorization: Bearer eyJhbGci...
  A-->>C: 4. 200 if the token is valid, otherwise 401
```

1. The employee logs in **once** with their email and password.
2. The API checks the password and returns a signed **token**.
3. The client sends that token in the `Authorization` header on **every** request.
4. The API checks the token's signature and expiry. It doesn't need the password again.

The server keeps no list of who's logged in: everything it needs is inside the token. That's why token login is called **stateless**, and why it works the same with one server or ten.

We'll build it in six small steps, and test each one before moving on:

| Step | You build | File |
|------|-----------|------|
| 1 | Hash and check passwords | `app/security.py` |
| 2 | Create and read tokens | `app/security.py` |
| 3 | A table of login accounts | `app/models.py`, `app/seed.py` |
| 4 | The login endpoint | `app/auth.py` |
| 5 | `CurrentUser`: protect any endpoint | `app/auth.py` |
| 6 | Roles and team rules | `app/routers.py` |

```bash
pip install bcrypt PyJWT
```

## Step 1: Hash Passwords

Never store passwords as they are. If the database leaks, every password leaks, and people reuse passwords on other sites (including their bank). Store a **hash** instead: a one-way fingerprint. You can turn a password into a hash, but not a hash back into a password.

| Approach | Safe? | Why |
|----------|-------|-----|
| Plain text | ❌ | Anyone who sees the table sees the passwords |
| Encryption | ❌ | Whoever has the key can decrypt everything |
| Fast hash (MD5, SHA-256) | ❌ | A GPU can try billions of guesses per second |
| **bcrypt** | ✅ | Deliberately slow, and adds a random **salt** to every password |

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

- `hashpw` makes the hash. `$2b$` means bcrypt, and `12` is the cost: higher is slower.
- `checkpw` answers one question: does this password match this hash?
- The last line is `False`: hashing the **same** password twice gives **different** hashes. That's the salt at work.

!!! example "Real-life analogy: a secret spice in every cup"
    Two people make chai from the same tea leaves (the same password). Each adds their own random mix of spices (the salt) before brewing, so the two cups taste different. Someone who steals the cups can't tell that both used the same leaves, and a "taste guide" for every common tea (a ready-made table of hashes for common passwords) is useless. The salt isn't secret: bcrypt stores it inside the hash string itself. Its job is to make every hash unique.

Because of the salt, you can never compare hashes with `==`. Always use `checkpw`.

## Step 2: Tokens with JWT

A **JWT** (JSON Web Token, said "jot") is a short string with three parts separated by dots:

```text
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9 . eyJzdWIiOiJFLTEwNDIiLCJyb2xlIjoiZW1wbG95ZWUifQ . 3kL9w...
       header (algorithm)                       payload (the claims)                     signature
```

| Part | Contains |
|------|----------|
| Header | The algorithm, here `HS256` |
| Payload | The **claims**: `sub` (who: the employee code), `role`, `iat` (issued at), `exp` (expires at) |
| Signature | A stamp made from the header, the payload and the server's **secret key** |

Let's make one and read it back:

```python
from datetime import datetime, timedelta, timezone

import jwt

SECRET = "only-the-server-knows-this-key-1234567890"

now = datetime.now(timezone.utc)
claims = {"sub": "E-1042", "role": "employee", "iat": now, "exp": now + timedelta(minutes=30)}
token = jwt.encode(claims, SECRET, algorithm="HS256")
print(token[:36] + "...")

decoded = jwt.decode(token, SECRET, algorithms=["HS256"])
print(decoded["sub"], decoded["role"], "| valid for", decoded["exp"] - decoded["iat"], "seconds")
```

```{ .text .output }
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
E-1042 employee | valid for 1800 seconds
```

- `jwt.encode` builds the token and **signs** it with the secret key.
- `jwt.decode` checks the signature and the expiry, then gives the claims back. If either check fails, it raises an error.

What does the signature actually protect? Let's attack our own token:

```python
import base64
import json
from datetime import datetime, timedelta, timezone

import jwt

SECRET = "only-the-server-knows-this-key-1234567890"


def make_token(minutes: int) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode({"sub": "E-1042", "role": "employee", "iat": now,
                       "exp": now + timedelta(minutes=minutes)}, SECRET, algorithm="HS256")


def check(label: str, token: str, key: str = SECRET) -> None:
    try:
        jwt.decode(token, key, algorithms=["HS256"])
        print(f"{label:<28} accepted")
    except jwt.InvalidTokenError as e:
        print(f"{label:<28} rejected ({type(e).__name__})")


token = make_token(30)
header, payload, signature = token.split(".")

# 1. Anyone can READ the payload: it's only Base64, no key needed
print("Payload, read without the key:", json.loads(base64.urlsafe_b64decode(payload + "=="))["role"])

# 2. Ananya edits her role to hr_admin and keeps the old signature
fake = base64.urlsafe_b64encode(json.dumps({"sub": "E-1042", "role": "hr_admin"}).encode()).decode().rstrip("=")
check("Real token", token)
check("Role changed to hr_admin", f"{header}.{fake}.{signature}")
check("Checked with a wrong key", token, key="some-other-key-that-is-long-enough-123")
check("Expired a minute ago", make_token(-1))
```

```{ .text .output }
Payload, read without the key: employee
Real token                   accepted
Role changed to hr_admin     rejected (InvalidSignatureError)
Checked with a wrong key     rejected (InvalidSignatureError)
Expired a minute ago         rejected (ExpiredSignatureError)
```

So the signature means **nobody can change** a token or make one up without the secret key. Expired tokens are refused too.

!!! warning "JWTs are signed, not encrypted"
    Line 1 of the output shows anyone can **read** a token. Only put what's safe to show in it: the employee code and role. Never put passwords, PAN numbers or other personal data in a JWT.

### Put both in app/security.py

Steps 1 and 2 become four small functions. The rest of the app only calls these:

```python title="app/security.py"
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.config import get_settings

MAX_PASSWORD_BYTES = 72        # bcrypt rejects longer input with ValueError


def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    if len(plain.encode()) > MAX_PASSWORD_BYTES:  # can never match a stored hash
        return False
    return bcrypt.checkpw(plain.encode(), hashed.encode())


# A real bcrypt hash of a throwaway password, used when the email has no account (see Step 4)
DUMMY_HASH = hash_password("no-such-account")


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

The secret key and token lifetime come from settings, as in lesson 09. Add three settings:

```text title=".env"
DATABASE_URL=mysql+mysqlconnector://root:password@localhost:3306/acmehr
SECRET_KEY=change-this-to-a-long-random-string-at-least-32-chars
ACCESS_TOKEN_MINUTES=30
```

!!! tip "Make a real secret key"
    Run `python -c "import secrets; print(secrets.token_urlsafe(32))"` and paste the result into `.env`. Anyone who knows the key can create tokens for any employee, so keep it out of Git, like your database password.

??? info "app/config.py and app/database.py (expand to copy)"

    `config.py` gets three new settings (highlighted). `database.py` is the same as lesson 09.

    ```python title="app/config.py" hl_lines="10 11 12"
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

## Step 3: A Table for Logins

Where do the password hashes live? Not in `employees`:

- Not every employee should be able to log in. Exited employees must not.
- Login details are security data, and should live apart from HR data.

So logins get their own table, `user_accounts`, with one row per employee who may log in:

| Column | Meaning |
|--------|---------|
| `employee_id` | Which employee this login belongs to (one account per employee) |
| `password_hash` | The 60-character bcrypt hash, never the password |
| `is_active` | Switch a login off without touching HR data |

In `app/models.py`, that's the `UserAccount` class, plus an `account` link on `Employee` (both highlighted). The other models are the ones you know from lesson 08:

??? info "app/models.py (expand to copy)"

    ```python title="app/models.py" hl_lines="25 32 33 34 35 36 37 38 40"
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

The table isn't in `acmehr.sql` yet. Since the model describes it completely, SQLAlchemy can create it: `create_all()` runs `CREATE TABLE` for tables that don't exist yet. This seed script does that, and gives every current employee a practice password:

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

```bash
python -m app.seed
```

```{ .text .output }
Created 19 user accounts
```

Nineteen accounts: everyone except Ritu, who has exited. Open `user_accounts` in MySQL Workbench: it holds only 60-character hashes starting with `$2b$12$`, never the passwords.

## Step 4: The Login Endpoint

Login swaps an email and password for a token:

```python title="app/auth.py"
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Employee
from app.security import DUMMY_HASH, create_access_token, verify_password

router = APIRouter(prefix="/auth", tags=["Auth"])
DB = Annotated[Session, Depends(get_db)]


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


def can_log_in(employee: Employee | None) -> bool:
    return (employee is not None and employee.status != "exited"
            and employee.account is not None and employee.account.is_active)


@router.post("/token", response_model=Token)
def login(form: Annotated[OAuth2PasswordRequestForm, Depends()], db: DB):
    employee = db.scalars(select(Employee).where(Employee.email == form.username.lower())).first()
    allowed = can_log_in(employee)
    # Always run bcrypt, even with no account, so the response time doesn't reveal which emails exist
    hashed = employee.account.password_hash if allowed else DUMMY_HASH
    if not verify_password(form.password, hashed) or not allowed:
        raise HTTPException(status_code=401, detail="Incorrect email or password",
                            headers={"WWW-Authenticate": "Bearer"})
    return {"access_token": create_access_token(employee.employee_code, employee.role)}
```

```python title="app/main.py"
from fastapi import FastAPI

from app.auth import router as auth_router

app = FastAPI(title="AcmeHR API", version="4.0")
app.include_router(auth_router)
```

Reading `login` from top to bottom:

1. **`OAuth2PasswordRequestForm`** reads the login details. The OAuth2 standard says they arrive as **form data** (not JSON), in fields called `username` and `password`. We use the work email as the username.
2. Find the employee by email.
3. **`can_log_in`** checks that they may log in at all: not exited, with an account that's switched on.
4. **`verify_password`** checks the password against the stored hash.
5. If everything passes, return a token holding their employee code and role.

Try it. Ananya logs in (note `-d`: form data, not JSON). We print just the start of the token:

```bash
curl -s -X POST http://127.0.0.1:8000/auth/token \
  -d "username=ananya.rao@acme.example&password=Acme@2026" \
  | python -c "import json,sys; t=json.load(sys.stdin); print(t['token_type'], t['access_token'][:36] + '...')"
```

```{ .text .output }
bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

A wrong password, and Ritu (exited, no account), get exactly the same answer:

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

!!! tip "Same answer, same speed, for every login failure"
    Wrong email, wrong password, an exited employee, a disabled account: all get *"Incorrect email or password"*. A message like *"No account with this email"* would tell an attacker which emails exist, and which employees have left.

    The **time** taken must match too. bcrypt takes about a quarter of a second, so if `login` skipped it for unknown emails, they'd be answered almost instantly. Someone timing the responses could tell them apart. That's why `login` checks against `DUMMY_HASH` when there's no account.

## Step 5: Protect Endpoints with CurrentUser

Now the other half: when a request arrives **with** a token, find out who sent it. We add one dependency, `get_current_user`, to `app/auth.py` (new lines highlighted), plus a `/auth/me` endpoint to try it on:

```python title="app/auth.py" hl_lines="3 4 5 12 16 24 25 26 27 28 29 30 31 32 33 34 35 36 37 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 78 79 80 81 82"
from typing import Annotated

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Employee
from app.security import DUMMY_HASH, create_access_token, decode_access_token, verify_password

router = APIRouter(prefix="/auth", tags=["Auth"])
DB = Annotated[Session, Depends(get_db)]
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")


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
    allowed = can_log_in(employee)
    # Always run bcrypt, even with no account, so the response time doesn't reveal which emails exist
    hashed = employee.account.password_hash if allowed else DUMMY_HASH
    if not verify_password(form.password, hashed) or not allowed:
        raise HTTPException(status_code=401, detail="Incorrect email or password",
                            headers={"WWW-Authenticate": "Bearer"})
    return {"access_token": create_access_token(employee.employee_code, employee.role)}


@router.get("/me", response_model=Me)
def me(user: CurrentUser):
    return Me(employee_code=user.employee_code, full_name=user.full_name, email=user.email, role=user.role)
```

`get_current_user` turns a token into an employee in four moves:

```mermaid
flowchart LR
  H["Authorization: Bearer eyJ..."] --> S["oauth2_scheme<br/>takes the token<br/>(missing → 401)"]
  S --> D["decode_access_token<br/>checks signature + expiry<br/>(bad → 401)"]
  D --> L["load the employee<br/>from MySQL"]
  L --> C["can_log_in?<br/>(exited / disabled → 401)"]
  C --> E["the Employee object"]
```

- **`OAuth2PasswordBearer`** reads the `Authorization: Bearer <token>` header and hands over the token, or answers 401 if there isn't one. Its `tokenUrl` tells `/docs` where to log in.
- **`CurrentUser`** is the shortcut, just like `DB`. Any endpoint that adds `user: CurrentUser` is now **login-only**, and gets the real `Employee` to make decisions with.
- **`require_role`** is used in Step 6.

!!! info "Why load the employee from MySQL on every request?"
    The token says `"role": "manager"`, but endpoints check `user.role` from the database. If HR changes someone's role, or marks them exited, it takes effect on their **next request**, not 30 minutes later when the token expires. (The `role` in the token is still useful to a frontend, for example to show or hide an "Approvals" menu.)

Each test below starts with the same one-line `login` helper, so you can run any block on its own. Spread out, it reads:

```{ .bash .no-run }
login() {
  curl -s -X POST http://127.0.0.1:8000/auth/token -d "username=$1&password=Acme@2026" \
    | python -c "import json,sys; print(json.load(sys.stdin)['access_token'])"
}
ANANYA=$(login ananya.rao@acme.example)     # Ananya's token, saved in a shell variable
```

Without a token, with Ananya's token, and with a token where one character was changed:

```bash
login() { curl -s -X POST http://127.0.0.1:8000/auth/token -d "username=$1&password=Acme@2026" | python -c "import json,sys; print(json.load(sys.stdin)['access_token'])"; }
ANANYA=$(login ananya.rao@acme.example)

curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1:8000/auth/me
curl -s -H "Authorization: Bearer $ANANYA" http://127.0.0.1:8000/auth/me; echo
curl -s -w "\nHTTP %{http_code}\n" -H "Authorization: Bearer ${ANANYA%?}X" http://127.0.0.1:8000/auth/me
```

```{ .text .output }
{"detail":"Not authenticated"}
HTTP 401
{"employee_code":"E-1042","full_name":"Ananya Rao","email":"ananya.rao@acme.example","role":"employee"}
{"detail":"Could not validate credentials"}
HTTP 401
```

!!! tip "Prefer clicking? Use /docs"
    Open `/docs` and click **Authorize** 🔒. Enter `karthik.menon@acme.example` / `Acme@2026`. Swagger UI calls `/auth/token` for you and sends the token with every request you try. This also works on Windows without Git Bash.

!!! tip "Updating your lesson 09 code"
    Delete `current_employee` and `CurrentEmployee` from your project, and change every `CurrentEmployee` in your endpoints to `CurrentUser`. Both give the endpoint the same `Employee` object, so nothing else in the endpoint changes. The next lesson's tests use the names `get_current_user` and `CurrentUser`.

## Step 6: Roles and Team Rules

Now we know **who** is calling. Authorisation decides **what they may do**. AcmeHR needs two kinds of check:

| Check | Example | How |
|-------|---------|-----|
| **Role-based** | Only HR admins change an employee's status | `Depends(require_role("hr_admin"))` |
| **Relationship-based** | Only Ananya's manager approves Ananya's leave | Compare `request.employee.manager_id` with `user.id` in the endpoint |

A role check only needs the user, so it fits in a reusable dependency. A relationship check needs the data too (which request? whose manager?), so it lives in the endpoint or service.

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
        remaining = balance.allocated - balance.used if balance else 0
        if request.days > remaining:
            raise HTTPException(status_code=409, detail=f"Only {float(remaining):g} day(s) of "
                                f"{request.leave_type.code} left; this request needs {float(request.days):g}")
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

```python title="app/main.py" hl_lines="4 8"
from fastapi import FastAPI

from app.auth import router as auth_router
from app.routers import router

app = FastAPI(title="AcmeHR API", version="4.0")
app.include_router(auth_router)
app.include_router(router)
```

Look at where each rule lives:

| Endpoint | Who may call it | The check |
|----------|-----------------|-----------|
| `GET /employees/{code}/profile` | The employee themselves, or HR | `user.employee_code != code and user.role != "hr_admin"` → 403 |
| `GET /leave-requests/pending-approvals` | Anyone logged in, but they only see **their own** team | `.where(Employee.manager_id == user.id)` |
| `POST /leave-requests/{id}/approve` | The requester's manager, or HR, never yourself | Three `if`s → 403 |
| `PATCH /employees/{code}/status` | HR admins only | `require_role("hr_admin")` → 403 |

The approval is a short version that changes the request and the balance in one commit. In your project, keep lesson 08's `LeaveService.approve()` with its audit row, and pass it the **current user** instead of an `approver_code` from the body.

### Employees see their own data

```bash
login() { curl -s -X POST http://127.0.0.1:8000/auth/token -d "username=$1&password=Acme@2026" | python -c "import json,sys; print(json.load(sys.stdin)['access_token'])"; }
ANANYA=$(login ananya.rao@acme.example)

curl -s -H "Authorization: Bearer $ANANYA" http://127.0.0.1:8000/employees/E-1042/profile; echo
curl -s -w "\nHTTP %{http_code}\n" -H "Authorization: Bearer $ANANYA" http://127.0.0.1:8000/employees/E-1002/profile
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/leave-requests/4/approve -H "Authorization: Bearer $ANANYA"
```

```{ .text .output }
{"employee_code":"E-1042","full_name":"Ananya Rao","phone":"9000001042","date_of_birth":"1994-08-17","emergency_contact":"Ravi Rao (9000011111)"}
{"detail":"You can only view your own private profile"}
HTTP 403
{"detail":"You can't approve your own leave"}
HTTP 403
```

Ananya sees her own date of birth and emergency contact. She gets **403** for her manager's profile, and for approving her own leave: she *is* logged in (so not 401), she just isn't allowed.

### Managers decide their own team's leave

Karthik logs in and lists his team's pending requests:

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

The list is built from **who Karthik is**, so nobody else's team appears. He approves Ananya's request, then tries Meera's (request 8). Meera reports to Suresh in Finance:

```bash
login() { curl -s -X POST http://127.0.0.1:8000/auth/token -d "username=$1&password=Acme@2026" | python -c "import json,sys; print(json.load(sys.stdin)['access_token'])"; }
KARTHIK=$(login karthik.menon@acme.example)

curl -s -X POST http://127.0.0.1:8000/leave-requests/4/approve -H "Authorization: Bearer $KARTHIK"; echo
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/leave-requests/8/approve -H "Authorization: Bearer $KARTHIK"
```

```{ .text .output }
{"id":4,"employee":"Ananya Rao","leave_type":"EL","start_date":"2026-11-16","end_date":"2026-11-20","days":5.0,"status":"approved"}
{"detail":"Only Meera Iyer's manager or HR can approve this"}
HTTP 403
```

Compare this with lesson 08, where anyone could send `"approver_code": "E-1005"` and approve as Suresh. Now the approver is whoever the **signed token** says, and the relationship check does the rest.

### HR admins manage employees

Rahul (`hr_admin`) reads Ananya's private profile and marks Manoj, who is serving his notice, as exited. Ananya tries the same on Vikram:

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

Manoj is now exited, so he can't log in any more, and gets the same generic message:

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

!!! note "Running the lesson twice"
    These commands change the database: request 4 is now approved and Manoj has exited. Run them again and you'll get a 409 and a failed login. Reload `acmehr.sql` and run `python -m app.seed` to start fresh.

## In Real Projects

!!! realworld "In Real Projects"
    - **HTTPS only.** Anyone who can see a token can use it until it expires, so tokens must never travel over plain HTTP.
    - **Short-lived tokens.** Keep access tokens to 15–60 minutes, and add **refresh tokens** so people stay logged in.
    - **Where the browser keeps the token.** `localStorage` (as in the frontend module's cart) is simple, but any injected script can read it. Many teams use an `httpOnly` cookie, which JavaScript can't read.
    - **Protect the login endpoint.** Rate-limit it and lock accounts after repeated failures.
    - **Single sign-on.** Companies like Acme usually log in through their identity provider (Microsoft Entra ID or Google Workspace, the SSO the BRD lists for a later phase). Your API then only **verifies** the provider's tokens, with the same `get_current_user` pattern, and maps the email to an employee.
    - **Audit access.** HR systems log every view of private data: who viewed whose profile, and when.

## Common Mistakes

| Mistake | Risk / Symptom | Fix |
|---------|----------------|-----|
| Storing plain-text passwords | Every account exposed in a leak | `bcrypt.hashpw` to store, `bcrypt.checkpw` to check |
| Comparing hashes with `==` | Always `False` (random salt) | `bcrypt.checkpw(plain, hashed)` |
| Hashing a password over 72 bytes | bcrypt raises `ValueError`, and the user sees a 500 | Limit new passwords to 72 bytes (`len(pw.encode())`, not `len(pw)`) |
| Secret key written in the code | Anyone with the repo can make tokens | Load it from `.env`; make it long and random |
| No `exp` claim | A stolen token works forever | Always set an expiry |
| Trusting the token's `role` | A demoted or exited employee keeps their powers until expiry | Load the employee and check the database |
| Taking the acting user from the request | Anyone can act as anyone | Take it from the token: `user: CurrentUser` |
| Sending JSON to `/auth/token` | `422` "Field required: username" | Send form data: `-d "username=...&password=..."` |
| Only role checks | Any manager can approve any team's leave | Add relationship checks: is this *their* report? |

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

    from pydantic import BaseModel, Field, field_validator

    from app.security import MAX_PASSWORD_BYTES, hash_password, verify_password

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
            if len(value.encode()) > MAX_PASSWORD_BYTES:   # bytes, not characters: "₹" is 3 bytes
                raise ValueError(f"must be at most {MAX_PASSWORD_BYTES} bytes")
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
    A compact, URL-safe token with three Base64URL parts: a header (algorithm, type), a payload (claims such as `sub`, `role`, `exp`, `iat`) and a signature (HMAC or RSA over header and payload). The signature proves the token wasn't changed and was made by someone with the key; the payload is readable by anyone, not encrypted.

!!! interview "3. Why use bcrypt instead of SHA-256 for passwords?"
    bcrypt is deliberately slow and has a tunable cost factor, plus a random salt per password, which makes brute-force and precomputed-table attacks impractical. SHA-256 is designed to be fast, so attackers can try billions of guesses per second.

!!! interview "4. What's the difference between role-based and relationship-based authorisation?"
    Role-based checks depend only on who the user is ("HR admins can change status"), so they fit in a reusable dependency like `require_role("hr_admin")`. Relationship-based checks depend on the data being accessed ("only this employee's manager can approve this request"), so they compare the user with the resource inside the endpoint or service. Most business systems need both.

!!! interview "5. How do you log a user out with JWTs, given that they're stateless?"
    Tokens can't be "deleted" server-side by default. Options: keep access tokens short-lived and delete them on the client; use refresh tokens stored server-side (revoke them on logout); maintain a denylist of revoked token ids (`jti`); or, as here, load the user on every request so disabling the account takes effect immediately.

!!! interview "Scenario: an employee resigned yesterday, but they could still approve leave this morning. What went wrong, and how do you fix it?"
    The API trusted the token alone (its `role` claim) and never rechecked the employee, so their still-valid token kept working. Load the employee from the database in `get_current_user` and reject exited employees and disabled accounts; disable the account in the same transaction as the exit; keep tokens short-lived; and review the audit log for actions taken after the exit date.

## Summary

| Step | Code |
|------|------|
| Install | `pip install bcrypt PyJWT` |
| 1. Hash / check a password | `bcrypt.hashpw(pw, bcrypt.gensalt())` · `bcrypt.checkpw(pw, hashed)` |
| 2. Make / read a token | `jwt.encode({"sub": code, "role": role, "exp": ...}, SECRET_KEY, algorithm="HS256")` · `jwt.decode(token, SECRET_KEY, algorithms=["HS256"])` |
| 3. Accounts table | `UserAccount` model + `Base.metadata.create_all(engine, tables=[...])` |
| 4. Login | `OAuth2PasswordRequestForm` (form data: `username`, `password`) → `{"access_token": ...}` |
| 5. Protect | `OAuth2PasswordBearer(tokenUrl="/auth/token")` + `user: CurrentUser` → 401 |
| 6a. Roles | `Depends(require_role("hr_admin"))` → 403 |
| 6b. Relationships | `request.employee.manager_id == user.id`, else 403 |
| Use a token | `Authorization: Bearer <token>` |

**Next lesson:** [Testing FastAPI](11-testing-fastapi.md), with automated tests for the leave rules and these permissions using pytest and TestClient.
