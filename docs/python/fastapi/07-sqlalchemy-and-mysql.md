---
lesson: true
category: FastAPI
short: SQLAlchemy
api_app: app.main:app
api_db: true
description: Connecting the AcmeHR API to MySQL with SQLAlchemy 2.0 — engine, sessions, ORM models for the acmehr tables, self-referencing relationships (managers and teams, departments and sub-departments), the N+1 problem, and aggregate reports.
---

# SQLAlchemy & MySQL

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain what an ORM is and how SQLAlchemy maps tables to Python classes
    - Connect FastAPI to MySQL with an engine, sessions and a `get_db` dependency
    - Model **self-referencing** relationships: an employee's manager and direct reports, a department's sub-departments
    - Write SQLAlchemy 2.0 `select()` queries with filters, joins, grouping and eager loading, and spot the N+1 problem
    - Return ORM objects through nested Pydantic response models with `from_attributes`

**Prerequisites:** [MySQL with mysql-connector-python](06-mysql-connector.md), with the [acmehr database](06-mysql-connector.md#loading-the-acmehr-database) loaded in your MySQL.

## From Raw SQL to an ORM

In the [previous lesson](06-mysql-connector.md) you built endpoints with `mysql-connector-python`: a five-table join for every directory row, a self-join with aliases for the manager, `%s` parameters, dict rows, and `commit()` / `rollback()` / `close()` by hand. That works, and it's worth knowing. But the AcmeHR API will need hundreds of queries, and writing each join by hand gets old fast.

An **ORM** (Object-Relational Mapper) lets you work with **Python classes and objects** instead, and generates the SQL for you:

| Database | ORM (SQLAlchemy) |
|----------|------------------|
| Table `employees` | Class `Employee` |
| Row | An `Employee` object |
| Column `hire_date` | Attribute `employee.hire_date` |
| Foreign key `department_id` | Relationship `employee.department` |
| Self-reference `manager_id` | `employee.manager` and `employee.direct_reports` |
| `SELECT * FROM employees WHERE id = 6` | `db.get(Employee, 6)` |

!!! example "Real-life analogy: an interpreter at a client meeting"
    Acme's consultants speak English; a client in Pune prefers Marathi. An interpreter turns each sentence into the other language and back. You speak Python; MySQL speaks SQL. The ORM is the interpreter, turning `employee.manager.first_name` into a `SELECT ... WHERE id = ...` and turning the reply back into an object. You can still talk to MySQL directly when you need to; the interpreter just saves effort in everyday conversations.

**SQLAlchemy** is Python's most widely used ORM and database toolkit. It also uses parameterised queries automatically, so ORM code is protected from SQL injection.

```bash
pip install sqlalchemy mysql-connector-python
```

| Package | Role |
|---------|------|
| `sqlalchemy` | The ORM |
| `mysql-connector-python` | The MySQL **driver** SQLAlchemy uses to talk to the server: the same one you used in lesson 06 |

## The Database Connection

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

| Piece | What it is |
|-------|-----------|
| `DATABASE_URL` | `dialect+driver://user:password@host:port/database`, read from an environment variable |
| `engine` | Manages a **pool** of connections to MySQL, created once for the whole app |
| `pool_pre_ping=True` | Checks a connection is alive before using it (avoids "MySQL server has gone away") |
| `SessionLocal` | A factory for **sessions**: a unit of work that tracks the objects you load and change |
| `Base` | Parent class for all ORM models |
| `get_db()` | A **dependency**: opens a session per request and always closes it afterwards |

Set the URL for your machine before starting the server:

=== "macOS / Linux"

    ```{ .bash .no-run }
    export DATABASE_URL="mysql+mysqlconnector://root:YOUR_PASSWORD@localhost:3306/acmehr"
    ```

=== "Windows (Command Prompt)"

    ```{ .bash .no-run }
    set DATABASE_URL=mysql+mysqlconnector://root:YOUR_PASSWORD@localhost:3306/acmehr
    ```

!!! warning "Special characters in the password"
    If your MySQL password contains `@`, `#`, `/` or `:`, URL-encode it: `@` becomes `%40` and `#` becomes `%23`. For example `Pass@123` becomes `Pass%40123` in the URL. In [lesson 09](09-dependencies-and-settings.md) you'll move all of this into a `.env` file.

## ORM Models

Models describe the **existing** acmehr tables. SQLAlchemy 2.0 uses type hints with `Mapped[...]` and `mapped_column(...)`:

```python title="app/models.py"
from datetime import date, datetime, time
from decimal import Decimal

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Location(Base):
    __tablename__ = "locations"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(60))
    city: Mapped[str] = mapped_column(String(60))
    region: Mapped[str] = mapped_column(String(30))


class Designation(Base):
    __tablename__ = "designations"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(60), unique=True)
    level: Mapped[int]


class Shift(Base):
    __tablename__ = "shifts"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(30), unique=True)
    start_time: Mapped[time]
    end_time: Mapped[time]
    grace_minutes: Mapped[int]


class Department(Base):
    __tablename__ = "departments"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(60), unique=True)
    parent_id: Mapped[int | None] = mapped_column(ForeignKey("departments.id"))
    head_id: Mapped[int | None] = mapped_column(ForeignKey("employees.id"))
    is_active: Mapped[bool] = mapped_column(default=True)

    parent: Mapped["Department | None"] = relationship(remote_side=[id], back_populates="sub_departments")
    sub_departments: Mapped[list["Department"]] = relationship(back_populates="parent")
    head: Mapped["Employee | None"] = relationship(foreign_keys=[head_id])
    employees: Mapped[list["Employee"]] = relationship(foreign_keys="Employee.department_id",
                                                       back_populates="department")


class Employee(Base):
    __tablename__ = "employees"

    id: Mapped[int] = mapped_column(primary_key=True)
    employee_code: Mapped[str] = mapped_column(String(10), unique=True)
    first_name: Mapped[str] = mapped_column(String(50))
    last_name: Mapped[str] = mapped_column(String(50))
    email: Mapped[str] = mapped_column(String(120), unique=True)
    phone: Mapped[str] = mapped_column(String(15))
    gender: Mapped[str] = mapped_column(String(10))
    date_of_birth: Mapped[date]
    hire_date: Mapped[date]
    department_id: Mapped[int] = mapped_column(ForeignKey("departments.id"))
    designation_id: Mapped[int] = mapped_column(ForeignKey("designations.id"))
    location_id: Mapped[int] = mapped_column(ForeignKey("locations.id"))
    manager_id: Mapped[int | None] = mapped_column(ForeignKey("employees.id"))
    shift_id: Mapped[int] = mapped_column(ForeignKey("shifts.id"))
    status: Mapped[str] = mapped_column(String(10), default="active")
    role: Mapped[str] = mapped_column(String(10), default="employee")
    emergency_contact_name: Mapped[str] = mapped_column(String(100))
    emergency_contact_relation: Mapped[str] = mapped_column(String(30))
    emergency_contact_phone: Mapped[str] = mapped_column(String(15))

    department: Mapped[Department] = relationship(foreign_keys=[department_id], back_populates="employees")
    designation: Mapped[Designation] = relationship()
    location: Mapped[Location] = relationship()
    shift: Mapped[Shift] = relationship()
    manager: Mapped["Employee | None"] = relationship(remote_side=[id], back_populates="direct_reports")
    direct_reports: Mapped[list["Employee"]] = relationship(back_populates="manager")

    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}"


class LeaveType(Base):
    __tablename__ = "leave_types"

    id: Mapped[int] = mapped_column(primary_key=True)
    code: Mapped[str] = mapped_column(String(5), unique=True)
    name: Mapped[str] = mapped_column(String(40))
    days_per_year: Mapped[int | None]
    carry_forward: Mapped[bool]
    is_paid: Mapped[bool]


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
    used: Mapped[Decimal] = mapped_column(default=0)

    leave_type: Mapped[LeaveType] = relationship()


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

| Syntax | Meaning |
|--------|---------|
| `__tablename__ = "employees"` | The MySQL table this class maps to |
| `Mapped[int]` | Column type; `Mapped[str \| None]` means the column is nullable |
| `mapped_column(primary_key=True)` | Column options: PK, `ForeignKey`, `String(100)`, `unique`, `default` |
| `Decimal` | Exact numbers for MySQL `DECIMAL`: 0.5 leave days stay exactly 0.5 |
| `relationship(back_populates=...)` | Navigation between objects: `employee.department`, `department.employees` |
| `@property full_name` | A normal Python property; Pydantic can read it like a column |

### Self-referencing relationships

The most interesting lines are the ones where a table points to **itself**:

```{ .python .no-run }
manager_id: Mapped[int | None] = mapped_column(ForeignKey("employees.id"))

manager: Mapped["Employee | None"] = relationship(remote_side=[id], back_populates="direct_reports")
direct_reports: Mapped[list["Employee"]] = relationship(back_populates="manager")
```

Both sides use the same foreign key, so SQLAlchemy needs a hint about which side is the "one": `remote_side=[id]` says *"for `manager`, the employee on the other end is matched by **its** `id`"*. The result is an org chart you can walk with plain attributes: `arjun.manager.manager.full_name` is `"Karthik Menon"`. Departments use the same trick for sub-departments.

### Several paths between two tables

`leave_requests` has **two** foreign keys to `employees` (who applied and who approved), and `departments` and `employees` point at each other (an employee's department, a department's head). When there's more than one path, SQLAlchemy can't guess which one a relationship should use, and stops with an `AmbiguousForeignKeysError`. `foreign_keys=[...]` tells it:

```{ .python .no-run }
employee: Mapped[Employee] = relationship(foreign_keys=[employee_id])
approver: Mapped[Employee | None] = relationship(foreign_keys=[approver_id])
```

!!! info "Existing tables vs creating tables"
    Here the tables already exist (we created them with `acmehr.sql`), so the models just **describe** them. For a brand-new project, `Base.metadata.create_all(engine)` can create tables from the models. Real projects use a **migration** tool such as **Alembic** to create and change tables safely over time.

## Response Schemas from ORM Objects

Pydantic needs `from_attributes=True` to read data from **object attributes** (`employee.hire_date`) instead of dict keys:

```python title="app/schemas.py"
from datetime import date

from pydantic import BaseModel, ConfigDict


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class EmployeeBrief(ORMModel):
    employee_code: str
    full_name: str


class DepartmentBrief(ORMModel):
    id: int
    name: str


class DesignationOut(ORMModel):
    title: str
    level: int


class LocationOut(ORMModel):
    name: str
    city: str


class EmployeeOut(ORMModel):
    employee_code: str
    full_name: str
    email: str
    hire_date: date
    status: str
    department: DepartmentBrief
    designation: DesignationOut
    location: LocationOut
    manager: EmployeeBrief | None


class TeamMember(EmployeeBrief):
    designation: DesignationOut


class TeamOut(ORMModel):
    manager: EmployeeBrief
    direct_reports: list[TeamMember]


class DepartmentOut(ORMModel):
    id: int
    name: str
    head: EmployeeBrief | None
    sub_departments: list[DepartmentBrief]
```

`EmployeeOut.manager` is a **nested** schema: FastAPI follows `employee.manager` (the relationship) and serialises it as `{"employee_code": ..., "full_name": ...}`, reading `full_name` from the property.

## Querying with select()

SQLAlchemy 2.0 builds queries with `select()`. The session executes them:

```python title="app/services.py"
from datetime import date, datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload, selectinload

from app.models import Attendance, Department, Designation, Employee, Holiday, LeaveRequest, Location


def get_employee(db: Session, code: str) -> Employee:
    stmt = (
        select(Employee)
        .where(Employee.employee_code == code)
        .options(joinedload(Employee.department), joinedload(Employee.designation),
                 joinedload(Employee.location), joinedload(Employee.manager))
    )
    employee = db.scalars(stmt).first()
    if employee is None:
        raise HTTPException(status_code=404, detail=f"Employee {code} not found")
    return employee


def get_team(db: Session, code: str) -> dict:
    manager = get_employee(db, code)
    stmt = (
        select(Employee)
        .where(Employee.manager_id == manager.id, Employee.status != "exited")
        .options(joinedload(Employee.designation))
        .order_by(Employee.first_name)
    )
    return {"manager": manager, "direct_reports": db.scalars(stmt).all()}


def list_departments(db: Session) -> list[Department]:
    stmt = (
        select(Department)
        .where(Department.parent_id.is_(None))
        .options(joinedload(Department.head), selectinload(Department.sub_departments))
        .order_by(Department.name)
    )
    return db.scalars(stmt).all()


def headcount(db: Session, by: str) -> list[dict]:
    group = {"department": Department.name, "location": Location.city, "designation": Designation.title}[by]
    stmt = (
        select(group.label("group"), func.count(Employee.id).label("headcount"))
        .select_from(Employee)
        .join(Employee.department).join(Employee.location).join(Employee.designation)
        .where(Employee.status != "exited")
        .group_by(group)
        .order_by(func.count(Employee.id).desc(), group)
    )
    return [row._asdict() for row in db.execute(stmt)]


def daily_attendance(db: Session, day: date) -> dict:
    if day.weekday() >= 5 or db.get(Holiday, day):
        raise HTTPException(status_code=400, detail=f"{day} is not a working day")
    employees = db.scalars(
        select(Employee).where(Employee.status != "exited", Employee.hire_date <= day)
        .options(joinedload(Employee.shift)).order_by(Employee.employee_code)
    ).all()
    records = {a.employee_id: a for a in db.scalars(select(Attendance).where(Attendance.work_date == day))}
    on_leave = set(db.scalars(
        select(LeaveRequest.employee_id)
        .where(LeaveRequest.status == "approved", LeaveRequest.duration == "full",
               LeaveRequest.start_date <= day, LeaveRequest.end_date >= day)
    ))

    late, leave, absent = [], [], []
    for e in employees:
        record = records.get(e.id)
        if record is None:
            (leave if e.id in on_leave else absent).append(e.full_name)
            continue
        deadline = datetime.combine(day, e.shift.start_time) + timedelta(minutes=e.shift.grace_minutes)
        if datetime.combine(day, record.check_in) > deadline:
            late.append({"employee": e.full_name, "shift": e.shift.name, "check_in": record.check_in})
    return {"date": day, "employees": len(employees), "present": len(records),
            "late": late, "on_leave": leave, "absent": absent}
```

(To keep this lesson focused on the database, the "not found" checks raise `HTTPException` directly. In [lesson 08](08-database-crud.md) you'll return to the clean router → service split with domain exceptions.)

| SQL | SQLAlchemy 2.0 |
|-----|----------------|
| `SELECT * FROM employees` | `select(Employee)` |
| `WHERE status <> 'exited'` | `.where(Employee.status != "exited")` |
| `WHERE parent_id IS NULL` | `.where(Department.parent_id.is_(None))` |
| `WHERE first_name LIKE 'A%'` | `.where(Employee.first_name.like("A%"))` |
| `JOIN departments ON ...` | `.join(Employee.department)` |
| `LEFT JOIN` | `.outerjoin(...)` |
| `ORDER BY hire_date DESC` | `.order_by(Employee.hire_date.desc())` |
| `LIMIT 10 OFFSET 20` | `.limit(10).offset(20)` |
| `COUNT(*)`, `GROUP BY` | `func.count(...)`, `.group_by(...)` |
| Get by primary key | `db.get(Employee, 6)` |
| Run, get objects | `db.scalars(stmt).all()` · one value: `db.scalar(stmt)` |

You can see the SQL that SQLAlchemy generates by printing a statement:

```python
from sqlalchemy import select
from app.models import Department, Employee

stmt = (
    select(Employee)
    .join(Employee.department)
    .where(Department.name == "Engineering", Employee.status == "active")
    .order_by(Employee.hire_date)
    .limit(3)
)
print(stmt)
```

```{ .text .output }
SELECT employees.id, employees.employee_code, employees.first_name, employees.last_name, employees.email, employees.phone, employees.gender, employees.date_of_birth, employees.hire_date, employees.department_id, employees.designation_id, employees.location_id, employees.manager_id, employees.shift_id, employees.status, employees.role, employees.emergency_contact_name, employees.emergency_contact_relation, employees.emergency_contact_phone 
FROM employees JOIN departments ON departments.id = employees.department_id 
WHERE departments.name = :name_1 AND employees.status = :status_1 ORDER BY employees.hire_date
 LIMIT :param_1
```

The `:name_1`-style placeholders are **bound parameters**: values are sent separately from the SQL, exactly like `%s` in mysql-connector, so this is safe from SQL injection. And notice that SQLAlchemy worked out the `JOIN ... ON` condition from the relationship.

## Routers with the get_db Dependency

```python title="app/routers.py"
from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Path
from sqlalchemy.orm import Session

from app import services
from app.database import get_db
from app.schemas import DepartmentOut, EmployeeOut, TeamOut

router = APIRouter()
DB = Annotated[Session, Depends(get_db)]
EmployeeCode = Annotated[str, Path(pattern=r"^E-\d{4}$")]


@router.get("/employees/{code}", response_model=EmployeeOut, tags=["Employees"])
def get_employee(code: EmployeeCode, db: DB):
    return services.get_employee(db, code)


@router.get("/employees/{code}/team", response_model=TeamOut, tags=["Employees"])
def get_team(code: EmployeeCode, db: DB):
    return services.get_team(db, code)


@router.get("/departments", response_model=list[DepartmentOut], tags=["Organisation"])
def list_departments(db: DB):
    return services.list_departments(db)


@router.get("/reports/headcount", tags=["Reports"])
def headcount(db: DB, by: Literal["department", "location", "designation"] = "department"):
    return services.headcount(db, by)


@router.get("/reports/attendance/daily", tags=["Reports"])
def daily_attendance(db: DB, date: date):
    return services.daily_attendance(db, date)
```

```python title="app/main.py"
from fastapi import FastAPI

from app.routers import router

app = FastAPI(title="AcmeHR API", version="2.0")
app.include_router(router)
```

`db: Annotated[Session, Depends(get_db)]` tells FastAPI: *"before calling this function, call `get_db()` and pass in what it yields; after the response, run its `finally` block"*. Every request gets its own session, and it's always closed, even if the endpoint raises an error. We saved that long annotation as `DB` to keep signatures short.

```mermaid
sequenceDiagram
  participant C as Client
  participant F as FastAPI
  participant G as get_db()
  participant E as Endpoint
  participant M as MySQL
  C->>F: GET /employees/E-1042
  F->>G: open session
  G-->>F: yield db
  F->>E: get_employee("E-1042", db)
  E->>M: SELECT ... JOIN ... WHERE employee_code = ...
  M-->>E: row
  E-->>F: Employee object
  F->>G: finally: db.close()
  F-->>C: 200 JSON
```

## Trying the API Against MySQL

Ananya's profile, with her department, designation, location and manager nested inside, straight from acmehr:

```bash
curl -s http://127.0.0.1:8000/employees/E-1042
```

```{ .text .output }
{
  "employee_code": "E-1042",
  "full_name": "Ananya Rao",
  "email": "ananya.rao@acme.example",
  "hire_date": "2021-07-12",
  "status": "active",
  "department": {
    "id": 2,
    "name": "Engineering"
  },
  "designation": {
    "title": "Senior Software Engineer",
    "level": 3
  },
  "location": {
    "name": "HITEC City",
    "city": "Hyderabad"
  },
  "manager": {
    "employee_code": "E-1002",
    "full_name": "Karthik Menon"
  }
}
```

Karthik's team, through the `direct_reports` side of the self-reference:

```bash
curl -s http://127.0.0.1:8000/employees/E-1002/team \
  | python -c "import json,sys; d=json.load(sys.stdin); print('Manager:', d['manager']['full_name']); [print(' ', r['employee_code'], r['full_name'], '-', r['designation']['title']) for r in d['direct_reports']]"
```

```{ .text .output }
Manager: Karthik Menon
  E-1042 Ananya Rao - Senior Software Engineer
  E-1050 Kavya Srinivasan - Software Engineer
  E-1046 Priya Nair - Software Engineer
  E-1051 Rohan Gupta - Senior Software Engineer
  E-1048 Sneha Patil - Software Engineer
  E-1056 Swati Kulkarni - QA Lead
  E-1047 Vikram Joshi - DevOps Engineer
```

The department tree: top-level departments with their heads and sub-departments:

```bash
curl -s http://127.0.0.1:8000/departments \
  | python -c "import json,sys; [print(d['name'], '| head:', d['head']['full_name'] if d['head'] else None, '| sub:', [s['name'] for s in d['sub_departments']]) for d in json.load(sys.stdin)]"
```

```{ .text .output }
Engineering | head: Karthik Menon | sub: ['Platform Engineering', 'Quality Assurance']
Finance | head: Suresh Babu | sub: []
Human Resources | head: Rahul Sharma | sub: []
IT Operations | head: Deepa Krishnan | sub: []
Leadership | head: Lakshmi Menon | sub: []
Product | head: Neha Kapoor | sub: []
```

### Reports with GROUP BY

The HR dashboard in the BRD shows headcount by department and by location. One `GROUP BY` query each, built in Python:

```bash
curl -s "http://127.0.0.1:8000/reports/headcount?by=location"
```

```{ .text .output }
[
  {
    "group": "Hyderabad",
    "headcount": 13
  },
  {
    "group": "Bengaluru",
    "headcount": 4
  },
  {
    "group": "Pune",
    "headcount": 2
  }
]
```

The BRD's attendance wireframe for Monday 5 October 2026 shows Karthik and Priya arriving late and Fatima on sick leave. A check-in counts as late after the shift's start **plus** its grace period (09:15 for the General shift, 07:10 for Early):

```bash
curl -s "http://127.0.0.1:8000/reports/attendance/daily?date=2026-10-05"
```

```{ .text .output }
{
  "date": "2026-10-05",
  "employees": 19,
  "present": 18,
  "late": [
    {
      "employee": "Karthik Menon",
      "shift": "General",
      "check_in": "09:41:00"
    },
    {
      "employee": "Priya Nair",
      "shift": "General",
      "check_in": "10:05:00"
    }
  ],
  "on_leave": ["Fatima Khan"],
  "absent": []
}
```

Wednesday shows someone absent with no leave on record, exactly the "exceptions" list HR checks every morning:

```bash
curl -s "http://127.0.0.1:8000/reports/attendance/daily?date=2026-10-07" \
  | python -c "import json,sys; d=json.load(sys.stdin); print('present', d['present'], 'of', d['employees']); print('late:', [l['employee'] for l in d['late']]); print('absent:', d['absent'])"
```

```{ .text .output }
present 18 of 19
late: ['Vikram Joshi', 'Deepa Krishnan', 'Manoj Pillai']
absent: ['Sneha Patil']
```

```bash
curl -s -w "\nHTTP %{http_code}\n" "http://127.0.0.1:8000/reports/attendance/daily?date=2026-10-20"
curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1:8000/employees/E-1999
```

```{ .text .output }
{"detail":"2026-10-20 is not a working day"}
HTTP 400
{"detail":"Employee E-1999 not found"}
HTTP 404
```

## Relationships and the N+1 Problem

Accessing a relationship like `department.employees` triggers a query the first time. Loop over 8 departments and touch `department.employees` on each, and you've sent **9 queries** (1 for the departments + 8 for their employees). With 500 departments it's 501 queries. This is the famous **N+1 problem**, and it's the most common ORM performance bug.

You can count the queries yourself with an SQLAlchemy event that fires before every statement:

```python
from sqlalchemy import event, select
from sqlalchemy.orm import selectinload

from app.database import SessionLocal, engine
from app.models import Department

queries = []
event.listen(engine, "before_cursor_execute", lambda *args: queries.append(args[2]))

with SessionLocal() as db:
    for dept in db.scalars(select(Department)):
        names = [e.first_name for e in dept.employees]          # lazy: one query per department
print("lazy loading:", len(queries), "queries")

queries.clear()
with SessionLocal() as db:
    stmt = select(Department).options(selectinload(Department.employees))
    for dept in db.scalars(stmt):
        names = [e.first_name for e in dept.employees]          # already loaded
print("selectinload:", len(queries), "queries")
print(queries[-1].split("WHERE")[1].strip())
```

```{ .text .output }
lazy loading: 9 queries
selectinload: 2 queries
employees.department_id IN (%(primary_keys_1)s, %(primary_keys_2)s, %(primary_keys_3)s, %(primary_keys_4)s, %(primary_keys_5)s, %(primary_keys_6)s, %(primary_keys_7)s, %(primary_keys_8)s)
```

`selectinload` loaded every department's employees in **one** extra query with `WHERE ... IN (...)`, whatever the number of departments.

| Loading strategy | Queries for 8 departments | Use when |
|------------------|---------------------------|----------|
| Default (lazy) | 1 + 8 | You rarely touch the relationship |
| `selectinload(...)` | 1 + 1 | Loading collections (`department.employees`, `manager.direct_reports`) |
| `joinedload(...)` | 1 (with a JOIN) | Loading single related objects (`employee.department`, `employee.manager`) |

That's why `get_employee` uses `joinedload` for the department, designation, location and manager (one row each), and `list_departments` uses `selectinload` for the sub-departments (a list).

!!! realworld "In Real Projects"
    Teams turn on `create_engine(..., echo=True)` during development to print every SQL statement SQLAlchemy runs. If loading the org chart prints hundreds of near-identical `SELECT`s, that's an N+1 problem waiting to be fixed with `selectinload` or `joinedload`. Many teams also add a test that fails if an endpoint runs more than a fixed number of queries.

## Common Mistakes

| Mistake | Error / Symptom | Fix |
|---------|-----------------|-----|
| Wrong URL / password | `ProgrammingError: (mysql.connector.errors.ProgrammingError) 1045 (28000): Access denied for user 'root'@'localhost'` | Check `DATABASE_URL`; URL-encode special characters |
| MySQL not running | `DatabaseError: (mysql.connector.errors.DatabaseError) 2003 (HY000): Can't connect to MySQL server on 'localhost:3306'` | Start MySQL; check host and port |
| Two foreign keys to the same table, no hint | `AmbiguousForeignKeysError: Could not determine join condition between parent/child tables` | `relationship(foreign_keys=[...])` |
| Self-reference without `remote_side` | `manager` behaves like a list, or a startup error about the relationship direction | `relationship(remote_side=[id])` on the "many-to-one" side |
| `from_attributes` missing | `ResponseValidationError` / "Input should be a valid dictionary" | `model_config = ConfigDict(from_attributes=True)` |
| `__tablename__` doesn't match the real table | `ProgrammingError: ... 1146 (42S02): Table 'acmehr.employee' doesn't exist` | Match the exact table name |
| Lazy-loading in a loop | Hundreds of queries, slow endpoints | `selectinload` / `joinedload` |
| `== None` in a query | Works, but linters complain | `.is_(None)` / `.is_not(None)` |

## Practice Exercises

Use a fresh `acmehr` and the code from this lesson.

**Easy**

1. Add `GET /locations` returning each office's name, city and region.
2. Add `GET /employees/{code}/manager` returning the employee's manager as an `EmployeeBrief`, or `null` for the CEO.
3. Add a `by=gender` option to the headcount report.

**Medium**

4. Add `GET /departments/{department_id}/employees` that lists the department's active employees **and** those of its sub-departments (hint: `Department.id.in_([...])`). Engineering should include Platform Engineering and QA.
5. Add `GET /employees/{code}/leave-balances?year=2026` with SQLAlchemy, returning the leave type's code and name, allocated, used and remaining.
6. Add `GET /reports/attendance/weekly?start=2026-10-05` that returns, for each employee, how many days of that week they were present and late.

**Challenge**

7. Add `GET /employees/{code}/org-chart` that returns the employee with their reports nested recursively (`{"employee_code", "full_name", "reports": [...]}`). Lakshmi's chart should contain the whole company. Make it run **one** query: load all active employees at once and build the tree in Python, instead of one query per level.

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    # 2
    @router.get("/employees/{code}/manager", response_model=EmployeeBrief | None, tags=["Employees"])
    def get_manager(code: EmployeeCode, db: DB):
        return services.get_employee(db, code).manager

    # 3  in headcount: add "gender": Employee.gender to the dict, and allow it in the Literal

    # 4
    @router.get("/departments/{department_id}/employees", response_model=list[EmployeeBrief], tags=["Organisation"])
    def department_employees(department_id: int, db: DB):
        dept = db.get(Department, department_id)
        if dept is None:
            raise HTTPException(status_code=404, detail="Department not found")
        ids = [dept.id] + [s.id for s in dept.sub_departments]
        stmt = (select(Employee).where(Employee.department_id.in_(ids), Employee.status != "exited")
                .order_by(Employee.first_name))
        return db.scalars(stmt).all()

    # 5
    @router.get("/employees/{code}/leave-balances", tags=["Leave"])
    def leave_balances(code: EmployeeCode, db: DB, year: int = 2026):
        employee = services.get_employee(db, code)
        stmt = (select(LeaveBalance).where(LeaveBalance.employee_id == employee.id, LeaveBalance.year == year)
                .options(joinedload(LeaveBalance.leave_type)).order_by(LeaveBalance.leave_type_id))
        return [{"code": b.leave_type.code, "name": b.leave_type.name, "allocated": float(b.allocated),
                 "used": float(b.used), "remaining": float(b.allocated - b.used)} for b in db.scalars(stmt)]

    # 7
    @router.get("/employees/{code}/org-chart", tags=["Employees"])
    def org_chart(code: EmployeeCode, db: DB):
        root = services.get_employee(db, code)
        everyone = db.scalars(select(Employee).where(Employee.status != "exited")).all()   # one query
        by_manager: dict[int, list[Employee]] = {}
        for e in everyone:
            by_manager.setdefault(e.manager_id, []).append(e)

        def build(e: Employee) -> dict:
            return {"employee_code": e.employee_code, "full_name": e.full_name,
                    "reports": [build(r) for r in sorted(by_manager.get(e.id, []), key=lambda r: r.first_name)]}
        return build(root)
    ```

!!! note "Mini Assignment"
    Move your **AcmeHR API** to SQLAlchemy: add `app/database.py` and `app/models.py` for the acmehr tables (with the `manager` / `direct_reports` and `parent` / `sub_departments` relationships), and convert every **read** endpoint (directory, profile, team, departments, leave balances, the headcount and daily attendance reports) to SQLAlchemy queries with `response_model`s. Turn on `echo=True` once and make sure no endpoint has an N+1 problem.

## Interview Questions

!!! interview "1. What is an ORM? What are its pros and cons?"
    An Object-Relational Mapper maps tables to classes and rows to objects, generating SQL for you. Pros: less boilerplate, database portability, safety from injection by default, and relationships as attributes. Cons: hidden or inefficient SQL (N+1), a learning curve, and complex reports are sometimes easier in raw SQL.

!!! interview "2. What is the difference between the engine and a session in SQLAlchemy?"
    The engine is created once per application; it holds the connection pool and the dialect for talking to the database. A session is a short-lived unit of work (typically one per request) that tracks loaded and changed objects and manages the transaction (`commit` / `rollback`).

!!! interview "3. How do you model an employee–manager relationship in SQLAlchemy?"
    A nullable `manager_id` foreign key to the same table, plus two relationships on the class: `manager = relationship(remote_side=[id], back_populates="direct_reports")` (many-to-one) and `direct_reports = relationship(back_populates="manager")` (one-to-many). `remote_side` tells SQLAlchemy which end is the parent.

!!! interview "4. What is the N+1 query problem and how do you fix it in SQLAlchemy?"
    Loading N parent objects with one query and then lazily loading a relationship for each one, so N extra queries run. Fix it with eager loading: `selectinload()` (one extra IN query for collections) or `joinedload()` (a JOIN, good for many-to-one), or with an explicit join in the query.

!!! interview "5. What does `from_attributes=True` do in Pydantic?"
    It lets a Pydantic model be built from arbitrary objects by reading attributes (`obj.hire_date`, including properties like `full_name`) instead of dict keys, which is needed to return SQLAlchemy ORM objects through `response_model`. (It was called `orm_mode` in Pydantic v1.)

!!! interview "Scenario: the org chart page takes 4 seconds and the logs show 200 SELECT statements. Diagnose and fix."
    Each employee's `direct_reports` is lazy-loaded while the tree is built, one query per person: an N+1 problem. Either load all employees in one query and build the tree in Python using `manager_id`, or use a recursive CTE in SQL. Add an index on `manager_id` (MySQL creates one for the foreign key) and a test that caps the number of queries.

## Summary

| Concept | Code |
|---------|------|
| Install | `pip install sqlalchemy mysql-connector-python` |
| URL | `mysql+mysqlconnector://user:pass@host:3306/acmehr` (from env) |
| Engine / sessions | `create_engine(URL, pool_pre_ping=True)` · `sessionmaker(bind=engine)` |
| Model | `class Employee(Base): __tablename__ = "employees"; id: Mapped[int] = mapped_column(primary_key=True)` |
| Relationship | `department: Mapped[Department] = relationship(back_populates="employees")` |
| Self-reference | `manager = relationship(remote_side=[id])` + `direct_reports = relationship(...)` |
| Several FKs | `relationship(foreign_keys=[approver_id])` |
| Dependency | `db: Annotated[Session, Depends(get_db)]` |
| Query | `db.scalars(select(Employee).where(...).order_by(...).limit(n)).all()` · `db.get(Employee, id)` |
| Response | Pydantic `ConfigDict(from_attributes=True)`, nested schemas |
| Performance | `selectinload` / `joinedload` against N+1; `echo=True` to see SQL |

**Next lesson:** [Database CRUD & Transactions](08-database-crud.md), applying for, approving and cancelling leave safely.
