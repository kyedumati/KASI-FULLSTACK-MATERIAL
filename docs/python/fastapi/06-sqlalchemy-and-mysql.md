---
lesson: true
category: FastAPI
short: SQLAlchemy
api_app: app.main:app
api_db: true
description: Connecting FastAPI to MySQL with SQLAlchemy 2.0 — engine, sessions, ORM models mapped to the ksr_shop tables, the get_db dependency, select queries, relationships and nested responses.
---

# SQLAlchemy & MySQL

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain what an ORM is and how SQLAlchemy maps tables to Python classes
    - Connect FastAPI to MySQL with an engine, sessions and a `get_db` dependency
    - Write SQLAlchemy 2.0 `select()` queries with filters, joins, ordering and pagination
    - Use relationships to load related data (a product's category, a customer's orders)
    - Return ORM objects through Pydantic response models with `from_attributes`

**Prerequisites:** [Routers & Project Structure](05-routers-and-project-structure.md), [Python + MySQL](../../database/mysql/13-python-mysql.md) and the [ksr_shop database](../../database/mysql/02-mysql-setup.md#loading-the-ksr_shop-database) loaded in your MySQL.

## From Raw SQL to an ORM

In the MySQL module you queried the database with `mysql-connector`: SQL strings, `%s` parameters and tuples or dicts back. That works, and it's worth knowing. But in a large API you'd write hundreds of near-identical SQL strings and convert rows to objects by hand.

An **ORM** (Object-Relational Mapper) lets you work with **Python classes and objects** instead, and generates the SQL for you:

| Database | ORM (SQLAlchemy) |
|----------|------------------|
| Table `products` | Class `Product` |
| Row | A `Product` object |
| Column `price` | Attribute `product.price` |
| Foreign key `category_id` | Relationship `product.category` |
| `SELECT * FROM products WHERE id = 7` | `db.get(Product, 7)` |

!!! example "Real-life analogy: a translator"
    You speak Python; MySQL speaks SQL. The ORM is a translator that sits between you, turning `db.get(Product, 7)` into `SELECT ... WHERE id = 7` and turning the reply back into a `Product` object. You can still talk to MySQL directly when you need to; the translator just saves effort for everyday conversations.

**SQLAlchemy** is Python's most widely used ORM and database toolkit. It also uses parameterised queries automatically, so ORM code is protected from SQL injection.

```bash
pip install sqlalchemy pymysql cryptography
```

| Package | Role |
|---------|------|
| `sqlalchemy` | The ORM |
| `pymysql` | The MySQL **driver** SQLAlchemy uses to talk to the server |
| `cryptography` | Needed by PyMySQL for MySQL 8's default password authentication |

## The Database Connection

```python title="app/database.py"
import os
from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

DATABASE_URL = os.environ.get(
    "DATABASE_URL", "mysql+pymysql://root:password@localhost:3306/ksr_shop"
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
    export DATABASE_URL="mysql+pymysql://root:YOUR_PASSWORD@localhost:3306/ksr_shop"
    ```

=== "Windows (Command Prompt)"

    ```{ .bash .no-run }
    set DATABASE_URL=mysql+pymysql://root:YOUR_PASSWORD@localhost:3306/ksr_shop
    ```

!!! warning "Special characters in the password"
    If your MySQL password contains `@`, `#`, `/` or `:`, URL-encode it: `@` becomes `%40` and `#` becomes `%23`. For example `Pass@123` becomes `Pass%40123` in the URL. In [lesson 08](08-dependencies-and-settings.md) you'll move all of this into a `.env` file.

## ORM Models

Models describe the **existing** ksr_shop tables. SQLAlchemy 2.0 uses type hints with `Mapped[...]` and `mapped_column(...)`:

```python title="app/models.py"
from datetime import date
from decimal import Decimal

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True)

    products: Mapped[list["Product"]] = relationship(back_populates="category")


class Product(Base):
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"))
    brand: Mapped[str | None] = mapped_column(String(50))
    price: Mapped[Decimal]
    stock: Mapped[int] = mapped_column(default=0)
    rating: Mapped[Decimal | None]
    added_on: Mapped[date]

    category: Mapped[Category] = relationship(back_populates="products")


class Customer(Base):
    __tablename__ = "customers"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    email: Mapped[str] = mapped_column(String(100), unique=True)
    city: Mapped[str] = mapped_column(String(50))
    phone: Mapped[str | None] = mapped_column(String(15))
    joined_on: Mapped[date]

    orders: Mapped[list["Order"]] = relationship(back_populates="customer")


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(primary_key=True)
    customer_id: Mapped[int] = mapped_column(ForeignKey("customers.id"))
    order_date: Mapped[date]
    status: Mapped[str] = mapped_column(String(20))

    customer: Mapped[Customer] = relationship(back_populates="orders")
    items: Mapped[list["OrderItem"]] = relationship(back_populates="order", cascade="all, delete-orphan")


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"))
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    quantity: Mapped[int]
    unit_price: Mapped[Decimal]

    order: Mapped[Order] = relationship(back_populates="items")
    product: Mapped[Product] = relationship()
```

| Syntax | Meaning |
|--------|---------|
| `__tablename__ = "products"` | The MySQL table this class maps to |
| `Mapped[int]` | Column type; `Mapped[str \| None]` means the column is nullable |
| `mapped_column(primary_key=True)` | Column options: PK, `ForeignKey`, `String(100)`, `unique`, `default` |
| `Decimal` | Exact numbers for MySQL `DECIMAL`: money stays exact |
| `relationship(back_populates=...)` | Navigation between objects: `product.category`, `category.products` |

!!! info "Existing tables vs creating tables"
    Here the tables already exist (we created them with `ksr_shop.sql`), so the models just **describe** them. For a brand-new project, `Base.metadata.create_all(engine)` can create tables from the models. Real projects use a **migration** tool such as **Alembic** to create and change tables safely over time.

## Response Schemas from ORM Objects

Pydantic needs `from_attributes=True` to read data from **object attributes** (`product.name`) instead of dict keys:

```python title="app/schemas.py"
from datetime import date

from pydantic import BaseModel, ConfigDict


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class CategoryBrief(ORMModel):
    id: int
    name: str


class CategoryOut(CategoryBrief):
    product_count: int


class ProductOut(ORMModel):
    id: int
    name: str
    brand: str | None
    price: float
    stock: int
    rating: float | None
    category: CategoryBrief


class ProductPage(BaseModel):
    total: int
    page: int
    size: int
    items: list[ProductOut]


class OrderItemOut(ORMModel):
    product_id: int
    product_name: str
    quantity: int
    unit_price: float
    line_total: float


class OrderOut(ORMModel):
    id: int
    order_date: date
    status: str
    items: list[OrderItemOut]
    total: float
```

`ProductOut.category` is a **nested** schema: FastAPI follows `product.category` (the relationship) and serialises it as `{"id": ..., "name": ...}`.

## Querying with select()

SQLAlchemy 2.0 builds queries with `select()`. The session executes them:

```python title="app/services.py"
from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.models import Category, Customer, Order, OrderItem, Product


def list_products(db: Session, category: str | None, search: str | None,
                  max_price: float | None, sort: str, page: int, size: int) -> dict:
    stmt = select(Product).join(Product.category)
    if category:
        stmt = stmt.where(Category.name == category)
    if search:
        stmt = stmt.where(Product.name.like(f"%{search}%"))
    if max_price is not None:
        stmt = stmt.where(Product.price <= max_price)

    total = db.scalar(select(func.count()).select_from(stmt.subquery()))

    order_column = {"name": Product.name, "price": Product.price, "rating": Product.rating.desc()}[sort]
    stmt = stmt.order_by(order_column, Product.id).offset((page - 1) * size).limit(size)
    items = db.scalars(stmt).all()
    return {"total": total, "page": page, "size": size, "items": items}


def get_product(db: Session, product_id: int) -> Product:
    product = db.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail=f"Product {product_id} not found")
    return product


def list_categories(db: Session) -> list[dict]:
    stmt = (
        select(Category.id, Category.name, func.count(Product.id).label("product_count"))
        .outerjoin(Product, Product.category_id == Category.id)
        .group_by(Category.id, Category.name)
        .order_by(Category.name)
    )
    return [row._asdict() for row in db.execute(stmt)]


def customer_orders(db: Session, customer_id: int) -> list[dict]:
    if db.get(Customer, customer_id) is None:
        raise HTTPException(status_code=404, detail=f"Customer {customer_id} not found")
    stmt = (
        select(Order)
        .where(Order.customer_id == customer_id)
        .options(selectinload(Order.items).selectinload(OrderItem.product))
        .order_by(Order.order_date)
    )
    result = []
    for order in db.scalars(stmt):
        items = [
            {"product_id": i.product_id, "product_name": i.product.name, "quantity": i.quantity,
             "unit_price": i.unit_price, "line_total": i.quantity * i.unit_price}
            for i in order.items
        ]
        result.append({"id": order.id, "order_date": order.order_date, "status": order.status,
                       "items": items, "total": sum(i["line_total"] for i in items)})
    return result
```

(To keep this lesson focused on the database, the "not found" checks raise `HTTPException` directly. In [lesson 07](07-database-crud.md) you'll return to the clean router → service → repository split.)

| SQL | SQLAlchemy 2.0 |
|-----|----------------|
| `SELECT * FROM products` | `select(Product)` |
| `WHERE price <= 5000` | `.where(Product.price <= 5000)` |
| `WHERE name LIKE '%shoe%'` | `.where(Product.name.like("%shoe%"))` |
| `JOIN categories ON ...` | `.join(Product.category)` |
| `LEFT JOIN` | `.outerjoin(...)` |
| `ORDER BY price DESC` | `.order_by(Product.price.desc())` |
| `LIMIT 10 OFFSET 20` | `.limit(10).offset(20)` |
| `COUNT(*)`, `GROUP BY` | `func.count(...)`, `.group_by(...)` |
| Get by primary key | `db.get(Product, 7)` |
| Run, get objects | `db.scalars(stmt).all()` · one value: `db.scalar(stmt)` |

You can see the SQL that SQLAlchemy generates by printing a statement:

```python
from sqlalchemy import select
from app.models import Category, Product

stmt = (
    select(Product)
    .join(Product.category)
    .where(Category.name == "Fashion", Product.price <= 5000)
    .order_by(Product.price.desc())
    .limit(3)
)
print(stmt)
```

```{ .text .output }
SELECT products.id, products.name, products.category_id, products.brand, products.price, products.stock, products.rating, products.added_on 
FROM products JOIN categories ON categories.id = products.category_id 
WHERE categories.name = :name_1 AND products.price <= :price_1 ORDER BY products.price DESC
 LIMIT :param_1
```

The `:name_1`-style placeholders are **bound parameters**: values are sent separately from the SQL, exactly like `%s` in mysql-connector, so this is safe from SQL injection.

## Routers with the get_db Dependency

```python title="app/routers.py"
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app import services
from app.database import get_db
from app.schemas import CategoryOut, OrderOut, ProductOut, ProductPage

router = APIRouter()
DB = Annotated[Session, Depends(get_db)]


@router.get("/products", response_model=ProductPage, tags=["Products"])
def list_products(
    db: DB,
    category: str | None = None,
    search: Annotated[str | None, Query(min_length=2)] = None,
    max_price: Annotated[float | None, Query(gt=0)] = None,
    sort: Literal["name", "price", "rating"] = "name",
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=50)] = 5,
):
    return services.list_products(db, category, search, max_price, sort, page, size)


@router.get("/products/{product_id}", response_model=ProductOut, tags=["Products"])
def get_product(product_id: int, db: DB):
    return services.get_product(db, product_id)


@router.get("/categories", response_model=list[CategoryOut], tags=["Categories"])
def list_categories(db: DB):
    return services.list_categories(db)


@router.get("/customers/{customer_id}/orders", response_model=list[OrderOut], tags=["Customers"])
def customer_orders(customer_id: int, db: DB):
    return services.customer_orders(db, customer_id)
```

```python title="app/main.py"
from fastapi import FastAPI

from app.routers import router

app = FastAPI(title="KSR Shop API", version="2.0")
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
  C->>F: GET /products/7
  F->>G: open session
  G-->>F: yield db
  F->>E: get_product(7, db)
  E->>M: SELECT ... WHERE id = 7
  M-->>E: row
  E-->>F: Product object
  F->>G: finally: db.close()
  F-->>C: 200 JSON
```

## Trying the API Against MySQL

A product, with its nested category, straight from ksr_shop:

```bash
curl -s http://127.0.0.1:8000/products/7
```

```{ .text .output }
{
  "id": 7,
  "name": "Running Shoes",
  "brand": "Puma",
  "price": 4299.0,
  "stock": 60,
  "rating": 4.2,
  "category": {
    "id": 2,
    "name": "Fashion"
  }
}
```

Filtering and sorting now run **in MySQL** (`WHERE`, `ORDER BY`, `LIMIT`), not in Python:

```bash
curl -s "http://127.0.0.1:8000/products?category=Electronics&sort=price&size=3"
```

```{ .text .output }
{
  "total": 5,
  "page": 1,
  "size": 3,
  "items": [
    {
      "id": 5,
      "name": "USB-C Cable",
      "brand": null,
      "price": 299.0,
      "stock": 500,
      "rating": 3.9,
      "category": {
        "id": 1,
        "name": "Electronics"
      }
    },
    {
      "id": 3,
      "name": "Airdopes 141",
      "brand": "boAt",
      "price": 1299.0,
      "stock": 200,
      "rating": 4.1,
      "category": {
        "id": 1,
        "name": "Electronics"
      }
    },
    {
      "id": 4,
      "name": "Inspiron 15 Laptop",
      "brand": "Dell",
      "price": 58999.0,
      "stock": 12,
      "rating": 4.3,
      "category": {
        "id": 1,
        "name": "Electronics"
      }
    }
  ]
}
```

Categories with product counts (a `LEFT JOIN` + `GROUP BY`, so Toys shows 0):

```bash
curl -s http://127.0.0.1:8000/categories
```

```{ .text .output }
[
  {
    "id": 3,
    "name": "Books",
    "product_count": 3
  },
  {
    "id": 1,
    "name": "Electronics",
    "product_count": 5
  },
  {
    "id": 2,
    "name": "Fashion",
    "product_count": 3
  },
  {
    "id": 4,
    "name": "Home & Kitchen",
    "product_count": 2
  },
  {
    "id": 5,
    "name": "Sports",
    "product_count": 2
  },
  {
    "id": 6,
    "name": "Toys",
    "product_count": 0
  }
]
```

A customer's orders with nested line items, loaded through relationships:

```bash
curl -s http://127.0.0.1:8000/customers/2/orders
```

```{ .text .output }
[
  {
    "id": 2,
    "order_date": "2025-06-18",
    "status": "delivered",
    "items": [
      {
        "product_id": 2,
        "product_name": "Galaxy S24",
        "quantity": 1,
        "unit_price": 74999.0,
        "line_total": 74999.0
      }
    ],
    "total": 74999.0
  },
  {
    "id": 7,
    "order_date": "2025-08-28",
    "status": "delivered",
    "items": [
      {
        "product_id": 11,
        "product_name": "Python Crash Course",
        "quantity": 1,
        "unit_price": 2199.0,
        "line_total": 2199.0
      },
      {
        "product_id": 9,
        "product_name": "Atomic Habits",
        "quantity": 1,
        "unit_price": 499.0,
        "line_total": 499.0
      }
    ],
    "total": 2698.0
  }
]
```

```bash
curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1:8000/customers/99/orders
```

```{ .text .output }
{
  "detail": "Customer 99 not found"
}
HTTP 404
```

## Relationships and the N+1 Problem

Accessing `order.items` triggers a query the first time. Loop over 100 orders and touch `order.items` on each, and you've sent **101 queries** (1 for the orders + 100 for the items). This is the famous **N+1 problem**, and it's the most common ORM performance bug.

`selectinload` fixes it by loading all the related rows in **one** extra query:

```{ .python .no-run }
select(Order).options(selectinload(Order.items).selectinload(OrderItem.product))
```

| Loading strategy | Queries for 100 orders | Use when |
|------------------|------------------------|----------|
| Default (lazy) | 1 + 100 (+100 for products) | You rarely touch the relationship |
| `selectinload(...)` | 1 + 1 (+1) | Loading collections (`order.items`) |
| `joinedload(...)` | 1 (with a JOIN) | Loading single related objects (`product.category`) |

!!! realworld "In Real Projects"
    Teams turn on `create_engine(..., echo=True)` during development to print every SQL statement SQLAlchemy runs. If one page load prints hundreds of near-identical `SELECT`s, that's an N+1 problem waiting to be fixed with `selectinload` or `joinedload`.

## Common Mistakes

| Mistake | Error / Symptom | Fix |
|---------|-----------------|-----|
| Wrong URL / password | `OperationalError: (1045, "Access denied for user 'root'@'localhost'")` | Check `DATABASE_URL`; URL-encode special characters |
| MySQL not running | `OperationalError: (2003, "Can't connect to MySQL server on 'localhost'")` | Start MySQL; check host and port |
| Missing driver | `ModuleNotFoundError: No module named 'pymysql'` | `pip install pymysql cryptography` |
| `from_attributes` missing | `ResponseValidationError` / "Input should be a valid dictionary" | `model_config = ConfigDict(from_attributes=True)` |
| Session never closed | "Too many connections" after a while | Use the `get_db` dependency with `try/finally` |
| `__tablename__` doesn't match the real table | `ProgrammingError: (1146, "Table 'ksr_shop.product' doesn't exist")` | Match the exact table name |
| Lazy-loading in a loop | Hundreds of queries, slow endpoints | `selectinload` / `joinedload` |
| Building SQL with f-strings via `text()` | SQL injection risk | Use `select()`/`where()`, or `text()` with bound `:params` |

## Practice Exercises

Use a fresh `ksr_shop` and the code from this lesson.

**Easy**

1. Add `GET /customers` returning id, name, city and email, with an optional `city` filter.
2. Add `GET /customers/{customer_id}` with a 404 for unknown ids.
3. Add a `brand` filter to `GET /products`.

**Medium**

4. Add `GET /categories/{category_id}/products`, sorted by price, returning 404 if the category doesn't exist.
5. Add `min_rating` and `in_stock` filters to `GET /products`, implemented as `.where()` clauses.
6. Add `GET /reports/top-products?limit=5` that returns product name and units sold (join `order_items`, `func.sum`, `group_by`, `order_by`), excluding cancelled orders.

**Challenge**

7. Add `GET /orders/{order_id}` that returns the order with customer name, city, items (product name, quantity, unit price, line total) and the order total, using exactly **one or two** SQL queries (use `joinedload`/`selectinload`; check with `echo=True`).

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    # 1 + 2 (schemas)
    class CustomerOut(ORMModel):
        id: int
        name: str
        email: str
        city: str

    # routers
    @router.get("/customers", response_model=list[CustomerOut], tags=["Customers"])
    def list_customers(db: DB, city: str | None = None):
        stmt = select(Customer).order_by(Customer.name)
        if city:
            stmt = stmt.where(Customer.city == city)
        return db.scalars(stmt).all()

    @router.get("/customers/{customer_id}", response_model=CustomerOut, tags=["Customers"])
    def get_customer(customer_id: int, db: DB):
        customer = db.get(Customer, customer_id)
        if customer is None:
            raise HTTPException(status_code=404, detail="Customer not found")
        return customer

    # 6
    @router.get("/reports/top-products", tags=["Reports"])
    def top_products(db: DB, limit: Annotated[int, Query(ge=1, le=20)] = 5):
        stmt = (
            select(Product.name, func.sum(OrderItem.quantity).label("units"))
            .join(OrderItem, OrderItem.product_id == Product.id)
            .join(Order, Order.id == OrderItem.order_id)
            .where(Order.status != "cancelled")
            .group_by(Product.id, Product.name)
            .order_by(func.sum(OrderItem.quantity).desc(), Product.name)
            .limit(limit)
        )
        return [{"product": name, "units": int(units)} for name, units in db.execute(stmt)]

    # 7
    from sqlalchemy.orm import joinedload, selectinload

    @router.get("/orders/{order_id}", tags=["Orders"])
    def get_order(order_id: int, db: DB):
        stmt = (
            select(Order).where(Order.id == order_id)
            .options(joinedload(Order.customer),
                     selectinload(Order.items).joinedload(OrderItem.product))
        )
        order = db.scalars(stmt).first()
        if order is None:
            raise HTTPException(status_code=404, detail="Order not found")
        items = [{"product": i.product.name, "quantity": i.quantity, "unit_price": float(i.unit_price),
                  "line_total": float(i.quantity * i.unit_price)} for i in order.items]
        return {"id": order.id, "customer": order.customer.name, "city": order.customer.city,
                "status": order.status, "items": items, "total": sum(i["line_total"] for i in items)}
    ```

!!! note "Mini Assignment"
    Connect your **KSR Shop API** to MySQL: add `app/database.py` and `app/models.py` for all six ksr_shop tables (including `Employee` with a self-referencing `manager` relationship), and convert every **read** endpoint (products, categories, customers, a customer's orders) to SQLAlchemy queries with `response_model`s. Keep the in-memory writes for now. You'll convert them in the next lesson.

## Interview Questions

!!! interview "1. What is an ORM? What are its pros and cons?"
    An Object-Relational Mapper maps tables to classes and rows to objects, generating SQL for you. Pros: less boilerplate, database portability, safety from injection by default, and relationships as attributes. Cons: hidden or inefficient SQL (N+1), a learning curve, and complex reports are sometimes easier in raw SQL.

!!! interview "2. What is the difference between the engine and a session in SQLAlchemy?"
    The engine is created once per application; it holds the connection pool and the dialect for talking to the database. A session is a short-lived unit of work (typically one per request) that tracks loaded and changed objects and manages the transaction (`commit` / `rollback`).

!!! interview "3. Why use a `get_db` dependency with `yield`?"
    It creates a session for each request, injects it into the endpoint, and guarantees cleanup in the `finally` block after the response, even if an exception occurs. That prevents connection leaks, and it's easy to override in tests.

!!! interview "4. What is the N+1 query problem and how do you fix it in SQLAlchemy?"
    Loading N parent objects with one query and then lazily loading a relationship for each one, so N extra queries run. Fix it with eager loading: `selectinload()` (one extra IN query for collections) or `joinedload()` (a JOIN, good for many-to-one), or with an explicit join in the query.

!!! interview "5. What does `from_attributes=True` do in Pydantic?"
    It lets a Pydantic model be built from arbitrary objects by reading attributes (`obj.name`) instead of dict keys, which is needed to return SQLAlchemy ORM objects through `response_model`. (It was called `orm_mode` in Pydantic v1.)

!!! interview "Scenario: an endpoint listing 50 orders takes 3 seconds, and the logs show 101 SELECT statements. Diagnose and fix."
    It's an N+1 problem: one query loads the orders and each order's items are lazy-loaded separately (possibly with their products too). Add `.options(selectinload(Order.items).selectinload(OrderItem.product))` to the query so the related rows load in one or two additional queries, and add indexes on the foreign key columns.

## Summary

| Concept | Code |
|---------|------|
| Install | `pip install sqlalchemy pymysql cryptography` |
| URL | `mysql+pymysql://user:pass@host:3306/ksr_shop` (from env) |
| Engine / sessions | `create_engine(URL, pool_pre_ping=True)` · `sessionmaker(bind=engine)` |
| Model | `class Product(Base): __tablename__ = "products"; id: Mapped[int] = mapped_column(primary_key=True)` |
| Relationship | `category: Mapped[Category] = relationship(back_populates="products")` |
| Dependency | `db: Annotated[Session, Depends(get_db)]` |
| Query | `db.scalars(select(Product).where(...).order_by(...).limit(n)).all()` · `db.get(Product, id)` |
| Response | Pydantic `ConfigDict(from_attributes=True)` |
| Performance | `selectinload` / `joinedload` against N+1; `echo=True` to see SQL |

**Next lesson:** [Database CRUD & Transactions](07-database-crud.md), creating, updating and deleting rows, and placing orders safely.
