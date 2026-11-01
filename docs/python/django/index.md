---
hide:
  - toc
---

# Django

Build a complete, database-driven website and REST API with Django's "batteries included" framework: the **KSR Store**, with a product catalogue, reviews, accounts, a back office, a JSON API, automated tests and a Docker deployment, all on MySQL.

!!! abstract "By the end of this module, you can"
    - Model data with Django models and migrations, and query MySQL with the Django ORM without N+1 problems
    - Build server-rendered pages with URLs, views, templates, forms and class-based views
    - Run a back office with the Django admin, and secure the site with authentication, groups and permissions
    - Expose a JSON API with Django REST Framework, test everything, and deploy with Gunicorn and Docker

!!! tip "Every output in this module is real"
    The lessons were replayed in order, in one project, with Django 6.1, Django REST Framework 3.18 and `mysql-connector-python` on MySQL 8.4. Every command output, shell result and `curl` response shown comes from that run.

<div class="grid cards ksr-topics" markdown>

-   Foundations

    1. [Introduction & Setup](01-introduction-and-setup.md)
    1. [URLs, Views & Templates](02-urls-views-templates.md)
    1. [Models & Migrations](03-models-and-migrations.md)
    1. [The Django ORM](04-the-django-orm.md)

-   Building the Site

    1. [Django Admin](05-django-admin.md)
    1. [Forms & ModelForms](06-forms-and-modelforms.md)
    1. [Class-Based Views](07-class-based-views.md)
    1. [Authentication & Authorization](08-authentication-and-authorization.md)

-   APIs & Production

    1. [Django REST Framework](09-django-rest-framework.md)
    1. [Testing Django](10-testing-django.md)
    1. [Security, Deployment & Capstone](11-security-deployment-capstone.md)

</div>
