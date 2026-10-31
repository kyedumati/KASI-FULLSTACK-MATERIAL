---
lesson: true
category: MySQL
short: Transactions
description: ACID transactions with START TRANSACTION, COMMIT, ROLLBACK and SAVEPOINT; isolation and row locking; indexes and EXPLAIN for performance; and database users with GRANT and REVOKE.
---

# Transactions, Indexes & Users

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain ACID and why money transfers need transactions
    - Use `START TRANSACTION`, `COMMIT`, `ROLLBACK` and `SAVEPOINT`
    - Describe isolation levels and lock rows with `SELECT … FOR UPDATE`
    - Speed up queries with indexes and check them with `EXPLAIN`
    - Create users and control access with `GRANT` and `REVOKE`

**Prerequisites:** [CRUD Operations](04-crud-operations.md) and [Joins](09-joins.md). Use a fresh `ksr_shop`.

## Why Transactions?

Transferring ₹1,000 from Asha to Ravi takes **two** updates:

1. Subtract ₹1,000 from Asha's balance.
2. Add ₹1,000 to Ravi's balance.

If the server crashes or an error happens **between** step 1 and step 2, ₹1,000 vanishes. A **transaction** groups statements so they **all succeed or all fail together**.

!!! example "Real-life analogy: an ATM withdrawal"
    The ATM debits your account **and** dispenses cash. If the cash gets stuck, the debit is reversed. You'd never accept "money debited, no cash". A transaction gives your SQL the same all-or-nothing guarantee.

Let's create a small accounts table to practise with:

```sql
CREATE TABLE accounts (
    id      INT PRIMARY KEY,
    holder  VARCHAR(50) NOT NULL,
    balance DECIMAL(12, 2) NOT NULL CHECK (balance >= 0)
);

INSERT INTO accounts VALUES (1, 'Asha', 5000.00), (2, 'Ravi', 2000.00);

SELECT * FROM accounts;
```

```{ .text .output }
+----+--------+---------+
| id | holder | balance |
+----+--------+---------+
|  1 | Asha   | 5000.00 |
|  2 | Ravi   | 2000.00 |
+----+--------+---------+
```

## ACID

Transactions in MySQL's InnoDB engine guarantee four properties:

| Property | Meaning | Transfer example |
|----------|---------|------------------|
| **A**tomicity | All statements succeed, or none take effect | Both updates happen, or neither |
| **C**onsistency | Data moves from one valid state to another; constraints always hold | Balance can never go negative (`CHECK`) |
| **I**solation | Concurrent transactions don't see each other's half-done work | Another user never sees money "in flight" |
| **D**urability | Once committed, changes survive crashes and power cuts | After `COMMIT`, the transfer is permanent |

## COMMIT and ROLLBACK

| Command | Effect |
|---------|--------|
| `START TRANSACTION;` (or `BEGIN;`) | Start grouping statements |
| `COMMIT;` | Save all changes permanently |
| `ROLLBACK;` | Undo every change since `START TRANSACTION` |

### A successful transfer

```sql
START TRANSACTION;

UPDATE accounts SET balance = balance - 1000 WHERE id = 1;   -- Asha pays
UPDATE accounts SET balance = balance + 1000 WHERE id = 2;   -- Ravi receives

COMMIT;

SELECT * FROM accounts;
```

```{ .text .output }
+----+--------+---------+
| id | holder | balance |
+----+--------+---------+
|  1 | Asha   | 4000.00 |
|  2 | Ravi   | 3000.00 |
+----+--------+---------+
```

### Changing your mind with ROLLBACK

```sql
START TRANSACTION;

UPDATE accounts SET balance = balance - 3000 WHERE id = 1;
SELECT holder, balance AS during_transaction FROM accounts WHERE id = 1;

ROLLBACK;

SELECT holder, balance AS after_rollback FROM accounts WHERE id = 1;
```

```{ .text .output }
+--------+--------------------+
| holder | during_transaction |
+--------+--------------------+
| Asha   |            1000.00 |
+--------+--------------------+
+--------+----------------+
| holder | after_rollback |
+--------+----------------+
| Asha   |        4000.00 |
+--------+----------------+
```

Inside the transaction, Asha's balance looked like ₹1,000. After `ROLLBACK`, it's back to ₹4,000, as if nothing happened.

### When a step fails

Asha tries to send ₹10,000, more than she has. The `CHECK (balance >= 0)` constraint rejects the debit:

```sql
START TRANSACTION;
UPDATE accounts SET balance = balance + 10000 WHERE id = 2;   -- credit Ravi first
UPDATE accounts SET balance = balance - 10000 WHERE id = 1;   -- fails: would go negative
```

```{ .text .output }
ERROR 3819 (HY000): Check constraint 'accounts_chk_1' is violated.
```

The second statement failed, but Ravi's credit is still **pending** inside the open transaction. Your application must now `ROLLBACK`, otherwise that half-finished transfer could be committed later:

```{ .sql .no-run }
ROLLBACK;
```

!!! realworld "In Real Projects"
    Your backend code wraps every multi-step operation in a transaction with `try` / `except` (Python) or `try` / `catch` (Java): **commit** if every step succeeds, **roll back** if anything raises an error. Placing an order is a classic example: insert the order, insert its items, reduce stock and record the payment, all in one transaction. Django has `transaction.atomic()`, Spring has `@Transactional`, and SQLAlchemy has `session.begin()`.

### Autocommit

By default MySQL runs in **autocommit** mode: every statement outside `START TRANSACTION` is its own transaction and is committed immediately. That's why a stray `DELETE` can't be undone. Remember too that **DDL** (`CREATE`, `ALTER`, `DROP`, `TRUNCATE`) commits immediately, even inside a transaction.

### SAVEPOINT: a partial undo

A **savepoint** is a bookmark inside a transaction that you can roll back to without undoing everything:

```sql
START TRANSACTION;

UPDATE accounts SET balance = balance - 500 WHERE id = 1;
SAVEPOINT after_first_payment;

UPDATE accounts SET balance = balance - 2000 WHERE id = 1;   -- oops, wrong amount
ROLLBACK TO SAVEPOINT after_first_payment;                    -- undo only this step

COMMIT;

SELECT * FROM accounts;
```

```{ .text .output }
+----+--------+---------+
| id | holder | balance |
+----+--------+---------+
|  1 | Asha   | 3500.00 |
|  2 | Ravi   | 3000.00 |
+----+--------+---------+
```

Only the first ₹500 payment was kept.

## Isolation and Locking

When many users run transactions at the same time, the **isolation level** decides what each transaction can see of the others' uncommitted or newly committed changes.

| Problem | What happens |
|---------|--------------|
| **Dirty read** | Reading another transaction's changes before it commits (they might be rolled back) |
| **Non-repeatable read** | Reading the same row twice in a transaction and getting different values |
| **Phantom read** | Running the same query twice and getting new rows |

| Isolation level | Dirty read | Non-repeatable read | Phantom read |
|-----------------|-----------|---------------------|--------------|
| `READ UNCOMMITTED` | Possible | Possible | Possible |
| `READ COMMITTED` | Prevented | Possible | Possible |
| `REPEATABLE READ` (**MySQL default**) | Prevented | Prevented | Mostly prevented in InnoDB |
| `SERIALIZABLE` | Prevented | Prevented | Prevented |

Stricter levels are safer but allow less concurrency. The MySQL default suits most applications.

### Locking a row before updating it

Two people buy the **last** iPhone at the same moment. Both read `stock = 1`, both sell it, and stock goes to −1 (or one order fails confusingly). `SELECT … FOR UPDATE` **locks** the row until the transaction ends, so the second buyer waits:

```{ .sql .no-run }
START TRANSACTION;

SELECT stock FROM products WHERE id = 1 FOR UPDATE;   -- other transactions must wait here

-- application checks stock > 0, then:
UPDATE products SET stock = stock - 1 WHERE id = 1;
INSERT INTO orders (customer_id, order_date, status) VALUES (5, CURDATE(), 'pending');

COMMIT;                                               -- lock released
```

!!! warning "Deadlocks"
    If transaction A locks row 1 then wants row 2, while transaction B locks row 2 then wants row 1, both wait forever. MySQL detects this, aborts one with `ERROR 1213 (40001): Deadlock found when trying to get lock`, and your application should retry. Keep transactions short, and always lock rows in the same order.

## Indexes

Without an index, finding customers from Pune means reading **every row** (a *full table scan*). On 10 rows that's instant; on 10 million rows it takes seconds.

An **index** is a separate, sorted data structure (a B-tree) that lets MySQL jump straight to matching rows.

!!! example "Real-life analogy: a book index"
    To find "normalisation" in a 500-page book, you don't read every page. You look it up in the index at the back, which points to page 212. A database index works the same way: a sorted lookup that points to the rows.

### EXPLAIN: how MySQL runs a query

`EXPLAIN` shows the plan without running the query. The `FORMAT=TREE` version is the easiest to read:

```sql
EXPLAIN FORMAT=TREE
SELECT name FROM customers WHERE city = 'Pune';
```

```{ .text .output }
-> Filter: (customers.city = 'Pune')  (cost=1.25 rows=1)
    -> Table scan on customers  (cost=1.25 rows=10)
```

"Table scan" means MySQL reads every row. Create an index on `city` and look again:

```sql
CREATE INDEX idx_customers_city ON customers (city);

EXPLAIN FORMAT=TREE
SELECT name FROM customers WHERE city = 'Pune';
```

```{ .text .output }
-> Index lookup on customers using idx_customers_city (city='Pune')  (cost=0.7 rows=2)
```

Now it's an "Index lookup": MySQL goes straight to the Pune rows. (The cost and row estimates on your machine may differ slightly; the plan type is what matters.)

### What gets indexed automatically

Primary keys, `UNIQUE` columns and foreign key columns are indexed automatically:

```sql
SELECT INDEX_NAME, COLUMN_NAME, NON_UNIQUE
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'ksr_shop' AND TABLE_NAME = 'orders'
ORDER BY INDEX_NAME;
```

```{ .text .output }
+-------------+-------------+------------+
| INDEX_NAME  | COLUMN_NAME | NON_UNIQUE |
+-------------+-------------+------------+
| customer_id | customer_id |          1 |
| PRIMARY     | id          |          0 |
+-------------+-------------+------------+
```

(`SHOW INDEX FROM orders;` shows the same information with more columns.)

### Composite indexes and the leftmost-prefix rule

An index can cover several columns. The **order matters**: an index on `(customer_id, order_date)` helps queries that filter on `customer_id`, or on `customer_id` **and** `order_date`, but **not** on `order_date` alone, just as a phone book sorted by surname then first name can't find "everyone named Ravi".

```sql
CREATE INDEX idx_orders_customer_date ON orders (customer_id, order_date);

EXPLAIN FORMAT=TREE
SELECT id, status FROM orders
WHERE customer_id = 1 AND order_date >= '2025-07-01';
```

```{ .text .output }
-> Index range scan on orders using idx_orders_customer_date over (customer_id = 1 AND '2025-07-01' <= order_date), with index condition: ((orders.customer_id = 1) and (orders.order_date >= DATE'2025-07-01'))  (cost=1.16 rows=2)
```

### When an index is NOT used

| Query pattern | Why the index can't help | Better |
|---------------|--------------------------|--------|
| `WHERE YEAR(order_date) = 2025` | A function wraps the column | `WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01'` |
| `WHERE name LIKE '%kumar'` | Leading wildcard | `LIKE 'Ravi%'`, or a FULLTEXT index |
| `WHERE phone = 9876500001` (number vs `VARCHAR`) | Type conversion on every row | `WHERE phone = '9876500001'` |
| Filtering only on the 2nd column of a composite index | Leftmost-prefix rule | Reorder the index or add another |
| Very small tables, or most rows match | A scan is cheaper | Nothing to fix |

### Index trade-offs

| ✅ Indexes help | ❌ Indexes cost |
|----------------|----------------|
| `WHERE`, `JOIN … ON`, `ORDER BY`, `GROUP BY` on the indexed columns | Extra disk space |
| Enforcing uniqueness | Slower `INSERT`, `UPDATE` and `DELETE` (every index must be updated) |

**Index columns you search, join or sort by often** (foreign keys, emails, statuses, dates). Don't index everything, and especially avoid indexing columns with few distinct values on write-heavy tables.

```{ .sql .no-run }
DROP INDEX idx_customers_city ON customers;   -- remove an index
```

!!! realworld "In Real Projects"
    The most common fix for a slow page is adding the right index. Teams turn on MySQL's **slow query log**, run `EXPLAIN` on the slow queries, and add indexes for the columns in their `WHERE` and `JOIN` clauses. A missing index on a foreign key such as `order_items.order_id` can turn a 5 ms query into a 5 second one as data grows.

## Users and Permissions (DCL)

Every application and person should get **only the permissions they need**. This is the principle of **least privilege**.

```sql
CREATE USER IF NOT EXISTS 'report_user'@'localhost' IDENTIFIED BY 'R3port#2026';

GRANT SELECT ON ksr_shop.* TO 'report_user'@'localhost';

SHOW GRANTS FOR 'report_user'@'localhost';
```

```{ .text .output }
+-----------------------------------------------------------+
| Grants for report_user@localhost                          |
+-----------------------------------------------------------+
| GRANT USAGE ON *.* TO `report_user`@`localhost`           |
| GRANT SELECT ON `ksr_shop`.* TO `report_user`@`localhost` |
+-----------------------------------------------------------+
```

`report_user` can read every table in ksr_shop but can't change anything. Grant more specific permissions as needed, down to individual tables:

```sql
GRANT INSERT, UPDATE ON ksr_shop.orders TO 'report_user'@'localhost';
REVOKE UPDATE ON ksr_shop.orders FROM 'report_user'@'localhost';

SHOW GRANTS FOR 'report_user'@'localhost';

DROP USER 'report_user'@'localhost';
```

```{ .text .output }
+------------------------------------------------------------------+
| Grants for report_user@localhost                                 |
+------------------------------------------------------------------+
| GRANT USAGE ON *.* TO `report_user`@`localhost`                  |
| GRANT SELECT ON `ksr_shop`.* TO `report_user`@`localhost`        |
| GRANT INSERT ON `ksr_shop`.`orders` TO `report_user`@`localhost` |
+------------------------------------------------------------------+
```

| Command | Purpose |
|---------|---------|
| `CREATE USER 'u'@'host' IDENTIFIED BY 'pw';` | Create a user |
| `GRANT privileges ON db.table TO 'u'@'host';` | Give permissions |
| `REVOKE privileges ON db.table FROM 'u'@'host';` | Take permissions away |
| `SHOW GRANTS FOR 'u'@'host';` | List a user's permissions |
| `ALTER USER 'u'@'host' IDENTIFIED BY 'new';` | Change a password |
| `DROP USER 'u'@'host';` | Delete a user |

| Who | Typical permissions |
|-----|---------------------|
| Web application | `SELECT, INSERT, UPDATE, DELETE` on its own database |
| Reporting / analytics | `SELECT` only (or only on views) |
| Migration tool | `CREATE, ALTER, DROP, INDEX` on its database |
| DBA | `ALL PRIVILEGES` |

`'u'@'localhost'` can connect only from the same machine; `'u'@'%'` from anywhere (use it with care, and always behind a firewall).

## Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| Multi-step changes without a transaction | Half-finished data after an error | `START TRANSACTION … COMMIT`, `ROLLBACK` on error |
| Forgetting to `COMMIT` | Changes invisible to others, then lost when the connection closes | Always end with `COMMIT` or `ROLLBACK` |
| Long transactions | Locks held for a long time; other users wait | Keep transactions short; no user input inside them |
| Expecting `ROLLBACK` to undo DDL | `DROP`/`ALTER` are already committed | Run DDL separately and carefully |
| Function on an indexed column in `WHERE` | Index ignored, full scan | Rewrite as a range on the raw column |
| Indexing every column | Slow writes, wasted space | Index what you filter, join and sort on |
| App connecting as root | Huge damage if compromised | A dedicated user with minimal grants |
| `'u'@'%'` with a weak password | Remote attacks | Strong passwords, specific hosts, firewall |

## Practice Exercises

Use a fresh `ksr_shop` (and create the `accounts` table from this lesson).

**Easy**

1. Transfer ₹750 from Ravi to Asha in a transaction and commit it.
2. Start a transaction, set every balance to 0, check the result, then roll back and check again.
3. Run `EXPLAIN FORMAT=TREE` on `SELECT * FROM products WHERE brand = 'Puma';`, add an index on `brand`, and compare.

**Medium**

4. Using a savepoint, apply three updates to Asha's balance and undo only the last two.
5. Rewrite this query so it can use an index on `joined_on`: `SELECT * FROM customers WHERE YEAR(joined_on) = 2024;`
6. Create a user `support_app` that can read `customers` and `orders`, and update only `orders`. Show its grants.

**Challenge**

7. Write the SQL for **placing an order** as one transaction: lock the product row with `FOR UPDATE`, check the stock, insert into `orders`, insert into `order_items` (using `LAST_INSERT_ID()`), reduce the stock, and commit. Explain in comments what your application should do if the stock is insufficient or any statement fails.

??? success "Solutions (click to expand)"

    ```{ .sql .no-run }
    -- 1
    START TRANSACTION;
    UPDATE accounts SET balance = balance - 750 WHERE id = 2;
    UPDATE accounts SET balance = balance + 750 WHERE id = 1;
    COMMIT;

    -- 2
    START TRANSACTION;
    UPDATE accounts SET balance = 0;
    SELECT * FROM accounts;      -- all 0
    ROLLBACK;
    SELECT * FROM accounts;      -- original balances

    -- 3
    EXPLAIN FORMAT=TREE SELECT * FROM products WHERE brand = 'Puma';   -- Table scan
    CREATE INDEX idx_products_brand ON products (brand);
    EXPLAIN FORMAT=TREE SELECT * FROM products WHERE brand = 'Puma';   -- Index lookup

    -- 4
    START TRANSACTION;
    UPDATE accounts SET balance = balance - 100 WHERE id = 1;
    SAVEPOINT s1;
    UPDATE accounts SET balance = balance - 200 WHERE id = 1;
    UPDATE accounts SET balance = balance - 300 WHERE id = 1;
    ROLLBACK TO SAVEPOINT s1;
    COMMIT;                      -- only the -100 is kept

    -- 5
    SELECT * FROM customers
    WHERE joined_on >= '2024-01-01' AND joined_on < '2025-01-01';

    -- 6
    CREATE USER 'support_app'@'localhost' IDENTIFIED BY 'Supp0rt#2026';
    GRANT SELECT ON ksr_shop.customers TO 'support_app'@'localhost';
    GRANT SELECT, UPDATE ON ksr_shop.orders TO 'support_app'@'localhost';
    SHOW GRANTS FOR 'support_app'@'localhost';

    -- 7
    START TRANSACTION;
    SELECT stock, price FROM products WHERE id = 7 FOR UPDATE;   -- lock the row
    -- application: if stock < requested quantity -> ROLLBACK and tell the user "out of stock"
    INSERT INTO orders (customer_id, order_date, status) VALUES (5, CURDATE(), 'pending');
    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (LAST_INSERT_ID(), 7, 2, 4299.00);
    UPDATE products SET stock = stock - 2 WHERE id = 7;
    COMMIT;
    -- application: wrap all of this in try/except; on any error -> ROLLBACK and log it
    ```

!!! note "Mini Assignment"
    Load ksr_shop and write down the 5 queries you think an e-commerce site runs most often (e.g. product search by category, a customer's order history, order details). Run `EXPLAIN FORMAT=TREE` on each, add indexes where you see a table scan on a filter or join column, and record the before/after plans in a short report. Finally, create two database users for the project, `shop_app` and `shop_reports`, with appropriate permissions.

## Interview Questions

!!! interview "1. What is a transaction? Explain ACID."
    A group of SQL statements executed as a single unit. Atomicity: all or nothing. Consistency: the database moves between valid states with constraints enforced. Isolation: concurrent transactions don't interfere. Durability: committed changes survive crashes.

!!! interview "2. What is the difference between COMMIT, ROLLBACK and SAVEPOINT?"
    COMMIT permanently saves all changes in the transaction. ROLLBACK undoes all changes since the transaction began. SAVEPOINT marks a point within a transaction, and `ROLLBACK TO SAVEPOINT` undoes only the changes made after it.

!!! interview "3. What is an index, and what are its disadvantages?"
    A data structure (usually a B-tree) that speeds up lookups, joins and sorting on the indexed columns. Downsides: extra storage and slower writes, since every INSERT, UPDATE and DELETE must maintain each index. Unused or redundant indexes are pure overhead.

!!! interview "4. What is the difference between a clustered and a non-clustered index in MySQL InnoDB?"
    InnoDB stores table rows in primary key order. The primary key is the clustered index, and the data lives in its leaf nodes. Secondary (non-clustered) indexes store the indexed columns plus the primary key value, which is used to look up the full row.

!!! interview "5. What is the default isolation level in MySQL, and what problem does `SELECT ... FOR UPDATE` solve?"
    REPEATABLE READ. `SELECT ... FOR UPDATE` locks the selected rows until the transaction ends, preventing lost updates or race conditions such as overselling stock when two transactions read and then update the same row.

!!! interview "Scenario: a product search page became slow after the catalogue grew to 2 million rows. How do you investigate?"
    Find the slow query (slow query log or APM), run `EXPLAIN` on it, and look for full table scans or filesort on large tables. Add indexes on the filter, join and sort columns (composite indexes in the right order), avoid functions on indexed columns and leading-wildcard `LIKE`, select only the needed columns, paginate, and consider FULLTEXT or a search engine for text search.

## Summary

| Topic | Remember |
|-------|----------|
| Transaction | `START TRANSACTION` → statements → `COMMIT` or `ROLLBACK` |
| ACID | Atomicity, Consistency, Isolation, Durability |
| Savepoint | `SAVEPOINT s;` … `ROLLBACK TO SAVEPOINT s;` |
| Autocommit | On by default; DDL always commits immediately |
| Isolation | MySQL default `REPEATABLE READ`; `FOR UPDATE` locks rows |
| Index | B-tree for fast lookups; `CREATE INDEX idx ON t (cols)` |
| EXPLAIN | `EXPLAIN FORMAT=TREE SELECT …`: "Table scan" vs "Index lookup" |
| Composite | Leftmost-prefix rule; no functions on indexed columns |
| Users | `CREATE USER`, `GRANT`, `REVOKE`, `SHOW GRANTS`; least privilege |

**Next lesson:** [Python + MySQL](13-python-mysql.md), connecting your Python code to the database safely.
