---
lesson: true
category: Django
short: Admin
description: Creating a superuser, registering models, customising ModelAdmin (list_display, filters, search, editable columns, prepopulated slugs), inlines, efficient admin querysets, custom actions, branding the admin, and staff users with permissions.
---

# Django Admin

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Create a superuser and log in to the Django admin
    - Register models and customise lists with `list_display`, `list_filter`, `search_fields` and `list_editable`
    - Edit related rows on one page with **inlines**
    - Keep admin pages fast with `list_select_related` and `get_queryset`
    - Write a custom **admin action**, brand the admin, and give staff users limited **permissions**

**Prerequisites:** [The Django ORM](04-the-django-orm.md)

## Why the Admin Matters

Every shop needs a back office: someone has to add products, fix prices and update order statuses. In most frameworks you'd build those screens yourself. Django generates them from your models.

| Without the admin | With the admin |
|-------------------|----------------|
| Build list, add, edit, delete pages for every table | Register the model in a few lines |
| Write search, filters, pagination, validation | Configure them with lists of field names |
| Build login and permissions for staff | Uses Django's users, groups and permissions |

The admin is for **trusted staff**, not for customers. Customers get the pages you build yourself (lessons 02, 06 and 07).

## Creating a Superuser

A superuser can do everything in the admin. Create one interactively:

```{ .bash .no-run }
python manage.py createsuperuser
```

```{ .text .output }
Username: admin
Email address: admin@example.com
Password:
Password (again):
Superuser created successfully.
```

On a server or in a script, the same command can run without prompts by reading the password from an environment variable. We use that here so every step can be repeated:

```bash
DJANGO_SUPERUSER_PASSWORD="KsrAdmin@2026" python manage.py createsuperuser --noinput --username admin --email admin@example.com
```

```{ .text .output }
Superuser created successfully.
```

Start the server and open **http://127.0.0.1:8000/admin/**. Log in, and you'll see **Users** and **Groups**, which come from `django.contrib.auth`. Your shop models aren't there yet.

!!! warning "Use a strong, private password"
    `KsrAdmin@2026` is only for this local practice project. Real admin accounts need long unique passwords, and the admin URL should never be guessable on a public site (lesson 11).

## Registering Models

The admin only shows models you register in the app's `admin.py`. One line per model is enough to get full add/edit/delete pages:

```{ .python .no-run }
from django.contrib import admin

from .models import Category, Product

admin.site.register(Category)
admin.site.register(Product)
```

That works, but the product list only shows each product's `__str__`. A `ModelAdmin` class tells the admin what to show. Here is the shop's complete `admin.py`:

```python title="shop/admin.py"
from django.contrib import admin
from django.db.models import Count, F, Sum

from .models import Category, Customer, Order, OrderItem, Product


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ["name", "slug", "product_count"]
    prepopulated_fields = {"slug": ["name"]}
    search_fields = ["name"]

    def get_queryset(self, request):
        return super().get_queryset(request).annotate(product_count=Count("products"))

    @admin.display(description="Products", ordering="product_count")
    def product_count(self, obj):
        return obj.product_count


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ["name", "category", "brand", "price", "stock", "in_stock"]
    list_filter = ["category", "brand"]
    search_fields = ["name", "brand"]
    list_editable = ["price", "stock"]
    list_select_related = ["category"]
    list_per_page = 25
    autocomplete_fields = ["category"]

    @admin.display(boolean=True, description="In stock")
    def in_stock(self, obj):
        return obj.stock > 0


@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):
    list_display = ["name", "email", "city", "phone", "joined_on"]
    list_filter = ["city"]
    search_fields = ["name", "email"]


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    autocomplete_fields = ["product"]


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ["id", "customer", "order_date", "status", "order_total"]
    list_filter = ["status", "order_date"]
    search_fields = ["customer__name", "customer__email"]
    date_hierarchy = "order_date"
    inlines = [OrderItemInline]
    actions = ["mark_shipped"]
    autocomplete_fields = ["customer"]

    def get_queryset(self, request):
        return (
            super().get_queryset(request)
            .select_related("customer")
            .annotate(total_amount=Sum(F("items__quantity") * F("items__unit_price")))
        )

    @admin.display(description="Total", ordering="total_amount")
    def order_total(self, obj):
        return f"₹{obj.total_amount or 0:,.2f}"

    @admin.action(description="Mark selected orders as shipped")
    def mark_shipped(self, request, queryset):
        updated = queryset.filter(status=Order.Status.PENDING).update(status=Order.Status.SHIPPED)
        self.message_user(request, f"{updated} order(s) marked as shipped.")
```

### What each option does

| Option | Effect |
|--------|--------|
| `list_display` | Columns on the list page: fields, or methods decorated with `@admin.display` |
| `list_filter` | Filter sidebar (by category, status, date...) |
| `search_fields` | Search box; `customer__name` searches across the relationship |
| `list_editable` | Edit these columns directly on the list page |
| `list_select_related` | JOIN related tables so the list doesn't run N+1 queries |
| `prepopulated_fields` | Fill the slug from the name as you type |
| `autocomplete_fields` | Searchable dropdown instead of a giant `<select>` (the target admin needs `search_fields`) |
| `date_hierarchy` | Year → month → day drill-down above the list |
| `inlines` | Edit child rows (order items) on the parent's page |
| `actions` | Bulk operations on selected rows |
| `get_queryset` | Customise the query, here to annotate totals in SQL |

`@admin.display(boolean=True)` shows the `in_stock` method as a green tick or red cross. `ordering="total_amount"` lets you sort by a calculated column.

The `OrderAdmin.get_queryset` uses the `annotate` + `F` pattern from lesson 04. Calling `order.total` (our Python property) in `list_display` instead would run one extra query per order: the N+1 problem inside the admin.

## Branding the Admin

Set the header and titles once in `config/urls.py`:

```python title="config/urls.py"
from django.contrib import admin
from django.urls import include, path

admin.site.site_header = "KSR Store Admin"
admin.site.site_title = "KSR Store Admin"
admin.site.index_title = "Back office"

urlpatterns = [
    path("admin/", admin.site.urls),
    path("", include("shop.urls")),
]
```

## Trying It from the Command Line

You'll use the admin in a browser, but we can also drive it with curl to see exactly what happens. First log in. The admin, like every Django form, needs a **CSRF token** (you'll meet CSRF properly in lesson 06), which Django sends as a cookie:

```bash
curl -s -c cookies.txt -o /dev/null http://127.0.0.1:8000/admin/login/
CSRF=$(grep csrftoken cookies.txt | cut -f7)
curl -s -b cookies.txt -c cookies.txt -o /dev/null -w "login -> HTTP %{http_code}, redirects to %{redirect_url}\n" \
  -d "csrfmiddlewaretoken=$CSRF&username=admin&password=KsrAdmin@2026&next=/admin/" \
  http://127.0.0.1:8000/admin/login/
```

```{ .text .output }
login -> HTTP 302, redirects to http://127.0.0.1:8000/admin/
```

The admin home page: the page title and heading use our branding, followed by the four registered shop models:

```bash
curl -s -b cookies.txt http://127.0.0.1:8000/admin/ | grep -oE '<title>[^<]+|<h1[^>]*>[^<]+|href="/admin/shop/[a-z]+/">[A-Za-z]+' | sed -E 's/<[^>]*>//; s/href="[^"]*">/model: /'
```

```{ .text .output }
Back office | KSR Store Admin
Back office
model: Categories
model: Customers
model: Orders
model: Products
```

Search the products for "puma". The admin shows our columns and the matching rows:

```bash
curl -s -b cookies.txt "http://127.0.0.1:8000/admin/shop/product/?q=puma" > products.html
grep -oE 'column-[a-z_]+' products.html | sed 's/column-//' | tr '\n' ' '; echo
grep -oE '[0-9]+ results? \(<a href="\?">[0-9]+ total' products.html | sed 's/(<a href="?">/(/; s/$/)/'
grep -oE 'field-name"><a [^>]*>[^<]+' products.html | sed 's/.*>/row: /'
```

```{ .text .output }
name category brand price stock in_stock 
2 results (15 total)
row: Cotton T-Shirt
row: Running Shoes
```

Orders, sorted by the calculated total (`?o=5` sorts by the 5th column, descending with `-5`):

```bash
curl -s -b cookies.txt "http://127.0.0.1:8000/admin/shop/order/?o=-5" | grep -oE 'field-order_total">[^<]+' | head -3 | sed 's/.*>/total: /'
```

```{ .text .output }
total: ₹79,999.00
total: ₹74,999.00
total: ₹58,999.00
```

Now the custom action. Select the two pending orders (9 and 12) and run `mark_shipped`, exactly what happens when you tick the boxes and press **Go**:

```bash
CSRF=$(grep csrftoken cookies.txt | cut -f7)
curl -s -b cookies.txt -c cookies.txt -o /dev/null -w "action -> HTTP %{http_code}\n" \
  -d "csrfmiddlewaretoken=$CSRF&action=mark_shipped&_selected_action=9&_selected_action=12" \
  http://127.0.0.1:8000/admin/shop/order/
```

```{ .text .output }
action -> HTTP 302
```

```{ .python .shell }
from shop.models import Order

print(list(Order.objects.filter(id__in=[9, 12]).values_list("id", "status")))
print(Order.objects.filter(status="pending").count(), "pending orders left")
```

```{ .text .output }
[(12, 'shipped'), (9, 'shipped')]
0 pending orders left
```

In the browser you'd also see the green message "2 order(s) marked as shipped." Reset the data:

```bash
python manage.py seed_shop
```

```{ .text .output }
Loaded 6 categories, 15 products, 10 customers, 12 orders and 17 order items.
```

## Staff Users, Groups and Permissions

You don't want every employee to be a superuser. Django creates four **permissions** for every model automatically: `add_`, `change_`, `delete_` and `view_`. A user can open the admin only if `is_staff=True`, and then sees only what their permissions allow.

```{ .python .shell }
from django.contrib.auth.models import Group, Permission, User

managers, _ = Group.objects.get_or_create(name="Store managers")
managers.permissions.set(Permission.objects.filter(
    content_type__app_label="shop",
    codename__in=["view_product", "change_product", "view_order", "change_order"],
))

meena = User.objects.create_user("meena", password="Practice@123", is_staff=True)
meena.groups.add(managers)

print(sorted(p.codename for p in managers.permissions.all()))
print("change product:", meena.has_perm("shop.change_product"))
print("delete product:", meena.has_perm("shop.delete_product"))
print("view customer: ", meena.has_perm("shop.view_customer"))
```

```{ .text .output }
['change_order', 'change_product', 'view_order', 'view_product']
change product: True
delete product: False
view customer:  False
```

When Meena logs in, she sees only Products and Orders, can edit but not delete them, and never sees Customers or Users. In the browser you manage the same things under **Users** and **Groups**.

| Flag / feature | Meaning |
|----------------|---------|
| `is_active` | Can log in at all |
| `is_staff` | Can log in to the admin |
| `is_superuser` | Has every permission |
| Groups | Named sets of permissions (assign roles, not individual permissions) |
| `user.has_perm("app.codename")` | Check a permission in your own code |

!!! realworld "In Real Projects"
    Many companies run their whole internal operations on the Django admin: support teams look up customers, warehouse staff update orders, content teams publish articles. Typical hardening: a non-obvious admin URL, groups per role, two-factor login (django-otp), audit history (django-simple-history), and `list_select_related` / `get_queryset` everywhere so pages stay fast with millions of rows.

## Common Mistakes

| Mistake | Error / Symptom | Fix |
|---------|-----------------|-----|
| Model not registered | Model missing from the admin | `@admin.register(Model)` in the app's `admin.py` |
| Method in `list_display` triggers a query per row | Slow admin list | `list_select_related` or annotate in `get_queryset` |
| `autocomplete_fields` target has no `search_fields` | `admin.E040` system check error | Add `search_fields` to the related model's admin |
| Field in `list_editable` also the first `list_display` column | `admin.E124` error | The first column is the link; make another column editable |
| `prepopulated_fields` on a `ForeignKey` | System check error | Use it only for `SlugField` / `CharField` |
| Giving everyone superuser | Anyone can delete anything | Staff users + groups with specific permissions |
| Using the admin as the customer-facing site | Poor UX, security risk | Build your own views for customers |

## Practice Exercises

**Easy**

1. Add `rating` and `added_on` to the product list, and a `rating` filter.
2. Show the customer's `city` in the order list (`customer__city` can't go in `list_display` directly; write an `@admin.display` method).
3. Change `index_title` to "KSR Store back office" and check the admin home page.

**Medium**

4. Add a `mark_delivered` action that only changes **shipped** orders.
5. Add an **Orders** inline (read-only) on the customer page, showing date, status and a link.
6. Show a `low_stock` column that is a red cross when stock is below 20.

**Challenge**

7. Add an admin action "Export selected products as CSV" that returns an `HttpResponse` with `content_type="text/csv"` and a `Content-Disposition: attachment` header.

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    # 2
    @admin.display(description="City", ordering="customer__city")
    def customer_city(self, obj):
        return obj.customer.city

    # 4
    @admin.action(description="Mark selected orders as delivered")
    def mark_delivered(self, request, queryset):
        updated = queryset.filter(status=Order.Status.SHIPPED).update(status=Order.Status.DELIVERED)
        self.message_user(request, f"{updated} order(s) marked as delivered.")

    # 5
    class OrderInline(admin.TabularInline):
        model = Order
        extra = 0
        fields = ["order_date", "status"]
        readonly_fields = ["order_date", "status"]
        show_change_link = True
        can_delete = False

    # 6
    @admin.display(boolean=True, description="Stock OK")
    def low_stock(self, obj):
        return obj.stock >= 20

    # 7
    import csv
    from django.http import HttpResponse

    @admin.action(description="Export selected products as CSV")
    def export_csv(self, request, queryset):
        response = HttpResponse(content_type="text/csv")
        response["Content-Disposition"] = 'attachment; filename="products.csv"'
        writer = csv.writer(response)
        writer.writerow(["id", "name", "category", "price", "stock"])
        for p in queryset.select_related("category"):
            writer.writerow([p.id, p.name, p.category.name, p.price, p.stock])
        return response
    ```

!!! note "Mini Assignment"
    Set up the back office for your **college library** models from lesson 03: searchable book list with author filter, a loans inline on the member page, a "Mark as returned" action that sets `returned_on` to today, and a "Librarians" group that can add and change loans but not delete books.

## Interview Questions

!!! interview "1. What is the Django admin and who should use it?"
    An automatically generated CRUD interface built from your models, protected by Django's authentication and permissions. It's meant for trusted internal staff (operations, support, content teams), not as the public, customer-facing interface.

!!! interview "2. What is the difference between `is_staff` and `is_superuser`?"
    `is_staff` allows a user to log in to the admin; what they can see and do depends on their permissions. `is_superuser` grants every permission automatically, regardless of groups.

!!! interview "3. Which permissions does Django create for a model?"
    Four per model: `add_<model>`, `change_<model>`, `delete_<model>` and `view_<model>`, created when migrations run. Custom permissions can be added in the model's `Meta.permissions`.

!!! interview "4. How do you make a slow admin list page fast?"
    Use `list_select_related` (or override `get_queryset` with `select_related` / `prefetch_related`), compute totals with `annotate` instead of per-row Python methods, add database indexes for filtered and sorted columns, limit `list_per_page`, and use `autocomplete_fields` / `raw_id_fields` instead of huge dropdowns.

!!! interview "5. What is an admin action?"
    A function that runs on the rows selected in the list page, registered with `@admin.action` and listed in `ModelAdmin.actions`. It receives the request and a QuerySet of the selected objects, for example to bulk-update order statuses or export data.

!!! interview "Scenario: a support agent should see orders and customers but must not change prices. How do you set that up?"
    Create a "Support" group with `view_order`, `change_order`, `view_customer` and `view_product` permissions (no `change_product`), add the agent to it, and set `is_staff=True` without `is_superuser`. The admin then hides edit controls for products automatically.

## Summary

| Task | Code |
|------|------|
| Create superuser | `python manage.py createsuperuser` |
| Register | `@admin.register(Product)` + `class ProductAdmin(admin.ModelAdmin)` |
| List page | `list_display`, `list_filter`, `search_fields`, `list_editable` |
| Calculated column | `@admin.display(description=..., ordering=..., boolean=...)` |
| Related rows | `inlines = [OrderItemInline]` with `admin.TabularInline` |
| Performance | `list_select_related`, `get_queryset()` with `annotate` |
| Bulk operation | `@admin.action` + `actions = [...]` |
| Branding | `admin.site.site_header`, `site_title`, `index_title` |
| Staff access | `is_staff`, groups, `user.has_perm("shop.change_product")` |

**Next lesson:** [Forms & ModelForms](06-forms-and-modelforms.md), letting customers send data to your site safely.
