---
lesson: true
category: FastAPI
short: DB CRUD
api_app: app.main:app
api_db: true
description: Writing to MySQL through SQLAlchemy in a layered FastAPI app — the AcmeHR leave workflow (apply, approve, reject, cancel) where every decision updates the request, the balance and the audit log in one transaction, with row locking and IntegrityError handling.
---

# Database CRUD & Transactions

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Insert and update rows with SQLAlchemy sessions (`add`, `flush`, `commit`, `refresh`)
    - Organise database code into **repositories**, business rules into **services**, and HTTP into **routers**
    - Approve leave as **one transaction**: update the request, deduct the balance and write an audit row, or change nothing
    - Lock rows with `with_for_update()` so two approvers can't decide the same request at once
    - Turn database constraint errors (`IntegrityError`) into proper responses

**Prerequisites:** [SQLAlchemy & MySQL](07-sqlalchemy-and-mysql.md) and [Transactions](../../database/mysql/12-transactions-indexes-users.md) from the MySQL module.

## The Leave Workflow

This is the heart of the BRD's leave module:

> An employee applies for leave. Their reporting manager approves or rejects it with an optional note. On approval, the days are deducted from the employee's balance. An employee can cancel a pending request, or an approved one that hasn't started, and the days are returned. Every decision is recorded in the audit log with who made it and when.

```mermaid
stateDiagram-v2
  [*] --> pending: apply
  pending --> approved: manager approves<br/>(balance deducted)
  pending --> rejected: manager rejects
  pending --> cancelled: employee cancels
  approved --> cancelled: employee cancels<br/>before it starts<br/>(balance returned)
```

Approval touches **three tables**: the request's status, the balance's `used` days, and a new `audit_logs` row. If the server crashed after updating the request but before deducting the balance, Ananya would have free leave and the books wouldn't add up. All three changes must happen together, or not at all. That's a **transaction**.

## How Writes Work in SQLAlchemy

The session is a **unit of work**: you make changes to objects, then `commit()` sends them all to MySQL in one transaction.

| Step | Code | SQL it causes |
|------|------|---------------|
| Create | `db.add(request)` | `INSERT` (at commit / flush) |
| Update | `request.status = "approved"` | `UPDATE` (at commit / flush) |
| Delete | `db.delete(document)` | `DELETE` (at commit / flush) |
| Save | `db.commit()` | `COMMIT` |
| Undo | `db.rollback()` | `ROLLBACK` |
| Reload | `db.refresh(request)` | `SELECT` (gets the generated id, defaults) |
| Send now, commit later | `db.flush()` | `INSERT/UPDATE` inside the open transaction |

!!! example "Real-life analogy: a bank transfer"
    When you transfer ₹5,000 to a friend, the bank debits your account and credits theirs. It would be a disaster if the debit happened and the credit didn't. Banks do both inside one transaction: either both entries are written, or neither is. Approving leave is the same: the request says "approved" only if the balance moved too.

## The Layers

```mermaid
flowchart LR
  R["routers.py<br/>HTTP in/out"] --> S["services.py<br/>rules, transactions"]
  S --> L["leave_rules.py<br/>working days"]
  S --> P["repositories.py<br/>queries"]
  P --> D[("MySQL")]
  S -.raises.-> E["exceptions.py<br/>NotFound, Conflict,<br/>Forbidden, BadRequest"]
  E -.handler.-> R
```

| File | Responsibility |
|------|----------------|
| `repositories.py` | **How** to read and write rows: queries only, no business rules, never commits |
| `services.py` | **What** is allowed: the workflow, checks against the database, transactions |
| `leave_rules.py` | Pure policy functions from [lesson 05](05-routers-and-project-structure.md) |
| `routers.py` | HTTP: parse input, call the service, return schemas and status codes |
| `exceptions.py` | Domain errors + one handler |

??? info "app/database.py, app/models.py and app/leave_rules.py (expand to copy)"

    The database setup is unchanged from lesson 07. The models map only the columns this lesson needs (SQLAlchemy doesn't require every column of an existing table), plus the `audit_logs` table.

    ```python title="app/database.py"
    import os
    from collections.abc import Generator

    from sqlalchemy import create_engine
    from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

    DATABASE_URL = os.environ.get(
        "DATABASE_URL", "mysql+mysqlconnector://root:password@localhost:3306/acmehr"
    )

    engine = create_engine(DATABASE_URL, pool_pre_ping=True)
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

    ```python title="app/models.py"
    from datetime import date, datetime
    from decimal import Decimal

    from sqlalchemy import JSON, BigInteger, ForeignKey, String, func
    from sqlalchemy.orm import Mapped, mapped_column, relationship

    from app.database import Base


    class Employee(Base):
        __tablename__ = "employees"
        id: Mapped[int] = mapped_column(primary_key=True)
        employee_code: Mapped[str] = mapped_column(String(10), unique=True)
        first_name: Mapped[str] = mapped_column(String(50))
        last_name: Mapped[str] = mapped_column(String(50))
        manager_id: Mapped[int | None] = mapped_column(ForeignKey("employees.id"))
        status: Mapped[str] = mapped_column(String(10))

        @property
        def full_name(self) -> str:
            return f"{self.first_name} {self.last_name}"


    class LeaveType(Base):
        __tablename__ = "leave_types"
        id: Mapped[int] = mapped_column(primary_key=True)
        code: Mapped[str] = mapped_column(String(5), unique=True)
        name: Mapped[str] = mapped_column(String(40))
        days_per_year: Mapped[int | None]


    class Holiday(Base):
        __tablename__ = "holidays"
        holiday_date: Mapped[date] = mapped_column(primary_key=True)
        name: Mapped[str] = mapped_column(String(60))


    class LeaveRequest(Base):
        __tablename__ = "leave_requests"
        id: Mapped[int] = mapped_column(primary_key=True)
        employee_id: Mapped[int] = mapped_column(ForeignKey("employees.id"))
        leave_type_id: Mapped[int] = mapped_column(ForeignKey("leave_types.id"))
        start_date: Mapped[date]
        end_date: Mapped[date]
        duration: Mapped[str] = mapped_column(String(12), default="full")
        days: Mapped[Decimal]
        reason: Mapped[str] = mapped_column(String(255))
        status: Mapped[str] = mapped_column(String(10), default="pending")
        approver_id: Mapped[int | None] = mapped_column(ForeignKey("employees.id"))
        decision_note: Mapped[str | None] = mapped_column(String(255))
        applied_at: Mapped[datetime]
        decided_at: Mapped[datetime | None]

        employee: Mapped[Employee] = relationship(foreign_keys=[employee_id])
        approver: Mapped[Employee | None] = relationship(foreign_keys=[approver_id])
        leave_type: Mapped[LeaveType] = relationship()


    class LeaveBalance(Base):
        __tablename__ = "leave_balances"
        employee_id: Mapped[int] = mapped_column(ForeignKey("employees.id"), primary_key=True)
        leave_type_id: Mapped[int] = mapped_column(ForeignKey("leave_types.id"), primary_key=True)
        year: Mapped[int] = mapped_column(primary_key=True)
        allocated: Mapped[Decimal]
        used: Mapped[Decimal]

        leave_type: Mapped[LeaveType] = relationship()

        @property
        def remaining(self) -> Decimal:
            return self.allocated - self.used


    class AuditLog(Base):
        __tablename__ = "audit_logs"
        id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
        actor_id: Mapped[int | None] = mapped_column(ForeignKey("employees.id"))
        action: Mapped[str] = mapped_column(String(40))
        entity: Mapped[str] = mapped_column(String(40))
        entity_id: Mapped[int | None]
        details: Mapped[dict | None] = mapped_column(JSON)
        created_at: Mapped[datetime] = mapped_column(server_default=func.now())

        actor: Mapped[Employee | None] = relationship()
    ```

    ```python title="app/leave_rules.py"
    from datetime import date, timedelta


    def working_days(start: date, end: date, duration: str, holidays: set[date]) -> float:
        """Days deducted from the balance: weekends and holidays don't count."""
        def is_working(day: date) -> bool:
            return day.weekday() < 5 and day not in holidays

        if duration != "full":
            return 0.5 if is_working(start) else 0.0
        days = 0
        day = start
        while day <= end:
            if is_working(day):
                days += 1
            day += timedelta(days=1)
        return float(days)
    ```

## Schemas and Exceptions

```python title="app/schemas.py"
from datetime import date
from enum import Enum
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

CODE = r"^E-\d{4}$"


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class LeaveTypeCode(str, Enum):
    CL = "CL"
    SL = "SL"
    EL = "EL"
    ML = "ML"
    PL = "PL"
    LOP = "LOP"


class LeaveRequestCreate(BaseModel):
    employee_code: str = Field(pattern=CODE)
    leave_type: LeaveTypeCode
    start_date: date
    end_date: date
    duration: Literal["full", "first_half", "second_half"] = "full"
    reason: str = Field(min_length=5, max_length=255)

    @model_validator(mode="after")
    def check_dates(self):
        if self.end_date < self.start_date:
            raise ValueError("end_date can't be before start_date")
        if self.duration != "full" and self.start_date != self.end_date:
            raise ValueError("a half day must start and end on the same date")
        return self


class Decision(BaseModel):
    approver_code: str = Field(pattern=CODE)
    note: str | None = Field(default=None, max_length=255)


class Rejection(Decision):
    note: str = Field(min_length=5, max_length=255)        # a reason is required to reject


class Cancellation(BaseModel):
    employee_code: str = Field(pattern=CODE)


class EmployeeBrief(ORMModel):
    employee_code: str
    full_name: str


class LeaveTypeBrief(ORMModel):
    code: str
    name: str


class LeaveRequestOut(ORMModel):
    id: int
    employee: EmployeeBrief
    leave_type: LeaveTypeBrief
    start_date: date
    end_date: date
    duration: str
    days: float
    reason: str
    status: str
    approver: EmployeeBrief | None
    decision_note: str | None


class LeaveBalanceOut(ORMModel):
    leave_type: LeaveTypeBrief
    year: int
    allocated: float
    used: float
    remaining: float


class AuditLogOut(ORMModel):
    id: int
    actor: EmployeeBrief | None
    action: str
    entity_id: int | None
    details: dict | None
```

Notice that the approver's code comes in the request body for now. That's a placeholder: in [lesson 10](10-authentication-jwt.md) the approver will be the **logged-in user**, read from a JWT token, so nobody can approve "as" their manager.

```python title="app/exceptions.py"
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class AppError(Exception):
    status_code = 400

    def __init__(self, message: str):
        self.message = message


class BadRequestError(AppError):
    status_code = 400


class ForbiddenError(AppError):
    status_code = 403


class NotFoundError(AppError):
    status_code = 404


class ConflictError(AppError):
    status_code = 409


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    def handle_app_error(request: Request, exc: AppError):
        return JSONResponse(status_code=exc.status_code, content={"detail": exc.message})
```

One handler covers all four: each subclass carries its own `status_code`.

## Repositories: Queries Only

```python title="app/repositories.py"
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models import AuditLog, Employee, Holiday, LeaveBalance, LeaveRequest, LeaveType


class LeaveRepository:
    def __init__(self, db: Session):
        self.db = db

    def employee_by_code(self, code: str) -> Employee | None:
        return self.db.scalars(select(Employee).where(Employee.employee_code == code)).first()

    def leave_type_by_code(self, code: str) -> LeaveType:
        return self.db.scalars(select(LeaveType).where(LeaveType.code == code)).one()

    def holidays_between(self, start: date, end: date) -> set[date]:
        stmt = select(Holiday.holiday_date).where(Holiday.holiday_date.between(start, end))
        return set(self.db.scalars(stmt))

    def find_overlapping(self, employee_id: int, start: date, end: date) -> LeaveRequest | None:
        stmt = select(LeaveRequest).where(
            LeaveRequest.employee_id == employee_id,
            LeaveRequest.status.in_(("pending", "approved")),
            LeaveRequest.start_date <= end,
            LeaveRequest.end_date >= start,
        )
        return self.db.scalars(stmt).first()

    def get_request(self, request_id: int, lock: bool = False) -> LeaveRequest | None:
        stmt = select(LeaveRequest).where(LeaveRequest.id == request_id)
        if lock:
            stmt = stmt.with_for_update()                   # SELECT ... FOR UPDATE
        return self.db.scalars(stmt).first()

    def get_balance(self, employee_id: int, leave_type_id: int, year: int, lock: bool = False) -> LeaveBalance | None:
        stmt = select(LeaveBalance).where(LeaveBalance.employee_id == employee_id,
                                          LeaveBalance.leave_type_id == leave_type_id,
                                          LeaveBalance.year == year)
        if lock:
            stmt = stmt.with_for_update()
        return self.db.scalars(stmt).first()

    def balances(self, employee_id: int, year: int) -> list[LeaveBalance]:
        stmt = (select(LeaveBalance).where(LeaveBalance.employee_id == employee_id, LeaveBalance.year == year)
                .options(joinedload(LeaveBalance.leave_type)).order_by(LeaveBalance.leave_type_id))
        return list(self.db.scalars(stmt))

    def audit_logs(self) -> list[AuditLog]:
        return list(self.db.scalars(select(AuditLog).options(joinedload(AuditLog.actor)).order_by(AuditLog.id)))

    def add(self, obj) -> None:
        self.db.add(obj)
```

Repositories never call `commit()`. Deciding **when** a unit of work is complete is the service's job. The overlap check from lesson 05 is now a `WHERE` clause, so MySQL does it in one query.

## Services: Rules and Transactions

```python title="app/services.py"
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy.orm import Session

from app.exceptions import BadRequestError, ConflictError, ForbiddenError, NotFoundError
from app.leave_rules import working_days
from app.models import AuditLog, Employee, LeaveBalance, LeaveRequest, LeaveType
from app.repositories import LeaveRepository
from app.schemas import Cancellation, Decision, LeaveRequestCreate

TODAY = date(2026, 10, 5)      # lesson 09 replaces this with a clock dependency


class LeaveService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = LeaveRepository(db)

    # ---------- helpers ----------
    def _employee(self, code: str) -> Employee:
        employee = self.repo.employee_by_code(code)
        if employee is None:
            raise NotFoundError(f"Employee {code} not found")
        return employee

    def _request(self, request_id: int, lock: bool = False) -> LeaveRequest:
        request = self.repo.get_request(request_id, lock=lock)
        if request is None:
            raise NotFoundError(f"Leave request {request_id} not found")
        return request

    def _check_balance(self, employee_id: int, leave_type: LeaveType, year: int, days: Decimal,
                       lock: bool = False) -> LeaveBalance:
        balance = self.repo.get_balance(employee_id, leave_type.id, year, lock=lock)
        remaining = balance.remaining if balance else Decimal(0)
        if days > remaining:
            raise ConflictError(f"Only {float(remaining):g} day(s) of {leave_type.code} left; "
                                f"this request needs {float(days):g}")
        return balance

    def _audit(self, actor: Employee, action: str, request: LeaveRequest, **details) -> None:
        self.repo.add(AuditLog(actor_id=actor.id, action=action, entity="leave_request",
                               entity_id=request.id, details=details))

    # ---------- reads ----------
    def get(self, request_id: int) -> LeaveRequest:
        return self._request(request_id)

    def balances(self, code: str, year: int) -> list[LeaveBalance]:
        return self.repo.balances(self._employee(code).id, year)

    def audit_logs(self) -> list[AuditLog]:
        return self.repo.audit_logs()

    # ---------- the workflow ----------
    def apply(self, data: LeaveRequestCreate) -> LeaveRequest:
        try:
            employee = self._employee(data.employee_code)
            leave_type = self.repo.leave_type_by_code(data.leave_type.value)
            holidays = self.repo.holidays_between(data.start_date, data.end_date)
            days = Decimal(str(working_days(data.start_date, data.end_date, data.duration, holidays)))
            if days == 0:
                raise BadRequestError("The selected dates have no working days (weekends and holidays don't count)")
            clash = self.repo.find_overlapping(employee.id, data.start_date, data.end_date)
            if clash:
                raise ConflictError(f"Overlaps leave request {clash.id} "
                                    f"({clash.start_date} to {clash.end_date}, {clash.status})")
            if leave_type.days_per_year is not None:                     # loss of pay has no limit
                self._check_balance(employee.id, leave_type, data.start_date.year, days)

            request = LeaveRequest(employee_id=employee.id, leave_type_id=leave_type.id,
                                   start_date=data.start_date, end_date=data.end_date,
                                   duration=data.duration, days=days, reason=data.reason,
                                   status="pending", applied_at=datetime.now())
            self.repo.add(request)
            self.db.flush()                    # INSERT now, so request.id exists for the audit row
            self._audit(employee, "leave.applied", request, days=float(days))
            self.db.commit()
            self.db.refresh(request)
            return request
        except Exception:
            self.db.rollback()
            raise

    def approve(self, request_id: int, decision: Decision) -> LeaveRequest:
        try:
            request = self._request(request_id, lock=True)           # 1. lock the request row
            approver = self._employee(decision.approver_code)
            if request.status != "pending":                          # 2. validate everything first
                raise ConflictError(f"Leave request {request_id} is already {request.status}")
            if request.employee.manager_id != approver.id:
                raise ForbiddenError(f"Only {request.employee.full_name}'s manager can decide this request")
            balance = None
            if request.leave_type.days_per_year is not None:
                balance = self._check_balance(request.employee_id, request.leave_type,
                                              request.start_date.year, request.days, lock=True)

            if balance:                                              # 3. then change
                balance.used += request.days
            request.status = "approved"
            request.approver_id = approver.id
            request.decision_note = decision.note
            request.decided_at = datetime.now()
            self._audit(approver, "leave.approved", request, days=float(request.days),
                        remaining=float(balance.remaining) if balance else None)
            self.db.commit()                                         # 4. all or nothing
            self.db.refresh(request)
            return request
        except Exception:
            self.db.rollback()
            raise

    def reject(self, request_id: int, decision: Decision) -> LeaveRequest:
        try:
            request = self._request(request_id, lock=True)
            approver = self._employee(decision.approver_code)
            if request.status != "pending":
                raise ConflictError(f"Leave request {request_id} is already {request.status}")
            if request.employee.manager_id != approver.id:
                raise ForbiddenError(f"Only {request.employee.full_name}'s manager can decide this request")
            request.status = "rejected"
            request.approver_id = approver.id
            request.decision_note = decision.note
            request.decided_at = datetime.now()
            self._audit(approver, "leave.rejected", request, note=decision.note)
            self.db.commit()
            self.db.refresh(request)
            return request
        except Exception:
            self.db.rollback()
            raise

    def cancel(self, request_id: int, data: Cancellation) -> LeaveRequest:
        try:
            request = self._request(request_id, lock=True)
            employee = self._employee(data.employee_code)
            if request.employee_id != employee.id:
                raise ForbiddenError("You can only cancel your own leave")
            if request.status not in ("pending", "approved"):
                raise ConflictError(f"Leave request {request_id} is already {request.status}")
            returned = 0.0
            if request.status == "approved":
                if request.start_date <= TODAY:
                    raise BadRequestError("Leave that has already started can't be cancelled")
                if request.leave_type.days_per_year is not None:
                    balance = self.repo.get_balance(request.employee_id, request.leave_type_id,
                                                    request.start_date.year, lock=True)
                    balance.used -= request.days
                    returned = float(request.days)
            request.status = "cancelled"
            self._audit(employee, "leave.cancelled", request, days_returned=returned)
            self.db.commit()
            self.db.refresh(request)
            return request
        except Exception:
            self.db.rollback()
            raise
```

The `approve` method is the important part:

1. **Lock** the request row with `SELECT … FOR UPDATE`, and later the balance row, so a second approver (or HR acting at the same moment) must wait until this transaction finishes.
2. **Validate everything** before changing anything: still pending? the right manager? enough balance?
3. **Change** the balance, the request and the audit log.
4. **Commit once.** If anything fails, `rollback()` undoes it all.

`apply` shows one more tool: `db.flush()` sends the `INSERT` to MySQL **inside** the open transaction, so MySQL generates the request's `id`, which the audit row needs, without committing yet.

## Routers

```python title="app/routers.py"
from typing import Annotated

from fastapi import APIRouter, Depends, Path, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas import (AuditLogOut, Cancellation, Decision, LeaveBalanceOut, LeaveRequestCreate,
                         LeaveRequestOut, Rejection)
from app.services import LeaveService

router = APIRouter()


def leave_service(db: Annotated[Session, Depends(get_db)]) -> LeaveService:
    return LeaveService(db)


Leave = Annotated[LeaveService, Depends(leave_service)]
EmployeeCode = Annotated[str, Path(pattern=r"^E-\d{4}$")]


@router.post("/leave-requests", response_model=LeaveRequestOut, status_code=status.HTTP_201_CREATED,
             tags=["Leave"])
def apply_leave(data: LeaveRequestCreate, service: Leave):
    return service.apply(data)


@router.get("/leave-requests/{request_id}", response_model=LeaveRequestOut, tags=["Leave"])
def get_leave_request(request_id: int, service: Leave):
    return service.get(request_id)


@router.post("/leave-requests/{request_id}/approve", response_model=LeaveRequestOut, tags=["Leave"])
def approve_leave(request_id: int, decision: Decision, service: Leave):
    return service.approve(request_id, decision)


@router.post("/leave-requests/{request_id}/reject", response_model=LeaveRequestOut, tags=["Leave"])
def reject_leave(request_id: int, decision: Rejection, service: Leave):
    return service.reject(request_id, decision)


@router.post("/leave-requests/{request_id}/cancel", response_model=LeaveRequestOut, tags=["Leave"])
def cancel_leave(request_id: int, data: Cancellation, service: Leave):
    return service.cancel(request_id, data)


@router.get("/employees/{code}/leave-balances", response_model=list[LeaveBalanceOut], tags=["Leave"])
def leave_balances(code: EmployeeCode, service: Leave, year: Annotated[int, Query(ge=2020)] = 2026):
    return service.balances(code, year)


@router.get("/audit-logs", response_model=list[AuditLogOut], tags=["Audit"])
def audit_logs(service: Leave):
    return service.audit_logs()
```

```python title="app/main.py"
from fastapi import FastAPI

from app.exceptions import register_exception_handlers
from app.routers import router

app = FastAPI(title="AcmeHR API", version="3.0")
register_exception_handlers(app)
app.include_router(router)
```

`leave_service` is a dependency that itself depends on `get_db`. FastAPI resolves the chain automatically: session → service → endpoint. You'll explore this in the [next lesson](09-dependencies-and-settings.md).

## Trying It: Approving and Rejecting

Arjun (E-1043) applied for two days of casual leave on 8–9 October for his sister's wedding: request **5** in the database. His manager is Swati (E-1056), the QA Lead:

```bash
curl -s -X POST http://127.0.0.1:8000/leave-requests/5/approve \
  -H "Content-Type: application/json" \
  -d '{"approver_code": "E-1056", "note": "Enjoy the wedding!"}'
```

```{ .text .output }
{
  "id": 5,
  "employee": {
    "employee_code": "E-1043",
    "full_name": "Arjun Reddy"
  },
  "leave_type": {
    "code": "CL",
    "name": "Casual leave"
  },
  "start_date": "2026-10-08",
  "end_date": "2026-10-09",
  "duration": "full",
  "days": 2.0,
  "reason": "Sister's wedding",
  "status": "approved",
  "approver": {
    "employee_code": "E-1056",
    "full_name": "Swati Kulkarni"
  },
  "decision_note": "Enjoy the wedding!"
}
```

The balance moved in the same transaction: Arjun's casual leave `used` went from 0 to 2:

```bash
curl -s http://127.0.0.1:8000/employees/E-1043/leave-balances \
  | python -c "import json,sys; [print(b['leave_type']['code'], 'used', b['used'], 'remaining', b['remaining']) for b in json.load(sys.stdin)]"
```

```{ .text .output }
CL used 2.0 remaining 10.0
SL used 0.0 remaining 12.0
EL used 0.0 remaining 15.0
```

Approving it twice (say, Swati double-clicks) is a conflict, and the balance is **not** deducted again:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/leave-requests/5/approve \
  -H "Content-Type: application/json" -d '{"approver_code": "E-1056"}'
```

```{ .text .output }
{
  "detail": "Leave request 5 is already approved"
}
HTTP 409
```

Meera (Finance) has earned leave pending for 19–23 October: request **8**, 4 working days. Neha manages Product, not Finance, so she can't approve it; Suresh, Meera's manager, can:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/leave-requests/8/approve \
  -H "Content-Type: application/json" -d '{"approver_code": "E-1003"}'
curl -s -X POST http://127.0.0.1:8000/leave-requests/8/approve \
  -H "Content-Type: application/json" -d '{"approver_code": "E-1005"}' \
  | python -c "import json,sys; r=json.load(sys.stdin); print(r['id'], r['employee']['full_name'], r['leave_type']['code'], r['days'], r['status'], 'by', r['approver']['full_name'])"
```

```{ .text .output }
{"detail":"Only Meera Iyer's manager can decide this request"}
HTTP 403
8 Meera Iyer EL 4.0 approved by Suresh Babu
```

Fatima's dental appointment on 12 October (request **7**) clashes with a design review, so Neha rejects it. A rejection needs a note:

```bash
curl -s -X POST http://127.0.0.1:8000/leave-requests/7/reject \
  -H "Content-Type: application/json" \
  -d '{"approver_code": "E-1003", "note": "Design review that day, please move it to the 13th"}' \
  | python -c "import json,sys; r=json.load(sys.stdin); print(r['status'], '-', r['decision_note'])"
```

```{ .text .output }
rejected - Design review that day, please move it to the 13th
```

Every decision left a row in the audit log, with who made it:

```bash
curl -s http://127.0.0.1:8000/audit-logs \
  | python -c "import json,sys; [print(a['id'], a['action'], 'request', a['entity_id'], 'by', a['actor']['full_name'], a['details']) for a in json.load(sys.stdin)]"
```

```{ .text .output }
1 leave.approved request 5 by Swati Kulkarni {'days': 2.0, 'remaining': 10.0}
2 leave.approved request 8 by Suresh Babu {'days': 4.0, 'remaining': 11.0}
3 leave.rejected request 7 by Neha Kapoor {'note': 'Design review that day, please move it to the 13th'}
```

## Trying It: All or Nothing

Ananya has 8 casual days left. An application for 9 days is refused straight away:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/leave-requests \
  -H "Content-Type: application/json" \
  -d '{"employee_code": "E-1042", "leave_type": "CL", "start_date": "2026-10-26",
       "end_date": "2026-11-05", "reason": "Family function"}'
```

```{ .text .output }
{
  "detail": "Only 8 day(s) of CL left; this request needs 9"
}
HTTP 409
```

But pending requests don't reserve balance, so two smaller requests can each pass on their own: 5 days in late October and 4 days in December:

```bash
for dates in '"2026-10-26", "end_date": "2026-10-30"' '"2026-12-01", "end_date": "2026-12-04"'; do
  curl -s -X POST http://127.0.0.1:8000/leave-requests \
    -H "Content-Type: application/json" \
    -d "{\"employee_code\": \"E-1042\", \"leave_type\": \"CL\", \"start_date\": $dates, \"reason\": \"Family function\"}" \
    | python -c "import json,sys; r=json.load(sys.stdin); print(r['id'], r['start_date'], r['end_date'], r['days'], r['status'])"
done
```

```{ .text .output }
16 2026-10-26 2026-10-30 5.0 pending
17 2026-12-01 2026-12-04 4.0 pending
```

Karthik approves the first (Ananya now has 3 left), then the second, which needs 4:

```bash
curl -s -X POST http://127.0.0.1:8000/leave-requests/16/approve \
  -H "Content-Type: application/json" -d '{"approver_code": "E-1002"}' \
  | python -c "import json,sys; print(json.load(sys.stdin)['status'])"
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/leave-requests/17/approve \
  -H "Content-Type: application/json" -d '{"approver_code": "E-1002"}'
```

```{ .text .output }
approved
{"detail":"Only 3 day(s) of CL left; this request needs 4"}
HTTP 409
```

Was anything half-saved by the failed approval? No: the checks failed before any change, and the rollback guarantees nothing was written. Request 17 is still pending and the balance still says 3:

```bash
curl -s http://127.0.0.1:8000/leave-requests/17 | python -c "import json,sys; print('request 17:', json.load(sys.stdin)['status'])"
curl -s http://127.0.0.1:8000/employees/E-1042/leave-balances \
  | python -c "import json,sys; [print(b['leave_type']['code'], 'remaining', b['remaining']) for b in json.load(sys.stdin) if b['leave_type']['code'] == 'CL']"
```

```{ .text .output }
request 17: pending
CL remaining 3.0
```

### The database's own safety net

The `leave_balances` table has `CHECK (used <= allocated)`. Even if a buggy script skipped the service's checks, MySQL would refuse the update (`ERROR 3819`):

```python
from sqlalchemy import update
from sqlalchemy.exc import DatabaseError

from app.database import SessionLocal
from app.models import LeaveBalance

with SessionLocal() as db:
    try:
        db.execute(update(LeaveBalance)
                   .where(LeaveBalance.employee_id == 6, LeaveBalance.leave_type_id == 1, LeaveBalance.year == 2026)
                   .values(used=99))
        db.commit()
    except DatabaseError as e:
        db.rollback()
        print(type(e).__name__, e.orig.errno, e.orig.msg)
```

```{ .text .output }
DatabaseError 3819 Check constraint 'leave_balances_chk_1' is violated.
```

Notice the exception class. With mysql-connector, `UNIQUE` and `FOREIGN KEY` violations arrive as `IntegrityError`, but a `CHECK` violation arrives as the more general `DatabaseError` (its parent class). Catching `DatabaseError` and looking at `e.orig.errno` handles all of them.

!!! tip "Check first, or rely on the database?"
    Both. The service **checks** first, which gives a clear message ("Only 3 day(s) of CL left"). The database constraint is the final guarantee, because between your check and the commit another request could change the data. In an endpoint, catch the error, roll back, and turn it into a friendly `409`.

## Trying It: Cancelling

Arjun's wedding plans change. His approved leave starts on 8 October, after "today" (5 October), so he can cancel it and the two days come back:

```bash
curl -s -X POST http://127.0.0.1:8000/leave-requests/5/cancel \
  -H "Content-Type: application/json" -d '{"employee_code": "E-1043"}' \
  | python -c "import json,sys; print('request 5:', json.load(sys.stdin)['status'])"
curl -s http://127.0.0.1:8000/employees/E-1043/leave-balances \
  | python -c "import json,sys; [print(b['leave_type']['code'], 'remaining', b['remaining']) for b in json.load(sys.stdin) if b['leave_type']['code'] == 'CL']"
```

```{ .text .output }
request 5: cancelled
CL remaining 12.0
```

Ananya's casual leave from March (request 1) is in the past, and Arjun's request isn't hers to cancel:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/leave-requests/1/cancel \
  -H "Content-Type: application/json" -d '{"employee_code": "E-1042"}'
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/leave-requests/17/cancel \
  -H "Content-Type: application/json" -d '{"employee_code": "E-1043"}'
```

```{ .text .output }
{"detail":"Leave that has already started can't be cancelled"}
HTTP 400
{"detail":"You can only cancel your own leave"}
HTTP 403
```

!!! realworld "In Real Projects"
    "Update the request, move the balance, write the audit row" is the same shape as every money-like workflow: payroll runs, expense reimbursements, bank transfers, inventory. It **must** be one transaction with row locks. Without `with_for_update()`, a manager and an HR admin approving the same request at the same second could both pass the "still pending?" check and deduct the balance twice. Auditors also check that every approval has a matching audit entry, which is only guaranteed if both are written in the same transaction.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Forgetting `db.commit()` | Response looks fine, but nothing is saved in MySQL | Commit in the service after the unit of work |
| Using the session after a failed commit without `rollback()` | `PendingRollbackError: This Session's transaction has been rolled back` | Always `db.rollback()` in `except` |
| Committing inside repositories | Can't group request + balance + audit into one transaction | Only services commit |
| Committing after each step | A crash leaves "approved" with no balance deducted | One `commit()` at the end |
| Needing an id before commit | `request.id` is `None` | `db.flush()` |
| No row lock on the request | Double approval deducts the balance twice | `select(...).with_for_update()` |
| Changing data before all validation | Partial changes before an error | Validate everything first, then change |
| Raw `IntegrityError` text in responses | Leaks table and constraint names | Translate to a friendly message |

## Practice Exercises

Reload a fresh `acmehr` before you start.

**Easy**

1. Add `GET /employees/{code}/leave-requests?status=pending` returning that employee's requests, newest first.
2. Add `GET /managers/{code}/pending-approvals`: the pending requests of everyone who reports to that manager. What does Karthik (E-1002) see?
3. Make `apply` reject earned leave (EL) that starts less than 7 days from `TODAY`, with a `BadRequestError`.

**Medium**

4. Make pending requests reserve balance: in `apply`, subtract the days of the employee's pending requests of the same type from `remaining`. Ananya's second December request should now be refused at apply time.
5. Add `POST /holidays` for HR. If a new holiday falls inside **approved** leave, the affected requests should get their `days` recalculated and the difference returned to the balance, all in one transaction.
6. Add `DELETE /documents/{document_id}` (with a `Document` model) that returns `204`, and records `document.deleted` in the audit log with the file name.

**Challenge**

7. Write a small script that fires **two approvals at the same time** for the same pending request (use `concurrent.futures.ThreadPoolExecutor` with `requests`, both as the right manager). With `with_for_update()`, exactly one should return 200 and the other 409, and `used` should increase once. Then remove the locks, reload the database and run it again. What happens to the balance? Explain why.

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    # 2  repository
    def pending_for_manager(self, manager_id: int) -> list[LeaveRequest]:
        stmt = (select(LeaveRequest).join(LeaveRequest.employee)
                .where(Employee.manager_id == manager_id, LeaveRequest.status == "pending")
                .order_by(LeaveRequest.start_date))
        return list(self.db.scalars(stmt))
    # Karthik sees Ananya's EL for 16-20 November (request 4).

    # 3  in apply, after loading leave_type
    if leave_type.code == "EL" and (data.start_date - TODAY).days < 7:
        raise BadRequestError("Earned leave must be applied at least 7 days in advance")

    # 4  in apply, before the balance check
    pending = sum((r.days for r in self.db.scalars(
        select(LeaveRequest).where(LeaveRequest.employee_id == employee.id,
                                   LeaveRequest.leave_type_id == leave_type.id,
                                   LeaveRequest.status == "pending"))), Decimal(0))
    # and in _check_balance compare days with remaining - pending

    # 5  service (core idea)
    def add_holiday(self, actor: Employee, day: date, name: str) -> None:
        try:
            self.repo.add(Holiday(holiday_date=day, name=name))
            self.db.flush()
            affected = self.db.scalars(select(LeaveRequest).where(
                LeaveRequest.status == "approved", LeaveRequest.start_date <= day,
                LeaveRequest.end_date >= day).with_for_update())
            for r in affected:
                holidays = self.repo.holidays_between(r.start_date, r.end_date)
                new_days = Decimal(str(working_days(r.start_date, r.end_date, r.duration, holidays)))
                balance = self.repo.get_balance(r.employee_id, r.leave_type_id, r.start_date.year, lock=True)
                if balance:
                    balance.used -= r.days - new_days
                r.days = new_days
                self._audit(actor, "leave.recalculated", r, days=float(new_days))
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

    # 7  race test
    from concurrent.futures import ThreadPoolExecutor
    import requests

    url = "http://127.0.0.1:8000/leave-requests/4/approve"
    with ThreadPoolExecutor(2) as pool:
        codes = list(pool.map(lambda _: requests.post(url, json={"approver_code": "E-1002"}).status_code, range(2)))
    print(codes)          # with the locks: [200, 409] (in either order)
    # Without the locks both transactions may read status='pending', both pass the checks,
    # and both add 5 days to `used`: Ananya loses 10 days of earned leave for one 5-day request.
    ```

!!! note "Mini Assignment"
    Implement the complete leave workflow in your **AcmeHR API** with the repository → service → router layers: apply, approve, reject and cancel, each one transaction with row locks and an audit row, plus the manager's pending-approvals list. Add a "Transactions" section to your README that lists, for each endpoint, which tables it changes and which rule each check enforces from the BRD.

## Interview Questions

!!! interview "1. What does `db.commit()` do, and what happens if you forget it?"
    It flushes pending changes (INSERT/UPDATE/DELETE) and commits the transaction, making them permanent and visible to others. Without it the changes stay in the session's open transaction and are rolled back when the session closes, so nothing is saved.

!!! interview "2. What is the difference between `flush()` and `commit()`?"
    `flush()` sends pending SQL to the database inside the current transaction (so generated ids exist and constraints are checked) without committing; it can still be rolled back. `commit()` flushes and then commits, making the changes permanent. Use `flush()` when you need a new row's id for another row in the same transaction, like an audit entry.

!!! interview "3. How do you handle a constraint violation in SQLAlchemy?"
    Catch `sqlalchemy.exc.IntegrityError` around the commit, call `db.rollback()` (the session is unusable until then), and translate it into a domain error such as a 409 Conflict with a friendly message. Checking first gives nicer messages, but the database constraint (`UNIQUE`, `FOREIGN KEY`, `CHECK`) is the final guarantee.

!!! interview "4. Why should repositories not commit?"
    Committing is a business decision about where a unit of work ends. If repositories committed, a service couldn't combine several writes (the request, the balance, the audit row) into one atomic transaction. Services own transaction boundaries; repositories just add and query.

!!! interview "5. How do you stop two people approving the same leave request at the same time?"
    Do the status check and the updates in one transaction and lock the row (`SELECT ... FOR UPDATE`, `with_for_update()` in SQLAlchemy), so the second transaction waits and then sees `approved`. Alternatively, use an atomic conditional update (`UPDATE leave_requests SET status='approved' WHERE id = ? AND status = 'pending'`) and check the affected row count. A `CHECK (used <= allocated)` constraint is a final safety net for the balance.

!!! interview "Scenario: HR reports an employee whose request shows 'approved' but whose balance never changed. How could that happen, and how do you prevent it?"
    The request update and the balance update were committed separately (or the balance update failed after the request was committed), so the work was half-done. Put the request, the balance and the audit row in a single transaction with one commit and a rollback on any error, and validate everything before changing anything. Then write a reconciliation query (approved days per employee vs `used`) to find and fix past mismatches.

## Summary

| Operation | SQLAlchemy |
|-----------|-----------|
| Create | `db.add(obj)` → `db.commit()` → `db.refresh(obj)` |
| Id before commit | `db.flush()` |
| Update | Set attributes → `db.commit()` |
| Delete | `db.delete(obj)` → `db.commit()` |
| Error | `except IntegrityError: db.rollback()` → domain error (409/400) |
| Lock rows | `select(...).with_for_update()` |
| Transaction rule | Lock → validate everything → change → commit once → rollback on any error |
| Layers | Router (HTTP) → Service (rules, commit) → Repository (queries) |
| Dependency chain | `get_db` → `LeaveService` → endpoint |

**Next lesson:** [Dependency Injection & Settings](09-dependencies-and-settings.md), reusable dependencies, configuration, `.env` files, and a clock you can control.
