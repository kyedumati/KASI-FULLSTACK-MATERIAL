---
lesson: true
category: FastAPI
short: Dependencies
api_app: app.main:app
description: FastAPI dependency injection — function, class and yield dependencies, dependency chains, router-level dependencies, header checks — plus configuration with pydantic-settings and .env files, and lifespan startup events.
---

# Dependency Injection & Settings

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain dependency injection and why FastAPI uses it
    - Write function, class and `yield` dependencies, and chain them together
    - Reuse common parameters (pagination, filters) with a single dependency
    - Protect a group of endpoints with router-level dependencies (an API-key check)
    - Load configuration from environment variables and `.env` files with **pydantic-settings**, and run code at startup with **lifespan**

**Prerequisites:** [Database CRUD & Transactions](08-database-crud.md)

## What is Dependency Injection?

You've already used it: `db: Annotated[Session, Depends(get_db)]`. Instead of each endpoint **creating** what it needs (a database session, the current user, settings), it **declares** what it needs, and FastAPI **provides** it.

```{ .python .no-run }
# Without DI: every endpoint repeats setup and cleanup
@app.get("/products")
def list_products():
    db = SessionLocal()
    try:
        ...
    finally:
        db.close()

# With DI: declare it, and FastAPI handles creation and cleanup
@app.get("/products")
def list_products(db: Annotated[Session, Depends(get_db)]):
    ...
```

!!! example "Real-life analogy: a hospital operation theatre"
    A surgeon doesn't fetch their own instruments, sterilise the room or find an anaesthetist. They say *"I need a scalpel, an anaesthetist and the patient's file"*, and the hospital system provides them, ready to use, then cleans up afterwards. Dependencies are the instruments; FastAPI is the hospital system.

| Benefit | Example |
|---------|---------|
| **No repetition** | Pagination, auth and DB sessions written once, used everywhere |
| **Guaranteed cleanup** | `yield` dependencies always close sessions and files |
| **Easy testing** | Swap the real database for a test one with `dependency_overrides` |
| **Readable endpoints** | The signature lists exactly what an endpoint needs |
| **Automatic docs** | Query params and headers from dependencies appear in `/docs` |

## The Complete Example

```text
app/
├── main.py
├── config.py          ← settings from environment / .env
├── dependencies.py    ← reusable dependencies
└── routers/
    ├── products.py    ← public endpoints
    └── admin.py       ← protected by an API key
.env                   ← local configuration (never committed)
```

```text title=".env"
APP_NAME="KSR Shop API (local)"
DEBUG=true
ADMIN_API_KEY=local-admin-key-123
MAX_PAGE_SIZE=20
```

```python title="app/config.py"
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "KSR Shop API"
    debug: bool = False
    database_url: str = "mysql+mysqlconnector://root:password@localhost:3306/ksr_shop"
    admin_api_key: str
    max_page_size: int = 50


@lru_cache
def get_settings() -> Settings:
    return Settings()
```

```python title="app/dependencies.py"
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, Header, HTTPException, Query

from app.config import Settings, get_settings

SettingsDep = Annotated[Settings, Depends(get_settings)]


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


class ProductFilters:
    def __init__(self, category: str | None = None, max_price: Annotated[float | None, Query(gt=0)] = None,
                 in_stock: bool = False):
        self.category = category
        self.max_price = max_price
        self.in_stock = in_stock

    def apply(self, products: list[dict]) -> list[dict]:
        result = products
        if self.category:
            result = [p for p in result if p["category"].lower() == self.category.lower()]
        if self.max_price is not None:
            result = [p for p in result if p["price"] <= self.max_price]
        if self.in_stock:
            result = [p for p in result if p["stock"] > 0]
        return result


def verify_admin_key(settings: SettingsDep, x_api_key: Annotated[str | None, Header()] = None) -> None:
    if x_api_key != settings.admin_api_key:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")


PaginationDep = Annotated[Pagination, Depends(pagination)]
FiltersDep = Annotated[ProductFilters, Depends()]
```

```python title="app/routers/products.py"
from fastapi import APIRouter

from app.dependencies import FiltersDep, PaginationDep

router = APIRouter(prefix="/products", tags=["Products"])

PRODUCTS = [
    {"id": 1, "name": "iPhone 15", "category": "Electronics", "price": 79999, "stock": 25},
    {"id": 3, "name": "Airdopes 141", "category": "Electronics", "price": 1299, "stock": 200},
    {"id": 5, "name": "USB-C Cable", "category": "Electronics", "price": 299, "stock": 500},
    {"id": 7, "name": "Running Shoes", "category": "Fashion", "price": 4299, "stock": 60},
    {"id": 10, "name": "Wings of Fire", "category": "Books", "price": 350, "stock": 0},
    {"id": 14, "name": "Yoga Mat", "category": "Sports", "price": 999, "stock": 0},
]


@router.get("")
def list_products(filters: FiltersDep, paging: PaginationDep):
    matched = filters.apply(PRODUCTS)
    items = matched[paging.offset:paging.offset + paging.size]
    return {"total": len(matched), "page": paging.page, "size": paging.size, "items": [p["name"] for p in items]}
```

```python title="app/routers/admin.py"
from fastapi import APIRouter, Depends

from app.dependencies import SettingsDep, verify_admin_key
from app.routers.products import PRODUCTS

router = APIRouter(prefix="/admin", tags=["Admin"], dependencies=[Depends(verify_admin_key)])


@router.get("/stats")
def stats():
    return {"products": len(PRODUCTS), "out_of_stock": sum(1 for p in PRODUCTS if p["stock"] == 0)}


@router.get("/config")
def show_config(settings: SettingsDep):
    return {"app_name": settings.app_name, "debug": settings.debug, "max_page_size": settings.max_page_size}
```

```python title="app/main.py"
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.config import get_settings
from app.routers import admin, products

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    print(f"Starting {settings.app_name} (debug={settings.debug})")
    yield
    print("Shutting down")


app = FastAPI(title=settings.app_name, debug=settings.debug, lifespan=lifespan)
app.include_router(products.router)
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
def list_products(filters: FiltersDep, paging: PaginationDep):
    ...
```

`list_products` never mentions `page` or `size`, yet they appear as query parameters in `/docs`, because they belong to the `pagination` dependency. Any endpoint that needs paging just adds `paging: PaginationDep`.

```bash
curl -s "http://127.0.0.1:8000/products?page=2&size=2"
```

```{ .text .output }
{
  "total": 6,
  "page": 2,
  "size": 2,
  "items": ["USB-C Cable", "Running Shoes"]
}
```

The dependency enforces a rule from the settings (`MAX_PAGE_SIZE=20` in `.env`):

```bash
curl -s -w "\nHTTP %{http_code}\n" "http://127.0.0.1:8000/products?size=100"
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
class ProductFilters:
    def __init__(self, category: str | None = None, max_price: float | None = None, in_stock: bool = False):
        ...

FiltersDep = Annotated[ProductFilters, Depends()]
```

Classes are handy when the dependency also has **behaviour**, here `filters.apply(products)`:

```bash
curl -s "http://127.0.0.1:8000/products?category=electronics&max_price=2000"
```

```{ .text .output }
{
  "total": 2,
  "page": 1,
  "size": 5,
  "items": ["Airdopes 141", "USB-C Cable"]
}
```

```bash
curl -s "http://127.0.0.1:8000/products?in_stock=true&size=10"
```

```{ .text .output }
{
  "total": 4,
  "page": 1,
  "size": 10,
  "items": [
    "iPhone 15",
    "Airdopes 141",
    "USB-C Cable",
    "Running Shoes"
  ]
}
```

## Dependency Chains and yield

Dependencies can depend on other dependencies. FastAPI builds the whole tree for each request and calls each dependency **only once per request**, even if several parts need it:

```mermaid
flowchart TD
  E["list_products endpoint"] --> P["pagination"]
  E --> F["ProductFilters"]
  P --> S["get_settings"]
  A["admin endpoints"] --> V["verify_admin_key"]
  V --> S
  V --> H["X-API-Key header"]
```

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
  "products": 6,
  "out_of_stock": 2
}
```

| Where you put `Depends(...)` | Applies to |
|------------------------------|------------|
| Endpoint parameter | That endpoint; you get the return value |
| `@router.get(..., dependencies=[...])` | That endpoint; return value ignored |
| `APIRouter(dependencies=[...])` | Every endpoint in the router |
| `FastAPI(dependencies=[...])` | The whole application |

!!! realworld "In Real Projects"
    Dependencies are where cross-cutting concerns live: `get_db`, `get_current_user` (next lesson), `require_role("admin")`, rate limiting, tenant selection in multi-company SaaS apps, and feature flags. Endpoints stay focused on their job while dependencies handle the plumbing.

## Settings with pydantic-settings

Hard-coding passwords, keys and URLs in code is dangerous (they leak through Git) and inflexible (production needs different values). The standard solution is **environment variables**, read through a typed `Settings` class:

```{ .python .no-run }
class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")

    app_name: str = "KSR Shop API"
    debug: bool = False
    admin_api_key: str              # required: no default
    max_page_size: int = 50
```

Values are looked up in this order, highest priority first:

1. **Real environment variables** (set by the server, Docker or the terminal)
2. The **`.env`** file
3. The **default** in the class

Names match case-insensitively: the field `admin_api_key` is read from `ADMIN_API_KEY`. Values are converted and validated by type (`"true"` becomes `True`, `"20"` becomes `20`).

```bash
curl -s -H "X-API-Key: local-admin-key-123" http://127.0.0.1:8000/admin/config
```

```{ .text .output }
{
  "app_name": "KSR Shop API (local)",
  "debug": true,
  "max_page_size": 20
}
```

These came from `.env`, overriding the class defaults. A real environment variable beats `.env`:

```bash
MAX_PAGE_SIZE=10 python -c "from app.config import Settings; s = Settings(); print(s.app_name, '|', s.max_page_size)"
```

```{ .text .output }
KSR Shop API (local) | 10
```

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
    APP_NAME="KSR Shop API"
    DEBUG=false
    DATABASE_URL=mysql+mysqlconnector://USER:PASSWORD@localhost:3306/ksr_shop
    ADMIN_API_KEY=change-me
    MAX_PAGE_SIZE=50
    ```

## Lifespan: Startup and Shutdown Code

Code that should run **once** when the app starts (connect to services, load an ML model, check the database) and once when it stops goes in a **lifespan** function:

```{ .python .no-run }
@asynccontextmanager
async def lifespan(app: FastAPI):
    print(f"Starting {settings.app_name}")    # startup
    yield                                      # the app serves requests here
    print("Shutting down")                     # shutdown

app = FastAPI(lifespan=lifespan)
```

When you run `fastapi dev app/main.py`, you'll see `Starting KSR Shop API (local) (debug=True)` in the logs before `Application startup complete`.

!!! realworld "In Real Projects"
    AI APIs load large models in `lifespan` so the first user doesn't wait 30 seconds, and many apps check database connectivity there so a misconfigured deployment fails immediately rather than on the first request. (Older code uses `@app.on_event("startup")`, which is deprecated in favour of `lifespan`.)

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `Depends(get_db())` with parentheses | Called once at import time, shared by everyone | `Depends(get_db)`: pass the function |
| Forgetting `Depends` (`db: Session`) | FastAPI treats it as a body/query → errors | `Annotated[Session, Depends(get_db)]` |
| Creating `Settings()` everywhere | `.env` re-read constantly; inconsistent values | `@lru_cache def get_settings()` |
| `.env` in Git | Secrets leaked | `.gitignore` + `.env.example` |
| Expecting `.env` to beat a real env var | Value "ignored" | Real environment variables have higher priority |
| Underscore vs hyphen confusion in headers | Header never read | `x_api_key` ↔ `X-API-Key`, automatically |
| Heavy work in every request instead of at startup | Slow responses | Load once in `lifespan` |
| `@app.on_event("startup")` | Deprecation warning | Use `lifespan` |

## Practice Exercises

**Easy**

1. Add a `sort: Literal["name", "price"] = "name"` option to `ProductFilters` and apply it in `apply()`.
2. Add `SUPPORT_EMAIL` to `Settings` and `.env`, and return it from `GET /contact`.
3. Call `/admin/config` with a wrong key, the right key, and no key, and note the responses.

**Medium**

4. Write a `common_headers` dependency that reads an optional `X-Request-ID` header and returns it (or a generated `uuid4` if missing), and include it in the `/products` response.
5. Make the app refuse to start when `DEBUG=true` **and** `ADMIN_API_KEY` is shorter than 16 characters (hint: a `model_validator` in `Settings`).
6. Add a `yield` dependency that records how long each request to `/products` took and prints it after the response.

**Challenge**

7. Write a dependency factory `require_plan(minimum: str)` that returns a dependency checking an `X-Plan` header (`free` < `pro` < `enterprise`) and raises **403** if the caller's plan is too low. Use it to protect a `GET /products/export` endpoint for `pro` and above.

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    import time
    import uuid
    from typing import Annotated, Literal
    from fastapi import Depends, Header, HTTPException
    from pydantic import model_validator

    # 1 (in ProductFilters.__init__): sort: Literal["name", "price"] = "name"
    #   in apply(): result = sorted(result, key=lambda p: p[self.sort])

    # 4
    def request_id(x_request_id: Annotated[str | None, Header()] = None) -> str:
        return x_request_id or str(uuid.uuid4())

    # 5 (inside Settings)
    @model_validator(mode="after")
    def strong_key(self):
        if self.debug and len(self.admin_api_key) < 16:
            raise ValueError("ADMIN_API_KEY must be at least 16 characters")
        return self

    # 6
    def timer():
        start = time.perf_counter()
        yield
        print(f"/products took {(time.perf_counter() - start) * 1000:.1f} ms")

    # @router.get("", dependencies=[Depends(timer)])

    # 7
    PLANS = {"free": 0, "pro": 1, "enterprise": 2}

    def require_plan(minimum: str):
        def checker(x_plan: Annotated[str, Header()] = "free"):
            if PLANS.get(x_plan, -1) < PLANS[minimum]:
                raise HTTPException(status_code=403, detail=f"Requires the {minimum} plan or higher")
        return checker

    @router.get("/export", dependencies=[Depends(require_plan("pro"))])
    def export_products():
        return PRODUCTS
    ```

!!! note "Mini Assignment"
    Add `app/config.py` to your **KSR Shop API** with `Settings` for `DATABASE_URL`, `APP_NAME`, `DEBUG`, `ADMIN_API_KEY` and `MAX_PAGE_SIZE`; make `database.py` use `get_settings().database_url`; replace every repeated `page`/`size` pair with a `PaginationDep`; protect an `/admin` router with the API-key dependency; and commit a `.env.example` (but not `.env`).

## Interview Questions

!!! interview "1. What is dependency injection in FastAPI?"
    A mechanism where endpoints declare what they need (`Depends(...)`) and FastAPI resolves and provides it per request: database sessions, current user, settings, parsed parameters. It reduces repetition, centralises cross-cutting logic, guarantees cleanup with `yield` dependencies, and makes testing easy via `dependency_overrides`.

!!! interview "2. What is the difference between a normal dependency and one using `yield`?"
    A normal dependency returns a value. A `yield` dependency runs setup code before the endpoint, yields the value, and runs teardown code (in `finally`) after the response is sent, even on exceptions, which is ideal for database sessions and other resources.

!!! interview "3. How do you apply a dependency to all endpoints of a router?"
    Pass it in the router's `dependencies` list: `APIRouter(dependencies=[Depends(verify_key)])`. You can do the same per endpoint in the decorator, or globally in `FastAPI(dependencies=[...])`. These are typically checks whose return value isn't needed.

!!! interview "4. How do you manage configuration and secrets in a FastAPI app?"
    With a `pydantic-settings` `BaseSettings` class that reads typed, validated values from environment variables and an optional `.env` file, cached with `@lru_cache` and injected via `Depends(get_settings)`. Secrets live only in the environment or a secrets manager, never in Git; commit a `.env.example` instead.

!!! interview "5. What is the lifespan function used for?"
    Running code once at application startup (before the first request) and at shutdown, for example creating connection pools, loading ML models, warming caches and closing resources. It replaces the deprecated `@app.on_event("startup"/"shutdown")`.

!!! interview "Scenario: the API works locally but in production it connects to the wrong database. How would you investigate?"
    Check which value `Settings` actually loaded. A real environment variable overrides `.env`, so look for a leftover `DATABASE_URL` in the server or container environment, or a `.env` file accidentally copied into the image. Log (without secrets) the database host at startup in `lifespan` so mismatches are visible immediately.

## Summary

| Concept | Code |
|---------|------|
| Dependency | `def pagination(page: int = 1, size: int = 5) -> Pagination: ...` |
| Use it | `paging: Annotated[Pagination, Depends(pagination)]` |
| Class dependency | `filters: Annotated[ProductFilters, Depends()]` |
| Cleanup | `yield` inside `try/finally` |
| Header | `x_api_key: Annotated[str \| None, Header()] = None` |
| Group protection | `APIRouter(dependencies=[Depends(verify_admin_key)])` |
| Settings | `class Settings(BaseSettings)` + `SettingsConfigDict(env_file=".env")` |
| Cache | `@lru_cache def get_settings()` |
| Priority | Environment variable > `.env` > default |
| Startup / shutdown | `lifespan` async context manager |

**Next lesson:** [Authentication with JWT](10-authentication-jwt.md), with password hashing, login, tokens and role-based access.
