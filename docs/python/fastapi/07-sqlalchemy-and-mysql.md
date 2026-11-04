---
lesson: true
category: FastAPI
short: SQLAlchemy
api_app: app.main:app
api_db: true
description: Connecting the AcmeHR API to MySQL with SQLAlchemy 2.0 — engine and connection pool settings, sessions, ORM models for four acmehr tables, self-referencing relationships (managers and teams, departments and sub-departments), the N+1 problem, and aggregate reports.
---

# SQLAlchemy & MySQL

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain what an ORM is and how SQLAlchemy maps tables to Python classes
    - Connect FastAPI to MySQL with an engine, sessions and a `get_db` dependency
    - Configure the connection pool (`pool_size`, `max_overflow`, `pool_timeout`, `pool_recycle`, `pool_pre_ping`) and size it for production
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
| Column `first_name` | Attribute `employee.first_name` |
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

engine = create_engine(
    DATABASE_URL,
    pool_size=5,            # connections kept open and ready
    max_overflow=10,        # extra connections allowed during a burst
    pool_timeout=30,        # seconds a request waits for a free connection
    pool_recycle=1800,      # replace connections older than 30 minutes
    pool_pre_ping=True,     # check a connection is alive before handing it out
)
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
| `engine` | Created once for the whole app; it owns the **connection pool** (next section) and knows how to speak MySQL |
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

## The Connection Pool

Opening a MySQL connection is slow: a network handshake, a login and a few setup queries, often 20–50 ms. An API that opened a new connection for every request would spend more time connecting than working. In lesson 06 you created a pool by hand with `MySQLConnectionPool(pool_size=5)`. SQLAlchemy's engine **always** has one (a `QueuePool`), and the five settings in `create_engine` control how it behaves.

!!! example "Real-life analogy: the office cab pool, again"
    Acme keeps **5 cabs** waiting in the parking lot (`pool_size`). On a busy morning it may call up to **10 more** from an agency (`max_overflow`), which go back to the agency once the rush is over. If all 15 are out, the next person waits at the gate for up to **30 seconds** (`pool_timeout`) before giving up. Every cab is swapped for a fresh one after **30 minutes** on the road (`pool_recycle`), and the driver checks the engine starts before you get in (`pool_pre_ping`).

```mermaid
flowchart LR
  R1["request 1"] --> P
  R2["request 2"] --> P
  R3["request …"] --> P
  P["Pool<br/>5 kept open<br/>+ up to 10 overflow"] --> M[("MySQL<br/>max_connections")]
  P -. "all 15 busy:<br/>wait up to 30 s,<br/>then TimeoutError" .-> R3
```

| Setting | Default | What it does | How to choose |
|---------|---------|--------------|---------------|
| `pool_size` | 5 | Connections kept open between requests | Roughly the number of requests one worker handles at the same time |
| `max_overflow` | 10 | Extra connections opened during a burst, closed again when returned | Headroom for spikes (09:00 check-ins); `0` makes `pool_size` a hard limit |
| `pool_timeout` | 30 | Seconds a request waits for a free connection before `TimeoutError` | Lower (5–10 s) so users get a fast error instead of a hanging page |
| `pool_recycle` | -1 (never) | Replace connections older than this many seconds | Below MySQL's `wait_timeout` (8 hours by default) or your cloud proxy's idle limit |
| `pool_pre_ping` | False | Runs a cheap check before handing out a connection | `True` in production: avoids "MySQL server has gone away" after a database restart |

The pool belongs to **one process**. When you run 4 workers in production (lesson 13), each has its own pool, so the API can open up to `workers × (pool_size + max_overflow)` connections. That number must stay below MySQL's limit:

```python
from sqlalchemy import text
from app.database import engine

with engine.connect() as conn:
    print(conn.execute(text("SHOW VARIABLES LIKE 'max_connections'")).one())

workers, pool_size, max_overflow = 4, 5, 10
print("worst case:", workers * (pool_size + max_overflow), "connections")
```

```{ .text .output }
('max_connections', '151')
worst case: 60 connections
```

60 is comfortably below 151. With 12 workers it would be 180, and MySQL would start refusing connections with `Too many connections`.

### Watching the pool fill up

A tiny pool makes the behaviour visible: 2 connections plus 1 overflow, and a 2-second timeout:

```python
import os
from sqlalchemy import create_engine
from sqlalchemy.exc import TimeoutError

small = create_engine(os.environ["DATABASE_URL"], pool_size=2, max_overflow=1, pool_timeout=2)

held = [small.connect() for _ in range(3)]          # 2 from the pool + 1 overflow
print(small.pool.status())
try:
    small.connect()                                  # a 4th request has to wait...
except TimeoutError as e:
    print("4th connection:", str(e).split(",")[0])

for conn in held:
    conn.close()                                     # back to the pool
print(small.pool.status())
```

```{ .text .output }
Pool size: 2  Connections in pool: 0 Current Overflow: 1 Current Checked out connections: 3
4th connection: QueuePool limit of size 2 overflow 1 reached
Pool size: 2  Connections in pool: 2 Current Overflow: 0 Current Checked out connections: 0
```

Three connections were handed out (the third as overflow). The fourth waited 2 seconds and gave up. After `close()`, the two regular connections went back into the pool, ready for the next request, and the overflow connection was closed. In the API, `get_db`'s `finally: db.close()` is what returns the connection: forget it and the pool slowly empties until every request times out.

!!! realworld "In Real Projects"
    "QueuePool limit of size 5 overflow 10 reached, connection timed out" in production logs almost always means connections are being **held too long** (a slow query, or calling an external API while a session is open), not that the pool is too small. Fix the leak first; raise `pool_size` only after measuring.

## ORM Models

The acmehr database has 12 tables, but you don't have to map them all at once. This lesson maps the **4 tables** it needs; lesson 08 adds the leave tables the same way.

```mermaid
erDiagram
  departments ||--o{ employees : "belongs to"
  departments ||--o{ departments : "parent of"
  employees ||--o{ employees : "manages"
  shifts ||--o{ employees : "works"
  employees ||--o{ attendance : "checks in"
```

SQLAlchemy 2.0 uses type hints with `Mapped[...]` and `mapped_column(...)`:

```python title="app/models.py"
from datetime import date, time

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Department(Base):
    __tablename__ = "departments"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(60))
    parent_id: Mapped[int | None] = mapped_column(ForeignKey("departments.id"))

    parent: Mapped["Department | None"] = relationship(remote_side=[id], back_populates="sub_departments")
    sub_departments: Mapped[list["Department"]] = relationship(back_populates="parent")
    employees: Mapped[list["Employee"]] = relationship(back_populates="department")


class Shift(Base):
    __tablename__ = "shifts"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(30))
    start_time: Mapped[time]
    grace_minutes: Mapped[int]


class Employee(Base):
    __tablename__ = "employees"

    id: Mapped[int] = mapped_column(primary_key=True)
    employee_code: Mapped[str] = mapped_column(String(10))
    first_name: Mapped[str] = mapped_column(String(50))
    last_name: Mapped[str] = mapped_column(String(50))
    status: Mapped[str] = mapped_column(String(10))
    department_id: Mapped[int] = mapped_column(ForeignKey("departments.id"))
    manager_id: Mapped[int | None] = mapped_column(ForeignKey("employees.id"))
    shift_id: Mapped[int] = mapped_column(ForeignKey("shifts.id"))

    department: Mapped[Department] = relationship(back_populates="employees")
    shift: Mapped[Shift] = relationship()
    manager: Mapped["Employee | None"] = relationship(remote_side=[id], back_populates="direct_reports")
    direct_reports: Mapped[list["Employee"]] = relationship(back_populates="manager")

    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}"


class Attendance(Base):
    __tablename__ = "attendance"

    id: Mapped[int] = mapped_column(primary_key=True)
    employee_id: Mapped[int] = mapped_column(ForeignKey("employees.id"))
    work_date: Mapped[date]
    check_in: Mapped[time]

    employee: Mapped[Employee] = relationship()
```

| Syntax | Meaning |
|--------|---------|
| `__tablename__ = "employees"` | The MySQL table this class maps to |
| `Mapped[int]` | Column type; `Mapped[str \| None]` means the column is nullable |
| `mapped_column(primary_key=True)` | Column options: primary key, `ForeignKey`, `String(50)` |
| `relationship(back_populates=...)` | Navigation between objects: `employee.department`, `department.employees` |
| `@property full_name` | A normal Python property; Pydantic can read it like a column |

Each class maps only the columns this lesson uses: `Employee` has 8 of the table's 20. That's allowed, because SQLAlchemy reads and writes only what you map. Add the email, phone and the rest when an endpoint needs them.

### Self-referencing relationships

The most interesting lines are the ones where a table points to **itself**:

```{ .python .no-run }
manager_id: Mapped[int | None] = mapped_column(ForeignKey("employees.id"))

manager: Mapped["Employee | None"] = relationship(remote_side=[id], back_populates="direct_reports")
direct_reports: Mapped[list["Employee"]] = relationship(back_populates="manager")
```

Both sides use the same foreign key, so SQLAlchemy needs a hint about which side is the "one": `remote_side=[id]` says *"for `manager`, the employee on the other end is matched by **its** `id`"*. The result is an org chart you can walk with plain attributes: `arjun.manager.manager.full_name` is `"Karthik Menon"`. Departments use the same trick for sub-departments.

!!! info "Existing tables vs creating tables"
    Here the tables already exist (we created them with `acmehr.sql`), so the models just **describe** them. For a brand-new project, `Base.metadata.create_all(engine)` can create tables from the models. Real projects use a **migration** tool such as **Alembic** to create and change tables safely over time.

## Response Schemas from ORM Objects

Pydantic needs `from_attributes=True` to read data from **object attributes** (`employee.first_name`) instead of dict keys:

```python title="app/schemas.py"
from pydantic import BaseModel, ConfigDict


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class EmployeeBrief(ORMModel):
    employee_code: str
    full_name: str


class DepartmentBrief(ORMModel):
    id: int
    name: str


class EmployeeOut(ORMModel):
    employee_code: str
    full_name: str
    status: str
    department: DepartmentBrief
    manager: EmployeeBrief | None


class TeamOut(ORMModel):
    manager: EmployeeBrief
    direct_reports: list[EmployeeBrief]


class DepartmentOut(ORMModel):
    id: int
    name: str
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

from app.models import Attendance, Department, Employee


def get_employee(db: Session, code: str) -> Employee:
    stmt = (
        select(Employee)
        .where(Employee.employee_code == code)
        .options(joinedload(Employee.department), joinedload(Employee.manager))
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
        .order_by(Employee.first_name)
    )
    return {"manager": manager, "direct_reports": db.scalars(stmt).all()}


def list_departments(db: Session) -> list[Department]:
    stmt = (
        select(Department)
        .where(Department.parent_id.is_(None))
        .options(selectinload(Department.sub_departments))
        .order_by(Department.name)
    )
    return db.scalars(stmt).all()


def headcount(db: Session) -> list[dict]:
    stmt = (
        select(Department.name, func.count(Employee.id).label("headcount"))
        .join(Employee.department)
        .where(Employee.status != "exited")
        .group_by(Department.name)
        .order_by(func.count(Employee.id).desc(), Department.name)
    )
    return [row._asdict() for row in db.execute(stmt)]


def daily_attendance(db: Session, day: date) -> dict:
    if day.weekday() >= 5:
        raise HTTPException(status_code=400, detail=f"{day} is a weekend")
    employees = db.scalars(
        select(Employee).where(Employee.status != "exited")
        .options(joinedload(Employee.shift)).order_by(Employee.employee_code)
    ).all()
    records = {a.employee_id: a for a in db.scalars(select(Attendance).where(Attendance.work_date == day))}

    late, missing = [], []
    for e in employees:
        record = records.get(e.id)
        if record is None:
            missing.append(e.full_name)
            continue
        deadline = datetime.combine(day, e.shift.start_time) + timedelta(minutes=e.shift.grace_minutes)
        if datetime.combine(day, record.check_in) > deadline:
            late.append({"employee": e.full_name, "check_in": record.check_in})
    return {"date": day, "present": len(records), "late": late, "not_checked_in": missing}
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
| `ORDER BY first_name DESC` | `.order_by(Employee.first_name.desc())` |
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
    .order_by(Employee.first_name)
    .limit(3)
)
print(stmt)
```

```{ .text .output }
SELECT employees.id, employees.employee_code, employees.first_name, employees.last_name, employees.status, employees.department_id, employees.manager_id, employees.shift_id 
FROM employees JOIN departments ON departments.id = employees.department_id 
WHERE departments.name = :name_1 AND employees.status = :status_1 ORDER BY employees.first_name
 LIMIT :param_1
```

The `:name_1`-style placeholders are **bound parameters**: values are sent separately from the SQL, exactly like `%s` in mysql-connector, so this is safe from SQL injection. And notice that SQLAlchemy worked out the `JOIN ... ON` condition from the relationship.

## Routers with the get_db Dependency

```python title="app/routers.py"
from datetime import date
from typing import Annotated

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
def headcount(db: DB):
    return services.headcount(db)


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

`db: Annotated[Session, Depends(get_db)]` tells FastAPI: *"before calling this function, call `get_db()` and pass in what it yields; after the response, run its `finally` block"*. Every request gets its own session (and a connection borrowed from the pool), and it's always closed, even if the endpoint raises an error. We saved that long annotation as `DB` to keep signatures short.

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
  E->>M: SELECT ... JOIN ... WHERE employee_code = ...<br/>(on a pooled connection)
  M-->>E: row
  E-->>F: Employee object
  F->>G: finally: db.close()<br/>(connection back to the pool)
  F-->>C: 200 JSON
```

## Trying the API Against MySQL

Ananya's profile, with her department and manager nested inside, straight from acmehr:

```bash
curl -s http://127.0.0.1:8000/employees/E-1042
```

```{ .text .output }
{
  "employee_code": "E-1042",
  "full_name": "Ananya Rao",
  "status": "active",
  "department": {
    "id": 2,
    "name": "Engineering"
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
  | python -c "import json,sys; d=json.load(sys.stdin); print('Manager:', d['manager']['full_name']); [print(' ', r['employee_code'], r['full_name']) for r in d['direct_reports']]"
```

```{ .text .output }
Manager: Karthik Menon
  E-1042 Ananya Rao
  E-1050 Kavya Srinivasan
  E-1046 Priya Nair
  E-1051 Rohan Gupta
  E-1048 Sneha Patil
  E-1056 Swati Kulkarni
  E-1047 Vikram Joshi
```

The department tree: top-level departments with their sub-departments:

```bash
curl -s http://127.0.0.1:8000/departments \
  | python -c "import json,sys; [print(d['name'], [s['name'] for s in d['sub_departments']]) for d in json.load(sys.stdin)]"
```

```{ .text .output }
Engineering ['Platform Engineering', 'Quality Assurance']
Finance []
Human Resources []
IT Operations []
Leadership []
Product []
```

### Reports with GROUP BY

The HR dashboard in the BRD shows headcount by department. One `GROUP BY` query, built in Python:

```bash
curl -s "http://127.0.0.1:8000/reports/headcount" \
  | python -c "import json,sys; [print(r['name'], r['headcount']) for r in json.load(sys.stdin)]"
```

```{ .text .output }
Engineering 5
Finance 3
Quality Assurance 3
Human Resources 2
Platform Engineering 2
Product 2
IT Operations 1
Leadership 1
```

The BRD's attendance wireframe for Monday 5 October 2026 shows Karthik and Priya arriving late. A check-in counts as late after the shift's start **plus** its grace period (09:15 for the General shift, 07:10 for Early):

```bash
curl -s "http://127.0.0.1:8000/reports/attendance/daily?date=2026-10-05"
```

```{ .text .output }
{
  "date": "2026-10-05",
  "present": 18,
  "late": [
    {
      "employee": "Karthik Menon",
      "check_in": "09:41:00"
    },
    {
      "employee": "Priya Nair",
      "check_in": "10:05:00"
    }
  ],
  "not_checked_in": ["Fatima Khan"]
}
```

Fatima hasn't checked in: she's on approved sick leave, but this report can't tell yet, because we haven't mapped `leave_requests`. That's exercise 6. Wednesday has Sneha missing with no leave at all, exactly the "exceptions" list HR checks every morning:

```bash
curl -s "http://127.0.0.1:8000/reports/attendance/daily?date=2026-10-07" \
  | python -c "import json,sys; d=json.load(sys.stdin); print('present', d['present']); print('late:', [l['employee'] for l in d['late']]); print('not checked in:', d['not_checked_in'])"
```

```{ .text .output }
present 18
late: ['Vikram Joshi', 'Deepa Krishnan', 'Manoj Pillai']
not checked in: ['Sneha Patil']
```

```bash
curl -s -w "\nHTTP %{http_code}\n" "http://127.0.0.1:8000/reports/attendance/daily?date=2026-10-10"
curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1:8000/employees/E-1999
```

```{ .text .output }
{"detail":"2026-10-10 is a weekend"}
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

That's why `get_employee` uses `joinedload` for the department and manager (one row each), and `list_departments` uses `selectinload` for the sub-departments (a list).

!!! realworld "In Real Projects"
    Teams turn on `create_engine(..., echo=True)` during development to print every SQL statement SQLAlchemy runs. If loading the org chart prints hundreds of near-identical `SELECT`s, that's an N+1 problem waiting to be fixed with `selectinload` or `joinedload`. Many teams also add a test that fails if an endpoint runs more than a fixed number of queries.

## Common Mistakes

| Mistake | Error / Symptom | Fix |
|---------|-----------------|-----|
| Wrong URL / password | `ProgrammingError: (mysql.connector.errors.ProgrammingError) 1045 (28000): Access denied for user 'root'@'localhost'` | Check `DATABASE_URL`; URL-encode special characters |
| MySQL not running | `DatabaseError: (mysql.connector.errors.DatabaseError) 2003 (HY000): Can't connect to MySQL server on 'localhost:3306'` | Start MySQL; check host and port |
| Self-reference without `remote_side` | `manager` behaves like a list, or a startup error about the relationship direction | `relationship(remote_side=[id])` on the "many-to-one" side |
| `from_attributes` missing | `ResponseValidationError` / "Input should be a valid dictionary" | `model_config = ConfigDict(from_attributes=True)` |
| `__tablename__` doesn't match the real table | `ProgrammingError: ... 1146 (42S02): Table 'acmehr.employee' doesn't exist` | Match the exact table name |
| Lazy-loading in a loop | Hundreds of queries, slow endpoints | `selectinload` / `joinedload` |
| Sessions not closed, or held during slow work | `TimeoutError: QueuePool limit of size 5 overflow 10 reached` | Always close via `get_db`; don't call slow external services with a session open |
| Many workers, each with a big pool | MySQL: `Too many connections` | Keep `workers × (pool_size + max_overflow)` below `max_connections` |
| `== None` in a query | Works, but linters complain | `.is_(None)` / `.is_not(None)` |

## Practice Exercises

Use a fresh `acmehr` and the code from this lesson.

**Easy**

1. Map the `locations` table (id, name, city, region), add `location_id` and a `location` relationship to `Employee`, and add `GET /locations`.
2. Add `GET /employees/{code}/manager` returning the employee's manager as an `EmployeeBrief`, or `null` for the CEO.
3. Add a `GET /reports/headcount/shifts` that counts active employees per shift.

**Medium**

4. Add `GET /departments/{department_id}/employees` that lists the department's active employees **and** those of its sub-departments (hint: `Department.id.in_([...])`). Engineering should include Platform Engineering and QA.
5. Map `leave_types` and `leave_balances` (a composite primary key: `employee_id`, `leave_type_id`, `year`), and add `GET /employees/{code}/leave-balances?year=2026` returning each type's code and name, allocated, used and remaining.
6. Map `leave_requests` and split the daily report's `not_checked_in` into `on_leave` (approved full-day leave covering the date) and `absent`. Fatima should move to `on_leave` on 5 October.

**Challenge**

7. Add `GET /employees/{code}/org-chart` that returns the employee with their reports nested recursively (`{"employee_code", "full_name", "reports": [...]}`). Lakshmi's chart should contain the whole company. Make it run **one** query: load all active employees at once and build the tree in Python, instead of one query per level.

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    # 2
    @router.get("/employees/{code}/manager", response_model=EmployeeBrief | None, tags=["Employees"])
    def get_manager(code: EmployeeCode, db: DB):
        return services.get_employee(db, code).manager

    # 3  same as headcount(), with Shift.name, .join(Employee.shift) and .group_by(Shift.name)

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

    # 5  models: LeaveType(id, code, name) and
    #    LeaveBalance(employee_id, leave_type_id, year: all primary_key=True; allocated, used; leave_type relationship)
    @router.get("/employees/{code}/leave-balances", tags=["Leave"])
    def leave_balances(code: EmployeeCode, db: DB, year: int = 2026):
        employee = services.get_employee(db, code)
        stmt = (select(LeaveBalance).where(LeaveBalance.employee_id == employee.id, LeaveBalance.year == year)
                .options(joinedload(LeaveBalance.leave_type)).order_by(LeaveBalance.leave_type_id))
        return [{"code": b.leave_type.code, "name": b.leave_type.name, "allocated": float(b.allocated),
                 "used": float(b.used), "remaining": float(b.allocated - b.used)} for b in db.scalars(stmt)]

    # 6  model LeaveRequest(id, employee_id, start_date, end_date, duration, status), then in daily_attendance:
    on_leave_ids = set(db.scalars(select(LeaveRequest.employee_id).where(
        LeaveRequest.status == "approved", LeaveRequest.duration == "full",
        LeaveRequest.start_date <= day, LeaveRequest.end_date >= day)))
    # ...and append to on_leave or absent depending on `e.id in on_leave_ids`

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
    Move your **AcmeHR API** to SQLAlchemy: add `app/database.py` with explicit pool settings and `app/models.py` for the four tables here plus `locations`, `designations` and the leave tables (exercises 1, 5 and 6), and convert every **read** endpoint (directory, profile, team, departments, leave balances, the headcount and daily attendance reports) to SQLAlchemy queries with `response_model`s. Turn on `echo=True` once and make sure no endpoint has an N+1 problem.

## Interview Questions

!!! interview "1. What is an ORM? What are its pros and cons?"
    An Object-Relational Mapper maps tables to classes and rows to objects, generating SQL for you. Pros: less boilerplate, database portability, safety from injection by default, and relationships as attributes. Cons: hidden or inefficient SQL (N+1), a learning curve, and complex reports are sometimes easier in raw SQL.

!!! interview "2. What is the difference between the engine and a session in SQLAlchemy?"
    The engine is created once per application; it holds the connection pool and the dialect for talking to the database. A session is a short-lived unit of work (typically one per request) that tracks loaded and changed objects and manages the transaction (`commit` / `rollback`).

!!! interview "What do `pool_size`, `max_overflow`, `pool_timeout` and `pool_recycle` control?"
    `pool_size` is how many connections the engine keeps open for reuse; `max_overflow` is how many extra connections it may open during a burst (closed again when returned); `pool_timeout` is how long a request waits for a free connection before a `TimeoutError`; `pool_recycle` replaces connections older than N seconds, so MySQL's `wait_timeout` or a proxy never kills one under you. Size them so `workers × (pool_size + max_overflow)` stays below MySQL's `max_connections`, and add `pool_pre_ping=True` to detect dead connections.

!!! interview "3. How do you model an employee–manager relationship in SQLAlchemy?"
    A nullable `manager_id` foreign key to the same table, plus two relationships on the class: `manager = relationship(remote_side=[id], back_populates="direct_reports")` (many-to-one) and `direct_reports = relationship(back_populates="manager")` (one-to-many). `remote_side` tells SQLAlchemy which end is the parent.

!!! interview "4. What is the N+1 query problem and how do you fix it in SQLAlchemy?"
    Loading N parent objects with one query and then lazily loading a relationship for each one, so N extra queries run. Fix it with eager loading: `selectinload()` (one extra IN query for collections) or `joinedload()` (a JOIN, good for many-to-one), or with an explicit join in the query.

!!! interview "5. What does `from_attributes=True` do in Pydantic?"
    It lets a Pydantic model be built from arbitrary objects by reading attributes (`obj.first_name`, including properties like `full_name`) instead of dict keys, which is needed to return SQLAlchemy ORM objects through `response_model`. (It was called `orm_mode` in Pydantic v1.)

!!! interview "Scenario: the org chart page takes 4 seconds and the logs show 200 SELECT statements. Diagnose and fix."
    Each employee's `direct_reports` is lazy-loaded while the tree is built, one query per person: an N+1 problem. Either load all employees in one query and build the tree in Python using `manager_id`, or use a recursive CTE in SQL. Add an index on `manager_id` (MySQL creates one for the foreign key) and a test that caps the number of queries.

## Summary

| Concept | Code |
|---------|------|
| Install | `pip install sqlalchemy mysql-connector-python` |
| URL | `mysql+mysqlconnector://user:pass@host:3306/acmehr` (from env) |
| Engine / sessions | `create_engine(URL, pool_size=5, max_overflow=10, pool_timeout=30, pool_recycle=1800, pool_pre_ping=True)` · `sessionmaker(bind=engine)` |
| Pool sizing | `workers × (pool_size + max_overflow)` < MySQL `max_connections` |
| Model | `class Employee(Base): __tablename__ = "employees"; id: Mapped[int] = mapped_column(primary_key=True)` |
| Relationship | `department: Mapped[Department] = relationship(back_populates="employees")` |
| Self-reference | `manager = relationship(remote_side=[id])` + `direct_reports = relationship(...)` |
| Several FKs | `relationship(foreign_keys=[approver_id])` |
| Dependency | `db: Annotated[Session, Depends(get_db)]` |
| Query | `db.scalars(select(Employee).where(...).order_by(...).limit(n)).all()` · `db.get(Employee, id)` |
| Response | Pydantic `ConfigDict(from_attributes=True)`, nested schemas |
| Performance | `selectinload` / `joinedload` against N+1; `echo=True` to see SQL |

**Next lesson:** [Database CRUD & Transactions](08-database-crud.md), applying for, approving and cancelling leave safely.
