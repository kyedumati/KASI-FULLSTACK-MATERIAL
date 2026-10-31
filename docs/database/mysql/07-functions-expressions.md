---
lesson: true
category: MySQL
short: Functions
description: Arithmetic, string, date and conversion functions; handling NULL with IFNULL and COALESCE; conditional logic with CASE and IF; and combining results with UNION.
---

# Functions & Expressions

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Calculate with arithmetic expressions and numeric functions like `ROUND`
    - Clean and format text with string functions
    - Work with dates: extract parts, format, add intervals and find differences
    - Replace `NULL` with `IFNULL` / `COALESCE` and add logic with `CASE`
    - Combine results from several queries with `UNION` and `UNION ALL`

**Prerequisites:** [Aggregations & GROUP BY](06-aggregations-group-by.md)

## Expressions

An **expression** is anything that produces a value: a column, a literal, a calculation or a function call. You can use expressions in `SELECT`, `WHERE`, `ORDER BY`, `GROUP BY`, `HAVING` and `UPDATE`.

| Operator | Meaning | Example |
|----------|---------|---------|
| `+ - * /` | Arithmetic | `price * 1.18` |
| `DIV` | Integer division | `17 DIV 5` → `3` |
| `%` or `MOD` | Remainder | `17 % 5` → `2` |

```sql
SELECT
    name,
    price,
    ROUND(price * 0.90, 2)        AS sale_price,
    ROUND(price * 0.18, 2)        AS gst,
    ROUND(price * 1.18)           AS price_with_gst
FROM products
WHERE category_id = 2;
```

```{ .text .output }
+----------------+---------+------------+--------+----------------+
| name           | price   | sale_price | gst    | price_with_gst |
+----------------+---------+------------+--------+----------------+
| Denim Jacket   | 3499.00 |    3149.10 | 629.82 |           4129 |
| Running Shoes  | 4299.00 |    3869.10 | 773.82 |           5073 |
| Cotton T-Shirt |  799.00 |     719.10 | 143.82 |            943 |
+----------------+---------+------------+--------+----------------+
```

Expressions in `WHERE`: *products whose stock is worth more than ₹5 lakh*:

```sql
SELECT name, price * stock AS stock_value
FROM products
WHERE price * stock > 500000
ORDER BY stock_value DESC;
```

```{ .text .output }
+--------------------+-------------+
| name               | stock_value |
+--------------------+-------------+
| Galaxy S24         |  2249970.00 |
| iPhone 15          |  1999975.00 |
| Inspiron 15 Laptop |   707988.00 |
+--------------------+-------------+
```

## Numeric Functions

| Function | Result | Example → result |
|----------|--------|------------------|
| `ROUND(x, d)` | Round to `d` decimals | `ROUND(4.567, 1)` → `4.6` |
| `CEIL(x)` / `FLOOR(x)` | Round up / down to a whole number | `CEIL(4.1)` → `5`, `FLOOR(4.9)` → `4` |
| `TRUNCATE(x, d)` | Cut off decimals (no rounding) | `TRUNCATE(4.567, 1)` → `4.5` |
| `ABS(x)` | Absolute value | `ABS(-7)` → `7` |
| `MOD(a, b)` | Remainder | `MOD(10, 3)` → `1` |
| `POWER(x, y)` / `SQRT(x)` | Power / square root | `POWER(2, 10)` → `1024` |

```sql
SELECT
    ROUND(4.567, 1)    AS rounded,
    CEIL(4.1)          AS ceiling,
    FLOOR(4.9)         AS floored,
    TRUNCATE(4.567, 1) AS truncated,
    17 DIV 5           AS whole_part,
    17 % 5             AS remainder;
```

```{ .text .output }
+---------+---------+---------+-----------+------------+-----------+
| rounded | ceiling | floored | truncated | whole_part | remainder |
+---------+---------+---------+-----------+------------+-----------+
|     4.6 |       5 |       4 |       4.5 |          3 |         2 |
+---------+---------+---------+-----------+------------+-----------+
```

*How many pages of 4 products do we need?* `CEIL` is perfect for pagination maths:

```sql
SELECT COUNT(*) AS products, CEIL(COUNT(*) / 4) AS pages
FROM products;
```

```{ .text .output }
+----------+-------+
| products | pages |
+----------+-------+
|       15 |     4 |
+----------+-------+
```

## String Functions

| Function | What it does | Example → result |
|----------|--------------|------------------|
| `CONCAT(a, b, ...)` | Join strings | `CONCAT('Asha', ' ', 'Reddy')` → `Asha Reddy` |
| `CONCAT_WS(sep, a, b)` | Join with a separator (skips NULLs) | `CONCAT_WS(', ', 'Pune', 'MH')` → `Pune, MH` |
| `UPPER(s)` / `LOWER(s)` | Change case | `UPPER('pune')` → `PUNE` |
| `CHAR_LENGTH(s)` | Number of characters | `CHAR_LENGTH('Asha')` → `4` |
| `LENGTH(s)` | Number of **bytes** | `LENGTH('₹')` → `3` |
| `SUBSTRING(s, start, len)` | Part of a string (1-based) | `SUBSTRING('Python', 1, 3)` → `Pyt` |
| `LEFT(s, n)` / `RIGHT(s, n)` | First / last `n` characters | `RIGHT('9876500001', 4)` → `0001` |
| `TRIM(s)` | Remove spaces at both ends | `TRIM('  hi  ')` → `hi` |
| `REPLACE(s, from, to)` | Replace text | `REPLACE('a-b-c', '-', '/')` → `a/b/c` |
| `LOCATE(sub, s)` | Position of a substring (0 if absent) | `LOCATE('@', 'a@b.com')` → `2` |

Build display values from several columns:

```sql
SELECT
    CONCAT(name, ' (', city, ')')                        AS customer,
    UPPER(LEFT(city, 3))                                 AS city_code,
    SUBSTRING(email, 1, LOCATE('@', email) - 1)          AS username,
    CHAR_LENGTH(name)                                    AS name_length
FROM customers
LIMIT 5;
```

```{ .text .output }
+------------------------+-----------+----------+-------------+
| customer               | city_code | username | name_length |
+------------------------+-----------+----------+-------------+
| Asha Reddy (Hyderabad) | HYD       | asha     |          10 |
| Ravi Kumar (Bangalore) | BAN       | ravi     |          10 |
| Kiran Rao (Hyderabad)  | HYD       | kiran    |           9 |
| Meena Iyer (Chennai)   | CHE       | meena    |          10 |
| Arjun Singh (Delhi)    | DEL       | arjun    |          11 |
+------------------------+-----------+----------+-------------+
```

Mask phone numbers for a support screen. Only the last 4 digits are shown:

```sql
SELECT name, CONCAT('XXXXXX', RIGHT(phone, 4)) AS masked_phone
FROM customers
WHERE phone IS NOT NULL
LIMIT 4;
```

```{ .text .output }
+-------------+--------------+
| name        | masked_phone |
+-------------+--------------+
| Asha Reddy  | XXXXXX0001   |
| Ravi Kumar  | XXXXXX0002   |
| Meena Iyer  | XXXXXX0004   |
| Arjun Singh | XXXXXX0005   |
+-------------+--------------+
```

!!! mistake "Common Mistake: CONCAT with a NULL returns NULL"
    ```sql
    SELECT name, CONCAT(name, ' - ', phone) AS contact
    FROM customers
    WHERE id IN (1, 3);
    ```

    ```{ .text .output }
    +------------+-------------------------+
    | name       | contact                 |
    +------------+-------------------------+
    | Asha Reddy | Asha Reddy - 9876500001 |
    | Kiran Rao  | NULL                    |
    +------------+-------------------------+
    ```

    Kiran's phone is `NULL`, so the whole result is `NULL`. Use `CONCAT_WS` (which skips NULLs) or wrap the column: `CONCAT(name, ' - ', IFNULL(phone, 'no phone'))`.

!!! realworld "In Real Projects"
    String functions are used to clean messy imported data: `UPDATE customers SET email = LOWER(TRIM(email));` fixes emails typed as `"  Ravi@Example.COM "`, so that duplicate checks and logins work. Run cleanups like this before adding a `UNIQUE` constraint.

## Date Functions

| Function | Result |
|----------|--------|
| `CURDATE()` / `NOW()` | Today's date / current date and time |
| `YEAR(d)`, `MONTH(d)`, `DAY(d)` | Parts of a date |
| `MONTHNAME(d)`, `DAYNAME(d)` | `'October'`, `'Friday'` |
| `DATE_FORMAT(d, format)` | Format a date as text |
| `DATEDIFF(d1, d2)` | Days between two dates (`d1 - d2`) |
| `TIMESTAMPDIFF(unit, d1, d2)` | Difference in a unit (`YEAR`, `MONTH`, `DAY`…) |
| `DATE_ADD(d, INTERVAL n unit)` / `DATE_SUB` | Add / subtract time |
| `LAST_DAY(d)` | Last day of that month |

`CURDATE()` changes every day, so these examples use a fixed date, `'2025-10-31'`, to give the same results every time. In real queries, use `CURDATE()`.

```sql
SELECT
    id,
    order_date,
    YEAR(order_date)                       AS yr,
    MONTHNAME(order_date)                  AS month_name,
    DAYNAME(order_date)                    AS weekday,
    DATE_FORMAT(order_date, '%d %b %Y')    AS pretty_date,
    DATEDIFF('2025-10-31', order_date)     AS days_ago
FROM orders
WHERE id <= 4;
```

```{ .text .output }
+----+------------+------+------------+-----------+-------------+----------+
| id | order_date | yr   | month_name | weekday   | pretty_date | days_ago |
+----+------------+------+------------+-----------+-------------+----------+
|  1 | 2025-06-05 | 2025 | June       | Thursday  | 05 Jun 2025 |      148 |
|  2 | 2025-06-18 | 2025 | June       | Wednesday | 18 Jun 2025 |      135 |
|  3 | 2025-07-02 | 2025 | July       | Wednesday | 02 Jul 2025 |      121 |
|  4 | 2025-07-20 | 2025 | July       | Sunday    | 20 Jul 2025 |      103 |
+----+------------+------+------------+-----------+-------------+----------+
```

| Format code | Meaning | Example |
|-------------|---------|---------|
| `%d` / `%m` / `%Y` | Day / month number / 4-digit year | `05` / `10` / `2025` |
| `%b` / `%M` | Short / full month name | `Oct` / `October` |
| `%a` / `%W` | Short / full weekday | `Fri` / `Friday` |
| `%H:%i:%s` | 24-hour time | `14:30:00` |

Delivery estimate and tenure:

```sql
SELECT
    id,
    order_date,
    DATE_ADD(order_date, INTERVAL 5 DAY) AS expected_delivery
FROM orders
WHERE status = 'shipped';
```

```{ .text .output }
+----+------------+-------------------+
| id | order_date | expected_delivery |
+----+------------+-------------------+
|  6 | 2025-08-15 | 2025-08-20        |
| 10 | 2025-10-01 | 2025-10-06        |
+----+------------+-------------------+
```

```sql
SELECT
    name,
    hire_date,
    TIMESTAMPDIFF(YEAR, hire_date, '2025-10-31') AS years_of_service
FROM employees
ORDER BY years_of_service DESC
LIMIT 4;
```

```{ .text .output }
+----------------+------------+------------------+
| name           | hire_date  | years_of_service |
+----------------+------------+------------------+
| Lakshmi Menon  | 2018-04-01 |                7 |
| Anita Desai    | 2019-09-01 |                6 |
| Suresh Babu    | 2019-06-15 |                6 |
| Swati Kulkarni | 2020-08-12 |                5 |
+----------------+------------+------------------+
```

Group by month: a very common report.

```sql
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, COUNT(*) AS orders
FROM orders
GROUP BY month
ORDER BY month;
```

```{ .text .output }
+---------+--------+
| month   | orders |
+---------+--------+
| 2025-06 |      2 |
| 2025-07 |      2 |
| 2025-08 |      3 |
| 2025-09 |      2 |
| 2025-10 |      3 |
+---------+--------+
```

## Type Conversion with CAST

```sql
SELECT
    CAST('2025-10-31' AS DATE)     AS as_date,
    CAST(79999.99 AS SIGNED)       AS as_integer,
    CAST(42 AS CHAR)               AS as_text,
    CAST('12.5' AS DECIMAL(5, 2))  AS as_decimal;
```

```{ .text .output }
+------------+------------+---------+------------+
| as_date    | as_integer | as_text | as_decimal |
+------------+------------+---------+------------+
| 2025-10-31 |      80000 | 42      |      12.50 |
+------------+------------+---------+------------+
```

Integer division can surprise you in reports. `CAST` or multiplying by `1.0` makes the intent explicit:

```sql
SELECT
    COUNT(*)                                           AS orders,
    SUM(status = 'delivered')                          AS delivered,
    ROUND(SUM(status = 'delivered') * 100.0 / COUNT(*), 1) AS delivered_pct
FROM orders;
```

```{ .text .output }
+--------+-----------+---------------+
| orders | delivered | delivered_pct |
+--------+-----------+---------------+
|     12 |         7 |          58.3 |
+--------+-----------+---------------+
```

(In MySQL a comparison like `status = 'delivered'` is `1` or `0`, so `SUM` of it counts the matching rows.)

## Handling NULL: IFNULL and COALESCE

| Function | Returns |
|----------|---------|
| `IFNULL(x, fallback)` | `x`, or `fallback` if `x` is NULL |
| `COALESCE(a, b, c, ...)` | The first non-NULL value (standard SQL) |
| `NULLIF(a, b)` | NULL if `a = b`, otherwise `a` (handy to avoid division by zero) |

```sql
SELECT name, IFNULL(phone, 'Not provided') AS phone
FROM customers
WHERE id IN (2, 3, 6);
```

```{ .text .output }
+------------+--------------+
| name       | phone        |
+------------+--------------+
| Ravi Kumar | 9876500002   |
| Kiran Rao  | Not provided |
| Divya Nair | Not provided |
+------------+--------------+
```

```sql
SELECT name, COALESCE(brand, 'Unbranded') AS brand_label
FROM products
WHERE category_id = 1;
```

```{ .text .output }
+--------------------+-------------+
| name               | brand_label |
+--------------------+-------------+
| iPhone 15          | Apple       |
| Galaxy S24         | Samsung     |
| Airdopes 141       | boAt        |
| Inspiron 15 Laptop | Dell        |
| USB-C Cable        | Unbranded   |
+--------------------+-------------+
```

`COALESCE` can take several fallbacks and returns the first one that isn't NULL: `COALESCE(mobile, office_phone, home_phone, 'No contact')`.

`NULLIF` prevents division-by-zero surprises:

```sql
SELECT name, stock, ROUND(price / NULLIF(stock, 0), 2) AS price_per_unit_in_stock
FROM products
WHERE category_id = 5;
```

```{ .text .output }
+-------------+-------+-------------------------+
| name        | stock | price_per_unit_in_stock |
+-------------+-------+-------------------------+
| Yoga Mat    |     0 |                    NULL |
| Cricket Bat |    22 |                  113.59 |
+-------------+-------+-------------------------+
```

## Conditional Logic: CASE and IF

`CASE` is SQL's `if / elif / else`. It returns a value per row.

```{ .sql .no-run }
CASE
    WHEN condition1 THEN value1
    WHEN condition2 THEN value2
    ELSE default_value
END
```

Label products by price band:

```sql
SELECT
    name,
    price,
    CASE
        WHEN price >= 50000 THEN 'Premium'
        WHEN price >= 2000  THEN 'Mid-range'
        ELSE 'Budget'
    END AS price_band
FROM products
ORDER BY price DESC;
```

```{ .text .output }
+---------------------+----------+------------+
| name                | price    | price_band |
+---------------------+----------+------------+
| iPhone 15           | 79999.00 | Premium    |
| Galaxy S24          | 74999.00 | Premium    |
| Inspiron 15 Laptop  | 58999.00 | Premium    |
| Running Shoes       |  4299.00 | Mid-range  |
| Mixer Grinder       |  3899.00 | Mid-range  |
| Denim Jacket        |  3499.00 | Mid-range  |
| Cricket Bat         |  2499.00 | Mid-range  |
| Python Crash Course |  2199.00 | Mid-range  |
| Non-stick Pan       |  1599.00 | Budget     |
| Airdopes 141        |  1299.00 | Budget     |
| Yoga Mat            |   999.00 | Budget     |
| Cotton T-Shirt      |   799.00 | Budget     |
| Atomic Habits       |   499.00 | Budget     |
| Wings of Fire       |   350.00 | Budget     |
| USB-C Cable         |   299.00 | Budget     |
+---------------------+----------+------------+
```

Stock status for the inventory screen, with the short `IF(condition, then, else)` form:

```sql
SELECT
    name,
    stock,
    IF(stock = 0, 'Out of stock', 'Available') AS availability,
    CASE
        WHEN stock = 0   THEN 'Reorder now'
        WHEN stock < 20  THEN 'Low'
        ELSE 'OK'
    END AS stock_level
FROM products
WHERE stock < 30
ORDER BY stock;
```

```{ .text .output }
+---------------------+-------+--------------+-------------+
| name                | stock | availability | stock_level |
+---------------------+-------+--------------+-------------+
| Wings of Fire       |     0 | Out of stock | Reorder now |
| Yoga Mat            |     0 | Out of stock | Reorder now |
| Inspiron 15 Laptop  |    12 | Available    | Low         |
| Python Crash Course |    15 | Available    | Low         |
| Mixer Grinder       |    18 | Available    | Low         |
| Cricket Bat         |    22 | Available    | OK          |
| iPhone 15           |    25 | Available    | OK          |
+---------------------+-------+--------------+-------------+
```

### CASE inside aggregates: pivot-style reports

Count orders by status **in one row**, a classic dashboard query:

```sql
SELECT
    COUNT(*)                                             AS total,
    SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS delivered,
    SUM(CASE WHEN status = 'shipped'   THEN 1 ELSE 0 END) AS shipped,
    SUM(CASE WHEN status = 'pending'   THEN 1 ELSE 0 END) AS pending,
    SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled
FROM orders;
```

```{ .text .output }
+-------+-----------+---------+---------+-----------+
| total | delivered | shipped | pending | cancelled |
+-------+-----------+---------+---------+-----------+
|    12 |         7 |       2 |       2 |         1 |
+-------+-----------+---------+---------+-----------+
```

`CASE` also works in `UPDATE`. Here's a price change with a different increase per category:

```sql
UPDATE products
SET price = CASE
    WHEN category_id = 3 THEN price * 1.05   -- books +5%
    WHEN category_id = 5 THEN price * 1.10   -- sports +10%
    ELSE price
END;

SELECT name, category_id, price FROM products WHERE category_id IN (3, 5);
```

```{ .text .output }
+---------------------+-------------+---------+
| name                | category_id | price   |
+---------------------+-------------+---------+
| Atomic Habits       |           3 |  523.95 |
| Wings of Fire       |           3 |  367.50 |
| Python Crash Course |           3 | 2308.95 |
| Yoga Mat            |           5 | 1098.90 |
| Cricket Bat         |           5 | 2748.90 |
+---------------------+-------------+---------+
```

## Combining Results with UNION

`UNION` stacks the results of two `SELECT`s vertically. Both must have the **same number of columns** with compatible types.

*One contact list containing both customers and employees*:

```sql
SELECT name, 'Customer' AS type FROM customers WHERE city = 'Pune'
UNION
SELECT name, 'Employee' FROM employees WHERE department = 'Support'
ORDER BY type, name;
```

```{ .text .output }
+----------------+----------+
| name           | type     |
+----------------+----------+
| Rahul Verma    | Customer |
| Sneha Patil    | Customer |
| Imran Shaikh   | Employee |
| Swati Kulkarni | Employee |
+----------------+----------+
```

| | `UNION` | `UNION ALL` |
|---|---|---|
| Duplicates | Removed | Kept |
| Speed | Slower (must de-duplicate) | Faster |
| Use when | You want unique rows | Rows can't overlap, or duplicates matter |

```sql
SELECT city FROM customers WHERE city LIKE 'B%'
UNION ALL
SELECT city FROM customers WHERE city = 'Pune';
```

```{ .text .output }
+-----------+
| city      |
+-----------+
| Bangalore |
| Bangalore |
| Pune      |
| Pune      |
+-----------+
```

`UNION ALL` kept every row: two customers live in Bangalore and two in Pune. With `UNION`, the result would be just `Bangalore` and `Pune`.

!!! tip "ORDER BY and LIMIT apply to the whole UNION"
    Write `ORDER BY` once, at the very end. Column names come from the **first** `SELECT`.

## Common Mistakes

| Mistake | Result | Fix |
|---------|--------|-----|
| `CONCAT` with a NULL column | Whole result is NULL | `CONCAT_WS` or `IFNULL(col, '')` |
| `LENGTH` for character count | Wrong for `₹`, Hindi and Telugu text (counts bytes) | `CHAR_LENGTH` |
| `SUBSTRING(s, 0, 3)` | Empty string (MySQL positions start at 1) | `SUBSTRING(s, 1, 3)` |
| `DATEDIFF` argument order | Negative numbers | `DATEDIFF(later, earlier)` |
| Using `CURDATE()` in saved reports | Results change daily | Pass the date as a parameter |
| Division by zero | NULL (with a warning) | `NULLIF(divisor, 0)` |
| Forgetting `END` in `CASE` | `ERROR 1064` | Every `CASE` needs `END` |
| UNION with different column counts | `ERROR 1222 (21000): The used SELECT statements have a different number of columns` | Match the columns |

## Practice Exercises

Use a fresh `ksr_shop`.

**Easy**

1. Show each customer's name in upper case and the domain of their email (the part after `@`).
2. Show each order's id and its order date formatted like `05-Jun-2025`.
3. Show every product's name and price rounded to the nearest hundred (`ROUND(price, -2)`).

**Medium**

4. Show each employee's name and a `level` column: `'Leadership'` for salaries ≥ 1,50,000, `'Senior'` for ≥ 80,000, otherwise `'Junior'`.
5. Show how many days old each order was on `'2025-10-31'`, and label orders older than 90 days as `'Archive'`, otherwise `'Recent'`.
6. In one row, show the number of customers from each of Hyderabad, Pune and Bangalore (pivot with `SUM(CASE ...)`).

**Challenge**

7. Write a query that produces a **customer contact card** for every customer: `Asha Reddy · Hyderabad · ******0001 · member for 1 year(s)`, using the fixed date `'2025-10-31'`. Customers without a phone should show `no phone` instead of the masked number.

??? success "Solutions (click to expand)"

    ```{ .sql .no-run }
    -- 1
    SELECT UPPER(name) AS name,
           SUBSTRING(email, LOCATE('@', email) + 1) AS domain
    FROM customers;

    -- 2
    SELECT id, DATE_FORMAT(order_date, '%d-%b-%Y') AS ordered_on FROM orders;

    -- 3
    SELECT name, ROUND(price, -2) AS approx_price FROM products;

    -- 4
    SELECT name, salary,
           CASE
               WHEN salary >= 150000 THEN 'Leadership'
               WHEN salary >= 80000  THEN 'Senior'
               ELSE 'Junior'
           END AS level
    FROM employees;

    -- 5
    SELECT id, order_date,
           DATEDIFF('2025-10-31', order_date) AS age_days,
           IF(DATEDIFF('2025-10-31', order_date) > 90, 'Archive', 'Recent') AS bucket
    FROM orders;

    -- 6
    SELECT
        SUM(city = 'Hyderabad') AS hyderabad,
        SUM(city = 'Pune')      AS pune,
        SUM(city = 'Bangalore') AS bangalore
    FROM customers;

    -- 7
    SELECT CONCAT_WS(' · ',
               name,
               city,
               IFNULL(CONCAT('******', RIGHT(phone, 4)), 'no phone'),
               CONCAT('member for ', TIMESTAMPDIFF(YEAR, joined_on, '2025-10-31'), ' year(s)')
           ) AS contact_card
    FROM customers;
    ```

!!! note "Mini Assignment"
    Write a single **product catalogue query** for the website that returns, for every product: a display name like `"iPhone 15 by Apple"` (or `"USB-C Cable"` when there's no brand), the price formatted with GST included and rounded, a price band (`Budget` / `Mid-range` / `Premium`), an availability label, how many days ago it was added (as of `'2025-10-31'`), and a `"NEW"` badge for products added in the last 60 days. Sort newest first.

## Interview Questions

!!! interview "1. What is the difference between `IFNULL` and `COALESCE`?"
    `IFNULL(a, b)` takes exactly two arguments and is MySQL-specific. `COALESCE(a, b, c, ...)` takes any number of arguments, returns the first non-NULL one, and is standard SQL (it works in every database).

!!! interview "2. What is the difference between `UNION` and `UNION ALL`?"
    `UNION` combines results and removes duplicate rows (extra work); `UNION ALL` keeps all rows, including duplicates, and is faster. Both require the same number of columns with compatible types.

!!! interview "3. How do you write if-else logic in SQL?"
    With `CASE WHEN condition THEN value ... ELSE value END`, which works in SELECT, WHERE, ORDER BY, GROUP BY and UPDATE. MySQL also has `IF(condition, then, else)` for two-way choices.

!!! interview "4. What's the difference between `LENGTH` and `CHAR_LENGTH`?"
    `LENGTH` returns the number of bytes; `CHAR_LENGTH` returns the number of characters. They differ for multi-byte UTF-8 characters such as `₹` or Indian-language text.

!!! interview "5. How do you count rows matching different conditions in a single query?"
    Conditional aggregation: `SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END)` (or `COUNT(CASE WHEN ... THEN 1 END)`) per condition, all in one `SELECT`.

!!! interview "Scenario: a report divides revenue by number of orders, and some rows show NULL. Why?"
    Some groups have zero orders, so the division is by zero, which MySQL returns as NULL. Decide what the business wants: show 0 with `COALESCE(revenue / NULLIF(orders, 0), 0)`, or filter those groups out.

## Summary

| Area | Key functions |
|------|---------------|
| Numbers | `ROUND`, `CEIL`, `FLOOR`, `TRUNCATE`, `ABS`, `MOD`, `DIV` |
| Strings | `CONCAT`, `CONCAT_WS`, `UPPER`, `LOWER`, `CHAR_LENGTH`, `SUBSTRING`, `LEFT`, `RIGHT`, `TRIM`, `REPLACE`, `LOCATE` |
| Dates | `CURDATE`, `NOW`, `YEAR`, `MONTHNAME`, `DAYNAME`, `DATE_FORMAT`, `DATEDIFF`, `TIMESTAMPDIFF`, `DATE_ADD` |
| Conversion | `CAST(x AS DATE / SIGNED / CHAR / DECIMAL)` |
| NULL | `IFNULL`, `COALESCE`, `NULLIF` |
| Logic | `CASE WHEN ... THEN ... ELSE ... END`, `IF(cond, a, b)`, `SUM(CASE ...)` pivots |
| Combine | `UNION` (unique rows), `UNION ALL` (all rows) |

**Next lesson:** [Database Design](08-database-design.md), with keys, relationships and normalisation.
