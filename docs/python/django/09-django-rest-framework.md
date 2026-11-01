---
lesson: true
category: Django
short: DRF
description: Building a JSON API with Django REST Framework - serializers and validation, ViewSets and routers, filtering and pagination, custom actions, token and session authentication, permissions (DjangoModelPermissions), status codes, and how DRF compares with FastAPI.
---

# Django REST Framework

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain what Django REST Framework (DRF) adds to Django, and compare it with FastAPI
    - Convert models to and from JSON with **serializers**, including validation
    - Build a full CRUD API with a **ViewSet** and a **router**, with filtering and pagination
    - Add a custom endpoint with `@action`
    - Secure the API with **token authentication** and **permissions**, and return the right status codes

**Prerequisites:** [Authentication & Authorization](08-authentication-and-authorization.md) and the [FastAPI](../fastapi/index.md) module (you know REST, JSON and status codes).

## Why DRF?

So far the KSR Store returns HTML for browsers. A mobile app or a React frontend (later in this course) needs **JSON**. Django can return JSON (`JsonResponse`), but an API needs much more: input validation, consistent errors, authentication by token, permissions, pagination, filtering and documentation. **Django REST Framework** provides all of that on top of your existing models and users.

| Concept | FastAPI (you know it) | Django REST Framework |
|---------|----------------------|-----------------------|
| Request / response schema | Pydantic model | **Serializer** |
| Endpoint | `@app.get("/products")` function | `APIView`, generic views, **ViewSet** |
| URL registration | Decorators on functions | `urls.py`, **routers** for ViewSets |
| Database | SQLAlchemy (you wire it up) | Django ORM (already there) |
| Auth | You build JWT / dependencies | Session, token, permission classes built in |
| Docs | Swagger UI built in | Browsable API built in; OpenAPI via drf-spectacular |
| Async | Async-first | Mostly synchronous |

Choose DRF when you already have (or want) a Django project with its admin, ORM and auth. Choose FastAPI for small, fast, async-first services.

## Installing DRF

```{ .bash .no-run }
pip install djangorestframework
```

```bash
python -c "import rest_framework; print('DRF', rest_framework.VERSION)"
python manage.py startapp api
```

```{ .text .output }
DRF 3.18.3
```

Add DRF, its token app and our `api` app to `INSTALLED_APPS`:

```{ .python .edit title="config/settings.py" }
INSTALLED_APPS = [
    ...
    "accounts",
    "rest_framework",  # new
    "rest_framework.authtoken",  # new
    "api",  # new
]
```

and configure DRF at the end of `settings.py`. These defaults apply to every API view unless a view overrides them:

```{ .python .append title="config/settings.py" }
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.TokenAuthentication",
        "rest_framework.authentication.SessionAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticatedOrReadOnly"],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 5,
}
```

`rest_framework.authtoken` has a model (one token per user), so migrate:

```bash
python manage.py migrate
```

```{ .text .output }
Operations to perform:
  Apply all migrations: admin, auth, authtoken, contenttypes, sessions, shop
Running migrations:
  Applying authtoken.0001_initial... OK
  Applying authtoken.0002_auto_20160226_1747... OK
  Applying authtoken.0003_tokenproxy... OK
  Applying authtoken.0004_alter_tokenproxy_options... OK
```

## Serializers

A serializer converts model instances to Python dicts (then JSON), and validates incoming data before saving it. A **`ModelSerializer`** builds its fields from the model, like a `ModelForm`:

```python title="api/serializers.py"
from rest_framework import serializers

from shop.models import Category, Product, Review


class CategorySerializer(serializers.ModelSerializer):
    product_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Category
        fields = ["id", "name", "slug", "product_count"]


class ProductSerializer(serializers.ModelSerializer):
    category = serializers.SlugRelatedField(slug_field="slug", queryset=Category.objects.all())
    category_name = serializers.CharField(source="category.name", read_only=True)
    in_stock = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = ["id", "name", "category", "category_name", "brand", "price", "stock", "rating", "in_stock", "added_on"]
        read_only_fields = ["rating"]

    def get_in_stock(self, obj):
        return obj.stock > 0

    def validate_price(self, value):
        if value <= 0:
            raise serializers.ValidationError("Price must be greater than zero.")
        return value


class ReviewSerializer(serializers.ModelSerializer):
    comment = serializers.CharField(min_length=10, max_length=500)

    class Meta:
        model = Review
        fields = ["id", "name", "rating", "comment", "created_at"]
        read_only_fields = ["name", "created_at"]
```

| Field style | Example | Meaning |
|-------------|---------|---------|
| From the model | `"name"`, `"price"` | Type, `max_length`, required-ness taken from the model |
| `SlugRelatedField` | `category` | Shows and accepts the category's **slug** (`"books"`) instead of its id |
| `source=` | `category_name` | Reads a value through a relationship (`product.category.name`) |
| `SerializerMethodField` | `in_stock` | Calculated by `get_<field>()`; read-only |
| `read_only_fields` | `rating` | Included in output, ignored in input |
| `validate_<field>()` | `validate_price` | Extra rule for one field (like `clean_<field>()` in forms) |

Try it in the shell:

```{ .python .shell }
import json
from api.serializers import ProductSerializer
from shop.models import Product

data = ProductSerializer(Product.objects.get(pk=9)).data
print(json.dumps(data, indent=2))

bad = ProductSerializer(data={"name": "", "category": "gadgets", "price": "-10", "stock": 5})
print(bad.is_valid())
print(json.dumps(bad.errors, indent=2))
```

```{ .text .output }
{
  "id": 9,
  "name": "Atomic Habits",
  "category": "books",
  "category_name": "Books",
  "brand": "Penguin",
  "price": "499.00",
  "stock": 80,
  "rating": "4.8",
  "in_stock": true,
  "added_on": "2025-01-20"
}
False
{
  "name": [
    "This field may not be blank."
  ],
  "category": [
    "Object with slug=gadgets does not exist."
  ],
  "price": [
    "Price must be greater than zero."
  ]
}
```

Notice `"price": "499.00"` is a **string**: DRF sends decimals as strings by default so no precision is lost in JavaScript.

## ViewSets and Routers

A **ViewSet** groups all the actions on one resource in a class. `ModelViewSet` gives list, create, retrieve, update, partial update and delete:

```python title="api/views.py"
from django.db.models import Count
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import DjangoModelPermissionsOrAnonReadOnly, IsAuthenticatedOrReadOnly
from rest_framework.response import Response

from shop.models import Category, Product

from .serializers import CategorySerializer, ProductSerializer, ReviewSerializer


class CategoryViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Category.objects.annotate(product_count=Count("products")).order_by("name")
    serializer_class = CategorySerializer
    lookup_field = "slug"
    pagination_class = None


class ProductViewSet(viewsets.ModelViewSet):
    serializer_class = ProductSerializer
    permission_classes = [DjangoModelPermissionsOrAnonReadOnly]

    def get_queryset(self):
        products = Product.objects.select_related("category")
        params = self.request.query_params
        if category := params.get("category"):
            products = products.filter(category__slug=category)
        if search := params.get("search"):
            products = products.filter(name__icontains=search)
        if params.get("in_stock") == "true":
            products = products.filter(stock__gt=0)
        if params.get("ordering") in ("price", "-price", "name", "-name"):
            products = products.order_by(params["ordering"])
        return products

    @action(detail=True, methods=["get", "post"], permission_classes=[IsAuthenticatedOrReadOnly])
    def reviews(self, request, pk=None):
        product = self.get_object()
        if request.method == "POST":
            serializer = ReviewSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            serializer.save(product=product, user=request.user, name=request.user.username)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(ReviewSerializer(product.reviews.all(), many=True).data)
```

A **router** creates the URLs for every ViewSet action:

```python title="api/urls.py"
from django.urls import include, path
from rest_framework.authtoken.views import obtain_auth_token
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register("categories", views.CategoryViewSet, basename="category")
router.register("products", views.ProductViewSet, basename="product")

urlpatterns = [
    path("", include(router.urls)),
    path("token/", obtain_auth_token, name="api_token"),
]
```

```{ .python .edit title="config/urls.py" }
urlpatterns = [
    path("admin/", admin.site.urls),
    path("accounts/", include("accounts.urls")),
    path("api/", include("api.urls")),  # new
```

The router generated these endpoints:

| Method + URL | ViewSet action | Who may call it |
|--------------|----------------|-----------------|
| `GET /api/products/` | `list` | Anyone |
| `POST /api/products/` | `create` | Users with `shop.add_product` |
| `GET /api/products/9/` | `retrieve` | Anyone |
| `PUT` / `PATCH /api/products/9/` | `update` / `partial_update` | Users with `shop.change_product` |
| `DELETE /api/products/9/` | `destroy` | Users with `shop.delete_product` |
| `GET` / `POST /api/products/9/reviews/` | our `@action` | Anyone / logged-in users |
| `GET /api/categories/`, `/api/categories/books/` | `list`, `retrieve` | Anyone |
| `POST /api/token/` | get a token | Anyone with a valid username and password |

`DjangoModelPermissionsOrAnonReadOnly` maps HTTP methods to the **model permissions** from lessons 05 and 08, so the same "Store managers" group controls the admin, the staff pages **and** the API.

## Reading the API

The API root lists the resources (open it in a browser to see DRF's **browsable API**, an HTML page where you can click through and even submit data):

```bash
curl -s http://127.0.0.1:8000/api/
```

```{ .text .output }
{
  "categories": "http://127.0.0.1:8000/api/categories/",
  "products": "http://127.0.0.1:8000/api/products/"
}
```

```bash
curl -s http://127.0.0.1:8000/api/categories/
```

```{ .text .output }
[
  {
    "id": 3,
    "name": "Books",
    "slug": "books",
    "product_count": 3
  },
  {
    "id": 1,
    "name": "Electronics",
    "slug": "electronics",
    "product_count": 5
  },
  {
    "id": 2,
    "name": "Fashion",
    "slug": "fashion",
    "product_count": 3
  },
  {
    "id": 4,
    "name": "Home & Kitchen",
    "slug": "home-kitchen",
    "product_count": 2
  },
  {
    "id": 5,
    "name": "Sports",
    "slug": "sports",
    "product_count": 2
  },
  {
    "id": 6,
    "name": "Toys",
    "slug": "toys",
    "product_count": 0
  }
]
```

Filtering with query parameters, wrapped in DRF's pagination format (`count`, `next`, `previous`, `results`):

```bash
curl -s "http://127.0.0.1:8000/api/products/?category=books&ordering=-price"
```

```{ .text .output }
{
  "count": 3,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 11,
      "name": "Python Crash Course",
      "category": "books",
      "category_name": "Books",
      "brand": "No Starch",
      "price": "2199.00",
      "stock": 15,
      "rating": "4.6",
      "in_stock": true,
      "added_on": "2025-04-18"
    },
    {
      "id": 9,
      "name": "Atomic Habits",
      "category": "books",
      "category_name": "Books",
      "brand": "Penguin",
      "price": "499.00",
      "stock": 80,
      "rating": "4.8",
      "in_stock": true,
      "added_on": "2025-01-20"
    },
    {
      "id": 10,
      "name": "Wings of Fire",
      "category": "books",
      "category_name": "Books",
      "brand": "Universities Press",
      "price": "350.00",
      "stock": 0,
      "rating": "4.7",
      "in_stock": false,
      "added_on": "2024-11-10"
    }
  ]
}
```

All 15 products don't fit on one page of 5. We print just the summary with a little Python:

```bash
curl -s "http://127.0.0.1:8000/api/products/?page=2" | python -c "import json, sys; d = json.load(sys.stdin); print(d['count'], d['next'], d['previous']); print([p['name'] for p in d['results']])"
```

```{ .text .output }
15 http://127.0.0.1:8000/api/products/?page=3 http://127.0.0.1:8000/api/products/
['Galaxy S24', 'Inspiron 15 Laptop', 'iPhone 15', 'Mixer Grinder', 'Non-stick Pan']
```

A product that doesn't exist, and the `reviews` action:

```bash
curl -s -w "\nHTTP %{http_code}" http://127.0.0.1:8000/api/products/999/
```

```{ .text .output }
{
  "detail": "No Product matches the given query."
}
HTTP 404
```

```bash
curl -s http://127.0.0.1:8000/api/products/9/reviews/
```

```{ .text .output }
[]
```

## Authentication with Tokens

A mobile app can't easily use session cookies and CSRF tokens. Instead it sends a **token** in a header: `Authorization: Token <key>`. Anonymous writes are refused with **401**:

```bash
curl -s -w "\nHTTP %{http_code}" -X POST http://127.0.0.1:8000/api/products/ -H "Content-Type: application/json" -d '{"name": "Test"}'
```

```{ .text .output }
{
  "detail": "Authentication credentials were not provided."
}
HTTP 401
```

Get a token by posting a username and password to `/api/token/`. We save each token to a file instead of printing the secret:

```bash
curl -s -d "username=meena&password=Practice@123" http://127.0.0.1:8000/api/token/ \
  | python -c "import json, sys; print(json.load(sys.stdin)['token'])" > meena.token
curl -s -d "username=admin&password=KsrAdmin@2026" http://127.0.0.1:8000/api/token/ \
  | python -c "import json, sys; print(json.load(sys.stdin)['token'])" > admin.token
curl -s -d "username=kiran&password=Kiran@Learns2026" http://127.0.0.1:8000/api/token/ \
  | python -c "import json, sys; print(json.load(sys.stdin)['token'])" > kiran.token
wc -c meena.token admin.token kiran.token
```

```{ .text .output }
      41 meena.token
      41 admin.token
      41 kiran.token
     123 total
```

Each token is 40 characters (plus a newline). The token is stored in the `authtoken_token` table, one per user, and stays valid until it's deleted. A wrong password gets **400**:

```bash
curl -s -w "\nHTTP %{http_code}" -d "username=meena&password=wrong" http://127.0.0.1:8000/api/token/
```

```{ .text .output }
{
  "non_field_errors": ["Unable to log in with provided credentials."]
}
HTTP 400
```

## Permissions in Action

**Meena** (store manager: `view` and `change` product) can update a price with `PATCH`:

```bash
curl -s -w "\nHTTP %{http_code}" -X PATCH http://127.0.0.1:8000/api/products/1/ \
  -H "Authorization: Token $(cat meena.token)" -H "Content-Type: application/json" \
  -d '{"price": "74999.00"}'
```

```{ .text .output }
{
  "id": 1,
  "name": "iPhone 15",
  "category": "electronics",
  "category_name": "Electronics",
  "brand": "Apple",
  "price": "74999.00",
  "stock": 25,
  "rating": "4.7",
  "in_stock": true,
  "added_on": "2025-09-20"
}
HTTP 200
```

but she has no `add_product` permission, so creating a product is **403 Forbidden** (she is authenticated, just not allowed):

```bash
curl -s -w "\nHTTP %{http_code}" -X POST http://127.0.0.1:8000/api/products/ \
  -H "Authorization: Token $(cat meena.token)" -H "Content-Type: application/json" \
  -d '{"name": "Lego Classic Box", "category": "toys", "brand": "Lego", "price": "2999", "stock": 10, "added_on": "2026-10-31"}'
```

```{ .text .output }
{
  "detail": "You do not have permission to perform this action."
}
HTTP 403
```

The **admin** superuser has every permission. Invalid data gets **400** with an error per field:

```bash
curl -s -w "\nHTTP %{http_code}" -X POST http://127.0.0.1:8000/api/products/ \
  -H "Authorization: Token $(cat admin.token)" -H "Content-Type: application/json" \
  -d '{"name": "Lego Classic Box", "category": "lego", "price": "0"}'
```

```{ .text .output }
{
  "category": ["Object with slug=lego does not exist."],
  "price": ["Price must be greater than zero."]
}
HTTP 400
```

Valid data gets **201 Created** with the new product:

```bash
curl -s -w "\nHTTP %{http_code}" -X POST http://127.0.0.1:8000/api/products/ \
  -H "Authorization: Token $(cat admin.token)" -H "Content-Type: application/json" \
  -d '{"name": "Lego Classic Box", "category": "toys", "brand": "Lego", "price": "2999", "stock": 10, "added_on": "2026-10-31"}'
```

```{ .text .output }
{
  "id": 18,
  "name": "Lego Classic Box",
  "category": "toys",
  "category_name": "Toys",
  "brand": "Lego",
  "price": "2999.00",
  "stock": 10,
  "rating": null,
  "in_stock": true,
  "added_on": "2026-10-31"
}
HTTP 201
```

(Your `id` may differ: MySQL never reuses auto-increment numbers, and we created and deleted products in lesson 04.) Find the new product's id with the search filter, then `DELETE` it, which returns **204 No Content**:

```bash
ID=$(curl -s "http://127.0.0.1:8000/api/products/?search=lego" | python -c "import json, sys; print(json.load(sys.stdin)['results'][0]['id'])")
curl -s -o /dev/null -w "DELETE -> HTTP %{http_code}\n" -X DELETE -H "Authorization: Token $(cat admin.token)" http://127.0.0.1:8000/api/products/$ID/
curl -s -o /dev/null -w "GET    -> HTTP %{http_code}\n" http://127.0.0.1:8000/api/products/$ID/
```

```{ .text .output }
DELETE -> HTTP 204
GET    -> HTTP 404
```

**Kiran**, a regular customer, can post a review through the `@action` (any logged-in user), with the name filled in from the account:

```bash
curl -s -w "\nHTTP %{http_code}" -X POST http://127.0.0.1:8000/api/products/9/reviews/ \
  -H "Authorization: Token $(cat kiran.token)" -H "Content-Type: application/json" \
  -d '{"rating": 5, "comment": "Small habits, big results. Loved it."}'
```

```{ .text .output }
{
  "id": 5,
  "name": "kiran",
  "rating": 5,
  "comment": "Small habits, big results. Loved it.",
  "created_at": "2026-11-01T19:19:51.543417+05:30"
}
HTTP 201
```

| Status | Meaning | When you saw it |
|--------|---------|-----------------|
| 200 OK | Success | List, retrieve, update |
| 201 Created | New resource created | Product created, review posted |
| 204 No Content | Deleted, no body | `DELETE` |
| 400 Bad Request | Validation failed | Price 0, unknown category |
| 401 Unauthorized | Not authenticated (no or bad token) | Anonymous `POST` |
| 403 Forbidden | Authenticated, not allowed | Meena creating a product |
| 404 Not Found | No such object | `/api/products/999/` |

Reset the data:

```bash
python manage.py seed_shop
```

```{ .text .output }
Loaded 6 categories, 15 products, 10 customers, 12 orders and 17 order items.
```

!!! tip "JWT and API docs"
    Many teams use **JWT** tokens (with expiry and refresh) via `djangorestframework-simplejwt` instead of DRF's simple tokens, and generate OpenAPI / Swagger documentation with **drf-spectacular**. The serializers and ViewSets you wrote stay the same; only settings and a few URLs change. **django-filter** replaces hand-written `get_queryset()` filtering with declarative filter classes.

!!! realworld "In Real Projects"
    A common architecture is Django + DRF as the backend for a React or mobile frontend: the same models, admin and permissions power both the internal back office and the public API. Teams version their APIs (`/api/v1/`), keep serializers thin, put business rules in services (like `place_order` from lesson 04), throttle anonymous traffic (`DEFAULT_THROTTLE_RATES`), and enable CORS (`django-cors-headers`) so the React app on another domain can call the API.

## Common Mistakes

| Mistake | Error / Symptom | Fix |
|---------|-----------------|-----|
| `rest_framework` not in `INSTALLED_APPS` | `TemplateDoesNotExist: rest_framework/api.html` in the browsable API | Add it to `INSTALLED_APPS` |
| `rest_framework.authtoken` without migrate | `Table 'authtoken_token' doesn't exist` | `python manage.py migrate` |
| `fields = "__all__"` on a serializer | Exposes and accepts every column | List fields explicitly; mark computed ones read-only |
| Nested serializers without `select_related` | N+1 queries on list endpoints | Optimise `get_queryset()` |
| `Authorization: Bearer <token>` with DRF tokens | 401 | DRF tokens use `Authorization: Token <key>` |
| Expecting `request.POST` in DRF views | Empty for JSON bodies | Use `request.data` |
| Forgetting `raise_exception=True` | Invalid data silently ignored | `serializer.is_valid(raise_exception=True)` |
| 401 vs 403 confusion | Wrong client behaviour | 401 = who are you? 403 = you can't do this |

## Practice Exercises

**Easy**

1. Add `?min_price=` and `?max_price=` filters to `ProductViewSet.get_queryset()`.
2. Add a read-only `review_count` field to `ProductSerializer` (annotate it in `get_queryset()` with `Count("reviews")`).
3. Change `PAGE_SIZE` to 3 and check `next` and `count` for `/api/products/`.

**Medium**

4. Add a `/api/me/` endpoint (an `APIView` with `IsAuthenticated`) that returns the logged-in user's username, email and number of reviews.
5. Add an `OrderSerializer` with nested read-only `items` (product name, quantity, unit price, line total) and an order `total`, and a `/api/orders/` endpoint that only staff with `view_order` can list.
6. Write a custom permission `IsReviewAuthorOrReadOnly` and a `ReviewViewSet` where only the author can edit or delete their review.

**Challenge**

7. Add `POST /api/orders/` that accepts `{"items": [{"product": 3, "quantity": 2}]}` for the logged-in user, validates stock, and uses the `place_order()` service from lesson 04 inside a transaction. Return 201 with the order, or 400 with a clear message when stock is insufficient.

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    # 1
    if min_price := params.get("min_price"):
        products = products.filter(price__gte=min_price)
    if max_price := params.get("max_price"):
        products = products.filter(price__lte=max_price)

    # 4
    from rest_framework.permissions import IsAuthenticated
    from rest_framework.views import APIView

    class MeView(APIView):
        permission_classes = [IsAuthenticated]

        def get(self, request):
            user = request.user
            return Response({"username": user.username, "email": user.email, "reviews": user.reviews.count()})

    # 6
    from rest_framework.permissions import SAFE_METHODS, BasePermission

    class IsReviewAuthorOrReadOnly(BasePermission):
        def has_object_permission(self, request, view, obj):
            return request.method in SAFE_METHODS or obj.user == request.user

    class ReviewViewSet(viewsets.ModelViewSet):
        queryset = Review.objects.select_related("product")
        serializer_class = ReviewSerializer
        permission_classes = [IsAuthenticatedOrReadOnly, IsReviewAuthorOrReadOnly]

    # 7 (outline)
    class OrderItemInputSerializer(serializers.Serializer):
        product = serializers.PrimaryKeyRelatedField(queryset=Product.objects.all())
        quantity = serializers.IntegerField(min_value=1)

    class OrderCreateSerializer(serializers.Serializer):
        items = OrderItemInputSerializer(many=True)
    # in the view: validate, map to {product.id: quantity}, call place_order(customer, items),
    # catch OutOfStock and return Response({"detail": str(e)}, status=400)
    ```

!!! note "Mini Assignment"
    Expose your **college library** as an API: read-only `/api/books/` with search and author filters, `/api/books/<id>/` with the author nested, and `POST /api/loans/` for logged-in members (token auth) that rejects books with no copies available. Test every endpoint with curl, including the 400, 401, 403 and 404 cases, and write the commands in a `API.md` file.

## Interview Questions

!!! interview "1. What is a serializer in DRF?"
    A class that converts complex data like model instances and querysets into Python primitives for JSON responses, and parses and validates incoming data before creating or updating objects. `ModelSerializer` generates fields and `create()` / `update()` from a model.

!!! interview "2. What is the difference between `APIView`, generic views and ViewSets?"
    `APIView` is the base class where you write `get()` / `post()` yourself. Generic views (`ListCreateAPIView`, `RetrieveUpdateDestroyAPIView`) implement common patterns with a queryset and serializer. ViewSets combine the actions for one resource into a single class and are wired to URLs automatically by a router.

!!! interview "3. What is the difference between authentication and permission classes in DRF?"
    Authentication classes identify the user from the request (token header, session cookie, JWT). Permission classes then decide whether that user may perform the action, for example `IsAuthenticated`, `IsAdminUser`, `DjangoModelPermissions` or a custom `has_permission` / `has_object_permission` check.

!!! interview "4. When does DRF return 401 and when 403?"
    401 Unauthorized when the request isn't authenticated and the first authentication class can provide a `WWW-Authenticate` challenge (like token auth). 403 Forbidden when the user is authenticated but lacks permission, or when the authentication scheme has no challenge header (session auth).

!!! interview "5. How do you avoid N+1 queries in a DRF list endpoint?"
    Override `get_queryset()` with `select_related()` for foreign keys and `prefetch_related()` for reverse and many-to-many relations used by (nested) serializers, use `annotate()` for counts instead of `SerializerMethodField` queries, and check query counts in tests with `assertNumQueries`.

!!! interview "Scenario: the React team says your API works in Postman but fails in the browser with a CORS error. What's going on?"
    Browsers block cross-origin requests unless the server sends CORS headers. Postman isn't a browser, so it isn't affected. Install `django-cors-headers`, add its middleware, and set `CORS_ALLOWED_ORIGINS` to the React app's origin (never allow all origins with credentials in production).

## Summary

| Concept | Code |
|---------|------|
| Serializer | `class ProductSerializer(serializers.ModelSerializer): class Meta: model = Product; fields = [...]` |
| Validation | `def validate_price(self, value): ...` · `serializer.is_valid(raise_exception=True)` |
| CRUD in one class | `class ProductViewSet(viewsets.ModelViewSet)` |
| URLs | `router = DefaultRouter(); router.register("products", ProductViewSet, basename="product")` |
| Filtering | `self.request.query_params.get("category")` in `get_queryset()` |
| Extra endpoint | `@action(detail=True, methods=["get", "post"])` |
| Token auth | `Authorization: Token <key>` · `obtain_auth_token` |
| Permissions | `IsAuthenticatedOrReadOnly`, `DjangoModelPermissionsOrAnonReadOnly`, custom `BasePermission` |
| Defaults | `REST_FRAMEWORK = {...}` in settings: auth, permissions, pagination |

**Next lesson:** [Testing Django](10-testing-django.md), automated tests for models, views, forms, permissions and the API.
