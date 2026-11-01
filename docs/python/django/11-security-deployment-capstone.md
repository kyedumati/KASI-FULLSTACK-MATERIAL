---
lesson: true
category: Django
short: Deploy
description: Django's built-in security protections, the deployment checklist (check --deploy), production settings from environment variables, HTTPS and secure cookies, static files with WhiteNoise, custom error pages, running with Gunicorn, Docker and docker compose with MySQL, deployment options, and the KSR Store capstone project.
---

# Security, Deployment & Capstone

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Name the attacks Django protects against by default, and what **you** still have to do
    - Use `python manage.py check --deploy` and fix every warning with production settings
    - Configure secrets, hosts, HTTPS, secure cookies, static files and error pages for production
    - Run Django with **Gunicorn**, then package it with **Docker** and **docker compose** together with MySQL
    - Plan, build and present the **KSR Store capstone**

**Prerequisites:** [Testing Django](10-testing-django.md), and the Docker basics from the [FastAPI deployment lesson](../fastapi/13-deployment-and-capstone.md).

## Development vs Production

| | Development (so far) | Production |
|---|---|---|
| Server | `runserver` (single process, auto-reload) | **Gunicorn** behind a reverse proxy (Nginx, a cloud load balancer) |
| `DEBUG` | `True`: detailed error pages | **`False`**: never show tracebacks to users |
| Secrets | A fallback key in the code | **Environment variables** / a secrets manager |
| Static files | Served by `runserver` | Collected once (`collectstatic`) and served by WhiteNoise, Nginx or a CDN |
| HTTPS | Plain HTTP on 127.0.0.1 | HTTPS only, secure cookies, HSTS |
| Database | Local MySQL as root | Managed MySQL, a dedicated user with limited rights, backups |

## What Django Protects You From

You've already met most of these protections:

| Attack | Django's protection | Your job |
|--------|---------------------|----------|
| **SQL injection** | The ORM sends values as parameters, never pasted into SQL | Use `params` in raw SQL; never build SQL with f-strings |
| **XSS** (cross-site scripting) | Templates auto-escape variables (lesson 02) | Never use `\|safe` / `mark_safe` on user input |
| **CSRF** | `CsrfViewMiddleware` + `{% csrf_token %}` (lesson 06) | Don't use `@csrf_exempt` on views that use cookies |
| **Clickjacking** | `XFrameOptionsMiddleware` sends `X-Frame-Options: DENY` | Keep the middleware |
| **Password theft** | Salted, slow PBKDF2 hashes (lesson 08) | Keep the password validators |
| **IDOR** (others' data by id) | Nothing automatic | Filter querysets by `request.user` (lesson 08) |
| **Host header attacks** | `ALLOWED_HOSTS` | List only your real domains |

See SQL injection being blocked. The "name" below is an attacker's attempt to make the `WHERE` clause always true:

```{ .python .shell }
from django.db import connection
from shop.models import Product

attack = "x' OR '1'='1"
print("ORM:", Product.objects.filter(name=attack).count(), "rows")

with connection.cursor() as cursor:
    cursor.execute("SELECT COUNT(*) FROM shop_product WHERE name = %s", [attack])
    print("Raw SQL with params:", cursor.fetchone()[0], "rows")

    cursor.execute(f"SELECT COUNT(*) FROM shop_product WHERE name = '{attack}'")   # NEVER do this
    print("Raw SQL with an f-string:", cursor.fetchone()[0], "rows")
```

```{ .text .output }
ORM: 0 rows
Raw SQL with params: 0 rows
Raw SQL with an f-string: 15 rows
```

With parameters, the attack is just a strange product name that matches nothing. Pasted into the SQL with an f-string, it rewrote the query and matched **every** row. On a login or delete query, that's a disaster.

## The Deployment Checklist: `check --deploy`

Django can review its own settings for production. Run it as production would, with `DEBUG` off and no secret key in the environment (so the development fallback key is used):

```bash
env -u DJANGO_SECRET_KEY DJANGO_DEBUG=false python manage.py check --deploy
```

```{ .text .output }
System check identified some issues:

WARNINGS:
?: (security.W004) You have not set a value for the SECURE_HSTS_SECONDS setting. If your entire site is served only over SSL, you may want to consider setting a value and enabling HTTP Strict Transport Security. Be sure to read the documentation first; enabling HSTS carelessly can cause serious, irreversible problems.
?: (security.W008) Your SECURE_SSL_REDIRECT setting is not set to True. Unless your site should be available over both SSL and non-SSL connections, you may want to either set this setting True or configure a load balancer or reverse-proxy server to redirect all connections to HTTPS.
?: (security.W009) Your SECRET_KEY has less than 50 characters, less than 5 unique characters, or it's prefixed with 'django-insecure-' indicating that it was generated automatically by Django. Please generate a long and random value, otherwise many of Django's security-critical features will be vulnerable to attack.
?: (security.W012) SESSION_COOKIE_SECURE is not set to True. Using a secure-only session cookie makes it more difficult for network traffic sniffers to hijack user sessions.
?: (security.W016) You have 'django.middleware.csrf.CsrfViewMiddleware' in your MIDDLEWARE, but you have not set CSRF_COOKIE_SECURE to True. Using a secure-only CSRF cookie makes it more difficult for network traffic sniffers to steal the CSRF token.

System check identified 5 issues (0 silenced).
```

Every warning is a real risk. We fix them all with production-ready settings.

## Production Settings

Here is the **final** `config/settings.py`. Compared with the version built up so far, it reads every environment-specific value from **environment variables**, defaults to `DEBUG = False`, refuses to start in production without a secret key, turns on HTTPS protections when `DEBUG` is off, serves static files with WhiteNoise, and logs to the console:

```python title="config/settings.py"
import os
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent


def env_list(name, default=""):
    return [item.strip() for item in os.environ.get(name, default).split(",") if item.strip()]


DEBUG = os.environ.get("DJANGO_DEBUG", "false").lower() == "true"

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "")
if not SECRET_KEY:
    if DEBUG:
        SECRET_KEY = "dev-only-insecure-key-change-me"
    else:
        raise ImproperlyConfigured("Set the DJANGO_SECRET_KEY environment variable.")

ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS", "127.0.0.1,localhost")
CSRF_TRUSTED_ORIGINS = env_list("DJANGO_CSRF_TRUSTED_ORIGINS")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "shop",
    "accounts",
    "rest_framework",
    "rest_framework.authtoken",
    "api",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

DATABASES = {
    "default": {
        "ENGINE": "mysql.connector.django",
        "NAME": os.environ.get("DB_NAME", "ksr_store"),
        "USER": os.environ.get("DB_USER", "root"),
        "PASSWORD": os.environ.get("DB_PASSWORD", ""),
        "HOST": os.environ.get("DB_HOST", "localhost"),
        "PORT": os.environ.get("DB_PORT", "3306"),
        "CONN_MAX_AGE": int(os.environ.get("DB_CONN_MAX_AGE", "60")),
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-in"
TIME_ZONE = "Asia/Kolkata"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATICFILES_DIRS = [BASE_DIR / "static"]
STATIC_ROOT = BASE_DIR / "staticfiles"
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"},
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

LOGIN_URL = "accounts:login"
LOGIN_REDIRECT_URL = "shop:home"
LOGOUT_REDIRECT_URL = "shop:home"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.TokenAuthentication",
        "rest_framework.authentication.SessionAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticatedOrReadOnly"],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 5,
}

# HTTPS and cookie security: on whenever DEBUG is off
if not DEBUG:
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
    SECURE_SSL_REDIRECT = os.environ.get("DJANGO_SECURE_SSL_REDIRECT", "true").lower() == "true"
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = int(os.environ.get("DJANGO_HSTS_SECONDS", "2592000"))  # 30 days
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": os.environ.get("DJANGO_LOG_LEVEL", "INFO")},
}
```

!!! warning "`DEBUG` now defaults to `False`"
    Safe defaults mean a forgotten variable can't expose debug pages in production. On your laptop, set `export DJANGO_DEBUG=true` (Windows PowerShell: `$env:DJANGO_DEBUG="true"`) alongside the database variables from lesson 01.

| Setting | Protects against |
|---------|------------------|
| `DEBUG = False` | Leaking code, settings and SQL in error pages |
| `SECRET_KEY` from the environment | Forged sessions, password-reset links and signed cookies if the code leaks |
| `ALLOWED_HOSTS` | Host header attacks (poisoned password-reset links) |
| `CSRF_TRUSTED_ORIGINS` | Needed for HTTPS form posts from your domain behind a proxy, e.g. `https://shop.example.com` |
| `SECURE_SSL_REDIRECT` | Users staying on plain HTTP |
| `SECURE_PROXY_SSL_HEADER` | Django not knowing the request was HTTPS when a proxy terminates TLS |
| `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE` | Cookies being sent over plain HTTP |
| `SECURE_HSTS_SECONDS` | Browsers trying HTTP first (downgrade attacks) |
| `CONN_MAX_AGE` | Opening a new MySQL connection on every request |

!!! mistake "Start HSTS small"
    HSTS tells browsers to use **only** HTTPS for your domain for `SECURE_HSTS_SECONDS`. If HTTPS breaks, users can't reach the site until it expires. Start with a few minutes (`DJANGO_HSTS_SECONDS=300`), then raise it to months once HTTPS is solid.

Install the two production packages, **Gunicorn** (the application server) and **WhiteNoise** (serves static files efficiently from Python):

```{ .bash .no-run }
pip install gunicorn whitenoise
```

Generate a strong secret key for production (store it in the environment or a secrets manager, **never** in Git):

```bash
python -c "from django.core.management.utils import get_random_secret_key as key; print(len(key()), 'characters')"
```

```{ .text .output }
50 characters
```

Run the checklist again with production values:

```bash
DJANGO_DEBUG=false DJANGO_SECRET_KEY="$(python -c 'from django.core.management.utils import get_random_secret_key as k; print(k())')" \
  python manage.py check --deploy
```

```{ .text .output }
System check identified no issues (0 silenced).
```

## Static Files and Error Pages

`collectstatic` copies every app's static files (ours, the admin's, DRF's) into `STATIC_ROOT`. WhiteNoise's storage also adds a content **hash** to each filename and compresses them, so browsers can cache them forever:

```bash
python manage.py collectstatic --noinput
```

```{ .text .output }
158 static files copied to '/home/student/ksr-store/staticfiles', 456 post-processed.
```

With `DEBUG = False`, Django shows `templates/404.html` and `templates/500.html` instead of its debug pages:

```html title="templates/404.html"
{% extends "base.html" %}

{% block title %}Page not found | KSR Store{% endblock %}

{% block content %}
<h1>Sorry, we couldn't find that page</h1>
<p>Try the <a href="{% url 'shop:product_list' %}">product list</a> or search for what you need.</p>
{% endblock %}
```

```html title="templates/500.html"
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Something went wrong | KSR Store</title></head>
<body>
  <h1>Something went wrong on our side</h1>
  <p>Our team has been notified. Please try again in a few minutes.</p>
</body>
</html>
```

`500.html` deliberately doesn't extend `base.html`: if the error came from the database or a template tag, the base template might fail too.

## Running with Gunicorn

`runserver` is for development only. **Gunicorn** runs several worker processes and is what production uses. Start it in production mode (we turn off the HTTPS redirect only because there's no HTTPS on our laptop):

```bash
export DJANGO_DEBUG=false DJANGO_SECURE_SSL_REDIRECT=false
export DJANGO_SECRET_KEY="local-production-test-key-0123456789-abcdefghijklmnopqrstuvwxyz"
gunicorn config.wsgi --bind 127.0.0.1:8800 --workers 2 --daemon --pid gunicorn.pid --error-logfile gunicorn.log
sleep 3
```

(`--daemon` runs it in the background so we can try it with curl. In production, a process manager such as systemd or Docker keeps it running instead.)

The security middleware adds protective headers to every response:

```bash
curl -s -I http://127.0.0.1:8800/ | grep -iE "^(HTTP|x-frame-options|x-content-type-options|referrer-policy|cross-origin-opener-policy)"
```

```{ .text .output }
HTTP/1.1 200 OK
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Referrer-Policy: same-origin
Cross-Origin-Opener-Policy: same-origin
```

When the request arrives through an HTTPS proxy (which sends `X-Forwarded-Proto: https`), Django also sends **HSTS** and marks cookies **Secure**:

```bash
curl -s -I -H "X-Forwarded-Proto: https" http://127.0.0.1:8800/accounts/login/ | grep -i "^strict-transport-security"
curl -s -I -H "X-Forwarded-Proto: https" http://127.0.0.1:8800/accounts/login/ | grep -i "^set-cookie" | grep -oE "csrftoken|SameSite=Lax|Secure"
```

```{ .text .output }
Strict-Transport-Security: max-age=2592000; includeSubDomains; preload
csrftoken
SameSite=Lax
Secure
```

The custom 404 page, and static files served by WhiteNoise with hashed names and a one-year cache:

```bash
curl -s -w "HTTP %{http_code}\n" http://127.0.0.1:8800/no-such-page/ | grep -E "<h1>|HTTP"
CSS=$(curl -s http://127.0.0.1:8800/ | grep -oE '/static/css/site\.[0-9a-f]+\.css')
echo "$CSS"
curl -s -I "http://127.0.0.1:8800$CSS" | grep -iE "^(HTTP|cache-control)"
```

```{ .text .output }
<h1>Sorry, we couldn't find that page</h1>
HTTP 404
/static/css/site.d9c704032d31.css
HTTP/1.1 200 OK
Cache-Control: max-age=315360000, public, immutable
```

Stop Gunicorn:

```bash
kill "$(cat gunicorn.pid)"
```

## Docker and docker compose

Docker packages the app and its exact dependencies into an **image** that runs the same on every machine and server. Pin every dependency first:

```text title="requirements.txt"
Django==6.1.2
djangorestframework==3.18.3
mysql-connector-python==26.10.0
gunicorn==26.2.0
whitenoise==6.12.0
```

```dockerfile title="Dockerfile"
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --root-user-action=ignore -r requirements.txt

COPY . .
RUN DJANGO_SECRET_KEY=collectstatic-only python manage.py collectstatic --noinput

RUN useradd --create-home appuser
USER appuser

EXPOSE 8000
CMD ["gunicorn", "config.wsgi", "--bind", "0.0.0.0:8000", "--workers", "3", "--access-logfile", "-"]
```

Keep secrets, local files and caches out of the image:

```text title=".dockerignore"
.venv/
__pycache__/
*.pyc
.env
staticfiles/
*.token
cookies.txt
kiran.txt
meena.txt
gunicorn.*
products.html
.coverage
htmlcov/
```

`docker compose` runs MySQL and the web app together. The web container waits until MySQL is healthy, applies migrations, then starts Gunicorn:

```yaml title="compose.yaml"
name: ksr-store

services:
  db:
    image: mysql:8.4
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ksr_store
    volumes:
      - db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 5s
      retries: 30

  web:
    build: .
    command: sh -c "python manage.py migrate --noinput && gunicorn config.wsgi --bind 0.0.0.0:8000 --workers 3 --access-logfile -"
    ports:
      - "8080:8000"
    environment:
      DJANGO_DEBUG: "false"
      DJANGO_SECRET_KEY: ${DJANGO_SECRET_KEY}
      DJANGO_ALLOWED_HOSTS: "localhost,127.0.0.1"
      DJANGO_SECURE_SSL_REDIRECT: "false"
      DB_HOST: db
      DB_NAME: ksr_store
      DB_USER: root
      DB_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/')"]
      interval: 5s
      retries: 30
    depends_on:
      db:
        condition: service_healthy

volumes:
  db_data:
```

The secrets live in a `.env` file next to `compose.yaml` (add it to `.gitignore`):

```text title=".env"
MYSQL_ROOT_PASSWORD=change-me-strong-db-password
DJANGO_SECRET_KEY=change-me-50-plus-random-characters-from-get_random_secret_key
```

Build and start everything. `--wait` returns once both containers are healthy (the first build downloads images and can take a few minutes):

```bash
docker compose up -d --build --wait > /dev/null 2>&1
docker compose ps --format "{{.Service}}: {{.State}} ({{.Health}})"
docker compose logs web | grep -oE "Applying shop\.[0-9a-z_]+\.\.\. OK|Listening at: [^ ]+"
```

```{ .text .output }
db: running (healthy)
web: running (healthy)
Applying shop.0001_initial... OK
Applying shop.0002_customer_order_orderitem... OK
Applying shop.0003_review... OK
Applying shop.0004_review_user... OK
Listening at: http://0.0.0.0:8000
```

Load the sample data inside the container and call the API through port 8080:

```bash
docker compose exec web python manage.py seed_shop
curl -s "http://127.0.0.1:8080/api/products/?category=books" | python -c "import json, sys; d = json.load(sys.stdin); print(d['count'], [p['name'] for p in d['results']])"
curl -s -o /dev/null -w "home page -> HTTP %{http_code}\n" http://127.0.0.1:8080/
```

```{ .text .output }
Loaded 6 categories, 15 products, 10 customers, 12 orders and 17 order items.
3 ['Atomic Habits', 'Python Crash Course', 'Wings of Fire']
home page -> HTTP 200
```

Stop and remove the containers (`-v` also deletes the database volume; leave it off to keep the data):

```bash
docker compose down -v > /dev/null 2>&1 && echo "stopped"
```

```{ .text .output }
stopped
```

## Deployment Options

| Option | You manage | Good for |
|--------|-----------|----------|
| **PythonAnywhere** | Just your code | First deployment, demos (supports MySQL) |
| **Render / Railway** | Code + a few settings; deploys from GitHub | Portfolios, small production apps |
| **A VPS** (AWS EC2, DigitalOcean, Azure VM) with Nginx + Gunicorn + systemd | The whole server | Learning Linux, full control |
| **Containers** (AWS ECS, Google Cloud Run, Azure Container Apps) | Your Docker image | Teams, scaling, the Docker setup above |
| Managed MySQL (AWS RDS, Azure Database for MySQL, Google Cloud SQL) | Nothing but the schema | The database in any of the options above |

On a VPS, **Nginx** sits in front of Gunicorn: it terminates HTTPS (free certificates from Let's Encrypt), serves `/static/` directly and forwards everything else, telling Django the original scheme:

```{ .text .no-run }
server {
    server_name shop.example.com;
    location /static/ { alias /srv/ksr-store/staticfiles/; }
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

## Go-Live Checklist

- [ ] `python manage.py check --deploy` reports no issues
- [ ] `DEBUG=False`, strong `DJANGO_SECRET_KEY` from the environment, real `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS`
- [ ] HTTPS everywhere; HSTS started small, then increased
- [ ] Dedicated MySQL user with only the rights the app needs; automated, **tested** backups
- [ ] `python manage.py migrate` runs on every deployment, before the new version starts
- [ ] `collectstatic` runs at build time; static files cached
- [ ] Custom 404 / 500 pages; errors reported to a tool like Sentry
- [ ] All tests pass in CI before deploying
- [ ] Admin URL changed from `/admin/`, staff accounts with strong passwords (and 2FA)
- [ ] Dependencies pinned and updated regularly (`pip list --outdated`, Dependabot)

!!! realworld "In Real Projects"
    A typical pipeline: a pull request runs tests and `check --deploy` in GitHub Actions; merging to `main` builds a Docker image, pushes it to a registry, runs migrations, and rolls out the new containers with zero downtime. Secrets come from the platform's secret store, logs and errors go to a monitoring service, and the database is a managed service with point-in-time recovery.

## Capstone: The KSR Store

Time to bring the whole module together. Extend the KSR Store you built in lessons 01–11 into a complete online shop.

### Requirements

**Customer website**

1. Product catalogue with search, category filter, price range, sorting and pagination (lessons 02, 06, 07).
2. Product pages with reviews; only logged-in customers can review, once per product (lessons 06, 08).
3. **Cart**: add, update quantity, remove (store the cart in the session: `request.session["cart"] = {product_id: quantity}`).
4. **Checkout**: creates an order with `place_order()` inside a transaction, rejects out-of-stock items, and shows a confirmation page (lesson 04).
5. **My orders**: each customer sees only their own orders and their status (link `Customer` to `User` with a `OneToOneField`).
6. Sign up, log in, log out, change password (lesson 08).

**Back office**

7. Admin for products, categories, customers and orders with filters, search, inlines and actions: mark shipped / delivered, export CSV (lesson 05).
8. A staff-only **sales dashboard** page: revenue this month, top 5 products, orders by status, low-stock products, using `annotate` / `aggregate` (lesson 04), protected by a permission (lesson 08).

**API**

9. Public read API for products and categories, plus authenticated endpoints: `GET /api/orders/` (own orders) and `POST /api/orders/` (place an order) with token authentication (lesson 09).

### Non-functional requirements

- At least **85% test coverage**, including permission tests (401/403/404) and an `assertNumQueries` test for the product list and the API (lesson 10).
- No N+1 queries on any list page.
- `check --deploy` clean with production settings; runs with `docker compose up` (this lesson).
- A `README.md` explaining setup, environment variables, how to run tests and how to deploy.

### Suggested plan

| Day | Goal |
|-----|------|
| 1 | Link customers to users, cart in the session, cart page |
| 2 | Checkout with `place_order()`, confirmation page, "My orders" |
| 3 | Sales dashboard and admin improvements |
| 4 | Orders API with token auth |
| 5 | Tests to 85%+, fix N+1 queries |
| 6 | Production settings, Docker, README, deploy |
| 7 | Polish, rehearse the demo |

### Evaluation rubric

| Area | Weight | Excellent looks like |
|------|--------|----------------------|
| Features | 30% | Every requirement works, including edge cases (empty cart, out of stock) |
| Code quality | 20% | Small views, business logic in services, clear names, no duplication |
| Security | 15% | Permissions on every view, users only see their own data, CSRF intact, settings from the environment |
| Tests | 15% | 85%+ coverage, meaningful assertions, permission and query-count tests |
| Database & performance | 10% | Sensible models and constraints, migrations committed, no N+1 queries |
| Deployment & docs | 10% | `docker compose up` works first time, clear README |

### Demo script (10 minutes)

1. **Customer journey** (3 min): search, filter, review, add to cart, checkout, see the order in "My orders".
2. **Back office** (2 min): ship the order with the admin action, show the sales dashboard.
3. **API** (2 min): get a token, list your orders, place an order with curl, show a 403 for another user.
4. **Quality** (2 min): run the test suite and coverage report, show `check --deploy`.
5. **Architecture** (1 min): explain one design decision you're proud of and one you'd change.

## Interview Questions

!!! interview "1. What do you change in a Django project before deploying it?"
    Set `DEBUG=False`, load `SECRET_KEY` and database credentials from the environment, set `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS`, enable HTTPS settings (SSL redirect, secure cookies, HSTS, proxy SSL header), configure static files (`STATIC_ROOT`, `collectstatic`, WhiteNoise or a CDN), add error pages and logging, and run with Gunicorn behind a reverse proxy. `check --deploy` verifies most of this.

!!! interview "2. Why shouldn't you use `runserver` in production?"
    It's a single-process development server, not tested for security or performance, and it serves static files inefficiently. Production uses a WSGI/ASGI server such as Gunicorn or Uvicorn with multiple workers, behind Nginx or a load balancer.

!!! interview "3. What is `collectstatic` and why is it needed?"
    It gathers static files from every app and `STATICFILES_DIRS` into `STATIC_ROOT`, so a single place (WhiteNoise, Nginx or a CDN) can serve them. With a manifest storage it also adds content hashes to filenames, allowing long-term browser caching.

!!! interview "4. How does Django prevent SQL injection, and when can you still be vulnerable?"
    The ORM builds parameterised queries, so values are sent separately from the SQL text. You can still be vulnerable with raw SQL built from strings (`cursor.execute(f"...{value}...")`, `extra()`, or `RawSQL` with interpolated input). Always pass values via the `params` argument.

!!! interview "5. What is `SECURE_PROXY_SSL_HEADER` for?"
    When a proxy terminates HTTPS and forwards plain HTTP to Gunicorn, Django can't see that the original request was secure. The setting tells Django to trust a header like `X-Forwarded-Proto: https` from the proxy, so `request.is_secure()`, SSL redirects and secure cookies work correctly. Only set it when your proxy always sets or strips that header.

!!! interview "Scenario: after deploying, every form submission fails with `403 CSRF verification failed`, but it worked locally. What do you check?"
    That `CSRF_TRUSTED_ORIGINS` includes the site's HTTPS origin (for example `https://shop.example.com`), that the proxy sends `X-Forwarded-Proto` and `SECURE_PROXY_SSL_HEADER` is set, that `CSRF_COOKIE_SECURE` matches the scheme the browser actually uses, and that the domain matches `ALLOWED_HOSTS`. Then check the browser's cookies and the error details in the logs.

## Summary

| Area | Key points |
|------|-----------|
| Built-in protection | ORM parameters, auto-escaping, CSRF, clickjacking header, password hashing |
| Checklist | `python manage.py check --deploy` |
| Settings | Environment variables, `DEBUG=False` by default, `ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS` |
| HTTPS | `SECURE_PROXY_SSL_HEADER`, `SECURE_SSL_REDIRECT`, secure cookies, HSTS |
| Static files | `STATIC_ROOT` + `collectstatic` + WhiteNoise (hashed, compressed, cached) |
| Server | Gunicorn with several workers, behind Nginx or a load balancer |
| Containers | `Dockerfile` + `compose.yaml` with MySQL, healthchecks, migrations on start |
| Capstone | Cart, checkout, my orders, dashboard, orders API, 85% tests, Docker |

**Congratulations!** You've built and deployed a complete Django application: models and migrations, the ORM, the admin, forms, class-based views, authentication, a REST API, tests and production settings.

**Next on the Python roadmap:** [HTML, CSS & JavaScript](../../frontend/index.md), building the frontend that will talk to your APIs.
