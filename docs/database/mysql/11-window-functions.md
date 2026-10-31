---
lesson: true
category: MySQL
short: Windows
description: Window functions in MySQL 8 — OVER and PARTITION BY, ROW_NUMBER, RANK, DENSE_RANK, top-N per group, running totals, LAG and LEAD, percentages of totals and NTILE.
---

# Window Functions

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain how window functions differ from `GROUP BY`
    - Use `OVER()` with `PARTITION BY` and `ORDER BY`
    - Rank rows with `ROW_NUMBER`, `RANK` and `DENSE_RANK`, and solve "top N per group"
    - Calculate running totals, moving averages and percentages of a total
    - Compare each row with the previous or next row using `LAG` and `LEAD`

**Prerequisites:** [Aggregations](06-aggregations-group-by.md) and [Subqueries & CTEs](10-subqueries-views-ctes.md). Window functions need **MySQL 8.0+**.

## What is a Window Function?

`GROUP BY` **collapses** rows: 10 employees grouped by department become 4 rows, and you lose the individual names.

A **window function** calculates across a set of related rows (the *window*) but **keeps every row**. You can show each employee **and** their department's average side by side:

```sql
SELECT
    name,
    department,
    salary,
    ROUND(AVG(salary) OVER (PARTITION BY department)) AS dept_avg
FROM employees
ORDER BY department, salary DESC;
```

```{ .text .output }
+----------------+-------------+-----------+----------+
| name           | department  | salary    | dept_avg |
+----------------+-------------+-----------+----------+
| Suresh Babu    | Engineering | 180000.00 |   117500 |
| Farhan Ali     | Engineering | 120000.00 |   117500 |
| Pooja Hegde    | Engineering |  85000.00 |   117500 |
| Nikhil Jain    | Engineering |  85000.00 |   117500 |
| Lakshmi Menon  | Management  | 250000.00 |   250000 |
| Anita Desai    | Sales       | 150000.00 |    88333 |
| Ritu Kapoor    | Sales       |  60000.00 |    88333 |
| Manoj Pillai   | Sales       |  55000.00 |    88333 |
| Swati Kulkarni | Support     |  70000.00 |    55000 |
| Imran Shaikh   | Support     |  40000.00 |    55000 |
+----------------+-------------+-----------+----------+
```

!!! example "Real-life analogy: a class report card"
    Each student's report card shows their own marks **and** the class average, plus their rank in class. You don't lose the individual student to show the class number. That's a window function: per-row detail plus group context.

### Anatomy of OVER()

```{ .sql .no-run }
function_name(...) OVER (
    PARTITION BY column      -- optional: split rows into groups (like GROUP BY, but rows are kept)
    ORDER BY column          -- optional: order rows inside each group
)
```

| Part | Meaning | Without it |
|------|---------|------------|
| `OVER ()` | Marks it as a window function | — |
| `PARTITION BY` | Restart the calculation for each group | The whole result is one window |
| `ORDER BY` (inside `OVER`) | Order within the window (needed for ranks, running totals, LAG) | No ordering |

```sql
SELECT
    name,
    salary,
    SUM(salary) OVER ()                       AS company_payroll,
    ROUND(100 * salary / SUM(salary) OVER (), 1) AS pct_of_payroll
FROM employees
ORDER BY salary DESC
LIMIT 5;
```

```{ .text .output }
+---------------+-----------+-----------------+----------------+
| name          | salary    | company_payroll | pct_of_payroll |
+---------------+-----------+-----------------+----------------+
| Lakshmi Menon | 250000.00 |      1095000.00 |           22.8 |
| Suresh Babu   | 180000.00 |      1095000.00 |           16.4 |
| Anita Desai   | 150000.00 |      1095000.00 |           13.7 |
| Farhan Ali    | 120000.00 |      1095000.00 |           11.0 |
| Pooja Hegde   |  85000.00 |      1095000.00 |            7.8 |
+---------------+-----------+-----------------+----------------+
```

`OVER ()` with nothing inside means "the whole result", which is perfect for percentage-of-total columns.

## Ranking: ROW_NUMBER, RANK, DENSE_RANK

Pooja and Nikhil both earn ₹85,000. Watch how each function treats the tie:

```sql
SELECT
    name,
    salary,
    ROW_NUMBER() OVER (ORDER BY salary DESC) AS row_num,
    RANK()       OVER (ORDER BY salary DESC) AS rnk,
    DENSE_RANK() OVER (ORDER BY salary DESC) AS dense_rnk
FROM employees
ORDER BY salary DESC;
```

```{ .text .output }
+----------------+-----------+---------+-----+-----------+
| name           | salary    | row_num | rnk | dense_rnk |
+----------------+-----------+---------+-----+-----------+
| Lakshmi Menon  | 250000.00 |       1 |   1 |         1 |
| Suresh Babu    | 180000.00 |       2 |   2 |         2 |
| Anita Desai    | 150000.00 |       3 |   3 |         3 |
| Farhan Ali     | 120000.00 |       4 |   4 |         4 |
| Pooja Hegde    |  85000.00 |       5 |   5 |         5 |
| Nikhil Jain    |  85000.00 |       6 |   5 |         5 |
| Swati Kulkarni |  70000.00 |       7 |   7 |         6 |
| Ritu Kapoor    |  60000.00 |       8 |   8 |         7 |
| Manoj Pillai   |  55000.00 |       9 |   9 |         8 |
| Imran Shaikh   |  40000.00 |      10 |  10 |         9 |
+----------------+-----------+---------+-----+-----------+
```

| Function | Ties | Gaps after ties | Example sequence |
|----------|------|-----------------|------------------|
| `ROW_NUMBER()` | Different numbers (arbitrary order between ties) | — | 1, 2, 3, 4, 5, 6 |
| `RANK()` | Same rank | **Yes**, it skips | 1, 2, 3, 4, 5, **5**, **7** |
| `DENSE_RANK()` | Same rank | **No** | 1, 2, 3, 4, 5, **5**, **6** |

!!! tip "Which one to use"
    `ROW_NUMBER` for "exactly one row per…" (de-duplication, pagination). `RANK` for competition-style rankings (two people tied for 5th means no 6th place). `DENSE_RANK` for "the Nth highest **value**" (second-highest salary).

### Ranking within groups

Add `PARTITION BY` to restart the ranking for each department:

```sql
SELECT
    department,
    name,
    salary,
    DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank_in_dept
FROM employees
ORDER BY department, rank_in_dept;
```

```{ .text .output }
+-------------+----------------+-----------+--------------+
| department  | name           | salary    | rank_in_dept |
+-------------+----------------+-----------+--------------+
| Engineering | Suresh Babu    | 180000.00 |            1 |
| Engineering | Farhan Ali     | 120000.00 |            2 |
| Engineering | Pooja Hegde    |  85000.00 |            3 |
| Engineering | Nikhil Jain    |  85000.00 |            3 |
| Management  | Lakshmi Menon  | 250000.00 |            1 |
| Sales       | Anita Desai    | 150000.00 |            1 |
| Sales       | Ritu Kapoor    |  60000.00 |            2 |
| Sales       | Manoj Pillai   |  55000.00 |            3 |
| Support     | Swati Kulkarni |  70000.00 |            1 |
| Support     | Imran Shaikh   |  40000.00 |            2 |
+-------------+----------------+-----------+--------------+
```

## Top N per Group

*The highest-paid employee in each department* is one of the most common interview questions, and impossible with plain `GROUP BY` (remember the "isn't in GROUP BY" error from lesson 06). Rank inside a CTE, then filter:

```sql
WITH ranked AS (
    SELECT
        department, name, salary,
        RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rnk
    FROM employees
)
SELECT department, name, salary
FROM ranked
WHERE rnk = 1
ORDER BY salary DESC;
```

```{ .text .output }
+-------------+----------------+-----------+
| department  | name           | salary    |
+-------------+----------------+-----------+
| Management  | Lakshmi Menon  | 250000.00 |
| Engineering | Suresh Babu    | 180000.00 |
| Sales       | Anita Desai    | 150000.00 |
| Support     | Swati Kulkarni |  70000.00 |
+-------------+----------------+-----------+
```

You can't put a window function directly in `WHERE`, because window functions are calculated **after** `WHERE`. That's why we rank in a CTE first.

*The two most expensive products in each category*:

```sql
WITH ranked AS (
    SELECT
        c.name AS category, p.name AS product, p.price,
        ROW_NUMBER() OVER (PARTITION BY p.category_id ORDER BY p.price DESC) AS rn
    FROM products p
    JOIN categories c ON c.id = p.category_id
)
SELECT category, product, price
FROM ranked
WHERE rn <= 2
ORDER BY category, price DESC;
```

```{ .text .output }
+----------------+---------------------+----------+
| category       | product             | price    |
+----------------+---------------------+----------+
| Books          | Python Crash Course |  2199.00 |
| Books          | Atomic Habits       |   499.00 |
| Electronics    | iPhone 15           | 79999.00 |
| Electronics    | Galaxy S24          | 74999.00 |
| Fashion        | Running Shoes       |  4299.00 |
| Fashion        | Denim Jacket        |  3499.00 |
| Home & Kitchen | Mixer Grinder       |  3899.00 |
| Home & Kitchen | Non-stick Pan       |  1599.00 |
| Sports         | Cricket Bat         |  2499.00 |
| Sports         | Yoga Mat            |   999.00 |
+----------------+---------------------+----------+
```

*The second-highest salary* with `DENSE_RANK`, which correctly handles ties:

```sql
WITH s AS (
    SELECT DISTINCT salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS dr
    FROM employees
)
SELECT salary FROM s WHERE dr = 2;
```

```{ .text .output }
+-----------+
| salary    |
+-----------+
| 180000.00 |
+-----------+
```

!!! realworld "In Real Projects"
    "Top N per group" shows up everywhere: the latest order per customer, the best-selling product per category, the top 3 students per batch, the most recent status update per ticket. The pattern is always the same: `ROW_NUMBER() OVER (PARTITION BY group ORDER BY metric DESC)` in a CTE, then `WHERE rn <= N`.

## Running Totals and Moving Averages

With `ORDER BY` inside `OVER`, `SUM` becomes a **running (cumulative) total**:

```sql
WITH daily AS (
    SELECT o.order_date, SUM(oi.quantity * oi.unit_price) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_date
)
SELECT
    order_date,
    revenue,
    SUM(revenue) OVER (ORDER BY order_date) AS running_total
FROM daily
ORDER BY order_date;
```

```{ .text .output }
+------------+----------+---------------+
| order_date | revenue  | running_total |
+------------+----------+---------------+
| 2025-06-05 |  2297.00 |       2297.00 |
| 2025-06-18 | 74999.00 |      77296.00 |
| 2025-07-02 |  6696.00 |      83992.00 |
| 2025-08-03 |  1599.00 |      85591.00 |
| 2025-08-15 |  2499.00 |      88090.00 |
| 2025-08-28 |  2698.00 |      90788.00 |
| 2025-09-10 |  3499.00 |      94287.00 |
| 2025-09-25 | 79999.00 |     174286.00 |
| 2025-10-01 |  3794.00 |     178080.00 |
| 2025-10-05 |  1948.00 |     180028.00 |
| 2025-10-12 |   499.00 |     180527.00 |
+------------+----------+---------------+
```

### Frames: which rows are in the window

A **frame** narrows the window to nearby rows. A 3-order moving average:

```sql
WITH totals AS (
    SELECT order_id, SUM(quantity * unit_price) AS total
    FROM order_items
    GROUP BY order_id
)
SELECT
    order_id,
    total,
    ROUND(AVG(total) OVER (ORDER BY order_id ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)) AS moving_avg_3
FROM totals
ORDER BY order_id;
```

```{ .text .output }
+----------+----------+--------------+
| order_id | total    | moving_avg_3 |
+----------+----------+--------------+
|        1 |  2297.00 |         2297 |
|        2 | 74999.00 |        38648 |
|        3 |  6696.00 |        27997 |
|        4 | 58999.00 |        46898 |
|        5 |  1599.00 |        22431 |
|        6 |  2499.00 |        21032 |
|        7 |  2698.00 |         2265 |
|        8 |  3499.00 |         2899 |
|        9 | 79999.00 |        28732 |
|       10 |  3794.00 |        29097 |
|       11 |  1948.00 |        28580 |
|       12 |   499.00 |         2080 |
+----------+----------+--------------+
```

| Frame | Meaning |
|-------|---------|
| `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` | From the first row up to this one (running total) |
| `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` | This row and the two before (moving average) |
| `ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING` | Previous, current and next |
| `ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING` | From here to the end |

## LAG and LEAD: Comparing Rows

`LAG(col)` reads the value from the **previous** row; `LEAD(col)` from the **next** row. They're perfect for "compared with last month" reports.

```sql
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
           SUM(oi.quantity * oi.unit_price)   AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    WHERE o.status <> 'cancelled'
    GROUP BY month
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month)                    AS prev_month,
    revenue - LAG(revenue) OVER (ORDER BY month)          AS change_amt,
    ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month))
          / LAG(revenue) OVER (ORDER BY month), 1)        AS change_pct
FROM monthly
ORDER BY month;
```

```{ .text .output }
+---------+----------+------------+------------+------------+
| month   | revenue  | prev_month | change_amt | change_pct |
+---------+----------+------------+------------+------------+
| 2025-06 | 77296.00 |       NULL |       NULL |       NULL |
| 2025-07 |  6696.00 |   77296.00 |  -70600.00 |      -91.3 |
| 2025-08 |  6796.00 |    6696.00 |     100.00 |        1.5 |
| 2025-09 | 83498.00 |    6796.00 |   76702.00 |     1128.6 |
| 2025-10 |  6241.00 |   83498.00 |  -77257.00 |      -92.5 |
+---------+----------+------------+------------+------------+
```

The first month has no previous row, so `LAG` returns `NULL`. You can give a default: `LAG(revenue, 1, 0)`.

*Days between each customer's consecutive orders*:

```sql
SELECT
    customer_id,
    id AS order_id,
    order_date,
    LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS previous_order,
    DATEDIFF(order_date,
             LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date)) AS days_between
FROM orders
WHERE customer_id IN (1, 2, 4)
ORDER BY customer_id, order_date;
```

```{ .text .output }
+-------------+----------+------------+----------------+--------------+
| customer_id | order_id | order_date | previous_order | days_between |
+-------------+----------+------------+----------------+--------------+
|           1 |        1 | 2025-06-05 | NULL           |         NULL |
|           1 |        3 | 2025-07-02 | 2025-06-05     |           27 |
|           1 |       10 | 2025-10-01 | 2025-07-02     |           91 |
|           2 |        2 | 2025-06-18 | NULL           |         NULL |
|           2 |        7 | 2025-08-28 | 2025-06-18     |           71 |
|           4 |        5 | 2025-08-03 | NULL           |         NULL |
|           4 |       12 | 2025-10-12 | 2025-08-03     |           70 |
+-------------+----------+------------+----------------+--------------+
```

## More Window Functions

| Function | Returns |
|----------|---------|
| `NTILE(n)` | Splits rows into `n` roughly equal buckets (quartiles, deciles) |
| `FIRST_VALUE(col)` / `LAST_VALUE(col)` | First / last value in the window |
| `PERCENT_RANK()` | Relative rank from 0 to 1 |
| `CUME_DIST()` | Fraction of rows with a value ≤ the current one |

Split products into 3 price tiers and show each product's gap to the cheapest item in its category:

```sql
SELECT
    name,
    price,
    NTILE(3) OVER (ORDER BY price DESC)                               AS price_tier,
    price - FIRST_VALUE(price) OVER (PARTITION BY category_id ORDER BY price) AS above_cheapest_in_category
FROM products
WHERE category_id IN (1, 2)
ORDER BY price DESC;
```

```{ .text .output }
+--------------------+----------+------------+----------------------------+
| name               | price    | price_tier | above_cheapest_in_category |
+--------------------+----------+------------+----------------------------+
| iPhone 15          | 79999.00 |          1 |                   79700.00 |
| Galaxy S24         | 74999.00 |          1 |                   74700.00 |
| Inspiron 15 Laptop | 58999.00 |          1 |                   58700.00 |
| Running Shoes      |  4299.00 |          2 |                    3500.00 |
| Denim Jacket       |  3499.00 |          2 |                    2700.00 |
| Airdopes 141       |  1299.00 |          2 |                    1000.00 |
| Cotton T-Shirt     |   799.00 |          3 |                       0.00 |
| USB-C Cable        |   299.00 |          3 |                       0.00 |
+--------------------+----------+------------+----------------------------+
```

### Named windows

When several functions share the same window, name it once with `WINDOW`:

```sql
SELECT
    name, department, salary,
    RANK()      OVER w AS rnk,
    MAX(salary) OVER w AS dept_max
FROM employees
WHERE department = 'Engineering'
WINDOW w AS (PARTITION BY department ORDER BY salary DESC);
```

```{ .text .output }
+-------------+-------------+-----------+-----+-----------+
| name        | department  | salary    | rnk | dept_max  |
+-------------+-------------+-----------+-----+-----------+
| Suresh Babu | Engineering | 180000.00 |   1 | 180000.00 |
| Farhan Ali  | Engineering | 120000.00 |   2 | 180000.00 |
| Pooja Hegde | Engineering |  85000.00 |   3 | 180000.00 |
| Nikhil Jain | Engineering |  85000.00 |   3 | 180000.00 |
+-------------+-------------+-----------+-----+-----------+
```

## GROUP BY vs Window Functions

| | `GROUP BY` | Window function |
|---|---|---|
| Rows returned | One per group | Every row |
| Individual columns | Only grouped columns | Any column |
| Typical use | Totals and summaries | Ranks, running totals, comparisons, % of total |
| Filtering on the result | `HAVING` | Wrap in a CTE or subquery, then `WHERE` |

Logical order: `FROM → WHERE → GROUP BY → HAVING → window functions → SELECT → ORDER BY → LIMIT`.

## Common Mistakes

| Mistake | Error / Result | Fix |
|---------|---------------|-----|
| Window function in `WHERE` | `ERROR 3593 (HY000): You cannot use the window function 'rank' in this context.` | Compute it in a CTE, then filter |
| `RANK` without `ORDER BY` in `OVER` | Everyone gets rank 1 | Add `ORDER BY` inside `OVER` |
| `ROW_NUMBER` for "Nth highest value" with ties | Picks an arbitrary row among ties | `DENSE_RANK` |
| `LAST_VALUE` returning the current row | The default frame ends at the current row | Add `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` |
| Forgetting `PARTITION BY` | Ranks or totals across the whole table instead of per group | Add `PARTITION BY group_column` |
| Using MySQL 5.7 | `ERROR 1064` near `OVER` | Window functions need MySQL 8.0+ |

## Practice Exercises

Use a fresh `ksr_shop`.

**Easy**

1. Number all products from most to least expensive with `ROW_NUMBER`.
2. Show each employee's salary and the highest salary in their department, without `GROUP BY`.
3. Show each product's price as a percentage of the total price of all products.

**Medium**

4. For each customer, show their orders with an order number per customer (1st order, 2nd order, …) based on date.
5. Find the **latest order** of every customer (one row per customer) with its status.
6. Rank cities by total revenue (non-cancelled orders) using `DENSE_RANK`.

**Challenge**

7. Build a **sales leaderboard** per category: for each product, show the category, product, units sold, revenue, rank within its category by revenue, its share of the category's revenue (%), and the running total of category revenue in rank order. Include products with zero sales.

??? success "Solutions (click to expand)"

    ```{ .sql .no-run }
    -- 1
    SELECT ROW_NUMBER() OVER (ORDER BY price DESC) AS n, name, price FROM products;

    -- 2
    SELECT name, department, salary,
           MAX(salary) OVER (PARTITION BY department) AS dept_max
    FROM employees;

    -- 3
    SELECT name, price,
           ROUND(100 * price / SUM(price) OVER (), 2) AS pct_of_total
    FROM products;

    -- 4
    SELECT customer_id, id, order_date,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS nth_order
    FROM orders;

    -- 5
    WITH ranked AS (
        SELECT o.*, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
        FROM orders o
    )
    SELECT c.name, r.id AS order_id, r.order_date, r.status
    FROM ranked r JOIN customers c ON c.id = r.customer_id
    WHERE r.rn = 1;

    -- 6
    SELECT c.city, SUM(oi.quantity * oi.unit_price) AS revenue,
           DENSE_RANK() OVER (ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS city_rank
    FROM customers c
    JOIN orders o       ON o.customer_id = c.id
    JOIN order_items oi ON oi.order_id = o.id
    WHERE o.status <> 'cancelled'
    GROUP BY c.city;

    -- 7
    WITH sales AS (
        SELECT cat.name AS category, p.name AS product,
               COALESCE(SUM(oi.quantity), 0)                 AS units,
               COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS revenue
        FROM products p
        JOIN categories cat      ON cat.id = p.category_id
        LEFT JOIN order_items oi ON oi.product_id = p.id
        GROUP BY cat.name, p.id, p.name
    )
    SELECT category, product, units, revenue,
           RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category,
           ROUND(100 * revenue / NULLIF(SUM(revenue) OVER (PARTITION BY category), 0), 1) AS share_pct,
           SUM(revenue) OVER (PARTITION BY category ORDER BY revenue DESC
                              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_revenue
    FROM sales
    ORDER BY category, rank_in_category;
    ```

!!! note "Mini Assignment"
    Using window functions, write the queries for a **student results portal** (create a small `results(student, subject, marks)` table in `ksr_practice` with 4 students × 3 subjects): rank students per subject, show each student's total and overall rank, find the topper in each subject (handling ties), show each student's marks compared with the subject average, and split students into 2 groups with `NTILE` for remedial classes.

## Interview Questions

!!! interview "1. What is the difference between window functions and GROUP BY?"
    GROUP BY collapses rows into one row per group. Window functions compute values across a set of related rows but return every original row, so you can show detail and aggregates (ranks, running totals, group averages) side by side.

!!! interview "2. Explain the difference between ROW_NUMBER, RANK and DENSE_RANK."
    For ties: ROW_NUMBER gives unique sequential numbers (arbitrary order among ties); RANK gives tied rows the same rank and skips the following ranks (1, 2, 2, 4); DENSE_RANK gives tied rows the same rank without gaps (1, 2, 2, 3).

!!! interview "3. How do you find the top N records per group?"
    Assign `ROW_NUMBER()` (or `RANK()` / `DENSE_RANK()` to include ties) with `OVER (PARTITION BY group ORDER BY metric DESC)` in a CTE or subquery, then filter `WHERE rn <= N` in the outer query.

!!! interview "4. What do LAG and LEAD do?"
    They access a value from a previous (LAG) or following (LEAD) row within the window's order, optionally with an offset and a default: `LAG(revenue, 1, 0) OVER (ORDER BY month)`. They're used for period-over-period comparisons and gaps between events.

!!! interview "5. How do you calculate a running total?"
    `SUM(amount) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`. Add `PARTITION BY` to restart the total per group (per customer, per month).

!!! interview "Scenario: you need each customer's most recent order, and the query with `GROUP BY customer_id` plus `MAX(order_date)` doesn't let you show the order's status. How do you solve it?"
    Use `ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC, id DESC)` in a CTE and keep `rn = 1`. That returns the full latest row, including status and amount, which `GROUP BY` can't do without joining back.

## Summary

| Concept | Syntax |
|---------|--------|
| Window | `fn() OVER (PARTITION BY ... ORDER BY ...)` |
| Whole result | `SUM(x) OVER ()` for percentages of a total |
| Rankings | `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()` |
| Top N per group | Rank in a CTE → `WHERE rn <= N` |
| Running total | `SUM(x) OVER (ORDER BY date)` |
| Moving average | `AVG(x) OVER (ORDER BY d ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)` |
| Compare rows | `LAG(x)`, `LEAD(x)` |
| Buckets | `NTILE(n)` |
| Reuse a window | `WINDOW w AS (...)` |

**Next lesson:** [Transactions, Indexes & Users](12-transactions-indexes-users.md), with ACID, performance and security.
