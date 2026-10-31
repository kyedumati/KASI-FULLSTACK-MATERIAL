---
hide:
  - toc
---

# FastAPI

Build production-style REST APIs in Python, from your first endpoint to a tested, secured, Dockerised backend for the KSR online store, running on the same `ksr_shop` MySQL database you designed in the MySQL module.

!!! abstract "By the end of this module, you can"
    - Design REST endpoints with path, query and body parameters validated by Pydantic
    - Structure a real project into routers, schemas, services and repositories
    - Query MySQL with `mysql-connector-python` and raw SQL, then with SQLAlchemy 2.0, including transactional order placement
    - Secure an API with JWT and roles, test it with pytest, and deploy it with Docker

!!! tip "Every response in this module is real"
    Each lesson's code was run with FastAPI 0.162, and every response shown came from calling the running API with `curl`. The database lessons ran against MySQL 8.4 loaded with [ksr_shop.sql](../../assets/sql/ksr_shop.sql).

<div class="grid cards ksr-topics" markdown>

-   Building APIs

    1. [Introduction to FastAPI](01-introduction-to-fastapi.md)
    1. [Path & Query Parameters](02-path-and-query-parameters.md)
    1. [Request Bodies & Pydantic](03-request-bodies-and-pydantic.md)
    1. [Responses, Status Codes & Errors](04-responses-and-errors.md)

-   Real Applications

    1. [Routers & Project Structure](05-routers-and-project-structure.md)
    1. [MySQL with mysql-connector-python](06-mysql-connector.md)
    1. [SQLAlchemy & MySQL](07-sqlalchemy-and-mysql.md)
    1. [Database CRUD & Transactions](08-database-crud.md)
    1. [Dependency Injection & Settings](09-dependencies-and-settings.md)

-   Production

    1. [Authentication with JWT](10-authentication-jwt.md)
    1. [Testing FastAPI](11-testing-fastapi.md)
    1. [CORS, Middleware & Background Tasks](12-cors-middleware-background.md)
    1. [Deployment & Capstone Project](13-deployment-and-capstone.md)

</div>
