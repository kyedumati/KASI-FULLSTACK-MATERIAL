---
lesson: true
category: FastAPI
short: Pydantic
description: Receiving JSON request bodies with Pydantic models, field constraints, email validation, custom validators, nested models, and combining body, path and query parameters.
---

# Request Bodies & Pydantic

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Receive JSON data in `POST`, `PUT` and `PATCH` requests using Pydantic models
    - Add rules to fields with `Field()`: lengths, ranges, defaults, examples
    - Validate emails and write custom validators for business rules
    - Model nested data, such as an order with a list of items
    - Read the 422 validation errors that FastAPI returns for bad bodies

**Prerequisites:** [Path & Query Parameters](02-path-and-query-parameters.md), and [Classes & Objects](../oop/01-classes-and-objects.md) from the OOP module.

## Why Request Bodies?

URLs are fine for ids and filters, but creating a customer or placing an order involves **structured data**: several fields, sometimes lists and nested objects. That data travels in the **request body** as JSON:

```http
POST /customers HTTP/1.1
Content-Type: application/json

{"name": "Neha Gupta", "email": "neha@example.com", "city": "Jaipur"}
```

| Method | Body? | Purpose |
|--------|-------|---------|
| `GET` | No | Read |
| `POST` | Yes | Create |
| `PUT` | Yes | Replace |
| `PATCH` | Yes (partial) | Update some fields |
| `DELETE` | Usually no | Remove |

FastAPI reads bodies with **Pydantic**, a library that defines the *shape* of data as a Python class and validates incoming data against it.

!!! example "Real-life analogy: a bank form"
    A bank's account-opening form has boxes with rules: name required, PAN exactly 10 characters, age 18 or over, a valid email. The clerk rejects a form with mistakes before it reaches the system and tells you exactly which box is wrong. A Pydantic model is that form, and FastAPI is the clerk.

## Your First Pydantic Model

```python title="main.py"
from datetime import date
from typing import Annotated

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator

app = FastAPI(title="KSR Shop API")

PRODUCTS: list[dict] = [
    {"id": 1, "name": "iPhone 15", "category": "Electronics", "brand": "Apple", "price": 79999.0, "stock": 25},
]
CUSTOMERS: list[dict] = []


class ProductCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100, examples=["Running Shoes"])
    category: str
    brand: str | None = None
    price: float = Field(gt=0, le=500000, description="Price in rupees")
    stock: int = Field(default=0, ge=0)


@app.post("/products", status_code=201)
def create_product(product: ProductCreate):
    new = {"id": len(PRODUCTS) + 1, **product.model_dump()}
    PRODUCTS.append(new)
    return new


class CustomerCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    name: str = Field(min_length=2, max_length=100)
    email: EmailStr
    phone: str | None = Field(default=None, pattern=r"^[6-9]\d{9}$")
    city: str
    password: str = Field(min_length=8)
    confirm_password: str
    date_of_birth: date | None = None

    @field_validator("name", "city")
    @classmethod
    def title_case(cls, value: str) -> str:
        return value.title()

    @field_validator("date_of_birth")
    @classmethod
    def must_be_adult(cls, value: date | None) -> date | None:
        if value and (date(2025, 10, 31) - value).days < 18 * 365:
            raise ValueError("customer must be at least 18 years old")
        return value

    @model_validator(mode="after")
    def passwords_match(self):
        if self.password != self.confirm_password:
            raise ValueError("passwords do not match")
        return self


@app.post("/customers", status_code=201)
def register_customer(customer: CustomerCreate):
    if any(c["email"] == customer.email for c in CUSTOMERS):
        raise HTTPException(status_code=409, detail="Email already registered")
    data = customer.model_dump(exclude={"password", "confirm_password"})
    data["id"] = len(CUSTOMERS) + 1
    CUSTOMERS.append(data)
    return data


class OrderItem(BaseModel):
    product_id: int = Field(gt=0)
    quantity: int = Field(ge=1, le=10)


class Address(BaseModel):
    line1: str
    city: str
    pincode: str = Field(pattern=r"^\d{6}$")


class OrderCreate(BaseModel):
    customer_id: int
    items: list[OrderItem] = Field(min_length=1)
    delivery_address: Address
    coupon: str | None = None


@app.post("/orders", status_code=201)
def place_order(order: OrderCreate):
    lines = []
    for item in order.items:
        product = next((p for p in PRODUCTS if p["id"] == item.product_id), None)
        if product is None:
            raise HTTPException(status_code=404, detail=f"Product {item.product_id} not found")
        lines.append({"product": product["name"], "quantity": item.quantity,
                      "line_total": product["price"] * item.quantity})
    return {
        "customer_id": order.customer_id,
        "ship_to": f"{order.delivery_address.city} - {order.delivery_address.pincode}",
        "lines": lines,
        "total": sum(line["line_total"] for line in lines),
    }


class StockUpdate(BaseModel):
    change: int = Field(description="Positive to add stock, negative to remove")
    reason: str


@app.post("/products/{product_id}/stock")
def update_stock(
    product_id: int,
    update: StockUpdate,
    notify: Annotated[bool, Query()] = False,
):
    product = next((p for p in PRODUCTS if p["id"] == product_id), None)
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    if product["stock"] + update.change < 0:
        raise HTTPException(status_code=400, detail="Stock cannot go below zero")
    product["stock"] += update.change
    return {"product": product["name"], "stock": product["stock"], "reason": update.reason, "notified": notify}
```

Let's look at the pieces.

### The model

```{ .python .no-run }
class ProductCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100, examples=["Running Shoes"])
    category: str
    brand: str | None = None
    price: float = Field(gt=0, le=500000, description="Price in rupees")
    stock: int = Field(default=0, ge=0)
```

- Each **attribute** is a field with a **type**.
- No default means **required** (`category`). A default makes it **optional** (`brand`, `stock`).
- `Field(...)` adds rules and documentation, like `Query()` did for query parameters.

When a function argument's type is a Pydantic model, FastAPI reads it from the **body**:

```{ .python .no-run }
@app.post("/products", status_code=201)
def create_product(product: ProductCreate):
    ...
```

Send a product with `curl`: `-X POST` sets the method, `-H` the content type, and `-d` the JSON body:

```bash
curl -s -X POST http://127.0.0.1:8000/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Running Shoes", "category": "Fashion", "brand": "Puma", "price": 4299, "stock": 60}'
```

```{ .text .output }
{
  "id": 2,
  "name": "Running Shoes",
  "category": "Fashion",
  "brand": "Puma",
  "price": 4299.0,
  "stock": 60
}
```

Inside the function, `product` is a real Python object: `product.name`, `product.price`. `product.model_dump()` turns it into a dict. Notice `price` came back as `4299.0`, because Pydantic converted it to the declared `float`.

Missing optional fields get their defaults:

```bash
curl -s -X POST http://127.0.0.1:8000/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Yoga Mat", "category": "Sports", "price": 999}'
```

```{ .text .output }
{
  "id": 3,
  "name": "Yoga Mat",
  "category": "Sports",
  "brand": null,
  "price": 999.0,
  "stock": 0
}
```

!!! tip "Try it in /docs"
    Open `/docs`, expand **POST /products** and click **Try it out**. FastAPI fills in an example body from your model (using `examples=` where you gave them), so you can edit it and execute without writing any curl.

## Validation Errors

Send a body that breaks several rules: a one-letter name, a negative price, and no category:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/products \
  -H "Content-Type: application/json" \
  -d '{"name": "X", "price": -50}'
```

```{ .text .output }
{
  "detail": [
    {
      "type": "string_too_short",
      "loc": ["body", "name"],
      "msg": "String should have at least 2 characters",
      "input": "X",
      "ctx": {
        "min_length": 2
      }
    },
    {
      "type": "missing",
      "loc": ["body", "category"],
      "msg": "Field required",
      "input": {
        "name": "X",
        "price": -50
      }
    },
    {
      "type": "greater_than",
      "loc": ["body", "price"],
      "msg": "Input should be greater than 0",
      "input": -50,
      "ctx": {
        "gt": 0.0
      }
    }
  ]
}
HTTP 422
```

Every problem is listed, with `loc` pointing to the exact field in the `body`. The frontend can show each message next to the right input box.

Wrong types are converted when it's safe (`"4299"` becomes `4299.0`) and rejected when it isn't:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Cable", "category": "Electronics", "price": "cheap"}'
```

```{ .text .output }
{
  "detail": [
    {
      "type": "float_parsing",
      "loc": ["body", "price"],
      "msg": "Input should be a valid number, unable to parse string as a number",
      "input": "cheap"
    }
  ]
}
HTTP 422
```

| `Field()` option | Meaning |
|------------------|---------|
| `default=` | Value when missing (or give `= value` directly) |
| `gt`, `ge`, `lt`, `le` | Number limits |
| `min_length`, `max_length` | String or list length |
| `pattern=` | Regular expression for strings |
| `description`, `examples` | Documentation in `/docs` |
| `alias=` | Accept a different JSON key (e.g. `"productName"`) |

## Emails, Validators and Strict Models

The customer registration model shows more powerful validation:

```{ .python .no-run }
class CustomerCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    name: str = Field(min_length=2, max_length=100)
    email: EmailStr
    phone: str | None = Field(default=None, pattern=r"^[6-9]\d{9}$")
    ...
```

| Feature | Effect |
|---------|--------|
| `EmailStr` | Must be a valid email address (installed with `fastapi[standard]`) |
| `pattern=r"^[6-9]\d{9}$"` | A 10-digit Indian mobile number starting with 6–9 |
| `extra="forbid"` | Reject unknown fields (catches typos like `"emial"`) |
| `str_strip_whitespace=True` | Trim spaces from every string |
| `date_of_birth: date` | Accepts `"1998-04-12"` and converts it to a `date` object |

### Field validators

`@field_validator` runs your own code on a field. Return the (possibly changed) value, or raise `ValueError` to reject it:

```{ .python .no-run }
@field_validator("name", "city")
@classmethod
def title_case(cls, value: str) -> str:
    return value.title()               # "neha gupta" -> "Neha Gupta"
```

### Model validators

`@model_validator(mode="after")` runs after all fields are valid, so it can compare **several** fields:

```{ .python .no-run }
@model_validator(mode="after")
def passwords_match(self):
    if self.password != self.confirm_password:
        raise ValueError("passwords do not match")
    return self
```

A valid registration. Note the spaces and lowercase in the input:

```bash
curl -s -X POST http://127.0.0.1:8000/customers \
  -H "Content-Type: application/json" \
  -d '{"name": "  neha gupta ", "email": "neha@example.com", "phone": "9876500011",
       "city": "jaipur", "password": "Secret@123", "confirm_password": "Secret@123",
       "date_of_birth": "1998-04-12"}'
```

```{ .text .output }
{
  "name": "Neha Gupta",
  "email": "neha@example.com",
  "phone": "9876500011",
  "city": "Jaipur",
  "date_of_birth": "1998-04-12",
  "id": 1
}
```

The name was trimmed and title-cased, and the passwords are **not** in the response. We excluded them with `model_dump(exclude={...})`. (In lesson 04 you'll do this properly with response models.)

A bad email, a bad phone number, mismatched passwords and an unexpected field:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/customers \
  -H "Content-Type: application/json" \
  -d '{"name": "Ravi", "email": "ravi-at-example", "phone": "12345",
       "city": "Pune", "password": "Secret@123", "confirm_password": "Secret@999",
       "is_admin": true}'
```

```{ .text .output }
{
  "detail": [
    {
      "type": "value_error",
      "loc": ["body", "email"],
      "msg": "value is not a valid email address: An email address must have an @-sign.",
      "input": "ravi-at-example",
      "ctx": {
        "reason": "An email address must have an @-sign."
      }
    },
    {
      "type": "string_pattern_mismatch",
      "loc": ["body", "phone"],
      "msg": "String should match pattern '^[6-9]\\d{9}$'",
      "input": "12345",
      "ctx": {
        "pattern": "^[6-9]\\d{9}$"
      }
    },
    {
      "type": "extra_forbidden",
      "loc": ["body", "is_admin"],
      "msg": "Extra inputs are not permitted",
      "input": true
    }
  ]
}
HTTP 422
```

The password check didn't appear yet: `model_validator(mode="after")` only runs once every field is individually valid. Fix the fields and you'll get the passwords error.

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/customers \
  -H "Content-Type: application/json" \
  -d '{"name": "Ravi", "email": "ravi@example.com", "city": "Pune",
       "password": "Secret@123", "confirm_password": "Secret@999"}'
```

```{ .text .output }
{
  "detail": [
    {
      "type": "value_error",
      "loc": ["body"],
      "msg": "Value error, passwords do not match",
      "input": {
        "name": "Ravi",
        "email": "ravi@example.com",
        "city": "Pune",
        "password": "Secret@123",
        "confirm_password": "Secret@999"
      },
      "ctx": {
        "error": {}
      }
    }
  ]
}
HTTP 422
```

!!! realworld "In Real Projects"
    `extra="forbid"` closes a real security hole called **mass assignment**: without it, an attacker could send `"is_admin": true` in a sign-up request, and if your code saved every field it received, they'd become an admin. Strict input models are a standard defence.

## Nested Models

Real payloads are nested. An order has a **list** of items and an **object** for the address:

```{ .python .no-run }
class OrderItem(BaseModel):
    product_id: int = Field(gt=0)
    quantity: int = Field(ge=1, le=10)

class Address(BaseModel):
    line1: str
    city: str
    pincode: str = Field(pattern=r"^\d{6}$")

class OrderCreate(BaseModel):
    customer_id: int
    items: list[OrderItem] = Field(min_length=1)
    delivery_address: Address
    coupon: str | None = None
```

```bash
curl -s -X POST http://127.0.0.1:8000/orders \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 1,
       "items": [{"product_id": 1, "quantity": 1}, {"product_id": 2, "quantity": 2}],
       "delivery_address": {"line1": "Flat 201, Madhapur", "city": "Hyderabad", "pincode": "500081"}}'
```

```{ .text .output }
{
  "customer_id": 1,
  "ship_to": "Hyderabad - 500081",
  "lines": [
    {
      "product": "iPhone 15",
      "quantity": 1,
      "line_total": 79999.0
    },
    {
      "product": "Running Shoes",
      "quantity": 2,
      "line_total": 8598.0
    }
  ],
  "total": 88597.0
}
```

Errors inside nested data point to the exact position: `items → 1 → quantity` means "the second item's quantity":

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/orders \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 1,
       "items": [{"product_id": 1, "quantity": 1}, {"product_id": 2, "quantity": 50}],
       "delivery_address": {"line1": "Madhapur", "city": "Hyderabad", "pincode": "5000"}}'
```

```{ .text .output }
{
  "detail": [
    {
      "type": "less_than_equal",
      "loc": ["body", "items", 1, "quantity"],
      "msg": "Input should be less than or equal to 10",
      "input": 50,
      "ctx": {
        "le": 10
      }
    },
    {
      "type": "string_pattern_mismatch",
      "loc": ["body", "delivery_address", "pincode"],
      "msg": "String should match pattern '^\\d{6}$'",
      "input": "5000",
      "ctx": {
        "pattern": "^\\d{6}$"
      }
    }
  ]
}
HTTP 422
```

## Body + Path + Query Together

FastAPI works out where each argument comes from:

| Argument | Comes from |
|----------|-----------|
| Name appears in the path (`{product_id}`) | **Path** |
| Type is a Pydantic model | **Body** |
| Simple type (`int`, `str`, `bool`…) not in the path | **Query** |

```{ .python .no-run }
@app.post("/products/{product_id}/stock")
def update_stock(product_id: int, update: StockUpdate, notify: bool = False):
```

```bash
curl -s -X POST "http://127.0.0.1:8000/products/1/stock?notify=true" \
  -H "Content-Type: application/json" \
  -d '{"change": -5, "reason": "Damaged in warehouse"}'
```

```{ .text .output }
{
  "product": "iPhone 15",
  "stock": 20,
  "reason": "Damaged in warehouse",
  "notified": true
}
```

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Missing `Content-Type: application/json` in curl | `422` "Input should be a valid dictionary or object…" | Add `-H "Content-Type: application/json"` |
| Invalid JSON (single quotes, trailing comma) | `422` with `"type": "json_invalid"` | Use double quotes in JSON; validate it |
| Sending a body with `GET` | Body ignored | Use `POST`/`PUT`/`PATCH` |
| Expecting the model to be a dict | `TypeError: 'ProductCreate' object is not subscriptable` | `product.name`, or `product.model_dump()` |
| Forgetting `@classmethod` on `@field_validator` | Errors at startup | Put `@classmethod` under `@field_validator` |
| Returning the full input including passwords | Secrets leak in responses | Exclude them, or use a response model (lesson 04) |
| Using Pydantic v1 syntax (`@validator`, `.dict()`) | Deprecation warnings / errors | v2: `@field_validator`, `.model_dump()` |

## Practice Exercises

**Easy**

1. Create a `CategoryCreate` model (`name` 2–50 characters, optional `description`) and a `POST /categories` endpoint.
2. Send three invalid bodies to it and note the `loc` and `msg` of each error.
3. Add `examples=` to every field of `ProductCreate` and check the example body in `/docs`.

**Medium**

4. Add a `discount_percent` field to `ProductCreate` (0–90, default 0) and return a calculated `final_price` from the endpoint.
5. Add a `field_validator` to `ProductCreate` that rejects names containing `<` or `>` (basic HTML injection protection).
6. Create `ReviewCreate` with `rating` (1–5), `comment` (10–500 characters) and `would_recommend` (bool), plus `POST /products/{product_id}/reviews` that also accepts a `verified: bool = False` query parameter.

**Challenge**

7. Extend `OrderCreate`: a coupon must match `^[A-Z0-9]{4,10}$`; the same `product_id` may not appear twice in `items` (`model_validator`); and orders with more than 20 total units are rejected. Write one valid request and one invalid request for each rule.

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    # 1
    class CategoryCreate(BaseModel):
        name: str = Field(min_length=2, max_length=50)
        description: str | None = None

    @app.post("/categories", status_code=201)
    def create_category(category: CategoryCreate):
        return category

    # 4 (in ProductCreate):  discount_percent: int = Field(default=0, ge=0, le=90)
    #   in the endpoint:      new["final_price"] = round(product.price * (100 - product.discount_percent) / 100, 2)

    # 5
    @field_validator("name")
    @classmethod
    def no_html(cls, value: str) -> str:
        if "<" in value or ">" in value:
            raise ValueError("name must not contain < or >")
        return value

    # 6
    class ReviewCreate(BaseModel):
        rating: int = Field(ge=1, le=5)
        comment: str = Field(min_length=10, max_length=500)
        would_recommend: bool

    @app.post("/products/{product_id}/reviews", status_code=201)
    def add_review(product_id: int, review: ReviewCreate, verified: bool = False):
        return {"product_id": product_id, "verified": verified, **review.model_dump()}

    # 7 (in OrderCreate)
    coupon: str | None = Field(default=None, pattern=r"^[A-Z0-9]{4,10}$")

    @model_validator(mode="after")
    def check_items(self):
        ids = [i.product_id for i in self.items]
        if len(ids) != len(set(ids)):
            raise ValueError("each product may appear only once")
        if sum(i.quantity for i in self.items) > 20:
            raise ValueError("an order may contain at most 20 units")
        return self
    ```

!!! note "Mini Assignment"
    In your **KSR Shop API**, add `POST /customers` (registration with `EmailStr`, phone pattern, password rules and confirmation), `POST /products` and `POST /orders` with nested items and address. Store them in in-memory lists. For each endpoint, save one valid and two invalid example requests in a `requests.http` or `curl_examples.md` file in the repo, so your trainer can test it quickly.

## Interview Questions

!!! interview "1. What is Pydantic and how does FastAPI use it?"
    A data validation library that uses Python type hints to define data models. FastAPI uses Pydantic models to parse and validate request bodies (returning 422 on errors), to serialise and filter responses (`response_model`), and to generate the JSON Schema for the OpenAPI docs.

!!! interview "2. How does FastAPI decide whether a parameter comes from the path, query or body?"
    If the name appears in the path template, it's a path parameter. If its type is a Pydantic model, it's read from the body. Other singular types are query parameters. You can be explicit with `Path()`, `Query()`, `Body()`, `Header()` and `Cookie()`.

!!! interview "3. What is the difference between `field_validator` and `model_validator`?"
    `field_validator` validates or transforms one (or a few) specific fields independently. `model_validator` runs on the whole model (`mode="before"` on the raw input, or `mode="after"` on the validated object) and is used for rules involving several fields, like password confirmation or date ranges.

!!! interview "4. How do you reject unknown fields in a request body, and why would you?"
    Set `model_config = ConfigDict(extra="forbid")`. It catches client typos and prevents mass-assignment attacks where extra fields like `is_admin` are smuggled into the request.

!!! interview "5. What changed between Pydantic v1 and v2 that you'd notice in code?"
    `.dict()` / `.json()` became `.model_dump()` / `.model_dump_json()`; `@validator` / `@root_validator` became `@field_validator` / `@model_validator`; `class Config` became `model_config = ConfigDict(...)`; `orm_mode` became `from_attributes`. v2's core is rewritten in Rust and is much faster.

!!! interview "Scenario: the frontend says 'every POST returns 422 even though the data looks right'. What do you check?"
    That they send `Content-Type: application/json` and a JSON body (not form data or a query string); that the JSON keys match the model's field names exactly (case, snake_case vs camelCase, or configure an alias); and that the types are right. Then read the `detail[].loc` in the 422 response, which says exactly which field failed.

## Summary

| Concept | Syntax |
|---------|--------|
| Model | `class ProductCreate(BaseModel): name: str; price: float` |
| Body parameter | `def create(product: ProductCreate)` |
| Rules | `Field(min_length=2, gt=0, ge=0, le=100, pattern=..., default=...)` |
| Email | `email: EmailStr` |
| Strict input | `model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)` |
| Custom rule | `@field_validator("field")` + `@classmethod` |
| Cross-field rule | `@model_validator(mode="after")` |
| Nested | `items: list[OrderItem]`, `address: Address` |
| Convert | `model.model_dump(exclude={...})` |
| Errors | 422 with `detail[].loc`, `msg`, `input` |

**Next lesson:** [Responses, Status Codes & Errors](04-responses-and-errors.md), controlling exactly what your API sends back.
