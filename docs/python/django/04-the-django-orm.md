---
lesson: true
category: Django
short: ORM
description: Querying MySQL with the Django ORM - QuerySets and laziness, field lookups, spanning relationships, Q and F expressions, aggregate and annotate, create/update/delete, the N+1 query problem with select_related and prefetch_related, and transactions.
---

# The Django ORM

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Retrieve rows with `all()`, `filter()`, `exclude()`, `get()`, `order_by()` and slicing, and explain why QuerySets are **lazy**
    - Use field lookups (`__icontains`, `__gte`, `__in`, `__range`, `__year`...) and follow relationships with `__`
    - Combine conditions with `Q`, compare and update columns with `F`
    - Summarise data with `aggregate()` and `annotate()` (the ORM's `GROUP BY`)
    - Create, update and delete rows, spot the **N+1 problem** and fix it with `select_related` / `prefetch_related`
    - Keep multi-step changes safe with `transaction.atomic`

**Prerequisites:** [Models & Migrations](03-models-and-migrations.md), and the SQL from the [MySQL](../../database/index.md) module (every query below has an SQL twin you already know).

All examples run in `python manage.py shell` on the KSR Store data loaded by `seed_shop`.

## QuerySets: Asking for Rows

Every model has a **manager**, `Product.objects`, which builds **QuerySets**: lists of rows that haven't been fetched yet.

```{ .python .shell }
from shop.models import Product

print(Product.objects.count())
print(Product.objects.filter(stock=0))
print(Product.objects.exclude(category__name="Electronics").count())
print(Product.objects.order_by("-price")[:3])
print(Product.objects.order_by("price").first(), "|", Product.objects.order_by("price").last())
```

```{ .text .output }
15
<QuerySet [<Product: Wings of Fire>, <Product: Yoga Mat>]>
10
<QuerySet [<Product: iPhone 15>, <Product: Galaxy S24>, <Product: Inspiron 15 Laptop>]>
USB-C Cable | iPhone 15
```

| ORM | SQL |
|-----|-----|
| `Product.objects.all()` | `SELECT * FROM shop_product` |
| `.filter(stock=0)` | `WHERE stock = 0` |
| `.exclude(...)` | `WHERE NOT (...)` |
| `.order_by("-price")` | `ORDER BY price DESC` |
| `[:3]` | `LIMIT 3` |
| `[3:6]` | `LIMIT 3 OFFSET 3` |
| `.count()` | `SELECT COUNT(*)` |
| `.exists()` | `SELECT 1 ... LIMIT 1` |

### QuerySets are lazy

Building a QuerySet runs **no SQL**. Django waits until you actually need the rows: when you loop, print, slice with a step, call `list()`, `len()` or `bool()`. That lets you build a query step by step:

```{ .python .shell }
from shop.models import Product

qs = Product.objects.filter(category__name="Fashion")
qs = qs.exclude(stock__lt=50)
qs = qs.order_by("price")
print(qs.query)
print([p.name for p in qs])
```

```{ .text .output }
SELECT `shop_product`.`id`, `shop_product`.`category_id`, `shop_product`.`name`, `shop_product`.`brand`, `shop_product`.`price`, `shop_product`.`stock`, `shop_product`.`rating`, `shop_product`.`added_on` FROM `shop_product` INNER JOIN `shop_category` ON (`shop_product`.`category_id` = `shop_category`.`id`) WHERE (`shop_category`.`name` = Fashion AND NOT (`shop_product`.`stock` < 50)) ORDER BY `shop_product`.`price` ASC
['Cotton T-Shirt', 'Running Shoes']
```

`print(qs.query)` shows the SQL Django will send, which is great for learning and debugging. Notice the `INNER JOIN`: `category__name` made Django join the category table for you.

### `get()`: exactly one row

`get()` returns one object, and raises an error if there are zero or several matches:

```{ .python .shell }
from shop.models import Product

print(Product.objects.get(pk=10))

try:
    Product.objects.get(pk=999)
except Product.DoesNotExist:
    print("No product with id 999")

try:
    Product.objects.get(brand="Puma")
except Product.MultipleObjectsReturned:
    print("More than one Puma product")
```

```{ .text .output }
Wings of Fire
No product with id 999
More than one Puma product
```

In views, prefer `get_object_or_404()`, which turns `DoesNotExist` into a 404 page.

### `values()` and `values_list()`: just the columns you need

```{ .python .shell }
from shop.models import Customer

print(list(Customer.objects.filter(city="Pune").values("name", "email")))
print(list(Customer.objects.values_list("city", flat=True).distinct().order_by("city")))
```

```{ .text .output }
[{'name': 'Rahul Verma', 'email': 'rahul@example.com'}, {'name': 'Sneha Patil', 'email': 'sneha@example.com'}]
['Bangalore', 'Chennai', 'Delhi', 'Hyderabad', 'Kochi', 'Mumbai', 'Pune']
```

## Field Lookups

A lookup is written `field__lookup=value` (two underscores):

```{ .python .shell }
from datetime import date
from shop.models import Customer, Order, Product

print(Product.objects.filter(name__icontains="shirt"))
print(Product.objects.filter(price__gte=50000).values_list("name", "price"))
print(Product.objects.filter(brand__in=["Puma", "Levis"]).count())
print(Product.objects.filter(price__range=(1000, 2000)).values_list("name", flat=True))
print(Customer.objects.filter(phone="").values_list("name", flat=True))
print(Order.objects.filter(order_date__year=2025, order_date__month=10).count())
print(Product.objects.filter(added_on__gte=date(2025, 9, 1)).values_list("name", flat=True))
```

```{ .text .output }
<QuerySet [<Product: Cotton T-Shirt>]>
<QuerySet [('Galaxy S24', Decimal('74999.00')), ('Inspiron 15 Laptop', Decimal('58999.00')), ('iPhone 15', Decimal('79999.00'))]>
3
<QuerySet ['Airdopes 141', 'Non-stick Pan']>
<QuerySet ['Divya Nair', 'Kiran Rao', 'Priya Sharma']>
3
<QuerySet ['Denim Jacket', 'iPhone 15', 'Running Shoes']>
```

| Lookup | SQL | Example |
|--------|-----|---------|
| `exact` (default) | `=` | `filter(stock=0)` |
| `iexact` | case-insensitive `=` | `filter(city__iexact="pune")` |
| `contains` / `icontains` | `LIKE '%x%'` | `filter(name__icontains="shirt")` |
| `startswith` / `endswith` | `LIKE 'x%'` / `LIKE '%x'` | `filter(name__startswith="i")` |
| `gt`, `gte`, `lt`, `lte` | `>`, `>=`, `<`, `<=` | `filter(price__gte=50000)` |
| `in` | `IN (...)` | `filter(brand__in=[...])` |
| `range` | `BETWEEN` | `filter(price__range=(1000, 2000))` |
| `isnull` | `IS NULL` | `filter(rating__isnull=True)` |
| `year`, `month`, `day` | date parts | `filter(order_date__year=2025)` |

## Following Relationships

Double underscores also **cross foreign keys**, in both directions:

```{ .python .shell }
from shop.models import Category, Customer, Order

# forward: order -> customer -> city
print(Order.objects.filter(customer__city="Hyderabad").count())

# reverse: category -> its products (related_name="products")
print(Category.objects.filter(products__stock=0).values_list("name", flat=True))

# two hops: customers who bought a book
print(Customer.objects.filter(orders__items__product__category__name="Books").distinct().values_list("name", flat=True))

# categories with no products at all
print(Category.objects.filter(products__isnull=True).values_list("name", flat=True))
```

```{ .text .output }
4
<QuerySet ['Books', 'Sports']>
<QuerySet ['Asha Reddy', 'Meena Iyer', 'Ravi Kumar', 'Sneha Patil']>
<QuerySet ['Toys']>
```

`.distinct()` matters in the third query: the join produces one row per matching order item, so a customer who bought several books would otherwise be listed several times.

## `Q` and `F` Expressions

Keyword arguments to `filter()` are combined with **AND**. For **OR** and **NOT**, wrap conditions in `Q` objects:

```{ .python .shell }
from django.db.models import Q
from shop.models import Product

cheap_or_books = Product.objects.filter(Q(price__lt=500) | Q(category__name="Books"))
print(cheap_or_books.values_list("name", flat=True))

fashion_not_puma = Product.objects.filter(Q(category__name="Fashion") & ~Q(brand="Puma"))
print(fashion_not_puma.values_list("name", flat=True))
```

```{ .text .output }
<QuerySet ['Atomic Habits', 'Python Crash Course', 'USB-C Cable', 'Wings of Fire']>
<QuerySet ['Denim Jacket']>
```

| Operator | Meaning |
|----------|---------|
| `Q(a) \| Q(b)` | `a OR b` |
| `Q(a) & Q(b)` | `a AND b` |
| `~Q(a)` | `NOT a` |

An `F` expression refers to **another column** of the same row, so the work happens inside MySQL:

```{ .python .shell }
from django.db.models import F
from shop.models import OrderItem, Product

# items sold at a price different from today's product price (none yet)
print(OrderItem.objects.exclude(unit_price=F("product__price")).count())

# add 10 to stock for every Sports product, in ONE UPDATE statement
updated = Product.objects.filter(category__name="Sports").update(stock=F("stock") + 10)
print(updated, "rows updated")
print(Product.objects.filter(category__name="Sports").values_list("name", "stock"))
```

```{ .text .output }
0
2 rows updated
<QuerySet [('Cricket Bat', 32), ('Yoga Mat', 10)]>
```

!!! mistake "Read-modify-write race condition"
    ```{ .python .no-run }
    product = Product.objects.get(pk=1)
    product.stock = product.stock - 1   # two customers at once both read 25...
    product.save()                      # ...and both save 24. One sale is lost.
    ```
    `Product.objects.filter(pk=1).update(stock=F("stock") - 1)` makes MySQL do `stock = stock - 1` atomically, so no sale is lost.

## Aggregation: `aggregate()` and `annotate()`

`aggregate()` summarises a whole QuerySet into **one dict**:

```{ .python .shell }
from django.db.models import Avg, Count, Max, Min, Sum
from shop.models import Product

print(Product.objects.aggregate(Count("id"), Min("price"), Max("price")))
stats = Product.objects.aggregate(avg_price=Avg("price"), total_stock=Sum("stock"))
print(f"Average price: {stats['avg_price']:.2f}, units in stock: {stats['total_stock']}")
```

```{ .text .output }
{'id__count': 15, 'price__min': Decimal('299.00'), 'price__max': Decimal('79999.00')}
Average price: 15749.07, units in stock: 1207
```

`annotate()` adds a calculated value **to every row**, which is SQL's `GROUP BY`:

```{ .python .shell }
from django.db.models import Count, Sum
from shop.models import Category

categories = Category.objects.annotate(product_count=Count("products"), units=Sum("products__stock"))
for c in categories.order_by("-product_count", "name"):
    print(f"{c.name:<15} {c.product_count} products, {c.units or 0} units")
```

```{ .text .output }
Electronics     5 products, 767 units
Books           3 products, 95 units
Fashion         3 products, 250 units
Home & Kitchen  2 products, 53 units
Sports          2 products, 42 units
Toys            0 products, 0 units
```

Revenue per customer from delivered orders, using `F` to multiply quantity by price:

```{ .python .shell }
from django.db.models import Count, F, Sum
from shop.models import Customer

delivered = {"orders__status": "delivered"}
top = (
    Customer.objects.filter(**delivered)
    .annotate(orders_count=Count("orders", distinct=True),
              revenue=Sum(F("orders__items__quantity") * F("orders__items__unit_price")))
    .order_by("-revenue")[:3]
)
for c in top:
    print(f"{c.name:<12} orders={c.orders_count}  revenue=₹{c.revenue:,.2f}")
```

```{ .text .output }
Ravi Kumar   orders=2  revenue=₹77,697.00
Asha Reddy   orders=2  revenue=₹8,993.00
Divya Nair   orders=1  revenue=₹3,499.00
```

| SQL | ORM |
|-----|-----|
| `SELECT COUNT(*), AVG(price) FROM ...` | `.aggregate(Count("id"), Avg("price"))` |
| `GROUP BY category_id` + `COUNT(*)` | `Category.objects.annotate(n=Count("products"))` |
| `HAVING COUNT(*) > 2` | `.annotate(n=Count("products")).filter(n__gt=2)` |
| `SUM(quantity * unit_price)` | `Sum(F("quantity") * F("unit_price"))` |

## Creating, Updating and Deleting

```{ .python .shell }
from shop.models import Category, Product

toys = Category.objects.get(slug="toys")

# create: INSERT
lego = Product.objects.create(category=toys, name="Lego Classic Box", brand="Lego", price=2999, stock=10)
print("created", lego.id, lego)

# update one object: change attributes, then save()
lego.price = 2799
lego.save(update_fields=["price"])
print(Product.objects.get(pk=lego.id).price)

# get_or_create: fetch it, or create it if missing
puzzle, created = Product.objects.get_or_create(name="Jigsaw Puzzle", defaults={"category": toys, "price": 599})
print(puzzle, "created" if created else "already existed")
puzzle, created = Product.objects.get_or_create(name="Jigsaw Puzzle", defaults={"category": toys, "price": 599})
print(puzzle, "created" if created else "already existed")

# bulk update: one UPDATE for many rows
print(Product.objects.filter(category=toys).update(stock=25), "toys restocked")

# delete: returns how many rows were deleted, per model
print(Product.objects.filter(category=toys).delete())
```

```{ .text .output }
created 16 Lego Classic Box
2799.00
Jigsaw Puzzle created
Jigsaw Puzzle already existed
2 toys restocked
(2, {'shop.Product': 2})
```

| Task | Code |
|------|------|
| Insert one | `Model.objects.create(...)` or `obj = Model(...); obj.save()` |
| Insert many | `Model.objects.bulk_create([Model(...), ...])` |
| Update one | change attributes, then `obj.save()` |
| Update many | `queryset.update(field=value)` (no `save()` signals) |
| Delete | `obj.delete()` or `queryset.delete()` |
| Fetch or create | `Model.objects.get_or_create(..., defaults={...})` |
| Create or update | `Model.objects.update_or_create(..., defaults={...})` |

Our experiments changed the data, so reset it:

```bash
python manage.py seed_shop
```

```{ .text .output }
Loaded 6 categories, 15 products, 10 customers, 12 orders and 17 order items.
```

## The N+1 Query Problem

Look at this innocent loop. How many queries does it run?

```{ .python .shell }
from django.test.utils import CaptureQueriesContext
from django.db import connection
from shop.models import Product

with CaptureQueriesContext(connection) as ctx:
    for p in Product.objects.all()[:5]:
        print(p.name, "-", p.category.name)
print("queries:", len(ctx.captured_queries))
```

```{ .text .output }
Airdopes 141 - Electronics
Atomic Habits - Books
Cotton T-Shirt - Fashion
Cricket Bat - Sports
Denim Jacket - Fashion
queries: 6
```

One query for the products, plus **one more for each product's category**: 1 + N. With 1,000 products that's 1,001 round trips to MySQL. This is the most common Django performance bug.

**`select_related`** fixes foreign-key (forward) access with a JOIN:

```{ .python .shell }
from django.test.utils import CaptureQueriesContext
from django.db import connection
from shop.models import Product

with CaptureQueriesContext(connection) as ctx:
    for p in Product.objects.select_related("category")[:5]:
        print(p.name, "-", p.category.name)
print("queries:", len(ctx.captured_queries))
```

```{ .text .output }
Airdopes 141 - Electronics
Atomic Habits - Books
Cotton T-Shirt - Fashion
Cricket Bat - Sports
Denim Jacket - Fashion
queries: 1
```

**`prefetch_related`** fixes reverse and many-to-many access with one extra query for all children:

```{ .python .shell }
from django.test.utils import CaptureQueriesContext
from django.db import connection
from shop.models import Order

with CaptureQueriesContext(connection) as ctx:
    orders = Order.objects.select_related("customer").prefetch_related("items__product").order_by("id")[:4]
    for order in orders:
        names = ", ".join(item.product.name for item in order.items.all())
        print(f"{order} {order.customer.name:<11} {names}")
print("queries:", len(ctx.captured_queries))
```

```{ .text .output }
Order #1 Asha Reddy  Atomic Habits, Airdopes 141
Order #2 Ravi Kumar  Galaxy S24
Order #3 Asha Reddy  Running Shoes, Cotton T-Shirt
Order #4 Kiran Rao   Inspiron 15 Laptop
queries: 3
```

| Relationship you access | Use |
|-------------------------|-----|
| Forward `ForeignKey` / `OneToOneField` (`product.category`) | `select_related("category")` (SQL JOIN) |
| Reverse FK / `ManyToManyField` (`order.items.all()`) | `prefetch_related("items")` (second query, joined in Python) |

!!! tip "Find N+1 problems early"
    In development, install **django-debug-toolbar** to see every query a page runs, or wrap code in `CaptureQueriesContext` as above. In tests, `self.assertNumQueries(2)` fails if the count changes (lesson 10).

## Transactions

Placing an order touches several tables: create the order, create its items, reduce stock. Either **all** of that should happen, or **none** of it. `transaction.atomic` gives you that:

```python title="shop/services.py"
from django.db import transaction
from django.db.models import F

from .models import Customer, Order, OrderItem, Product


class OutOfStock(Exception):
    pass


@transaction.atomic
def place_order(customer: Customer, items: dict[int, int]) -> Order:
    """items maps product id -> quantity."""
    order = Order.objects.create(customer=customer)
    for product_id, quantity in items.items():
        product = Product.objects.select_for_update().get(pk=product_id)
        if product.stock < quantity:
            raise OutOfStock(f"Only {product.stock} x {product.name} left")
        OrderItem.objects.create(order=order, product=product, quantity=quantity, unit_price=product.price)
        Product.objects.filter(pk=product.pk).update(stock=F("stock") - quantity)
    return order
```

- `@transaction.atomic` starts a transaction; an exception **rolls back** everything done inside it.
- `select_for_update()` locks the product rows until the transaction ends, so two orders can't oversell the same stock.

```{ .python .shell }
from shop.models import Customer, Order, Product
from shop.services import OutOfStock, place_order

asha = Customer.objects.get(email="asha@example.com")
order = place_order(asha, {3: 2, 9: 1})
print(order, order.total, "| Airdopes stock:", Product.objects.get(pk=3).stock)

before = Order.objects.count()
try:
    place_order(asha, {1: 1, 10: 1})      # Wings of Fire has 0 stock
except OutOfStock as e:
    print("Failed:", e)
print("orders before/after:", before, Order.objects.count(), "| iPhone stock:", Product.objects.get(pk=1).stock)
```

```{ .text .output }
Order #13 3097.00 | Airdopes stock: 198
Failed: Only 0 x Wings of Fire left
orders before/after: 13 13 | iPhone stock: 25
```

The failed order created an `Order` row and reduced the iPhone stock **before** it hit the out-of-stock product, yet both changes were rolled back: the order count and iPhone stock are unchanged.

```bash
python manage.py seed_shop
```

```{ .text .output }
Loaded 6 categories, 15 products, 10 customers, 12 orders and 17 order items.
```

## Using the ORM in a View

Put `annotate` to work: show categories with product counts on the home page.

```python title="shop/views.py"
from django.db.models import Count
from django.http import JsonResponse
from django.shortcuts import get_object_or_404, redirect, render

from .models import Category, Product


def home(request):
    featured = Product.objects.select_related("category").filter(stock__gt=0)[:3]
    categories = Category.objects.annotate(product_count=Count("products")).order_by("name")
    return render(request, "shop/home.html", {"featured": featured, "categories": categories})


def health(request):
    return JsonResponse({"status": "ok", "framework": "Django"})


def product_list(request):
    query = request.GET.get("q", "").strip()
    products = Product.objects.select_related("category")
    if query:
        products = products.filter(name__icontains=query)
    return render(request, "shop/product_list.html", {"products": products, "query": query})


def product_detail(request, product_id):
    product = get_object_or_404(Product.objects.select_related("category"), pk=product_id)
    return render(request, "shop/product_detail.html", {"product": product})


def category_products(request, slug):
    category = get_object_or_404(Category, slug=slug)
    products = category.products.all()
    return render(request, "shop/product_list.html", {"products": products, "query": "", "category": category})


def old_shop_redirect(request):
    return redirect("shop:product_list")
```

```html title="shop/templates/shop/home.html"
{% extends "base.html" %}

{% block title %}Home | KSR Store{% endblock %}

{% block content %}
<h1>Welcome to KSR Store</h1>
<h2>Featured products</h2>
<ul>
{% for product in featured %}
  <li><a href="{% url 'shop:product_detail' product.id %}">{{ product.name }}</a> - ₹{{ product.price|floatformat:"0g" }}</li>
{% endfor %}
</ul>
<h2>Shop by category</h2>
<ul class="categories">
{% for category in categories %}
  <li><a href="{% url 'shop:category' category.slug %}">{{ category.name }}</a> ({{ category.product_count }})</li>
{% endfor %}
</ul>
{% endblock %}
```

```bash
curl -s http://127.0.0.1:8000/ | grep '/category/'
```

```{ .text .output }
  <li><a href="/category/books/">Books</a> (3)</li>
  <li><a href="/category/electronics/">Electronics</a> (5)</li>
  <li><a href="/category/fashion/">Fashion</a> (3)</li>
  <li><a href="/category/home-kitchen/">Home &amp; Kitchen</a> (2)</li>
  <li><a href="/category/sports/">Sports</a> (2)</li>
  <li><a href="/category/toys/">Toys</a> (0)</li>
```

One query with `GROUP BY` produced all six counts, including Toys with 0. We added `.order_by("name")` because a `GROUP BY` query doesn't use the model's `Meta.ordering`.

!!! realworld "In Real Projects"
    Most Django performance work is ORM work: adding `select_related` / `prefetch_related`, fetching only needed columns with `values()` or `only()`, adding database indexes for common filters, and moving business logic like `place_order` into a **services** module wrapped in transactions. Teams watch query counts per page in development, and in production use tools like Sentry or New Relic to find slow queries.

## Common Mistakes

| Mistake | Error / Symptom | Fix |
|---------|-----------------|-----|
| `get()` with no or many matches | `DoesNotExist` / `MultipleObjectsReturned` | `filter().first()`, or catch the error, or `get_object_or_404` |
| One underscore in a lookup | `FieldError: Cannot resolve keyword 'price_gte'` | Two underscores: `price__gte` |
| Accessing related objects in a loop | Page runs hundreds of queries (N+1) | `select_related` / `prefetch_related` |
| Duplicate rows after a reverse join | Same customer listed twice | `.distinct()` |
| `obj.stock -= 1; obj.save()` under load | Lost updates | `update(stock=F("stock") - 1)` |
| `queryset.update()` expecting `save()` to run | Custom `save()` logic skipped | Loop and `save()`, or put the logic elsewhere |
| `len(queryset)` just to count | Fetches every row | `queryset.count()` |
| `if queryset:` just to check existence | Fetches every row | `queryset.exists()` |

## Practice Exercises

**Easy**

1. List the names of all products under ₹1,000, cheapest first.
2. Count customers per city using `values("city").annotate(n=Count("id"))`.
3. Find all orders that are `pending` or `shipped` using `status__in`.

**Medium**

4. Find the best-selling product by total quantity ordered (`annotate(sold=Sum("order_items__quantity"))`).
5. List customers who have **never** placed an order.
6. Calculate the total revenue of each order with `annotate` (no Python loop), and print the three largest orders.

**Challenge**

7. Write a `monthly_revenue()` function that returns revenue per month for delivered orders, using `TruncMonth("order_date")` from `django.db.models.functions`, with `values()` + `annotate()`. Print it as `2025-06  ₹76,297.00`.

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    from django.db.models import Count, F, Sum
    from django.db.models.functions import TruncMonth
    from shop.models import Customer, Order, Product

    # 1
    print(Product.objects.filter(price__lt=1000).order_by("price").values_list("name", flat=True))
    # 2
    print(Customer.objects.values("city").annotate(n=Count("id")).order_by("-n"))
    # 3
    print(Order.objects.filter(status__in=["pending", "shipped"]))
    # 4
    print(Product.objects.annotate(sold=Sum("order_items__quantity")).order_by(F("sold").desc(nulls_last=True)).first())
    # 5
    print(Customer.objects.filter(orders__isnull=True))
    # 6
    orders = Order.objects.annotate(revenue=Sum(F("items__quantity") * F("items__unit_price"))).order_by("-revenue")[:3]
    for o in orders:
        print(o, o.revenue)

    # 7
    def monthly_revenue():
        return (
            Order.objects.filter(status="delivered")
            .annotate(month=TruncMonth("order_date"))
            .values("month")
            .annotate(revenue=Sum(F("items__quantity") * F("items__unit_price")))
            .order_by("month")
        )

    for row in monthly_revenue():
        print(f"{row['month']:%Y-%m}  ₹{row['revenue']:,.2f}")
    ```

!!! note "Mini Assignment"
    Build a **sales report** management command, `python manage.py sales_report`, that prints: total revenue from delivered orders, revenue per category, the top 3 customers, products that were never ordered, and products that are out of stock. Use `CaptureQueriesContext` to keep the whole report under 10 queries.

## Interview Questions

!!! interview "1. What does it mean that QuerySets are lazy?"
    Creating or chaining a QuerySet doesn't hit the database. The SQL runs only when the results are needed: iteration, `list()`, `len()`, slicing with a step, `bool()`, or methods like `get()`, `count()` and `exists()`. Evaluated results are cached on the QuerySet.

!!! interview "2. What is the difference between `select_related` and `prefetch_related`?"
    `select_related` follows forward foreign keys and one-to-one fields with an SQL JOIN in the same query. `prefetch_related` handles reverse foreign keys and many-to-many relationships by running one extra query per relationship and joining the results in Python.

!!! interview "3. What is the N+1 problem?"
    Fetching a list (1 query) and then triggering an extra query for each item's related data (N queries), usually by accessing a relationship inside a loop or template. It's fixed with `select_related` / `prefetch_related`.

!!! interview "4. What is the difference between `aggregate()` and `annotate()`?"
    `aggregate()` returns a single dict summarising the whole QuerySet (like `SELECT SUM(...)` without `GROUP BY`). `annotate()` adds a computed value to each object in the QuerySet (like `GROUP BY` per row).

!!! interview "5. What are `Q` and `F` objects?"
    `Q` objects wrap conditions so they can be combined with `|` (OR), `&` (AND) and `~` (NOT). `F` objects reference a column's value inside the database, for comparing two fields or doing atomic updates such as `update(stock=F("stock") - 1)`.

!!! interview "Scenario: the order history page takes 4 seconds. How do you investigate?"
    Check the number and duration of queries with django-debug-toolbar or `CaptureQueriesContext`. Typical fixes are adding `select_related("customer")` and `prefetch_related("items__product")` to remove N+1 queries, paginating instead of loading every order, computing totals with `annotate` in SQL, and adding an index on the filtered columns (for example `customer_id, order_date`).

## Summary

| Task | ORM |
|------|-----|
| Filter / exclude / sort / limit | `.filter(price__gte=1000).exclude(stock=0).order_by("-price")[:5]` |
| One object | `.get(pk=1)` · `get_object_or_404(Model, pk=1)` |
| Lookups | `__icontains`, `__gte`, `__in`, `__range`, `__isnull`, `__year` |
| Relationships | `filter(category__name="Books")` · `filter(orders__items__product=...)` |
| OR / NOT | `Q(a) \| Q(b)` · `~Q(a)` |
| Column math | `F("stock") - 1` · `Sum(F("quantity") * F("unit_price"))` |
| Summaries | `.aggregate(Avg("price"))` · `.annotate(n=Count("products"))` |
| Avoid N+1 | `select_related("fk")` · `prefetch_related("reverse_fk")` |
| All or nothing | `@transaction.atomic` + `select_for_update()` |

**Next lesson:** [Django Admin](05-django-admin.md), a complete back office for the shop in a few lines of code.
