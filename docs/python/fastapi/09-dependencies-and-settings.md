---
lesson: true
category: FastAPI
short: Dependencies
api_app: app.main:app
api_db: true
description: FastAPI dependency injection on AcmeHR attendance — function, class and yield dependencies, dependency chains, a clock you can control, header checks and router-level protection — plus configuration with pydantic-settings and .env files, and lifespan startup events.
---

# Dependency Injection & Settings

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain dependency injection and why FastAPI uses it
    - Write function, class and `yield` dependencies, and chain them together
    - Inject the **current time** through a clock dependency, so time-based rules can be demonstrated and tested
    - Protect endpoints with header checks and router-level dependencies
    - Load configuration from environment variables and `.env` files with **pydantic-settings**, and run code at startup with **lifespan**

**Prerequisites:** [Database CRUD & Transactions](08-database-crud.md)

## What is Dependency Injection?

You've already used it: `db: Annotated[Session, Depends(get_db)]`. Instead of each endpoint **creating** what it needs (a database session, the current employee, settings, the current time), it **declares** what it needs, and FastAPI **provides** it.

```{ .python .no-run }
# Without DI: every endpoint repeats setup and cleanup
@app.post("/attendance/check-in")
def check_in():
    db = SessionLocal()
    try:
        ...
    finally:
        db.close()

# With DI: declare it, and FastAPI handles creation and cleanup
@app.post("/attendance/check-in")
def check_in(db: Annotated[Session, Depends(get_db)]):
    ...
```

!!! example "Real-life analogy: a new joiner's first day"
    A new Acme employee doesn't buy their own laptop, create their email account or find a desk. They tell IT *"I need a laptop, an email account and building access"*, and the IT team provides everything, ready to use, and takes it back when they leave. Dependencies are the laptop and the access card; FastAPI is the IT team.

| Benefit | Example |
|---------|---------|
| **No repetition** | Pagination, the current employee and DB sessions written once, used everywhere |
| **Guaranteed cleanup** | `yield` dependencies always close sessions and files |
| **Easy testing** | Swap the real clock or database for a fake one with `dependency_overrides` |
| **Readable endpoints** | The signature lists exactly what an endpoint needs |
| **Automatic docs** | Query params and headers from dependencies appear in `/docs` |

## Attendance and the Problem of "Now"

The BRD's attendance module:

> Employees check in and check out from the web or mobile app. A check-in after the shift start plus the grace period is marked late. Each employee checks in at most once per day. HR sees the day's attendance with filters for department and late arrivals.

Every one of those rules depends on **the current time**. If the code calls `datetime.now()` directly, the result changes every second: you can't demonstrate "Ananya checks in at 09:12" in a class, and you can't write a test for "Vikram is late" that passes tomorrow. The fix is to treat time as a dependency, like the database: the endpoint asks for a **clock**, and configuration decides whether it's the real clock or a frozen one.

## The Complete Example

```text
app/
├── main.py
├── config.py          ← settings from environment / .env
├── database.py        ← engine built from the settings
├── models.py
├── dependencies.py    ← reusable dependencies, including the clock
└── routers/
    ├── attendance.py  ← check-in, check-out, daily list
    └── admin.py       ← protected by an API key
.env                   ← local configuration (never committed)
```

```text title=".env"
APP_NAME="AcmeHR API (local)"
DEBUG=true
DATABASE_URL=mysql+mysqlconnector://root:password@localhost:3306/acmehr
ADMIN_API_KEY=local-admin-key-123
MAX_PAGE_SIZE=20
FIXED_NOW=2026-10-12T09:12:00
```

```python title="app/config.py"
from datetime import datetime
from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "AcmeHR API"
    debug: bool = False
    database_url: str = "mysql+mysqlconnector://root:password@localhost:3306/acmehr"
    admin_api_key: str
    max_page_size: int = 50
    fixed_now: datetime | None = Field(default=None, description="Freeze the clock (demos and tests only)")


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

??? info "app/models.py (the columns this lesson needs, expand to copy)"

    ```python title="app/models.py"
    from datetime import date, time

    from sqlalchemy import ForeignKey, String
    from sqlalchemy.orm import Mapped, mapped_column, relationship

    from app.database import Base


    class Department(Base):
        __tablename__ = "departments"
        id: Mapped[int] = mapped_column(primary_key=True)
        name: Mapped[str] = mapped_column(String(60))


    class Shift(Base):
        __tablename__ = "shifts"
        id: Mapped[int] = mapped_column(primary_key=True)
        name: Mapped[str] = mapped_column(String(30))
        start_time: Mapped[time]
        grace_minutes: Mapped[int]


    class Employee(Base):
        __tablename__ = "employees"
        id: Mapped[int] = mapped_column(primary_key=True)
        employee_code: Mapped[str] = mapped_column(String(10), unique=True)
        first_name: Mapped[str] = mapped_column(String(50))
        last_name: Mapped[str] = mapped_column(String(50))
        department_id: Mapped[int] = mapped_column(ForeignKey("departments.id"))
        shift_id: Mapped[int] = mapped_column(ForeignKey("shifts.id"))
        status: Mapped[str] = mapped_column(String(10))

        department: Mapped[Department] = relationship()
        shift: Mapped[Shift] = relationship()

        @property
        def full_name(self) -> str:
            return f"{self.first_name} {self.last_name}"


    class Attendance(Base):
        __tablename__ = "attendance"
        id: Mapped[int] = mapped_column(primary_key=True)
        employee_id: Mapped[int] = mapped_column(ForeignKey("employees.id"))
        work_date: Mapped[date]
        check_in: Mapped[time]
        check_out: Mapped[time | None]
        source: Mapped[str] = mapped_column(String(10))

        employee: Mapped[Employee] = relationship()
    ```

```python title="app/dependencies.py"
from dataclasses import dataclass
from datetime import date, datetime
from typing import Annotated

from fastapi import Depends, Header, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import Settings, get_settings
from app.database import get_db
from app.models import Employee

SettingsDep = Annotated[Settings, Depends(get_settings)]
DB = Annotated[Session, Depends(get_db)]


# ---------- the clock ----------
class Clock:
    def now(self) -> datetime:
        return datetime.now().replace(microsecond=0)


class FixedClock(Clock):
    def __init__(self, moment: datetime):
        self.moment = moment

    def now(self) -> datetime:
        return self.moment


def get_clock(settings: SettingsDep) -> Clock:
    return FixedClock(settings.fixed_now) if settings.fixed_now else Clock()


ClockDep = Annotated[Clock, Depends(get_clock)]


# ---------- pagination (a function dependency) ----------
@dataclass
class Pagination:
    page: int
    size: int

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.size


def pagination(
    settings: SettingsDep,
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1)] = 5,
) -> Pagination:
    if size > settings.max_page_size:
        raise HTTPException(status_code=400, detail=f"size cannot exceed {settings.max_page_size}")
    return Pagination(page=page, size=size)


PaginationDep = Annotated[Pagination, Depends(pagination)]


# ---------- filters (a class dependency) ----------
class AttendanceFilters:
    def __init__(
        self,
        clock: ClockDep,
        day: Annotated[date | None, Query(alias="date", description="Defaults to today")] = None,
        department: str | None = None,
        late_only: bool = False,
    ):
        self.day = day or clock.now().date()
        self.department = department
        self.late_only = late_only


FiltersDep = Annotated[AttendanceFilters, Depends()]


# ---------- who is calling? (a stand-in for login, replaced by JWT in lesson 10) ----------
def current_employee(db: DB, x_employee_code: Annotated[str | None, Header()] = None) -> Employee:
    if x_employee_code is None:
        raise HTTPException(status_code=401, detail="Missing X-Employee-Code header")
    employee = db.scalars(select(Employee).where(Employee.employee_code == x_employee_code,
                                                 Employee.status != "exited")).first()
    if employee is None:
        raise HTTPException(status_code=401, detail=f"Unknown employee {x_employee_code}")
    return employee


CurrentEmployee = Annotated[Employee, Depends(current_employee)]


# ---------- admin check (used at router level) ----------
def verify_admin_key(settings: SettingsDep, x_api_key: Annotated[str | None, Header()] = None) -> None:
    if x_api_key != settings.admin_api_key:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")
```

```python title="app/routers/attendance.py"
from datetime import date, datetime, time, timedelta

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import joinedload

from app.dependencies import DB, ClockDep, CurrentEmployee, FiltersDep, PaginationDep
from app.models import Attendance, Department, Employee

router = APIRouter(prefix="/attendance", tags=["Attendance"])


def minutes_late(employee: Employee, day: date, check_in: time) -> int:
    deadline = datetime.combine(day, employee.shift.start_time) + timedelta(minutes=employee.shift.grace_minutes)
    late = datetime.combine(day, check_in) - deadline
    return max(0, int(late.total_seconds() // 60))


def to_out(record: Attendance) -> dict:
    return {"employee": record.employee.employee_code, "name": record.employee.full_name,
            "work_date": record.work_date, "check_in": record.check_in, "check_out": record.check_out,
            "late_by_minutes": minutes_late(record.employee, record.work_date, record.check_in)}


def todays_record(db: DB, employee: Employee, day: date) -> Attendance | None:
    stmt = select(Attendance).where(Attendance.employee_id == employee.id, Attendance.work_date == day)
    return db.scalars(stmt).first()


@router.post("/check-in", status_code=status.HTTP_201_CREATED)
def check_in(me: CurrentEmployee, db: DB, clock: ClockDep):
    now = clock.now()
    if todays_record(db, me, now.date()):
        raise HTTPException(status_code=409, detail=f"{me.full_name} already checked in on {now.date()}")
    record = Attendance(employee_id=me.id, work_date=now.date(), check_in=now.time(), source="web")
    db.add(record)
    db.commit()
    db.refresh(record)
    return to_out(record)


@router.post("/check-out")
def check_out(me: CurrentEmployee, db: DB, clock: ClockDep):
    now = clock.now()
    record = todays_record(db, me, now.date())
    if record is None:
        raise HTTPException(status_code=409, detail=f"{me.full_name} hasn't checked in today")
    if record.check_out is not None:
        raise HTTPException(status_code=409, detail=f"{me.full_name} already checked out at {record.check_out}")
    record.check_out = now.time()
    db.commit()
    worked = datetime.combine(now.date(), record.check_out) - datetime.combine(now.date(), record.check_in)
    return {**to_out(record), "hours_worked": round(worked.total_seconds() / 3600, 2)}


@router.get("")
def list_attendance(db: DB, filters: FiltersDep, paging: PaginationDep):
    stmt = (select(Attendance).join(Attendance.employee)
            .where(Attendance.work_date == filters.day)
            .options(joinedload(Attendance.employee).joinedload(Employee.shift))
            .order_by(Attendance.check_in))
    if filters.department:
        stmt = stmt.join(Employee.department).where(Department.name == filters.department)
    records = [to_out(r) for r in db.scalars(stmt)]
    if filters.late_only:
        records = [r for r in records if r["late_by_minutes"] > 0]
    return {"date": filters.day, "total": len(records), "page": paging.page, "size": paging.size,
            "items": records[paging.offset:paging.offset + paging.size]}
```

```python title="app/routers/admin.py"
from fastapi import APIRouter, Depends
from sqlalchemy import func, select

from app.dependencies import DB, ClockDep, SettingsDep, verify_admin_key
from app.models import Attendance, Employee

router = APIRouter(prefix="/admin", tags=["Admin"], dependencies=[Depends(verify_admin_key)])


@router.get("/stats")
def stats(db: DB, clock: ClockDep):
    today = clock.now().date()
    active = db.scalar(select(func.count()).select_from(Employee).where(Employee.status != "exited"))
    checked_in = db.scalar(select(func.count()).select_from(Attendance).where(Attendance.work_date == today))
    return {"date": today, "active_employees": active, "checked_in": checked_in}


@router.get("/config")
def show_config(settings: SettingsDep):
    return {"app_name": settings.app_name, "debug": settings.debug,
            "max_page_size": settings.max_page_size, "fixed_now": settings.fixed_now}
```

```python title="app/main.py"
from contextlib import asynccontextmanager

from fastapi import FastAPI
from sqlalchemy import text

from app.config import get_settings
from app.database import engine
from app.routers import admin, attendance

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    with engine.connect() as conn:                      # fail fast if MySQL is unreachable
        conn.execute(text("SELECT 1"))
    print(f"Starting {settings.app_name} (debug={settings.debug}, fixed_now={settings.fixed_now})")
    yield
    print("Shutting down")


app = FastAPI(title=settings.app_name, debug=settings.debug, lifespan=lifespan)
app.include_router(attendance.router)
app.include_router(admin.router)
```

Install the settings package:

```bash
pip install pydantic-settings
```

## Function Dependencies

A dependency is just a function. Whatever it **returns** is passed to the endpoint. It can declare its own query parameters, headers and other dependencies, and FastAPI reads them from the request:

```{ .python .no-run }
def pagination(settings: SettingsDep, page: int = 1, size: int = 5) -> Pagination:
    ...

@router.get("")
def list_attendance(db: DB, filters: FiltersDep, paging: PaginationDep):
    ...
```

`list_attendance` never mentions `page` or `size`, yet they appear as query parameters in `/docs`, because they belong to the `pagination` dependency. Any endpoint that needs paging (the directory, leave requests, the audit log) just adds `paging: PaginationDep`.

Monday 5 October, the day from the BRD's wireframe, latest arrivals last, page 4 of 5 per page:

```bash
curl -s "http://127.0.0.1:8000/attendance?date=2026-10-05&page=4" \
  | python -c "import json,sys; d=json.load(sys.stdin); print(d['date'], 'total', d['total'], 'page', d['page']); [print(' ', r['check_in'], r['name'], '(late %d min)' % r['late_by_minutes'] if r['late_by_minutes'] else '') for r in d['items']]"
```

```{ .text .output }
2026-10-05 total 18 page 4
  09:10:00 Rahul Sharma 
  09:41:00 Karthik Menon (late 26 min)
  10:05:00 Priya Nair (late 50 min)
```

The dependency enforces a rule from the settings (`MAX_PAGE_SIZE=20` in `.env`):

```bash
curl -s -w "\nHTTP %{http_code}\n" "http://127.0.0.1:8000/attendance?size=100"
```

```{ .text .output }
{
  "detail": "size cannot exceed 20"
}
HTTP 400
```

## Class Dependencies

A class works as a dependency too: FastAPI calls it like a function, so its `__init__` parameters become query parameters. `Depends()` with no argument means "use the type annotation itself":

```{ .python .no-run }
class AttendanceFilters:
    def __init__(self, clock: ClockDep, day: Annotated[date | None, Query(alias="date")] = None,
                 department: str | None = None, late_only: bool = False):
        self.day = day or clock.now().date()
        ...

FiltersDep = Annotated[AttendanceFilters, Depends()]
```

Two details: `Query(alias="date")` lets the URL say `?date=...` while the Python name is `day` (so it doesn't hide the `date` type), and the class itself depends on the **clock**, so "no date given" means "today" according to whichever clock is configured.

The late arrivals that HR checks every morning:

```bash
curl -s "http://127.0.0.1:8000/attendance?date=2026-10-05&late_only=true" \
  | python -c "import json,sys; [print(r['employee'], r['name'], r['check_in'], 'late by', r['late_by_minutes'], 'min') for r in json.load(sys.stdin)['items']]"
```

```{ .text .output }
E-1002 Karthik Menon 09:41:00 late by 26 min
E-1046 Priya Nair 10:05:00 late by 50 min
```

```bash
curl -s "http://127.0.0.1:8000/attendance?date=2026-10-05&department=Platform%20Engineering" \
  | python -c "import json,sys; [print(r['name'], r['check_in'], '-', r['check_out']) for r in json.load(sys.stdin)['items']]"
```

```{ .text .output }
Vikram Joshi 06:45:00 - 15:35:00
Sneha Patil 06:52:00 - 15:52:00
```

## The Clock Dependency

`get_clock` reads the settings: if `FIXED_NOW` is set, every endpoint sees that exact moment; otherwise it gets the real time. Our `.env` freezes the clock at **Monday 12 October 2026, 09:12**.

`check_in` depends on **three** things: who's calling, a database session, and the clock. The caller comes from a header for now (`X-Employee-Code`); in [lesson 10](10-authentication-jwt.md) the same `current_employee` dependency will read a login token instead, and no endpoint will need to change.

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/attendance/check-in
```

```{ .text .output }
{
  "detail": "Missing X-Employee-Code header"
}
HTTP 401
```

Ananya is on the General shift (09:00, with 15 minutes' grace), so 09:12 is on time:

```bash
curl -s -X POST http://127.0.0.1:8000/attendance/check-in -H "X-Employee-Code: E-1042"
```

```{ .text .output }
{
  "employee": "E-1042",
  "name": "Ananya Rao",
  "work_date": "2026-10-12",
  "check_in": "09:12:00",
  "check_out": null,
  "late_by_minutes": 0
}
```

Vikram is on the Early shift (07:00, with 10 minutes' grace), so the same 09:12 is two hours late. The rule depends on the employee's shift, not on a hard-coded time:

```bash
curl -s -X POST http://127.0.0.1:8000/attendance/check-in -H "X-Employee-Code: E-1047"
```

```{ .text .output }
{
  "employee": "E-1047",
  "name": "Vikram Joshi",
  "work_date": "2026-10-12",
  "check_in": "09:12:00",
  "check_out": null,
  "late_by_minutes": 122
}
```

Checking in twice on the same day is a conflict:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/attendance/check-in -H "X-Employee-Code: E-1042"
```

```{ .text .output }
{
  "detail": "Ananya Rao already checked in on 2026-10-12"
}
HTTP 409
```

### Moving the clock

Time is now **configuration**. To act out the end of the day, change `FIXED_NOW` in `.env` and restart the server (the dev server reloads when `.py` files change, not `.env`):

```text title=".env"
APP_NAME="AcmeHR API (local)"
DEBUG=true
DATABASE_URL=mysql+mysqlconnector://root:password@localhost:3306/acmehr
ADMIN_API_KEY=local-admin-key-123
MAX_PAGE_SIZE=20
FIXED_NOW=2026-10-12T18:20:00
```

```bash
curl -s -X POST http://127.0.0.1:8000/attendance/check-out -H "X-Employee-Code: E-1042"
```

```{ .text .output }
{
  "employee": "E-1042",
  "name": "Ananya Rao",
  "work_date": "2026-10-12",
  "check_in": "09:12:00",
  "check_out": "18:20:00",
  "late_by_minutes": 0,
  "hours_worked": 9.13
}
```

Priya never checked in today, and Ananya can't check out twice:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/attendance/check-out -H "X-Employee-Code: E-1046"
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/attendance/check-out -H "X-Employee-Code: E-1042"
```

```{ .text .output }
{"detail":"Priya Nair hasn't checked in today"}
HTTP 409
{"detail":"Ananya Rao already checked out at 18:20:00"}
HTTP 409
```

With no `date`, the filters default to the clock's today:

```bash
curl -s "http://127.0.0.1:8000/attendance" \
  | python -c "import json,sys; d=json.load(sys.stdin); print(d['date'], [(r['name'], r['check_in'], r['check_out']) for r in d['items']])"
```

```{ .text .output }
2026-10-12 [('Ananya Rao', '09:12:00', '18:20:00'), ('Vikram Joshi', '09:12:00', None)]
```

!!! warning "Never freeze the clock in production"
    `FIXED_NOW` is for demos, training and tests. Leave it unset in production, and consider refusing to start if it's set while `DEBUG` is false (exercise 5). In [lesson 11](11-testing-fastapi.md), tests will replace `get_clock` with `dependency_overrides` instead of using `.env` at all.

## Dependency Chains and yield

Dependencies can depend on other dependencies. FastAPI builds the whole tree for each request and calls each dependency **only once per request**, even if several parts need it:

```mermaid
flowchart TD
  E["check_in endpoint"] --> C["current_employee"]
  E --> K["get_clock"]
  E --> D["get_db"]
  C --> D
  C --> H["X-Employee-Code header"]
  K --> S["get_settings"]
  L["list_attendance"] --> F["AttendanceFilters"]
  L --> P["pagination"]
  F --> K
  P --> S
```

`check_in` and `current_employee` both need `get_db`, but they get the **same** session, so the employee loaded by `current_employee` belongs to the session the endpoint commits.

A dependency with **`yield`** runs code **before** the endpoint (up to `yield`) and **after** the response (the `finally` block). That's exactly how `get_db` opens and closes a session:

```{ .python .no-run }
def get_db():
    db = SessionLocal()       # before the endpoint
    try:
        yield db              # the endpoint runs here
    finally:
        db.close()            # after the response, even on errors
```

Use `yield` dependencies for anything that must be cleaned up: database sessions, file handles, temporary directories, locks.

## Router-Level Dependencies: Protecting a Group of Endpoints

Some dependencies don't return anything useful; they **check** something and raise an error if it fails. Add them to the router so **every** endpoint in it is protected:

```{ .python .no-run }
def verify_admin_key(settings: SettingsDep, x_api_key: Annotated[str | None, Header()] = None):
    if x_api_key != settings.admin_api_key:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")

router = APIRouter(prefix="/admin", dependencies=[Depends(verify_admin_key)])
```

`Header()` reads an HTTP header. FastAPI converts the parameter name `x_api_key` to the header name `X-Api-Key` (underscores become hyphens, and header names are case-insensitive).

```bash
curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1:8000/admin/stats
```

```{ .text .output }
{
  "detail": "Invalid or missing API key"
}
HTTP 401
```

```bash
curl -s -H "X-API-Key: local-admin-key-123" http://127.0.0.1:8000/admin/stats
```

```{ .text .output }
{
  "date": "2026-10-12",
  "active_employees": 19,
  "checked_in": 2
}
```

| Where you put `Depends(...)` | Applies to |
|------------------------------|------------|
| Endpoint parameter | That endpoint; you get the return value |
| `@router.get(..., dependencies=[...])` | That endpoint; return value ignored |
| `APIRouter(dependencies=[...])` | Every endpoint in the router |
| `FastAPI(dependencies=[...])` | The whole application |

!!! realworld "In Real Projects"
    Dependencies are where cross-cutting concerns live: `get_db`, `get_current_user` (next lesson), `require_role("hr_admin")`, rate limiting, choosing the right company in multi-tenant HR products (one database, many client companies), the clock, and feature flags. Endpoints stay focused on their job while dependencies handle the plumbing.

## Settings with pydantic-settings

Hard-coding passwords, keys and URLs in code is dangerous (they leak through Git) and inflexible (production needs different values). The standard solution is **environment variables**, read through a typed `Settings` class:

```{ .python .no-run }
class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")

    app_name: str = "AcmeHR API"
    debug: bool = False
    database_url: str = "mysql+mysqlconnector://..."
    admin_api_key: str              # required: no default
    max_page_size: int = 50
    fixed_now: datetime | None = None
```

Values are looked up in this order, highest priority first:

1. **Real environment variables** (set by the server, Docker or the terminal)
2. The **`.env`** file
3. The **default** in the class

Names match case-insensitively: the field `admin_api_key` is read from `ADMIN_API_KEY`. Values are converted and validated by type (`"true"` becomes `True`, `"20"` becomes `20`, `"2026-10-12T18:20:00"` becomes a `datetime`).

```bash
curl -s -H "X-API-Key: local-admin-key-123" http://127.0.0.1:8000/admin/config
```

```{ .text .output }
{
  "app_name": "AcmeHR API (local)",
  "debug": true,
  "max_page_size": 20,
  "fixed_now": "2026-10-12T18:20:00"
}
```

These came from `.env`, overriding the class defaults. A real environment variable beats `.env`:

```bash
MAX_PAGE_SIZE=10 python -c "from app.config import Settings; s = Settings(); print(s.app_name, '|', s.max_page_size)"
```

```{ .text .output }
AcmeHR API (local) | 10
```

That's also why the `DATABASE_URL` in `.env` above can hold a placeholder password: on a real server, the deployment sets `DATABASE_URL` as an environment variable, and it wins.

If a **required** setting is missing everywhere, the app refuses to start with a clear error, which is much better than failing later in production:

```bash
mv .env .env.backup
python -c "from app.config import Settings; Settings()" 2>&1 | grep -oE "1 validation error for Settings|^admin_api_key|Field required"
mv .env.backup .env
```

```{ .text .output }
1 validation error for Settings
admin_api_key
Field required
```

`@lru_cache` on `get_settings()` means the `.env` file is read **once**, not on every request.

!!! warning "Never commit `.env`"
    Add `.env` to `.gitignore`. Commit a **`.env.example`** with the same keys and fake values instead, so teammates know which settings to provide:

    ```text title=".env.example"
    APP_NAME="AcmeHR API"
    DEBUG=false
    DATABASE_URL=mysql+mysqlconnector://USER:PASSWORD@localhost:3306/acmehr
    ADMIN_API_KEY=change-me
    MAX_PAGE_SIZE=50
    # FIXED_NOW=2026-10-12T09:12:00   (demos only)
    ```

## Lifespan: Startup and Shutdown Code

Code that should run **once** when the app starts (connect to services, load an ML model, check the database) and once when it stops goes in a **lifespan** function:

```{ .python .no-run }
@asynccontextmanager
async def lifespan(app: FastAPI):
    with engine.connect() as conn:            # startup: fail fast if MySQL is unreachable
        conn.execute(text("SELECT 1"))
    print(f"Starting {settings.app_name}")
    yield                                      # the app serves requests here
    print("Shutting down")                     # shutdown

app = FastAPI(lifespan=lifespan)
```

When you run `fastapi dev app/main.py`, you'll see `Starting AcmeHR API (local) (debug=True, fixed_now=...)` in the logs before `Application startup complete`. If MySQL isn't running, the server stops right there with a connection error, instead of starting and failing on the first real request.

!!! realworld "In Real Projects"
    AI APIs load large models in `lifespan` so the first user doesn't wait 30 seconds, and many apps check database connectivity there so a misconfigured deployment fails immediately rather than on the first request. (Older code uses `@app.on_event("startup")`, which is deprecated in favour of `lifespan`.)

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `Depends(get_db())` with parentheses | Called once at import time, shared by everyone | `Depends(get_db)`: pass the function |
| Forgetting `Depends` (`db: Session`) | FastAPI treats it as a body/query → errors | `Annotated[Session, Depends(get_db)]` |
| `datetime.now()` inside business logic | Rules can't be demonstrated or tested reliably | Inject a clock |
| Creating `Settings()` everywhere | `.env` re-read constantly; inconsistent values | `@lru_cache def get_settings()` |
| `.env` in Git | Secrets leaked | `.gitignore` + `.env.example` |
| Expecting `.env` to beat a real env var | Value "ignored" | Real environment variables have higher priority |
| Editing `.env` and expecting the dev server to notice | Old values still used | Restart the server (and `get_settings` is cached) |
| `@app.on_event("startup")` | Deprecation warning | Use `lifespan` |

## Practice Exercises

**Easy**

1. Add a `sort: Literal["check_in", "name"] = "check_in"` option to `AttendanceFilters` and apply it in the endpoint.
2. Add `SUPPORT_EMAIL` to `Settings` and `.env`, and return it from `GET /contact`.
3. Call `/admin/config` with a wrong key, the right key, and no key, and note the responses.

**Medium**

4. Make `check_in` refuse weekends and holidays with a `400` (load the `holidays` table), using the clock's date.
5. Make the app refuse to start when `FIXED_NOW` is set but `DEBUG` is false (hint: a `model_validator` in `Settings`).
6. Add `GET /attendance/me?month=10` for the current employee: their records for that month (of the clock's year) and the number of late days.

**Challenge**

7. Write a dependency factory `require_role(*roles: str)` that returns a dependency which uses `current_employee` and raises **403** unless the employee's `role` column is one of `roles`. Use it to add `GET /attendance/exceptions` (absent or late employees for a date) for `manager` and `hr_admin` only. (You'll need to map the `role` column.)

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    from typing import Annotated, Literal
    from fastapi import Depends, HTTPException
    from pydantic import model_validator

    # 1 (in AttendanceFilters.__init__): sort: Literal["check_in", "name"] = "check_in"
    #   in list_attendance(): records.sort(key=lambda r: r[filters.sort])

    # 4 (in check_in, with a Holiday model mapped to the holidays table)
    if now.weekday() >= 5 or db.get(Holiday, now.date()):
        raise HTTPException(status_code=400, detail=f"{now.date()} is not a working day")

    # 5 (inside Settings)
    @model_validator(mode="after")
    def no_frozen_clock_in_production(self):
        if self.fixed_now and not self.debug:
            raise ValueError("FIXED_NOW may only be set when DEBUG=true")
        return self

    # 6
    @router.get("/me")
    def my_attendance(me: CurrentEmployee, db: DB, clock: ClockDep, month: Annotated[int, Query(ge=1, le=12)]):
        year = clock.now().year
        stmt = (select(Attendance).where(Attendance.employee_id == me.id,
                                         func.year(Attendance.work_date) == year,
                                         func.month(Attendance.work_date) == month)
                .order_by(Attendance.work_date))
        records = [to_out(r) for r in db.scalars(stmt)]
        return {"month": month, "days": len(records),
                "late_days": sum(1 for r in records if r["late_by_minutes"]), "records": records}

    # 7  (models.py: role: Mapped[str] = mapped_column(String(10)) on Employee)
    def require_role(*roles: str):
        def checker(me: CurrentEmployee) -> Employee:
            if me.role not in roles:
                raise HTTPException(status_code=403, detail=f"Requires one of: {', '.join(roles)}")
            return me
        return checker

    @router.get("/exceptions")
    def exceptions(db: DB, filters: FiltersDep,
                   viewer: Annotated[Employee, Depends(require_role("manager", "hr_admin"))]):
        ...
    ```

!!! note "Mini Assignment"
    Add `app/config.py` to your **AcmeHR API** with `Settings` for `DATABASE_URL`, `APP_NAME`, `DEBUG`, `ADMIN_API_KEY`, `MAX_PAGE_SIZE` and `FIXED_NOW`; make `database.py` use `get_settings().database_url`; replace every repeated `page`/`size` pair with a `PaginationDep`; replace every `datetime.now()` and `TODAY` constant (the leave workflow has one) with the clock dependency; add check-in and check-out; and commit a `.env.example` (but not `.env`).

## Interview Questions

!!! interview "1. What is dependency injection in FastAPI?"
    A mechanism where endpoints declare what they need (`Depends(...)`) and FastAPI resolves and provides it per request: database sessions, the current user, settings, a clock, parsed parameters. It reduces repetition, centralises cross-cutting logic, guarantees cleanup with `yield` dependencies, and makes testing easy via `dependency_overrides`.

!!! interview "2. What is the difference between a normal dependency and one using `yield`?"
    A normal dependency returns a value. A `yield` dependency runs setup code before the endpoint, yields the value, and runs teardown code (in `finally`) after the response is sent, even on exceptions, which is ideal for database sessions and other resources.

!!! interview "3. Why inject a clock instead of calling `datetime.now()`?"
    Business rules that depend on time (late arrivals, leave that has already started, token expiry, month-end reports) become impossible to demonstrate or test deterministically if they read the real time. Injecting a clock lets configuration or tests supply a fixed moment, while production uses the real one, with no change to the business code.

!!! interview "4. How do you manage configuration and secrets in a FastAPI app?"
    With a `pydantic-settings` `BaseSettings` class that reads typed, validated values from environment variables and an optional `.env` file, cached with `@lru_cache` and injected via `Depends(get_settings)`. Secrets live only in the environment or a secrets manager, never in Git; commit a `.env.example` instead.

!!! interview "5. What is the lifespan function used for?"
    Running code once at application startup (before the first request) and at shutdown, for example creating connection pools, checking database connectivity, loading ML models, warming caches and closing resources. It replaces the deprecated `@app.on_event("startup"/"shutdown")`.

!!! interview "Scenario: employees in the Pune office complain that the API marks them late at 09:05. The server is in a US data centre. What's going on?"
    The code compares check-in times using the server's local time zone. The server's clock says 23:35 the previous day (US time), or it converts times inconsistently. Store and compare times in one explicit zone: keep an `office_timezone` (e.g. `Asia/Kolkata`) in settings, have the clock return `datetime.now(ZoneInfo(...))`, and set the containers' time zone. Then add tests with a fixed clock for times around midnight.

## Summary

| Concept | Code |
|---------|------|
| Dependency | `def pagination(page: int = 1, size: int = 5) -> Pagination: ...` |
| Use it | `paging: Annotated[Pagination, Depends(pagination)]` |
| Class dependency | `filters: Annotated[AttendanceFilters, Depends()]` |
| Clock | `get_clock()` → `FixedClock(settings.fixed_now)` or `Clock()` |
| Cleanup | `yield` inside `try/finally` |
| Header | `x_employee_code: Annotated[str \| None, Header()] = None` |
| Group protection | `APIRouter(dependencies=[Depends(verify_admin_key)])` |
| Settings | `class Settings(BaseSettings)` + `SettingsConfigDict(env_file=".env")` |
| Cache | `@lru_cache def get_settings()` |
| Priority | Environment variable > `.env` > default |
| Startup / shutdown | `lifespan` async context manager |

**Next lesson:** [Authentication with JWT](10-authentication-jwt.md), with password hashing, login, tokens and the BRD's roles: employee, manager and HR admin.
