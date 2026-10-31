---
lesson: true
category: FastAPI
short: DB CRUD
api_app: app.main:app
api_db: true
description: Creating, updating and deleting MySQL rows through SQLAlchemy in a layered FastAPI app — repositories, services, IntegrityError handling, and placing an order as one transaction with row locking.
---

# Database CRUD & Transactions

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Insert, update and delete rows with SQLAlchemy sessions (`add`, `commit`, `refresh`, `delete`)
    - Organise database code into **repositories**, business rules into **services**, and HTTP into **routers**
    - Turn database constraint errors (`IntegrityError`) into proper `400` / `409` responses
    - Place an order as **one transaction**: check stock, write rows, reduce stock, commit or roll back
    - Lock rows with `with_for_update()` to prevent overselling

**Prerequisites:** [SQLAlchemy & MySQL](07-sqlalchemy-and-mysql.md) and [Transactions](../../database/mysql/12-transactions-indexes-users.md) from the MySQL module.

## How Writes Work in SQLAlchemy

The session is a **unit of work**: you make changes to objects, then `commit()` sends them all to MySQL in one transaction.

| Step | Code | SQL it causes |
|------|------|---------------|
| Create | `db.add(product)` | `INSERT` (at commit / flush) |
| Update | `product.price = 999` | `UPDATE` (at commit / flush) |
| Delete | `db.delete(product)` | `DELETE` (at commit / flush) |
| Save | `db.commit()` | `COMMIT` |
| Undo | `db.rollback()` | `ROLLBACK` |
| Reload | `db.refresh(product)` | `SELECT` (gets the generated id, defaults) |
| Send now, commit later | `db.flush()` | `INSERT/UPDATE` inside the open transaction |

!!! example "Real-life analogy: a shopping cart"
    Adding items to your online cart changes nothing in the warehouse. Only when you press **Place order** (`commit`) does everything happen together. If payment fails, the whole cart is abandoned (`rollback`), and nothing is half-done.

## The Layers

```mermaid
flowchart LR
  R["routers.py<br/>HTTP in/out"] --> S["services.py<br/>rules, transactions"]
  S --> P["repositories.py<br/>queries"]
  P --> D[("MySQL")]
  S -.raises.-> E["exceptions.py<br/>NotFound, Conflict,<br/>BadRequest"]
  E -.handlers.-> R
```

| File | Responsibility |
|------|----------------|
| `repositories.py` | **How** to read and write rows: queries only, no business rules |
| `services.py` | **What** is allowed: validation against the database, transactions, commit/rollback |
| `routers.py` | HTTP: parse input, call the service, return schemas and status codes |
| `exceptions.py` | Domain errors + one handler each |

??? info "app/database.py and app/models.py (unchanged from lesson 07, expand to copy)"

    ```python title="app/database.py"
    import os
    from collections.abc import Generator

    from sqlalchemy import create_engine
    from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

    DATABASE_URL = os.environ.get(
        "DATABASE_URL", "mysql+mysqlconnector://root:password@localhost:3306/ksr_shop"
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

## Schemas and Exceptions

```python title="app/schemas.py"
from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class ProductCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    category_id: int
    brand: str | None = None
    price: float = Field(gt=0)
    stock: int = Field(default=0, ge=0)


class ProductUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str | None = Field(default=None, min_length=2, max_length=100)
    category_id: int | None = None
    brand: str | None = None
    price: float | None = Field(default=None, gt=0)
    stock: int | None = Field(default=None, ge=0)


class ProductOut(ORMModel):
    id: int
    name: str
    category_id: int
    brand: str | None
    price: float
    stock: int


class OrderItemIn(BaseModel):
    product_id: int
    quantity: int = Field(ge=1, le=10)


class OrderCreate(BaseModel):
    customer_id: int
    items: list[OrderItemIn] = Field(min_length=1)


class OrderItemOut(ORMModel):
    product_id: int
    quantity: int
    unit_price: float


class OrderOut(ORMModel):
    id: int
    customer_id: int
    order_date: date
    status: str
    items: list[OrderItemOut]
    total: float
```

```python title="app/exceptions.py"
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class AppError(Exception):
    status_code = 400

    def __init__(self, message: str):
        self.message = message


class NotFoundError(AppError):
    status_code = 404


class ConflictError(AppError):
    status_code = 409


class BadRequestError(AppError):
    status_code = 400


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    def handle_app_error(request: Request, exc: AppError):
        return JSONResponse(status_code=exc.status_code, content={"detail": exc.message})
```

One handler covers all three: each subclass carries its own `status_code`.

## Repositories: Queries Only

```python title="app/repositories.py"
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models import Category, Customer, Order, Product


class ProductRepository:
    def __init__(self, db: Session):
        self.db = db

    def get(self, product_id: int) -> Product | None:
        return self.db.get(Product, product_id)

    def get_for_update(self, product_ids: list[int]) -> dict[int, Product]:
        stmt = select(Product).where(Product.id.in_(product_ids)).with_for_update()
        return {p.id: p for p in self.db.scalars(stmt)}

    def find_by_name(self, name: str) -> Product | None:
        return self.db.scalars(select(Product).where(Product.name == name)).first()

    def add(self, product: Product) -> Product:
        self.db.add(product)
        return product

    def delete(self, product: Product) -> None:
        self.db.delete(product)


class CategoryRepository:
    def __init__(self, db: Session):
        self.db = db

    def exists(self, category_id: int) -> bool:
        return self.db.get(Category, category_id) is not None


class OrderRepository:
    def __init__(self, db: Session):
        self.db = db

    def get(self, order_id: int) -> Order | None:
        stmt = select(Order).where(Order.id == order_id).options(selectinload(Order.items))
        return self.db.scalars(stmt).first()

    def add(self, order: Order) -> Order:
        self.db.add(order)
        return order

    def customer_exists(self, customer_id: int) -> bool:
        return self.db.get(Customer, customer_id) is not None
```

Repositories never call `commit()`. Deciding **when** a unit of work is complete is the service's job.

## Services: Rules and Transactions

```python title="app/services.py"
from datetime import date

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.exceptions import BadRequestError, ConflictError, NotFoundError
from app.models import Order, OrderItem, Product
from app.repositories import CategoryRepository, OrderRepository, ProductRepository
from app.schemas import OrderCreate, ProductCreate, ProductUpdate


class ProductService:
    def __init__(self, db: Session):
        self.db = db
        self.products = ProductRepository(db)
        self.categories = CategoryRepository(db)

    def get(self, product_id: int) -> Product:
        product = self.products.get(product_id)
        if product is None:
            raise NotFoundError(f"Product {product_id} not found")
        return product

    def create(self, data: ProductCreate) -> Product:
        if not self.categories.exists(data.category_id):
            raise BadRequestError(f"Category {data.category_id} does not exist")
        if self.products.find_by_name(data.name):
            raise ConflictError(f"Product '{data.name}' already exists")
        product = Product(**data.model_dump(), added_on=date.today())
        self.products.add(product)
        self.db.commit()
        self.db.refresh(product)
        return product

    def update(self, product_id: int, changes: ProductUpdate) -> Product:
        product = self.get(product_id)
        updates = changes.model_dump(exclude_unset=True)
        if "category_id" in updates and not self.categories.exists(updates["category_id"]):
            raise BadRequestError(f"Category {updates['category_id']} does not exist")
        for field, value in updates.items():
            setattr(product, field, value)
        self.db.commit()
        self.db.refresh(product)
        return product

    def delete(self, product_id: int) -> None:
        product = self.get(product_id)
        self.products.delete(product)
        try:
            self.db.commit()
        except IntegrityError:
            self.db.rollback()
            raise ConflictError("Product has orders and cannot be deleted; set its stock to 0 instead")


class OrderService:
    def __init__(self, db: Session):
        self.db = db
        self.orders = OrderRepository(db)
        self.products = ProductRepository(db)

    def get(self, order_id: int) -> dict:
        order = self.orders.get(order_id)
        if order is None:
            raise NotFoundError(f"Order {order_id} not found")
        return self._to_dict(order)

    def place(self, data: OrderCreate) -> dict:
        try:
            if not self.orders.customer_exists(data.customer_id):
                raise NotFoundError(f"Customer {data.customer_id} not found")

            ids = [item.product_id for item in data.items]
            locked = self.products.get_for_update(ids)          # SELECT ... FOR UPDATE

            for item in data.items:                             # 1. validate everything first
                product = locked.get(item.product_id)
                if product is None:
                    raise NotFoundError(f"Product {item.product_id} not found")
                if product.stock < item.quantity:
                    raise ConflictError(f"Only {product.stock} unit(s) of {product.name} in stock")

            order = Order(customer_id=data.customer_id, order_date=date.today(), status="pending")
            for item in data.items:                             # 2. then change
                product = locked[item.product_id]
                product.stock -= item.quantity
                order.items.append(OrderItem(product_id=product.id, quantity=item.quantity,
                                             unit_price=product.price))
            self.orders.add(order)
            self.db.commit()                                    # 3. all or nothing
            self.db.refresh(order)
            return self._to_dict(order)
        except Exception:
            self.db.rollback()
            raise

    @staticmethod
    def _to_dict(order: Order) -> dict:
        return {"id": order.id, "customer_id": order.customer_id, "order_date": order.order_date,
                "status": order.status, "items": order.items,
                "total": sum(i.quantity * i.unit_price for i in order.items)}
```

The order flow is the important part:

1. **Lock** the product rows with `SELECT … FOR UPDATE`, so a second buyer must wait until this transaction finishes.
2. **Validate everything** before changing anything.
3. Reduce stock, create the order and its items, then **commit once**. If anything fails, `rollback()` undoes it all.

## Routers

```python title="app/routers.py"
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas import OrderCreate, OrderOut, ProductCreate, ProductOut, ProductUpdate
from app.services import OrderService, ProductService

router = APIRouter()


def product_service(db: Annotated[Session, Depends(get_db)]) -> ProductService:
    return ProductService(db)


def order_service(db: Annotated[Session, Depends(get_db)]) -> OrderService:
    return OrderService(db)


Products = Annotated[ProductService, Depends(product_service)]
Orders = Annotated[OrderService, Depends(order_service)]


@router.get("/products/{product_id}", response_model=ProductOut, tags=["Products"])
def get_product(product_id: int, service: Products):
    return service.get(product_id)


@router.post("/products", response_model=ProductOut, status_code=status.HTTP_201_CREATED, tags=["Products"])
def create_product(data: ProductCreate, service: Products):
    return service.create(data)


@router.patch("/products/{product_id}", response_model=ProductOut, tags=["Products"])
def update_product(product_id: int, changes: ProductUpdate, service: Products):
    return service.update(product_id, changes)


@router.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Products"])
def delete_product(product_id: int, service: Products):
    service.delete(product_id)


@router.post("/orders", response_model=OrderOut, status_code=status.HTTP_201_CREATED, tags=["Orders"])
def place_order(data: OrderCreate, service: Orders):
    return service.place(data)


@router.get("/orders/{order_id}", response_model=OrderOut, tags=["Orders"])
def get_order(order_id: int, service: Orders):
    return service.get(order_id)
```

```python title="app/main.py"
from fastapi import FastAPI

from app.exceptions import register_exception_handlers
from app.routers import router

app = FastAPI(title="KSR Shop API", version="3.0")
register_exception_handlers(app)
app.include_router(router)
```

`product_service` is a dependency that itself depends on `get_db`. FastAPI resolves the chain automatically: session → service → endpoint. You'll explore this in the [next lesson](09-dependencies-and-settings.md).

## Trying It: Create, Update, Delete

Create a product in category 5 (Sports):

```bash
curl -s -X POST http://127.0.0.1:8000/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Football", "category_id": 5, "brand": "Nivia", "price": 899, "stock": 40}'
```

```{ .text .output }
{
  "id": 16,
  "name": "Football",
  "category_id": 5,
  "brand": "Nivia",
  "price": 899.0,
  "stock": 40
}
```

MySQL generated the id (`16`), and `db.refresh()` loaded it back. It's a real row now. Check it in MySQL Workbench with `SELECT * FROM products WHERE id = 16;`.

Update it:

```bash
curl -s -X PATCH http://127.0.0.1:8000/products/16 \
  -H "Content-Type: application/json" -d '{"price": 799, "stock": 35}'
```

```{ .text .output }
{
  "id": 16,
  "name": "Football",
  "category_id": 5,
  "brand": "Nivia",
  "price": 799.0,
  "stock": 35
}
```

Business rules checked against the database:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Kite", "category_id": 99, "price": 150}'
```

```{ .text .output }
{
  "detail": "Category 99 does not exist"
}
HTTP 400
```

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Football", "category_id": 5, "price": 500}'
```

```{ .text .output }
{
  "detail": "Product 'Football' already exists"
}
HTTP 409
```

Delete the new product (no orders reference it), then try to delete product 7, which appears in past orders:

```bash
curl -s -w "HTTP %{http_code}\n" -X DELETE http://127.0.0.1:8000/products/16
curl -s -w "\nHTTP %{http_code}\n" -X DELETE http://127.0.0.1:8000/products/7
```

```{ .text .output }
HTTP 204
{"detail":"Product has orders and cannot be deleted; set its stock to 0 instead"}
HTTP 409
```

MySQL's foreign key on `order_items.product_id` refused the delete (`ERROR 1451` from the MySQL module). SQLAlchemy raised `IntegrityError`, and the service rolled back and turned it into a friendly **409**.

!!! tip "Check first, or catch the error?"
    We **check** the category exists before inserting (clear message), but we **catch** `IntegrityError` on delete. Both are fine. Checks give nicer messages; catching the database error is the final safety net, because between your check and the commit another request could change the data. Real code often does both.

## Trying It: Placing Orders

Running Shoes (product 7) has 60 in stock and Atomic Habits (9) has 80. Customer 9 orders 2 shoes and 1 book:

```bash
curl -s -X POST http://127.0.0.1:8000/orders \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 9, "items": [{"product_id": 7, "quantity": 2}, {"product_id": 9, "quantity": 1}]}'
```

```{ .text .output }
{
  "id": 13,
  "customer_id": 9,
  "order_date": "2026-10-31",
  "status": "pending",
  "items": [
    {
      "product_id": 7,
      "quantity": 2,
      "unit_price": 4299.0
    },
    {
      "product_id": 9,
      "quantity": 1,
      "unit_price": 499.0
    }
  ],
  "total": 9097.0
}
```

The stock went down in the same transaction:

```bash
curl -s http://127.0.0.1:8000/products/7
```

```{ .text .output }
{
  "id": 7,
  "name": "Running Shoes",
  "category_id": 2,
  "brand": "Puma",
  "price": 4299.0,
  "stock": 58
}
```

Now an order where the **second** item fails: Wings of Fire (10) has 0 in stock:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/orders \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 9, "items": [{"product_id": 7, "quantity": 1}, {"product_id": 10, "quantity": 1}]}'
```

```{ .text .output }
{
  "detail": "Only 0 unit(s) of Wings of Fire in stock"
}
HTTP 409
```

Was the first item's stock reduced? No: the validation loop failed before any change, and the rollback guarantees nothing was half-saved:

```bash
curl -s http://127.0.0.1:8000/products/7 | python -c "import json,sys; print('Running Shoes stock:', json.load(sys.stdin)['stock'])"
```

```{ .text .output }
Running Shoes stock: 58
```

Still 58. An order for a customer who doesn't exist:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/orders \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 999, "items": [{"product_id": 7, "quantity": 1}]}'
```

```{ .text .output }
{
  "detail": "Customer 999 not found"
}
HTTP 404
```

!!! realworld "In Real Projects"
    "Check stock, create order, reduce stock, record payment" is the heart of every e-commerce backend, and it **must** be one transaction with row locks. Without `with_for_update()`, two customers buying the last unit at the same moment could both pass the stock check, and you'd sell an item you don't have. Big sale events (like a phone launch at 12:00 noon) are exactly when this race condition happens.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Forgetting `db.commit()` | Response looks fine, but nothing is saved in MySQL | Commit in the service after the unit of work |
| Using the object after a failed commit without `rollback()` | `PendingRollbackError: This Session's transaction has been rolled back` | Always `db.rollback()` in `except` |
| Committing inside repositories | Can't group several writes into one transaction | Only services commit |
| Returning the new object without `refresh()` | `id` or defaults missing | `db.refresh(obj)` after commit |
| No row lock when checking stock | Overselling under concurrent orders | `select(...).with_for_update()` |
| Changing data before all validation | Partial changes before an error | Validate everything first, then change |
| Catching all exceptions and returning 200 | Errors hidden from the client | Re-raise, or map to domain errors |
| Raw `IntegrityError` text in responses | Leaks table and constraint names | Translate to a friendly message |

## Practice Exercises

Use a fresh `ksr_shop`.

**Easy**

1. Add `POST /categories` that creates a category and returns `409` if the name exists (check first, and also catch `IntegrityError` from the `UNIQUE` constraint).
2. Add `PATCH /customers/{customer_id}` to update `city` and `phone`.
3. Add `DELETE /categories/{category_id}` that returns `409` if the category still has products.

**Medium**

4. Add `PATCH /orders/{order_id}/status` that only allows valid transitions: `pending → shipped → delivered`, and `pending → cancelled`. Anything else is a `400`.
5. When an order is **cancelled**, return its items' quantities to stock in the same transaction.
6. Add `POST /products/{product_id}/restock` with a body `{"quantity": n}` that locks the row and increases the stock.

**Challenge**

7. Write a small script that fires **two orders at the same time** for the last 3 units of a product (use `concurrent.futures.ThreadPoolExecutor` with `requests`): each order asks for 2 units. Run it with the `with_for_update()` lock and confirm exactly one order succeeds. Then remove the lock, set the stock back to 3, and run it again. What happens to the stock? Explain why.

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    # 1  (service)
    def create_category(self, name: str) -> Category:
        if self.db.scalars(select(Category).where(Category.name == name)).first():
            raise ConflictError(f"Category '{name}' already exists")
        category = Category(name=name)
        self.db.add(category)
        try:
            self.db.commit()
        except IntegrityError:
            self.db.rollback()
            raise ConflictError(f"Category '{name}' already exists")
        self.db.refresh(category)
        return category

    # 4 + 5  (OrderService)
    ALLOWED = {"pending": {"shipped", "cancelled"}, "shipped": {"delivered"}}

    def change_status(self, order_id: int, new_status: str) -> dict:
        order = self.orders.get(order_id)
        if order is None:
            raise NotFoundError(f"Order {order_id} not found")
        if new_status not in ALLOWED.get(order.status, set()):
            raise BadRequestError(f"Cannot change status from {order.status} to {new_status}")
        try:
            if new_status == "cancelled":
                locked = self.products.get_for_update([i.product_id for i in order.items])
                for item in order.items:
                    locked[item.product_id].stock += item.quantity
            order.status = new_status
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise
        return self._to_dict(order)

    # 7  race test
    from concurrent.futures import ThreadPoolExecutor
    import requests

    body = {"customer_id": 9, "items": [{"product_id": 15, "quantity": 2}]}
    with ThreadPoolExecutor(2) as pool:
        results = list(pool.map(lambda _: requests.post("http://127.0.0.1:8000/orders", json=body).status_code, range(2)))
    print(results)        # with the lock: [201, 409]
    # Without the lock both requests may read stock=3, both pass the check, and both subtract 2:
    # two orders succeed and stock ends at -1 (or 1 if one update overwrites the other), which is wrong either way.
    ```

!!! note "Mini Assignment"
    Convert every **write** endpoint in your **KSR Shop API** to MySQL using the repository → service → router layers: create, update and delete for products, categories and customers, plus `POST /orders` with stock locking and full rollback, and `PATCH /orders/{id}/status` with valid transitions and stock restoration on cancel. Add a section to your README describing the transaction rules.

## Interview Questions

!!! interview "1. What does `db.commit()` do, and what happens if you forget it?"
    It flushes pending changes (INSERT/UPDATE/DELETE) and commits the transaction, making them permanent and visible to others. Without it the changes stay in the session's open transaction and are rolled back when the session closes, so nothing is saved.

!!! interview "2. What is the difference between `flush()` and `commit()`?"
    `flush()` sends pending SQL to the database inside the current transaction (so generated ids exist and constraints are checked) without committing; it can still be rolled back. `commit()` flushes and then commits, making the changes permanent.

!!! interview "3. How do you handle a unique-constraint violation in SQLAlchemy?"
    Catch `sqlalchemy.exc.IntegrityError` around the commit, call `db.rollback()` (the session is unusable until then), and translate it into a domain error such as a 409 Conflict with a friendly message. Checking for duplicates first gives nicer messages, but the database constraint is the final guarantee.

!!! interview "4. Why should repositories not commit?"
    Committing is a business decision about where a unit of work ends. If repositories committed, a service couldn't combine several writes (order, items, stock) into one atomic transaction. Services own transaction boundaries; repositories just add and query.

!!! interview "5. How do you prevent overselling when two users buy the last item at the same time?"
    Do the stock check and the update in a single transaction and lock the rows (`SELECT ... FOR UPDATE`, `with_for_update()` in SQLAlchemy), so the second transaction waits and then sees the updated stock. Alternatively, use an atomic conditional update (`UPDATE products SET stock = stock - 2 WHERE id = ? AND stock >= 2`) and check the affected row count. A `CHECK (stock >= 0)` constraint is a final safety net.

!!! interview "Scenario: after an exception in one request, later requests fail with `PendingRollbackError`. What's wrong?"
    A session (or a shared, global session) hit a database error and was never rolled back, so it's stuck in a failed transaction. Use one session per request via the `get_db` dependency, and always call `db.rollback()` in error paths before reusing the session or raising.

## Summary

| Operation | SQLAlchemy |
|-----------|-----------|
| Create | `db.add(obj)` → `db.commit()` → `db.refresh(obj)` |
| Update | Set attributes → `db.commit()` |
| Delete | `db.delete(obj)` → `db.commit()` |
| Error | `except IntegrityError: db.rollback()` → domain error (409/400) |
| Lock rows | `select(...).with_for_update()` |
| Transaction rule | Validate everything → change → commit once → rollback on any error |
| Layers | Router (HTTP) → Service (rules, commit) → Repository (queries) |
| Dependency chain | `get_db` → `ProductService` → endpoint |

**Next lesson:** [Dependency Injection & Settings](09-dependencies-and-settings.md), reusable dependencies, configuration and `.env` files.
