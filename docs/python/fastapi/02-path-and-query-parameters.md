---
lesson: true
category: FastAPI
short: Parameters
description: Building the AcmeHR employee directory from URL input with path parameters and query parameters, automatic type conversion, Enum choices, dates, and validation with Path and Query.
---

# Path & Query Parameters

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Read values from the URL path, like `/employees/E-1042`
    - Read optional filters from the query string, like `?department=Engineering&location=pune`
    - Let type hints convert and validate input automatically, including dates
    - Restrict values with `Enum`, and add rules with `Path()` and `Query()`
    - Avoid route-order bugs and build a filtered, paginated directory endpoint

**Prerequisites:** [Introduction to FastAPI](01-introduction-to-fastapi.md)

## Two Ways to Send Input in a URL

```text
http://127.0.0.1:8000/employees/E-1042/tenure?as_of=2026-10-05
                     └───────┬───────┘        └──────┬───────┘
                       path parameter         query parameter
```

| | Path parameter | Query parameter |
|---|---|---|
| Looks like | `/employees/E-1042` | `/employees?location=pune` |
| Used for | **Identifying** a specific resource | **Filtering, sorting, paging, options** |
| Required? | Always | Usually optional (with defaults) |
| Example | `/departments/2`, `/leave-requests/12` | `?page=2`, `?status=on_notice`, `?q=rao` |

!!! example "Real-life analogy: the office reception"
    *"I'm here to meet employee E-1042"* is a **path parameter**: it identifies one exact person. *"Who in Engineering works from the Pune office?"* is a **query**: filters on a list.

The BRD's first module is the **employee directory**: *"Employees can search colleagues by name, department or location and view their work profile."* We'll build it from a small in-memory list for now. In lesson 06 the same endpoints will read the `acmehr` database in MySQL.

```python title="main.py"
from datetime import date
from enum import Enum
from typing import Annotated

from fastapi import FastAPI, HTTPException, Path, Query

app = FastAPI(title="AcmeHR API")

EMPLOYEES = [
    {"code": "E-1001", "name": "Lakshmi Menon", "department": "Leadership",  "designation": "Chief Executive Officer",  "location": "hyderabad", "status": "active",    "hire_date": "2018-04-01"},
    {"code": "E-1002", "name": "Karthik Menon", "department": "Engineering", "designation": "Engineering Manager",      "location": "hyderabad", "status": "active",    "hire_date": "2019-06-15"},
    {"code": "E-1003", "name": "Neha Kapoor",   "department": "Product",     "designation": "Product Manager",          "location": "bengaluru", "status": "active",    "hire_date": "2019-09-01"},
    {"code": "E-1042", "name": "Ananya Rao",    "department": "Engineering", "designation": "Senior Software Engineer", "location": "hyderabad", "status": "active",    "hire_date": "2021-07-12"},
    {"code": "E-1044", "name": "Fatima Khan",   "department": "Product",     "designation": "Product Designer",         "location": "bengaluru", "status": "active",    "hire_date": "2021-10-18"},
    {"code": "E-1046", "name": "Priya Nair",    "department": "Engineering", "designation": "Software Engineer",        "location": "hyderabad", "status": "active",    "hire_date": "2023-02-13"},
    {"code": "E-1047", "name": "Vikram Joshi",  "department": "Engineering", "designation": "DevOps Engineer",          "location": "pune",      "status": "active",    "hire_date": "2020-08-24"},
    {"code": "E-1053", "name": "Manoj Pillai",  "department": "Finance",     "designation": "Accountant",               "location": "hyderabad", "status": "on_notice", "hire_date": "2022-09-19"},
    {"code": "E-1054", "name": "Ritu Kapoor",   "department": "Product",     "designation": "Product Designer",         "location": "bengaluru", "status": "exited",    "hire_date": "2020-05-11"},
]

DEPARTMENTS = [
    {"id": 1, "name": "Leadership"},
    {"id": 2, "name": "Engineering"},
    {"id": 3, "name": "Product"},
    {"id": 4, "name": "Finance"},
]

EmployeeCode = Annotated[str, Path(pattern=r"^E-\d{4}$", description="Employee code, like E-1042")]


class Location(str, Enum):
    hyderabad = "hyderabad"
    bengaluru = "bengaluru"
    pune = "pune"


class Status(str, Enum):
    active = "active"
    on_notice = "on_notice"
    exited = "exited"


@app.get("/employees/newest")
def newest_employee():
    active = [e for e in EMPLOYEES if e["status"] == "active"]
    return max(active, key=lambda e: e["hire_date"])


@app.get("/employees/{code}")
def get_employee(code: EmployeeCode):
    for employee in EMPLOYEES:
        if employee["code"] == code:
            return employee
    raise HTTPException(status_code=404, detail=f"Employee {code} not found")


@app.get("/departments/{department_id}")
def get_department(department_id: int):
    for dept in DEPARTMENTS:
        if dept["id"] == department_id:
            members = [e["name"] for e in EMPLOYEES if e["department"] == dept["name"] and e["status"] != "exited"]
            return {**dept, "headcount": len(members), "members": members}
    raise HTTPException(status_code=404, detail=f"Department {department_id} not found")


@app.get("/locations/{location}/employees")
def employees_at_location(location: Location):
    return [e["name"] for e in EMPLOYEES if e["location"] == location.value and e["status"] == "active"]


@app.get("/employees")
def list_employees(
    q: Annotated[str | None, Query(min_length=2, max_length=50, description="Search in the name")] = None,
    department: str | None = None,
    location: Location | None = None,
    status: Status = Status.active,
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=50)] = 3,
):
    results = [e for e in EMPLOYEES if e["status"] == status.value]
    if q:
        results = [e for e in results if q.lower() in e["name"].lower()]
    if department:
        results = [e for e in results if e["department"].lower() == department.lower()]
    if location:
        results = [e for e in results if e["location"] == location.value]
    start = (page - 1) * size
    return {"total": len(results), "page": page, "size": size, "items": results[start:start + size]}


@app.get("/employees/{code}/tenure")
def employee_tenure(code: EmployeeCode, as_of: date | None = None):
    employee = get_employee(code)
    as_of = as_of or date.today()
    hired = date.fromisoformat(employee["hire_date"])
    if as_of < hired:
        raise HTTPException(status_code=400, detail=f"{code} joined on {hired}")
    years = as_of.year - hired.year - ((as_of.month, as_of.day) < (hired.month, hired.day))
    return {"employee": employee["name"], "hire_date": hired, "as_of": as_of,
            "years": years, "days": (as_of - hired).days}
```

We'll go through this file piece by piece. Run it with `fastapi dev main.py` and follow along.

## Path Parameters

A path parameter is a variable part of the URL, written in curly braces: `/employees/{code}`. FastAPI passes it to the function argument with the **same name**:

```{ .python .no-run }
@app.get("/employees/{code}")
def get_employee(code: EmployeeCode):
    ...
```

```bash
curl -s http://127.0.0.1:8000/employees/E-1042
```

```{ .text .output }
{
  "code": "E-1042",
  "name": "Ananya Rao",
  "department": "Engineering",
  "designation": "Senior Software Engineer",
  "location": "hyderabad",
  "status": "active",
  "hire_date": "2021-07-12"
}
```

### Type conversion and validation

URLs are always text. For `/departments/{department_id}` we wrote `department_id: int`, so FastAPI **converts** `"2"` to the integer `2`:

```bash
curl -s http://127.0.0.1:8000/departments/2
```

```{ .text .output }
{
  "id": 2,
  "name": "Engineering",
  "headcount": 4,
  "members": [
    "Karthik Menon",
    "Ananya Rao",
    "Priya Nair",
    "Vikram Joshi"
  ]
}
```

If the value can't be converted, FastAPI rejects the request with **422 Unprocessable Content** before your code even runs:

```bash
curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1:8000/departments/engineering
```

```{ .text .output }
{
  "detail": [
    {
      "type": "int_parsing",
      "loc": ["path", "department_id"],
      "msg": "Input should be a valid integer, unable to parse string as an integer",
      "input": "engineering"
    }
  ]
}
HTTP 422
```

The error tells the caller exactly what's wrong: in the **path**, the parameter **department_id**, should be a **valid integer**, and you gave `"engineering"`. You wrote zero validation code.

### A pattern for employee codes

Every Acme employee code looks like `E-` followed by four digits. Instead of checking that by hand, the `EmployeeCode` type adds a **regular expression** rule with `Path(pattern=...)`:

```{ .python .no-run }
EmployeeCode = Annotated[str, Path(pattern=r"^E-\d{4}$", description="Employee code, like E-1042")]
```

Defining it once as a named type means every endpoint that takes a code (`/employees/{code}`, `/employees/{code}/tenure`, and many more later) gets the same rule and the same documentation. A malformed code never reaches your function:

```bash
curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1:8000/employees/E-42
```

```{ .text .output }
{
  "detail": [
    {
      "type": "string_pattern_mismatch",
      "loc": ["path", "code"],
      "msg": "String should match pattern '^E-\\d{4}$'",
      "input": "E-42",
      "ctx": {
        "pattern": "^E-\\d{4}$"
      }
    }
  ]
}
HTTP 422
```

A well-formed code that doesn't exist reaches your function and gets the **404** we raised:

```bash
curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1:8000/employees/E-9999
```

```{ .text .output }
{
  "detail": "Employee E-9999 not found"
}
HTTP 404
```

`raise HTTPException(status_code=404, detail=...)` stops the function and sends an error response. You'll learn it properly in [lesson 04](04-responses-and-errors.md).

!!! tip "422 or 404?"
    **422** means "your request is malformed" (`E-42` can never be an employee code). **404** means "your request is fine, but that employee doesn't exist" (`E-9999`). A frontend shows different messages for each, so the difference matters.

### Route order matters

`/employees/newest` is declared **before** `/employees/{code}`. FastAPI checks routes in order, top to bottom:

```bash
curl -s http://127.0.0.1:8000/employees/newest
```

```{ .text .output }
{
  "code": "E-1046",
  "name": "Priya Nair",
  "department": "Engineering",
  "designation": "Software Engineer",
  "location": "hyderabad",
  "status": "active",
  "hire_date": "2023-02-13"
}
```

!!! mistake "Common Mistake: a fixed path after a parameter path"
    If `/employees/{code}` came first, a request to `/employees/newest` would match it with `code = "newest"`, fail the pattern, and return **422**. **Always declare fixed paths before parameter paths** that could swallow them.

### Choices with Enum

Acme has exactly three offices. To accept only those values, use an `Enum`:

```{ .python .no-run }
class Location(str, Enum):
    hyderabad = "hyderabad"
    bengaluru = "bengaluru"
    pune = "pune"

@app.get("/locations/{location}/employees")
def employees_at_location(location: Location):
    ...
```

```bash
curl -s http://127.0.0.1:8000/locations/bengaluru/employees
```

```{ .text .output }
["Neha Kapoor", "Fatima Khan"]
```

```bash
curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1:8000/locations/chennai/employees
```

```{ .text .output }
{
  "detail": [
    {
      "type": "enum",
      "loc": ["path", "location"],
      "msg": "Input should be 'hyderabad', 'bengaluru' or 'pune'",
      "input": "chennai",
      "ctx": {
        "expected": "'hyderabad', 'bengaluru' or 'pune'"
      }
    }
  ]
}
HTTP 422
```

The `/docs` page now shows a **dropdown** with the three valid values. When Acme opens a Chennai office, you add one line to the `Enum`.

## Query Parameters

Any function argument that is **not** in the path is treated as a **query parameter**. Give it a default value to make it optional:

```{ .python .no-run }
@app.get("/employees")
def list_employees(q: str | None = None, department: str | None = None, status: Status = Status.active, ...):
```

| Declaration | Meaning |
|-------------|---------|
| `department: str` | Required query parameter (422 if missing) |
| `department: str = "Engineering"` | Optional, defaults to `"Engineering"` |
| `department: str \| None = None` | Optional, `None` when not given |
| `status: Status = Status.active` | Optional, only the Enum's values allowed |
| `include_contacts: bool = False` | `true`, `1`, `yes`, `on` all become `True` |

The directory, page 1, 3 per page. Only **active** employees appear by default: Manoj (on notice) and Ritu (exited) are filtered out, as the BRD asks:

```bash
curl -s "http://127.0.0.1:8000/employees"
```

```{ .text .output }
{
  "total": 7,
  "page": 1,
  "size": 3,
  "items": [
    {
      "code": "E-1001",
      "name": "Lakshmi Menon",
      "department": "Leadership",
      "designation": "Chief Executive Officer",
      "location": "hyderabad",
      "status": "active",
      "hire_date": "2018-04-01"
    },
    {
      "code": "E-1002",
      "name": "Karthik Menon",
      "department": "Engineering",
      "designation": "Engineering Manager",
      "location": "hyderabad",
      "status": "active",
      "hire_date": "2019-06-15"
    },
    {
      "code": "E-1003",
      "name": "Neha Kapoor",
      "department": "Product",
      "designation": "Product Manager",
      "location": "bengaluru",
      "status": "active",
      "hire_date": "2019-09-01"
    }
  ]
}
```

Filters combine with `&`:

```bash
curl -s "http://127.0.0.1:8000/employees?department=engineering&location=pune"
```

```{ .text .output }
{
  "total": 1,
  "page": 1,
  "size": 3,
  "items": [
    {
      "code": "E-1047",
      "name": "Vikram Joshi",
      "department": "Engineering",
      "designation": "DevOps Engineer",
      "location": "pune",
      "status": "active",
      "hire_date": "2020-08-24"
    }
  ]
}
```

```bash
curl -s "http://127.0.0.1:8000/employees?q=kapoor&status=exited"
```

```{ .text .output }
{
  "total": 1,
  "page": 1,
  "size": 3,
  "items": [
    {
      "code": "E-1054",
      "name": "Ritu Kapoor",
      "department": "Product",
      "designation": "Product Designer",
      "location": "bengaluru",
      "status": "exited",
      "hire_date": "2020-05-11"
    }
  ]
}
```

Page 3 of the directory:

```bash
curl -s "http://127.0.0.1:8000/employees?page=3&size=3"
```

```{ .text .output }
{
  "total": 7,
  "page": 3,
  "size": 3,
  "items": [
    {
      "code": "E-1047",
      "name": "Vikram Joshi",
      "department": "Engineering",
      "designation": "DevOps Engineer",
      "location": "pune",
      "status": "active",
      "hire_date": "2020-08-24"
    }
  ]
}
```

!!! tip "Quote URLs that contain `&`"
    In the terminal, `&` means "run in background". Always wrap URLs with query strings in quotes: `curl -s "http://...?a=1&b=2"`.

!!! realworld "In Real Projects"
    Every directory, search page and admin table in a real HR system is a `GET` endpoint with query parameters: `?q=rao&department=Engineering&location=pune&sort=name&page=2&size=25`. The frontend builds the query string from the filters the user clicks, and the backend turns it into SQL `WHERE`, `ORDER BY` and `LIMIT/OFFSET`, exactly as you learned in the MySQL module.

### Dates in the query string

Type hints aren't limited to `int` and `str`. With `as_of: date | None = None`, FastAPI parses an ISO date (`YYYY-MM-DD`) into a real `datetime.date`, and puts dates back into JSON as text:

```bash
curl -s "http://127.0.0.1:8000/employees/E-1042/tenure?as_of=2026-10-05"
```

```{ .text .output }
{
  "employee": "Ananya Rao",
  "hire_date": "2021-07-12",
  "as_of": "2026-10-05",
  "years": 5,
  "days": 1911
}
```

Your function did date arithmetic (`as_of - hired`) without parsing anything. Business rules that the type can't express stay in your code, like "the date can't be before the employee joined":

```bash
curl -s -w "\nHTTP %{http_code}\n" "http://127.0.0.1:8000/employees/E-1046/tenure?as_of=2022-01-01"
```

```{ .text .output }
{
  "detail": "E-1046 joined on 2023-02-13"
}
HTTP 400
```

## Validation with Path() and Query()

Type hints check the **type**. `Path()` and `Query()` add **rules** and **documentation**, written with `Annotated`:

```{ .python .no-run }
from typing import Annotated
from fastapi import Path, Query

q:    Annotated[str | None, Query(min_length=2, max_length=50, description="Search in the name")] = None
size: Annotated[int, Query(ge=1, le=50)] = 3
code: Annotated[str, Path(pattern=r"^E-\d{4}$")]
```

| Rule | Meaning | Works on |
|------|---------|----------|
| `gt`, `ge` | Greater than / greater or equal | Numbers |
| `lt`, `le` | Less than / less or equal | Numbers |
| `min_length`, `max_length` | Length limits | Strings |
| `pattern` | Must match a regular expression | Strings |
| `description`, `examples` | Shown in `/docs` | Any |
| `alias` | Different name in the URL (e.g. `as-of`) | Any |

A page size of 100 breaks the `le=50` rule:

```bash
curl -s -w "\nHTTP %{http_code}\n" "http://127.0.0.1:8000/employees?size=100"
```

```{ .text .output }
{
  "detail": [
    {
      "type": "less_than_equal",
      "loc": ["query", "size"],
      "msg": "Input should be less than or equal to 50",
      "input": "100",
      "ctx": {
        "le": 50
      }
    }
  ]
}
HTTP 422
```

When several things are wrong, all of them are reported:

```bash
curl -s -w "\nHTTP %{http_code}\n" "http://127.0.0.1:8000/employees/E-42/tenure?as_of=2026-13-01"
```

```{ .text .output }
{
  "detail": [
    {
      "type": "string_pattern_mismatch",
      "loc": ["path", "code"],
      "msg": "String should match pattern '^E-\\d{4}$'",
      "input": "E-42",
      "ctx": {
        "pattern": "^E-\\d{4}$"
      }
    },
    {
      "type": "date_from_datetime_parsing",
      "loc": ["query", "as_of"],
      "msg": "Input should be a valid date or datetime, month value is outside expected range of 1-12",
      "input": "2026-13-01",
      "ctx": {
        "error": "month value is outside expected range of 1-12"
      }
    }
  ]
}
HTTP 422
```

Both problems are reported **at once** (a bad code in the path *and* a month 13 in the query), which makes life easy for the frontend developer.

!!! tip "Why limit page size?"
    Without `le=50`, anyone could request `?size=1000000` and make your server load the whole employee table into memory. Validation isn't just about correctness; it protects your API from accidental or deliberate overload.

### List query parameters

To accept several values for the same name (`?department=Engineering&department=Product`), declare a list with `Query()`:

```{ .python .no-run }
@app.get("/employees/by-departments")
def by_departments(department: Annotated[list[str], Query()] = []):
    return [e["name"] for e in EMPLOYEES if e["department"] in department]
```

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Fixed route declared after `/{code}` | `422` "should match pattern" for `/employees/newest` | Declare fixed paths first |
| Name in path ≠ function argument | It's treated as a query param; path value ignored | `/{department_id}` ↔ `department_id` |
| No type hint on a numeric path param | Arrives as `str`; `==` with ints never matches | `department_id: int` |
| Pattern without `^` and `$` | `XE-1042abc` passes, because the pattern only has to appear *somewhere* | Anchor it: `^E-\d{4}$` |
| Unquoted URL with `&` in the terminal | Only the first parameter is sent | Quote the URL |
| Required query param by accident (`department: str`) | `422` "Field required" when omitted | Give it a default (`= None`) |
| Mutable default for lists without `Query()` | Treated as a request body | `Annotated[list[str], Query()]` |
| No limit on `size` | Huge responses, slow server | `Query(le=50)` |

## Practice Exercises

Use the `main.py` from this lesson.

**Easy**

1. Add a placeholder `GET /employees/{code}/manager-chain` that returns `{"code": code, "chain": []}`, using the `EmployeeCode` type. Check that `/employees/X1/manager-chain` returns 422.
2. Add a `sort` query parameter to `GET /employees` that accepts `name` or `hire_date` (use an `Enum`).
3. Call `GET /departments/abc` and read the 422 error. Which part tells you the location of the problem?

**Medium**

4. Add `order: Literal["asc", "desc"] = "asc"` (from `typing import Literal`) to control the sort direction.
5. Add `GET /search?q=...` that requires `q` with at least 3 characters and searches the name **and** the designation.
6. Add `joined_after: date | None = None` to `GET /employees` to list only employees hired after that date. Who joined after 1 January 2021?

**Challenge**

7. Add `GET /anniversaries?month=10` that lists active employees whose work anniversary falls in that month, with the number of years they'll complete in 2026. Validate `month` with `Query(ge=1, le=12)`. Hint: `date.fromisoformat(e["hire_date"]).month`.

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    from typing import Literal

    class SortField(str, Enum):
        name = "name"
        hire_date = "hire_date"

    # 1 (order doesn't matter here: the extra /manager-chain segment can't match /employees/{code})
    @app.get("/employees/{code}/manager-chain")
    def manager_chain(code: EmployeeCode):
        return {"code": code, "chain": []}

    # 2 + 4 + 6 (add to list_employees' parameters and before pagination)
    #   sort: SortField = SortField.name,
    #   order: Literal["asc", "desc"] = "asc",
    #   joined_after: date | None = None,
    #
    #   if joined_after:
    #       results = [e for e in results if date.fromisoformat(e["hire_date"]) > joined_after]
    #   results.sort(key=lambda e: e[sort.value], reverse=(order == "desc"))
    #
    # 6: Ananya, Fatima and Priya (Manoj too, with status=on_notice)

    # 5
    @app.get("/search")
    def search(q: Annotated[str, Query(min_length=3)]):
        q = q.lower()
        return [e for e in EMPLOYEES if q in e["name"].lower() or q in e["designation"].lower()]

    # 7
    @app.get("/anniversaries")
    def anniversaries(month: Annotated[int, Query(ge=1, le=12)]):
        result = []
        for e in EMPLOYEES:
            hired = date.fromisoformat(e["hire_date"])
            if e["status"] == "active" and hired.month == month:
                result.append({"name": e["name"], "date": hired.replace(year=2026), "years": 2026 - hired.year})
        return result
    ```

!!! note "Mini Assignment"
    In your **AcmeHR API** repo, add an in-memory `LEAVE_TYPES` list (CL Casual 12 days, SL Sick 12, EL Earned 15 with carry forward, LOP Loss of pay with no limit) and build: `GET /leave-types` with a `paid_only: bool = False` filter; `GET /leave-types/{code}` that accepts only the codes in an `Enum` and returns 422 for anything else; and `GET /holidays?month=10` from a list of Acme's 2026 holidays (Republic Day 26 Jan, Holi 4 Mar, Independence Day 15 Aug, Gandhi Jayanti 2 Oct, Dussehra 20 Oct, Diwali 9 Nov, Christmas 25 Dec). Document every parameter so `/docs` is self-explanatory.

## Interview Questions

!!! interview "1. What is the difference between path and query parameters?"
    Path parameters are part of the URL path (`/employees/E-1042`) and identify a specific resource; they are required. Query parameters come after `?` (`?department=Engineering&page=2`) and are used for optional filtering, sorting, pagination and flags.

!!! interview "2. How does FastAPI validate parameters?"
    From type hints: values are converted to the declared type (int, float, bool, date, Enum…) and invalid values produce a 422 response describing the location and reason. Extra rules (`gt`, `le`, `min_length`, `pattern`) are declared with `Path()` / `Query()`, usually via `Annotated`.

!!! interview "3. Why does route order matter in FastAPI?"
    Routes are matched in the order they're declared. A parameterised route like `/employees/{code}` would capture `/employees/newest` if it were declared first. Fixed paths must be declared before parameterised paths that could match them.

!!! interview "4. How do you make a query parameter optional?"
    Give it a default value: `department: str | None = None` or `page: int = 1`. Without a default, it's required.

!!! interview "5. What status code does FastAPI return for invalid input, and what does the body contain?"
    422 Unprocessable Content (also called Unprocessable Entity). The body has a `detail` list; each item contains `type`, `loc` (where: path, query, body plus the field name), `msg`, `input` and sometimes `ctx` with the rule's limits.

!!! interview "Scenario: the HR team pastes employee codes into the URL with spaces and lowercase, like ` e-1042`. What do you do?"
    Decide whether to be strict or forgiving. Strict: keep the `^E-\d{4}$` pattern and let the frontend trim and upper-case the input, so the API contract stays simple. Forgiving: accept a looser string, normalise it (`code.strip().upper()`) in the function, then validate. Either way, document the format in `/docs` and never let an unvalidated value reach a database query.

## Summary

| Concept | Syntax |
|---------|--------|
| Path parameter | `@app.get("/employees/{code}")` + `def f(code: str)` |
| Query parameter | Any other argument: `department: str \| None = None` |
| Type conversion | Type hints convert (`int`, `date`, `bool`…); bad input returns 422 |
| Fixed choices | `class Location(str, Enum)` |
| Rules | `Annotated[int, Query(ge=1, le=50)]`, `Annotated[str, Path(pattern=...)]` |
| Reusable rule | `EmployeeCode = Annotated[str, Path(pattern=r"^E-\d{4}$")]` |
| Lists | `Annotated[list[str], Query()]` |
| Route order | Fixed paths before `/{param}` paths |
| Pagination | `page` + `size` with limits → slice / `LIMIT OFFSET` |

**Next lesson:** [Request Bodies & Pydantic](03-request-bodies-and-pydantic.md), receiving and validating new employees and leave requests.
