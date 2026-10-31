---
lesson: true
category: FastAPI
short: Parameters
description: Reading input from the URL with path parameters and query parameters, automatic type conversion, Enum choices, optional values, and validation with Path and Query.
---

# Path & Query Parameters

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Read values from the URL path, like `/products/7`
    - Read optional filters from the query string, like `?brand=Puma&max_price=5000`
    - Let type hints convert and validate input automatically
    - Restrict values with `Enum`, and add rules with `Path()` and `Query()`
    - Avoid route-order bugs and build a filtered, paginated list endpoint

**Prerequisites:** [Introduction to FastAPI](01-introduction-to-fastapi.md)

## Two Ways to Send Input in a URL

```text
http://127.0.0.1:8000/products/7?currency=INR&details=true
                     └───┬────┘ └─────────────┬──────────┘
                     path parameter      query parameters
```

| | Path parameter | Query parameter |
|---|---|---|
| Looks like | `/products/7` | `/products?brand=Puma` |
| Used for | **Identifying** a specific resource | **Filtering, sorting, paging, options** |
| Required? | Always | Usually optional (with defaults) |
| Example | `/customers/3`, `/orders/12` | `?page=2`, `?sort=price`, `?in_stock=true` |

!!! example "Real-life analogy: a library"
    *"Give me book number 1042"* is a **path parameter**: it identifies one exact book. *"Show me books by Penguin, under ₹500, page 2"* is a **query**: filters on a list.

We'll use a small in-memory list of products from ksr_shop for now. In lesson 06 the same endpoints will read from MySQL.

```python title="main.py"
from enum import Enum
from typing import Annotated

from fastapi import FastAPI, HTTPException, Path, Query

app = FastAPI(title="KSR Shop API")

PRODUCTS = [
    {"id": 1, "name": "iPhone 15",      "category": "electronics", "brand": "Apple",   "price": 79999, "stock": 25},
    {"id": 3, "name": "Airdopes 141",   "category": "electronics", "brand": "boAt",    "price": 1299,  "stock": 200},
    {"id": 6, "name": "Denim Jacket",   "category": "fashion",     "brand": "Levis",   "price": 3499,  "stock": 40},
    {"id": 7, "name": "Running Shoes",  "category": "fashion",     "brand": "Puma",    "price": 4299,  "stock": 60},
    {"id": 8, "name": "Cotton T-Shirt", "category": "fashion",     "brand": "Puma",    "price": 799,   "stock": 150},
    {"id": 9, "name": "Atomic Habits",  "category": "books",       "brand": "Penguin", "price": 499,   "stock": 80},
    {"id": 10, "name": "Wings of Fire", "category": "books",       "brand": "Universities Press", "price": 350, "stock": 0},
]


class Category(str, Enum):
    electronics = "electronics"
    fashion = "fashion"
    books = "books"


@app.get("/products/cheapest")
def cheapest_product():
    return min(PRODUCTS, key=lambda p: p["price"])


@app.get("/products/{product_id}")
def get_product(product_id: int):
    for product in PRODUCTS:
        if product["id"] == product_id:
            return product
    raise HTTPException(status_code=404, detail=f"Product {product_id} not found")


@app.get("/categories/{category}/products")
def products_in_category(category: Category):
    return [p["name"] for p in PRODUCTS if p["category"] == category.value]


@app.get("/products")
def list_products(
    brand: str | None = None,
    min_price: Annotated[int, Query(ge=0)] = 0,
    max_price: Annotated[int | None, Query(gt=0, description="Upper price limit in rupees")] = None,
    in_stock: bool = False,
    search: Annotated[str | None, Query(min_length=2, max_length=50)] = None,
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=50)] = 3,
):
    results = [p for p in PRODUCTS if p["price"] >= min_price]
    if brand:
        results = [p for p in results if p["brand"].lower() == brand.lower()]
    if max_price is not None:
        results = [p for p in results if p["price"] <= max_price]
    if in_stock:
        results = [p for p in results if p["stock"] > 0]
    if search:
        results = [p for p in results if search.lower() in p["name"].lower()]
    start = (page - 1) * size
    return {"total": len(results), "page": page, "size": size, "items": results[start:start + size]}


@app.get("/products/{product_id}/price")
def product_price(
    product_id: Annotated[int, Path(gt=0, description="The product's id")],
    quantity: Annotated[int, Query(ge=1, le=10)] = 1,
    gst: bool = True,
):
    product = get_product(product_id)
    subtotal = product["price"] * quantity
    total = round(subtotal * 1.18, 2) if gst else subtotal
    return {"product": product["name"], "quantity": quantity, "subtotal": subtotal, "total": total}
```

We'll go through this file piece by piece. Run it with `fastapi dev main.py` and follow along.

## Path Parameters

A path parameter is a variable part of the URL, written in curly braces: `/products/{product_id}`. FastAPI passes it to the function argument with the **same name**:

```{ .python .no-run }
@app.get("/products/{product_id}")
def get_product(product_id: int):
    ...
```

```bash
curl -s http://127.0.0.1:8000/products/7
```

```{ .text .output }
{
  "id": 7,
  "name": "Running Shoes",
  "category": "fashion",
  "brand": "Puma",
  "price": 4299,
  "stock": 60
}
```

### Type conversion and validation

URLs are always text, but because we wrote `product_id: int`, FastAPI **converts** `"7"` to the integer `7`. If the value can't be converted, it rejects the request with **422 Unprocessable Content** before your code even runs:

```bash
curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1:8000/products/seven
```

```{ .text .output }
{
  "detail": [
    {
      "type": "int_parsing",
      "loc": ["path", "product_id"],
      "msg": "Input should be a valid integer, unable to parse string as an integer",
      "input": "seven"
    }
  ]
}
HTTP 422
```

The error tells the caller exactly what's wrong: in the **path**, the parameter **product_id**, should be a **valid integer**, and you gave `"seven"`. You wrote zero validation code.

A product that doesn't exist returns the **404** we raised:

```bash
curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1:8000/products/99
```

```{ .text .output }
{
  "detail": "Product 99 not found"
}
HTTP 404
```

`raise HTTPException(status_code=404, detail=...)` stops the function and sends an error response. You'll learn it properly in [lesson 04](04-responses-and-errors.md).

### Route order matters

`/products/cheapest` is declared **before** `/products/{product_id}`. FastAPI checks routes in order, top to bottom:

```bash
curl -s http://127.0.0.1:8000/products/cheapest
```

```{ .text .output }
{
  "id": 10,
  "name": "Wings of Fire",
  "category": "books",
  "brand": "Universities Press",
  "price": 350,
  "stock": 0
}
```

!!! mistake "Common Mistake: a fixed path after a parameter path"
    If `/products/{product_id}` came first, a request to `/products/cheapest` would match it with `product_id = "cheapest"`, fail the `int` conversion, and return **422**. **Always declare fixed paths before parameter paths** that could swallow them.

### Choices with Enum

To accept only specific values, use an `Enum`:

```{ .python .no-run }
class Category(str, Enum):
    electronics = "electronics"
    fashion = "fashion"
    books = "books"

@app.get("/categories/{category}/products")
def products_in_category(category: Category):
    ...
```

```bash
curl -s http://127.0.0.1:8000/categories/books/products
```

```{ .text .output }
["Atomic Habits", "Wings of Fire"]
```

```bash
curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1:8000/categories/toys/products
```

```{ .text .output }
{
  "detail": [
    {
      "type": "enum",
      "loc": ["path", "category"],
      "msg": "Input should be 'electronics', 'fashion' or 'books'",
      "input": "toys",
      "ctx": {
        "expected": "'electronics', 'fashion' or 'books'"
      }
    }
  ]
}
HTTP 422
```

The `/docs` page now shows a **dropdown** with the three valid values.

## Query Parameters

Any function argument that is **not** in the path is treated as a **query parameter**. Give it a default value to make it optional:

```{ .python .no-run }
@app.get("/products")
def list_products(brand: str | None = None, in_stock: bool = False, page: int = 1, ...):
```

| Declaration | Meaning |
|-------------|---------|
| `brand: str` | Required query parameter (422 if missing) |
| `brand: str = "Puma"` | Optional, defaults to `"Puma"` |
| `brand: str \| None = None` | Optional, `None` when not given |
| `in_stock: bool = False` | `true`, `1`, `yes`, `on` all become `True` |

All products, page 1, 3 per page:

```bash
curl -s "http://127.0.0.1:8000/products"
```

```{ .text .output }
{
  "total": 7,
  "page": 1,
  "size": 3,
  "items": [
    {
      "id": 1,
      "name": "iPhone 15",
      "category": "electronics",
      "brand": "Apple",
      "price": 79999,
      "stock": 25
    },
    {
      "id": 3,
      "name": "Airdopes 141",
      "category": "electronics",
      "brand": "boAt",
      "price": 1299,
      "stock": 200
    },
    {
      "id": 6,
      "name": "Denim Jacket",
      "category": "fashion",
      "brand": "Levis",
      "price": 3499,
      "stock": 40
    }
  ]
}
```

Filters combine with `&`:

```bash
curl -s "http://127.0.0.1:8000/products?brand=puma&max_price=1000"
```

```{ .text .output }
{
  "total": 1,
  "page": 1,
  "size": 3,
  "items": [
    {
      "id": 8,
      "name": "Cotton T-Shirt",
      "category": "fashion",
      "brand": "Puma",
      "price": 799,
      "stock": 150
    }
  ]
}
```

```bash
curl -s "http://127.0.0.1:8000/products?search=ing&in_stock=true"
```

```{ .text .output }
{
  "total": 1,
  "page": 1,
  "size": 3,
  "items": [
    {
      "id": 7,
      "name": "Running Shoes",
      "category": "fashion",
      "brand": "Puma",
      "price": 4299,
      "stock": 60
    }
  ]
}
```

Page 3 of everything:

```bash
curl -s "http://127.0.0.1:8000/products?page=3&size=3"
```

```{ .text .output }
{
  "total": 7,
  "page": 3,
  "size": 3,
  "items": [
    {
      "id": 10,
      "name": "Wings of Fire",
      "category": "books",
      "brand": "Universities Press",
      "price": 350,
      "stock": 0
    }
  ]
}
```

!!! tip "Quote URLs that contain `&`"
    In the terminal, `&` means "run in background". Always wrap URLs with query strings in quotes: `curl -s "http://...?a=1&b=2"`.

!!! realworld "In Real Projects"
    Every product listing, search page and admin table in a real app is a `GET` endpoint with query parameters: `?q=shoes&brand=puma&sort=price&page=2&size=24`. The frontend builds the query string from the filters the user clicks, and the backend turns it into SQL `WHERE`, `ORDER BY` and `LIMIT/OFFSET`, exactly as you learned in the MySQL module.

## Validation with Path() and Query()

Type hints check the **type**. `Path()` and `Query()` add **rules** and **documentation**, written with `Annotated`:

```{ .python .no-run }
from typing import Annotated
from fastapi import Path, Query

max_price: Annotated[int | None, Query(gt=0, description="Upper price limit in rupees")] = None
size:      Annotated[int, Query(ge=1, le=50)] = 3
search:    Annotated[str | None, Query(min_length=2, max_length=50)] = None
product_id: Annotated[int, Path(gt=0)]
```

| Rule | Meaning | Works on |
|------|---------|----------|
| `gt`, `ge` | Greater than / greater or equal | Numbers |
| `lt`, `le` | Less than / less or equal | Numbers |
| `min_length`, `max_length` | Length limits | Strings |
| `pattern` | Must match a regular expression | Strings |
| `description`, `examples` | Shown in `/docs` | Any |
| `alias` | Different name in the URL (e.g. `item-query`) | Any |

A page size of 100 breaks the `le=50` rule:

```bash
curl -s -w "\nHTTP %{http_code}\n" "http://127.0.0.1:8000/products?size=100"
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

Path and query parameters together:

```bash
curl -s "http://127.0.0.1:8000/products/7/price?quantity=2"
```

```{ .text .output }
{
  "product": "Running Shoes",
  "quantity": 2,
  "subtotal": 8598,
  "total": 10145.64
}
```

```bash
curl -s "http://127.0.0.1:8000/products/7/price?quantity=2&gst=false"
```

```{ .text .output }
{
  "product": "Running Shoes",
  "quantity": 2,
  "subtotal": 8598,
  "total": 8598
}
```

```bash
curl -s -w "\nHTTP %{http_code}\n" "http://127.0.0.1:8000/products/0/price?quantity=20"
```

```{ .text .output }
{
  "detail": [
    {
      "type": "greater_than",
      "loc": ["path", "product_id"],
      "msg": "Input should be greater than 0",
      "input": "0",
      "ctx": {
        "gt": 0
      }
    },
    {
      "type": "less_than_equal",
      "loc": ["query", "quantity"],
      "msg": "Input should be less than or equal to 10",
      "input": "20",
      "ctx": {
        "le": 10
      }
    }
  ]
}
HTTP 422
```

Both problems are reported **at once**, which makes life easy for the frontend developer.

!!! tip "Why limit page size?"
    Without `le=50`, anyone could request `?size=1000000` and make your server load the whole table into memory. Validation isn't just about correctness; it protects your API from accidental or deliberate overload.

### List query parameters

To accept several values for the same name (`?brand=Puma&brand=Levis`), declare a list with `Query()`:

```{ .python .no-run }
@app.get("/products/by-brands")
def by_brands(brand: Annotated[list[str], Query()] = []):
    return [p["name"] for p in PRODUCTS if p["brand"] in brand]
```

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Fixed route declared after `/{id}` | `422` "should be a valid integer" for `/products/cheapest` | Declare fixed paths first |
| Name in path ≠ function argument | It's treated as a query param; path value ignored | `/{product_id}` ↔ `product_id` |
| No type hint on a path param | Arrives as `str`; `==` with ints never matches | `product_id: int` |
| Unquoted URL with `&` in the terminal | Only the first parameter is sent | Quote the URL |
| Required query param by accident (`brand: str`) | `422` "Field required" when omitted | Give it a default (`= None`) |
| Mutable default for lists without `Query()` | Treated as a request body | `Annotated[list[str], Query()]` |
| No limit on `size` | Huge responses, slow server | `Query(le=50)` |

## Practice Exercises

Use the `main.py` from this lesson.

**Easy**

1. Add `GET /products/{product_id}/stock` that returns `{"name": ..., "in_stock": true/false, "stock": n}`.
2. Add a `sort` query parameter to `GET /products` that accepts `price` or `name` (use an `Enum`).
3. Call `GET /products/abc` and read the 422 error. Which part tells you the location of the problem?

**Medium**

4. Add `order: Literal["asc", "desc"] = "asc"` (from `typing import Literal`) to control the sort direction.
5. Add `GET /search?q=...` that requires `q` with at least 3 characters and searches name **and** brand.
6. Make `size` default to 10, with a maximum of 100, and add a `description` to every query parameter. Check how `/docs` looks.

**Challenge**

7. Add `GET /products/compare?ids=1&ids=7&ids=9` that accepts 2 to 4 product ids, returns them side by side with the cheapest one marked `"best_price": true`, and returns 404 if any id doesn't exist. Validate the count (hint: check `len(ids)` and raise `HTTPException(status_code=400, ...)`).

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    from typing import Literal

    class SortField(str, Enum):
        price = "price"
        name = "name"

    # 1
    @app.get("/products/{product_id}/stock")
    def product_stock(product_id: int):
        p = get_product(product_id)
        return {"name": p["name"], "in_stock": p["stock"] > 0, "stock": p["stock"]}

    # 2 + 4 (add to list_products' parameters and before pagination)
    #   sort: SortField = SortField.name,
    #   order: Literal["asc", "desc"] = "asc",
    #   results.sort(key=lambda p: p[sort.value], reverse=(order == "desc"))

    # 5
    @app.get("/search")
    def search(q: Annotated[str, Query(min_length=3)]):
        q = q.lower()
        return [p for p in PRODUCTS if q in p["name"].lower() or q in p["brand"].lower()]

    # 7 (declare before /products/{product_id})
    @app.get("/products/compare")
    def compare(ids: Annotated[list[int], Query()]):
        if not 2 <= len(ids) <= 4:
            raise HTTPException(status_code=400, detail="Compare between 2 and 4 products")
        items = [dict(get_product(i)) for i in ids]          # 404 if any is missing
        cheapest = min(items, key=lambda p: p["price"])
        for item in items:
            item["best_price"] = item is cheapest
        return items
    ```

!!! note "Mini Assignment"
    In your **KSR Shop API** repo, add an in-memory `CUSTOMERS` list (copy 6 customers from ksr_shop) and build: `GET /customers` with `city`, `has_phone` and pagination filters; `GET /customers/{customer_id}` with a 404 for unknown ids; and `GET /cities/{city}/customers` using an `Enum` of the cities in your data. Document every parameter so `/docs` is self-explanatory.

## Interview Questions

!!! interview "1. What is the difference between path and query parameters?"
    Path parameters are part of the URL path (`/products/7`) and identify a specific resource; they are required. Query parameters come after `?` (`?brand=Puma&page=2`) and are used for optional filtering, sorting, pagination and flags.

!!! interview "2. How does FastAPI validate parameters?"
    From type hints: values are converted to the declared type (int, float, bool, Enum…) and invalid values produce a 422 response describing the location and reason. Extra rules (`gt`, `le`, `min_length`, `pattern`) are declared with `Path()` / `Query()`, usually via `Annotated`.

!!! interview "3. Why does route order matter in FastAPI?"
    Routes are matched in the order they're declared. A parameterised route like `/products/{product_id}` would capture `/products/cheapest` if it were declared first. Fixed paths must be declared before parameterised paths that could match them.

!!! interview "4. How do you make a query parameter optional?"
    Give it a default value: `brand: str | None = None` or `page: int = 1`. Without a default, it's required.

!!! interview "5. What status code does FastAPI return for invalid input, and what does the body contain?"
    422 Unprocessable Content (also called Unprocessable Entity). The body has a `detail` list; each item contains `type`, `loc` (where: path, query, body plus the field name), `msg`, `input` and sometimes `ctx` with the rule's limits.

!!! interview "Scenario: a client sends `?size=100000` and the server slows down. How do you prevent this?"
    Validate and cap the parameter: `size: Annotated[int, Query(ge=1, le=100)] = 20`. Apply pagination in the database query (LIMIT/OFFSET), not in Python, and consider rate limiting.

## Summary

| Concept | Syntax |
|---------|--------|
| Path parameter | `@app.get("/products/{product_id}")` + `def f(product_id: int)` |
| Query parameter | Any other argument: `brand: str \| None = None` |
| Type conversion | Type hints convert; bad input returns 422 |
| Fixed choices | `class Category(str, Enum)` |
| Rules | `Annotated[int, Query(ge=1, le=50)]`, `Annotated[int, Path(gt=0)]` |
| Lists | `Annotated[list[str], Query()]` |
| Route order | Fixed paths before `/{param}` paths |
| Pagination | `page` + `size` with limits → slice / `LIMIT OFFSET` |

**Next lesson:** [Request Bodies & Pydantic](03-request-bodies-and-pydantic.md), receiving and validating JSON data.
