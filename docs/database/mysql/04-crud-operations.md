---
lesson: true
category: MySQL
short: CRUD
description: Create, read, update and delete rows with INSERT, SELECT, UPDATE and DELETE; column aliases, safe updates, foreign key protection and upserts.
---

# CRUD: Insert, Select, Update, Delete

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Insert one or many rows with `INSERT`
    - Read data with `SELECT`: chosen columns, all columns, aliases and simple filters
    - Change data safely with `UPDATE ... WHERE`
    - Remove data with `DELETE ... WHERE`, and understand how foreign keys protect related rows
    - Avoid the most dangerous mistake in SQL: forgetting `WHERE`

**Prerequisites:** [Creating Tables & Data Types](03-creating-tables.md). Make sure the [ksr_shop database](02-mysql-setup.md#loading-the-ksr_shop-database) is loaded and run `USE ksr_shop;`.

## What is CRUD?

Almost every feature of every application comes down to four operations on data:

| Operation | SQL | Example in an app |
|-----------|-----|-------------------|
| **C**reate | `INSERT` | Sign up, place an order, add a product |
| **R**ead | `SELECT` | View products, see order history, search |
| **U**pdate | `UPDATE` | Edit profile, change order status, restock |
| **D**elete | `DELETE` | Remove an item from the cart, delete an account |

!!! example "Real-life analogy: a contacts app"
    Adding a contact is **Create**, scrolling your contacts is **Read**, editing a number is **Update**, and removing someone is **Delete**. Your phone's contacts app is a CRUD app, and so are Instagram, Swiggy and banking apps, just with more tables.

These map directly to the REST API methods from the Python module: `POST` → `INSERT`, `GET` → `SELECT`, `PUT/PATCH` → `UPDATE`, `DELETE` → `DELETE`.

## Create: INSERT

```{ .sql .no-run }
INSERT INTO table_name (column1, column2, ...)
VALUES (value1, value2, ...);
```

Add a new customer:

```sql
INSERT INTO customers (name, email, city, phone, joined_on)
VALUES ('Neha Gupta', 'neha@example.com', 'Jaipur', '9876500011', '2025-10-20');

SELECT * FROM customers WHERE email = 'neha@example.com';
```

```{ .text .output }
+----+------------+------------------+--------+------------+------------+
| id | name       | email            | city   | phone      | joined_on  |
+----+------------+------------------+--------+------------+------------+
| 11 | Neha Gupta | neha@example.com | Jaipur | 9876500011 | 2025-10-20 |
+----+------------+------------------+--------+------------+------------+
```

We didn't give an `id`. `AUTO_INCREMENT` assigned the next number. To see the id that was just generated (your backend needs this, for example to redirect to the new order's page):

```sql
INSERT INTO categories (name) VALUES ('Beauty');
SELECT LAST_INSERT_ID();
```

```{ .text .output }
+------------------+
| LAST_INSERT_ID() |
+------------------+
|                7 |
+------------------+
```

### Inserting several rows at once

```sql
INSERT INTO products (name, category_id, brand, price, stock, rating, added_on)
VALUES
    ('Lipstick',      7, 'Lakme',   599.00, 120, 4.1, '2025-10-21'),
    ('Face Wash',     7, 'Himalaya', 199.00, 300, 4.3, '2025-10-21'),
    ('Steel Bottle',  4, 'Milton',  749.00,  90, 4.5, '2025-10-22');

SELECT id, name, brand, price FROM products WHERE id > 15;
```

```{ .text .output }
+----+--------------+----------+--------+
| id | name         | brand    | price  |
+----+--------------+----------+--------+
| 16 | Lipstick     | Lakme    | 599.00 |
| 17 | Face Wash    | Himalaya | 199.00 |
| 18 | Steel Bottle | Milton   | 749.00 |
+----+--------------+----------+--------+
```

One multi-row `INSERT` is much faster than many single inserts, which matters when importing thousands of rows.

!!! tip "Always list the columns"
    `INSERT INTO customers VALUES (...)` without a column list also works, but it depends on the exact column **order** and count, so it breaks the moment someone adds a column. Always name the columns.

!!! mistake "Common Mistake: double quotes and value count"
    - Strings and dates use **single quotes**: `'Pune'`, `'2025-10-20'`. (MySQL often accepts double quotes too, but standard SQL and other databases treat `"..."` as a column name.)
    - The number of values must match the number of columns:

    ```sql
    INSERT INTO categories (name) VALUES ('Garden', 'Pets');
    ```

    ```{ .text .output }
    ERROR 1136 (21S01): Column count doesn't match value count at row 1
    ```

## Read: SELECT

`SELECT` reads data without changing it. It's by far the most-used SQL command.

### Specific columns

```sql
SELECT name, city FROM customers;
```

```{ .text .output }
+--------------+-----------+
| name         | city      |
+--------------+-----------+
| Asha Reddy   | Hyderabad |
| Ravi Kumar   | Bangalore |
| Kiran Rao    | Hyderabad |
| Meena Iyer   | Chennai   |
| Arjun Singh  | Delhi     |
| Divya Nair   | Kochi     |
| Rahul Verma  | Pune      |
| Sneha Patil  | Pune      |
| Vikram Joshi | Mumbai    |
| Priya Sharma | Bangalore |
| Neha Gupta   | Jaipur    |
+--------------+-----------+
```

### All columns

```{ .sql .no-run }
SELECT * FROM customers;
```

`*` means "every column". It's handy for exploring, but in application code always list the columns you need: it's faster, uses less network, and doesn't break when columns are added.

### Column aliases and calculated columns

`AS` gives a column a friendlier name. You can also calculate new columns on the fly:

```sql
SELECT
    name                 AS product,
    price,
    stock,
    price * stock        AS stock_value,
    price * 0.18         AS gst_amount
FROM products
WHERE category_id = 1;
```

```{ .text .output }
+--------------------+----------+-------+-------------+------------+
| product            | price    | stock | stock_value | gst_amount |
+--------------------+----------+-------+-------------+------------+
| iPhone 15          | 79999.00 |    25 |  1999975.00 | 14399.8200 |
| Galaxy S24         | 74999.00 |    30 |  2249970.00 | 13499.8200 |
| Airdopes 141       |  1299.00 |   200 |   259800.00 |   233.8200 |
| Inspiron 15 Laptop | 58999.00 |    12 |   707988.00 | 10619.8200 |
| USB-C Cable        |   299.00 |   500 |   149500.00 |    53.8200 |
+--------------------+----------+-------+-------------+------------+
```

The table isn't changed; `stock_value` and `gst_amount` exist only in the result.

### Filtering rows with WHERE

```sql
SELECT id, name, city FROM customers WHERE city = 'Pune';
```

```{ .text .output }
+----+-------------+------+
| id | name        | city |
+----+-------------+------+
|  7 | Rahul Verma | Pune |
|  8 | Sneha Patil | Pune |
+----+-------------+------+
```

```sql
SELECT name, price FROM products WHERE price < 1000;
```

```{ .text .output }
+----------------+--------+
| name           | price  |
+----------------+--------+
| USB-C Cable    | 299.00 |
| Cotton T-Shirt | 799.00 |
| Atomic Habits  | 499.00 |
| Wings of Fire  | 350.00 |
| Yoga Mat       | 999.00 |
| Lipstick       | 599.00 |
| Face Wash      | 199.00 |
| Steel Bottle   | 749.00 |
+----------------+--------+
```

You'll master filtering (`AND`, `OR`, `LIKE`, `IN`, `BETWEEN`, `NULL`) and sorting in the next lesson.

!!! info "SQL keywords are case-insensitive"
    `SELECT`, `select` and `Select` all work. The convention is UPPERCASE keywords and lowercase table and column names, which makes queries easier to read. String comparisons in MySQL are case-insensitive by default too: `WHERE city = 'pune'` matches `'Pune'`.

## Update: UPDATE

```{ .sql .no-run }
UPDATE table_name
SET column1 = value1, column2 = value2
WHERE condition;
```

Kiran finally added a phone number:

```sql
UPDATE customers
SET phone = '9876500003'
WHERE id = 3;

SELECT id, name, phone FROM customers WHERE id = 3;
```

```{ .text .output }
+----+-----------+------------+
| id | name      | phone      |
+----+-----------+------------+
|  3 | Kiran Rao | 9876500003 |
+----+-----------+------------+
```

Update several columns, and use the column's current value in the calculation. Here we restock Wings of Fire and raise its price by 10%:

```sql
UPDATE products
SET stock = stock + 50,
    price = price * 1.10
WHERE name = 'Wings of Fire';

SELECT name, price, stock FROM products WHERE name = 'Wings of Fire';
```

```{ .text .output }
+---------------+--------+-------+
| name          | price  | stock |
+---------------+--------+-------+
| Wings of Fire | 385.00 |    50 |
+---------------+--------+-------+
```

Update many rows at once: mark all of Asha's shipped orders as delivered:

```sql
UPDATE orders
SET status = 'delivered'
WHERE customer_id = 1 AND status = 'shipped';

SELECT id, customer_id, status FROM orders WHERE customer_id = 1;
```

```{ .text .output }
+----+-------------+-----------+
| id | customer_id | status    |
+----+-------------+-----------+
|  1 |           1 | delivered |
|  3 |           1 | delivered |
| 10 |           1 | delivered |
+----+-------------+-----------+
```

!!! danger "Never forget WHERE"
    ```{ .sql .no-run }
    UPDATE products SET price = 99;
    ```

    Without `WHERE`, **every row** in the table is updated: all 18 products now cost ₹99. There is no undo button. Before running an `UPDATE` or `DELETE`, run the same `WHERE` with a `SELECT` first to see exactly which rows will be affected:

    ```{ .sql .no-run }
    SELECT * FROM products WHERE name = 'Wings of Fire';   -- check first
    UPDATE products SET price = 385 WHERE name = 'Wings of Fire';
    ```

    MySQL Workbench enables **safe update mode** by default, which blocks `UPDATE` and `DELETE` statements that don't filter on a key column. You'll see `Error Code: 1175. You are using safe update mode...`. Keep it on while learning.

## Delete: DELETE

```{ .sql .no-run }
DELETE FROM table_name WHERE condition;
```

Let's try to remove the Beauty category we added earlier. First check what we're about to delete:

```sql
SELECT * FROM categories WHERE name = 'Beauty';
```

```{ .text .output }
+----+--------+
| id | name   |
+----+--------+
|  7 | Beauty |
+----+--------+
```

The Beauty category now has products (Lipstick and Face Wash), so deleting it would leave those products pointing at nothing. MySQL refuses:

```sql
DELETE FROM categories WHERE name = 'Beauty';
```

```{ .text .output }
ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key constraint fails (`ksr_shop`.`products`, CONSTRAINT `products_ibfk_1` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`))
```

This is a **foreign key** protecting your data: you can't delete a parent row while child rows still reference it. Delete or reassign the children first:

```sql
DELETE FROM products WHERE category_id = 7;
DELETE FROM categories WHERE name = 'Beauty';

SELECT * FROM categories;
```

```{ .text .output }
+----+----------------+
| id | name           |
+----+----------------+
|  3 | Books          |
|  1 | Electronics    |
|  2 | Fashion        |
|  4 | Home & Kitchen |
|  5 | Sports         |
|  6 | Toys           |
+----+----------------+
```

!!! info "Why is this list in alphabetical order, not by id?"
    Without `ORDER BY`, **MySQL doesn't guarantee any order**. Here it happened to read the rows through the `UNIQUE` index on `name`, so they came back alphabetically. Never rely on the "natural" order of rows. When order matters, always say so with `ORDER BY`, as you'll learn in the next lesson.

Some relationships are set up to delete children automatically with `ON DELETE CASCADE`. In ksr_shop, deleting an **order** also deletes its **order_items**:

```sql
SELECT COUNT(*) AS items_before FROM order_items WHERE order_id = 12;
DELETE FROM orders WHERE id = 12;
SELECT COUNT(*) AS items_after FROM order_items WHERE order_id = 12;
```

```{ .text .output }
+--------------+
| items_before |
+--------------+
|            1 |
+--------------+
+-------------+
| items_after |
+-------------+
|           0 |
+-------------+
```

You'll design these rules yourself in [Database Design](08-database-design.md).

!!! realworld "In Real Projects"
    Many companies **never actually delete** important records like customers or orders. Instead they do a **soft delete**: add a column such as `is_deleted BOOLEAN DEFAULT FALSE` or `deleted_at DATETIME`, and "deleting" just sets it with an `UPDATE`. The data stays available for audits, refunds and analytics, and can be restored if a user deletes something by mistake.

## Upsert: Insert or Update

A common need: *"insert this row, but if it already exists, update it instead"*. MySQL does this with `ON DUPLICATE KEY UPDATE`, which kicks in when an insert would break a `PRIMARY KEY` or `UNIQUE` constraint:

```sql
INSERT INTO customers (name, email, city, phone, joined_on)
VALUES ('Ravi Kumar', 'ravi@example.com', 'Hyderabad', '9876500002', '2024-03-22') AS new
ON DUPLICATE KEY UPDATE city = new.city;

SELECT id, name, email, city FROM customers WHERE email = 'ravi@example.com';
```

```{ .text .output }
+----+------------+------------------+-----------+
| id | name       | email            | city      |
+----+------------+------------------+-----------+
|  2 | Ravi Kumar | ravi@example.com | Hyderabad |
+----+------------+------------------+-----------+
```

Ravi's email already existed, so instead of failing with a duplicate error, MySQL updated his city. `AS new` names the row we tried to insert, so `new.city` means "the city from that row". (Older tutorials write `VALUES(city)`, which still works but is deprecated in MySQL 8.)

## Common Mistakes

| Mistake | Error / Result | Fix |
|---------|---------------|-----|
| `UPDATE` / `DELETE` without `WHERE` | Every row changed or deleted | Always write `WHERE`; test it with `SELECT` first |
| Column count ≠ value count | `ERROR 1136 (21S01): Column count doesn't match value count at row 1` | Match the lists |
| Unknown column name | `ERROR 1054 (42S22): Unknown column '...' in 'field list'` | Check spelling with `DESCRIBE` |
| Text without quotes: `WHERE city = Pune` | `ERROR 1054: Unknown column 'Pune'` | `'Pune'` |
| Deleting a parent row that has children | `ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key constraint fails` | Delete or reassign the children first, or use `ON DELETE CASCADE` deliberately |
| Inserting a child with a non-existent parent | `ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails` | Insert the parent first; use a valid id |
| Expecting a `SELECT` alias to be saved | Aliases and calculated columns exist only in the result | Use `ALTER TABLE` + `UPDATE` to store data |
| `= NULL` in WHERE | Matches nothing | Use `IS NULL` (next lesson) |

## Practice Exercises

Use `ksr_shop`. Reset it any time by re-running `ksr_shop.sql`.

**Easy**

1. Insert yourself as a customer (use your own name, a made-up email, your city and today's date).
2. Select only the `name`, `brand` and `price` of all products.
3. Select products with fewer than 20 items in stock.

**Medium**

4. Insert three new products in the Books category in a single `INSERT`.
5. Show each product's name, price and a column `discounted_price` with 15% off. Give it a clear alias.
6. Increase the salary of every employee in the Support department by ₹5,000. Run a `SELECT` before and after.

**Challenge**

7. A customer wants to close their account. Write the statements to delete customer **Divya Nair** (id 6) and explain the error you get. Then write a **soft delete** version instead: add a `deleted_at DATETIME` column to `customers`, set it for Divya, and write a query that lists only active customers.

??? success "Solutions (click to expand)"

    ```{ .sql .no-run }
    -- 1
    INSERT INTO customers (name, email, city, phone, joined_on)
    VALUES ('Your Name', 'you@example.com', 'Hyderabad', '9000000000', '2026-10-31');

    -- 2
    SELECT name, brand, price FROM products;

    -- 3
    SELECT name, stock FROM products WHERE stock < 20;

    -- 4
    INSERT INTO products (name, category_id, brand, price, stock, rating, added_on) VALUES
        ('Clean Code',         3, 'Pearson',  899.00, 40, 4.6, '2026-10-31'),
        ('The Alchemist',      3, 'Harper',   299.00, 70, 4.5, '2026-10-31'),
        ('Ikigai',             3, 'Penguin',  350.00, 55, 4.4, '2026-10-31');

    -- 5
    SELECT name, price, price * 0.85 AS discounted_price FROM products;

    -- 6
    SELECT name, salary FROM employees WHERE department = 'Support';
    UPDATE employees SET salary = salary + 5000 WHERE department = 'Support';
    SELECT name, salary FROM employees WHERE department = 'Support';

    -- 7
    DELETE FROM customers WHERE id = 6;
    -- ERROR 1451: Divya has an order (order 8) referencing her, so the FK blocks the delete

    ALTER TABLE customers ADD COLUMN deleted_at DATETIME NULL;
    UPDATE customers SET deleted_at = NOW() WHERE id = 6;
    SELECT id, name FROM customers WHERE deleted_at IS NULL;
    ```

!!! note "Mini Assignment"
    In `ksr_practice`, build a **to-do app** table: `tasks (id, title, priority ENUM('low','medium','high'), is_done BOOLEAN DEFAULT FALSE, due_date DATE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`. Write the SQL for every feature of the app: add a task, list all tasks, list pending high-priority tasks, mark a task done, rename a task, delete completed tasks, and "undo" a completion. Save all statements in a `todo.sql` file.

## Interview Questions

!!! interview "1. What does CRUD stand for and which SQL commands map to it?"
    Create → `INSERT`, Read → `SELECT`, Update → `UPDATE`, Delete → `DELETE`. In REST APIs these typically correspond to POST, GET, PUT/PATCH and DELETE.

!!! interview "2. What happens if you run UPDATE or DELETE without a WHERE clause?"
    It applies to every row in the table. All rows get updated or deleted, and outside a transaction it can't be undone. That's why you should test the `WHERE` with a `SELECT` first, and why Workbench's safe update mode exists.

!!! interview "3. Why should you avoid `SELECT *` in application code?"
    It fetches unnecessary columns (more I/O and network), can expose sensitive columns, prevents some index-only optimisations, and code that depends on column positions can break when the table changes. Select only the columns you need.

!!! interview "4. How do you get the id of the row you just inserted?"
    `SELECT LAST_INSERT_ID();` returns the last AUTO_INCREMENT value generated in the current connection. Database drivers expose it too: `cursor.lastrowid` in Python, `getGeneratedKeys()` in JDBC.

!!! interview "5. What is a soft delete and why use it?"
    Marking a row as deleted (for example `deleted_at = NOW()` or `is_deleted = 1`) instead of physically removing it. It preserves history for audits and analytics, allows recovery, and avoids breaking foreign key relationships. Queries must then filter out soft-deleted rows.

!!! interview "Scenario: a teammate ran `UPDATE orders SET status = 'cancelled'` in production by mistake. What should happen next, and how do you prevent it?"
    Stop further writes if possible and restore the affected data from the latest backup or binary logs (point-in-time recovery). Prevention: never run ad-hoc DML on production without review; use transactions (`START TRANSACTION`, check, then `COMMIT`); keep safe update mode on; give developers read-only production access; and make changes through tested scripts or migrations.

## Summary

| Operation | Syntax |
|-----------|--------|
| Insert one | `INSERT INTO t (c1, c2) VALUES (v1, v2);` |
| Insert many | `INSERT INTO t (c1, c2) VALUES (...), (...), (...);` |
| New id | `SELECT LAST_INSERT_ID();` |
| Read | `SELECT c1, c2 FROM t WHERE ...;` · `AS` for aliases · calculated columns |
| Update | `UPDATE t SET c1 = v1, c2 = c2 + 1 WHERE ...;` |
| Delete | `DELETE FROM t WHERE ...;` |
| Upsert | `INSERT ... VALUES (...) AS new ON DUPLICATE KEY UPDATE c = new.c;` |
| Safety | `SELECT` with the same `WHERE` first; foreign keys block orphan rows; consider soft deletes |

**Next lesson:** [Filtering, Sorting & Pagination](05-filtering-sorting.md), finding exactly the rows you need.
