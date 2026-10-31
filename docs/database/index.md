---
hide:
  - toc
---

# MySQL

Everything a full stack developer needs to know about relational databases, from your first table to transactions, window functions and connecting from code. This module is **shared by the Full Stack Python and Full Stack Java tracks**.

!!! abstract "By the end of this module, you can"
    - Design normalised databases with keys, relationships and constraints
    - Write SQL to filter, sort, aggregate and join data, including subqueries, CTEs and window functions
    - Keep data safe and fast with transactions, indexes and least-privilege users
    - Query MySQL from Python safely, without SQL injection

!!! tip "Practice database"
    Every lesson uses the same **ksr_shop** online-store database: categories, products, customers, orders, order items and employees.

    [:material-download: Download ksr_shop.sql](../assets/sql/ksr_shop.sql){ .md-button .md-button--primary download }

    All outputs in these lessons were produced by running the queries on MySQL 8.4 against this exact data.

<div class="grid cards ksr-topics" markdown>

-   Foundations

    1. [Introduction to Databases](mysql/01-introduction-to-databases.md)
    1. [MySQL Setup & First Database](mysql/02-mysql-setup.md)
    1. [Creating Tables & Data Types](mysql/03-creating-tables.md)
    1. [CRUD: Insert, Select, Update, Delete](mysql/04-crud-operations.md)
    1. [Filtering, Sorting & Pagination](mysql/05-filtering-sorting.md)

-   Querying Like a Pro

    1. [Aggregations & GROUP BY](mysql/06-aggregations-group-by.md)
    1. [Functions & Expressions](mysql/07-functions-expressions.md)
    1. [Database Design](mysql/08-database-design.md)
    1. [Joins](mysql/09-joins.md)
    1. [Subqueries, Views & CTEs](mysql/10-subqueries-views-ctes.md)

-   Advanced & Real World

    1. [Window Functions](mysql/11-window-functions.md)
    1. [Transactions, Indexes & Users](mysql/12-transactions-indexes-users.md)
    1. [Python + MySQL](mysql/13-python-mysql.md)
    1. [Real-Time Projects](mysql/14-real-time-projects.md)

</div>
