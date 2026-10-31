---
lesson: true
category: MySQL
short: Tables
sql_db: ksr_practice
description: SQL command categories, CREATE TABLE, MySQL data types, constraints (PRIMARY KEY, NOT NULL, UNIQUE, DEFAULT, CHECK), ALTER TABLE, and DROP vs TRUNCATE.
---

# Creating Tables & Data Types

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Place any SQL command in its category: DDL, DML, DQL, TCL or DCL
    - Create tables with `CREATE TABLE` and inspect them with `DESCRIBE`
    - Choose the right data type for each column (especially money and dates)
    - Protect data with constraints: `PRIMARY KEY`, `AUTO_INCREMENT`, `NOT NULL`, `UNIQUE`, `DEFAULT`, `CHECK`
    - Change tables with `ALTER TABLE` and remove them with `TRUNCATE` and `DROP`

**Prerequisites:** [MySQL Setup & First Database](02-mysql-setup.md)

!!! info "Practice database for this lesson"
    In this lesson you create tables **from scratch**, so work in a separate empty database:

    ```{ .sql .no-run }
    CREATE DATABASE ksr_practice;
    USE ksr_practice;
    ```

## SQL Command Categories

**SQL** (Structured Query Language) is the language for talking to relational databases. It's **declarative**: you describe **what** you want (*"customers from Pune"*), and the database figures out **how** to get it. There are no loops like in Python.

SQL commands fall into five groups:

| Category | Full form | Purpose | Commands |
|----------|-----------|---------|----------|
| **DDL** | Data Definition Language | Define structure | `CREATE`, `ALTER`, `DROP`, `TRUNCATE`, `RENAME` |
| **DML** | Data Manipulation Language | Change data | `INSERT`, `UPDATE`, `DELETE` |
| **DQL** | Data Query Language | Read data | `SELECT` |
| **TCL** | Transaction Control Language | Group changes safely | `START TRANSACTION`, `COMMIT`, `ROLLBACK`, `SAVEPOINT` |
| **DCL** | Data Control Language | Permissions | `GRANT`, `REVOKE` |

!!! example "Real-life analogy: building a library"
    **DDL** builds the shelves (structure). **DML** puts books on, swaps or removes them (data). **DQL** finds books. **TCL** makes sure a batch of changes happens completely or not at all. **DCL** decides who has a library card.

!!! warning "DDL commits automatically"
    In MySQL, DDL statements (`CREATE`, `ALTER`, `DROP`, `TRUNCATE`) are saved **immediately and permanently**; they can't be undone with `ROLLBACK`. DML changes inside a transaction can be rolled back. You'll see this in the [Transactions](12-transactions-indexes-users.md) lesson.

## Creating a Table

```{ .sql .no-run }
CREATE TABLE table_name (
    column1 datatype constraints,
    column2 datatype constraints,
    ...
);
```

Let's create a `students` table for an academy:

```sql
CREATE TABLE students (
    id        INT PRIMARY KEY AUTO_INCREMENT,
    name      VARCHAR(100) NOT NULL,
    email     VARCHAR(100) NOT NULL UNIQUE,
    phone     VARCHAR(15),
    course    VARCHAR(50)  NOT NULL DEFAULT 'Full Stack Python',
    fee_paid  DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (fee_paid >= 0),
    joined_on DATE NOT NULL
);

DESCRIBE students;
```

```{ .text .output }
+-----------+---------------+------+-----+-------------------+----------------+
| Field     | Type          | Null | Key | Default           | Extra          |
+-----------+---------------+------+-----+-------------------+----------------+
| id        | int           | NO   | PRI | NULL              | auto_increment |
| name      | varchar(100)  | NO   |     | NULL              |                |
| email     | varchar(100)  | NO   | UNI | NULL              |                |
| phone     | varchar(15)   | YES  |     | NULL              |                |
| course    | varchar(50)   | NO   |     | Full Stack Python |                |
| fee_paid  | decimal(10,2) | NO   |     | 0.00              |                |
| joined_on | date          | NO   |     | NULL              |                |
+-----------+---------------+------+-----+-------------------+----------------+
```

**Naming conventions** used by most teams:

- `snake_case` for table and column names: `order_items`, `joined_on`
- Plural table names (`students`, `orders`); singular is also common, so pick one and be consistent
- `id` for the primary key; `<table>_id` for foreign keys (`student_id`)
- Avoid spaces, hyphens and reserved words (`order`, `group`, `select`)

!!! mistake "Common Mistake: creating a table that already exists"
    ```sql
    CREATE TABLE students (id INT);
    ```

    ```{ .text .output }
    ERROR 1050 (42S01): Table 'students' already exists
    ```

    Use `CREATE TABLE IF NOT EXISTS students (...)` in scripts that may run more than once.

## Choosing Data Types

Every column has a **data type** that decides what values it can store and how much space they take. Choosing well prevents bugs and saves storage.

### Numbers

| Type | Range / precision | Use for |
|------|-------------------|---------|
| `TINYINT` | −128 to 127 | Small codes, age |
| `SMALLINT` | −32,768 to 32,767 | Small counts |
| `INT` | about ±2.1 billion | IDs, quantities, stock |
| `BIGINT` | about ±9.2 × 10¹⁸ | Very large IDs (social media posts, analytics events) |
| `DECIMAL(p, s)` | Exact: `p` digits total, `s` after the point | **Money**, prices, percentages |
| `FLOAT` / `DOUBLE` | Approximate | Scientific measurements, coordinates |

!!! mistake "Never store money in FLOAT"
    `FLOAT` and `DOUBLE` are approximate, just like Python floats (`0.1 + 0.2 = 0.30000000000000004`). Over thousands of transactions the rounding errors add up. Use `DECIMAL(10, 2)` for prices and balances: up to 99,999,999.99, stored exactly.

### Text

| Type | Max length | Use for |
|------|------------|---------|
| `CHAR(n)` | Exactly `n` characters (padded) | Fixed-length codes: `CHAR(2)` state code, `CHAR(6)` PIN code |
| `VARCHAR(n)` | Up to `n` characters | Names, emails, cities: most text |
| `TEXT` | About 65,000 characters | Descriptions, reviews, blog posts |
| `ENUM('a', 'b')` | One value from a fixed list | Status: `'pending'`, `'shipped'`, `'delivered'` |

!!! tip "Store phone numbers and PIN codes as text"
    They're identifiers, not quantities. You never add two phone numbers. `INT` would also drop leading zeros (`040…` becomes `40…`) and can't hold `+91`. Use `VARCHAR(15)`.

### Dates and times

| Type | Format | Use for |
|------|--------|---------|
| `DATE` | `YYYY-MM-DD` | Birthdays, joining dates, order dates |
| `TIME` | `HH:MM:SS` | Class timings |
| `DATETIME` | `YYYY-MM-DD HH:MM:SS` | Appointment slots, events |
| `TIMESTAMP` | Same format, stored in UTC | `created_at` / `updated_at` audit columns |
| `YEAR` | `YYYY` | Graduation year |

### Others

| Type | Use for |
|------|---------|
| `BOOLEAN` / `BOOL` | True/false (stored as `TINYINT(1)`: 1 or 0) |
| `JSON` | Flexible extra attributes (validated JSON) |
| `BLOB` | Binary data. For images, store files in cloud storage and save only the URL in a `VARCHAR` |

## Constraints

**Constraints** are rules the database enforces on every insert and update. They are your last line of defence against bad data, even if the application code has a bug.

| Constraint | Rule |
|------------|------|
| `PRIMARY KEY` | Unique and not NULL; identifies each row (one per table) |
| `AUTO_INCREMENT` | MySQL assigns the next number automatically |
| `NOT NULL` | A value is required |
| `UNIQUE` | No two rows may have the same value (NULLs allowed) |
| `DEFAULT value` | Used when no value is given |
| `CHECK (condition)` | The value must satisfy the condition |
| `FOREIGN KEY` | The value must exist in another table (covered in [Database Design](08-database-design.md)) |

Let's watch the constraints protect the `students` table. A valid row:

```sql
INSERT INTO students (name, email, phone, fee_paid, joined_on)
VALUES ('Asha Reddy', 'asha@example.com', '9876500001', 15000, '2026-01-10');

SELECT * FROM students;
```

```{ .text .output }
+----+------------+------------------+------------+-------------------+----------+------------+
| id | name       | email            | phone      | course            | fee_paid | joined_on  |
+----+------------+------------------+------------+-------------------+----------+------------+
|  1 | Asha Reddy | asha@example.com | 9876500001 | Full Stack Python | 15000.00 | 2026-01-10 |
+----+------------+------------------+------------+-------------------+----------+------------+
```

`id` was assigned by `AUTO_INCREMENT`, and `course` came from its `DEFAULT`. Now let's break each rule.

**`NOT NULL`**: a name is required.

```sql
INSERT INTO students (name, email, joined_on)
VALUES (NULL, 'ravi@example.com', '2026-01-12');
```

```{ .text .output }
ERROR 1048 (23000): Column 'name' cannot be null
```

**`UNIQUE`**: the email is already used.

```sql
INSERT INTO students (name, email, joined_on)
VALUES ('Another Asha', 'asha@example.com', '2026-01-12');
```

```{ .text .output }
ERROR 1062 (23000): Duplicate entry 'asha@example.com' for key 'students.email'
```

**`CHECK`**: the fee can't be negative.

```sql
INSERT INTO students (name, email, fee_paid, joined_on)
VALUES ('Ravi Kumar', 'ravi@example.com', -500, '2026-01-12');
```

```{ .text .output }
ERROR 3819 (HY000): Check constraint 'students_chk_1' is violated.
```

**Data type**: not a valid date.

```sql
INSERT INTO students (name, email, joined_on)
VALUES ('Ravi Kumar', 'ravi@example.com', '12-01-2026');
```

```{ .text .output }
ERROR 1292 (22007): Incorrect date value: '12-01-2026' for column 'joined_on' at row 1
```

MySQL dates are always written `'YYYY-MM-DD'`. Every rejected insert left the table unchanged. Only valid data gets in.

!!! realworld "In Real Projects"
    When a user signs up with an email that already exists, the backend's insert fails with **ERROR 1062 Duplicate entry**. FastAPI, Django and Spring Boot catch this error and return a friendly *"This email is already registered"* message. The database's `UNIQUE` constraint is what guarantees no duplicate accounts, even when two sign-up requests arrive at the same millisecond.

## Changing Tables with ALTER TABLE

Requirements change. `ALTER TABLE` modifies an existing table without losing its data.

```sql
-- add a new column (placed after email)
ALTER TABLE students ADD COLUMN city VARCHAR(50) AFTER email;

-- change a column's type or constraints
ALTER TABLE students MODIFY COLUMN phone VARCHAR(20);

-- rename a column
ALTER TABLE students RENAME COLUMN joined_on TO enrolled_on;

-- remove a column (its data is deleted!)
ALTER TABLE students DROP COLUMN city;

-- add a constraint later
ALTER TABLE students ADD CONSTRAINT chk_course CHECK (course <> '');

DESCRIBE students;
```

```{ .text .output }
+-------------+---------------+------+-----+-------------------+----------------+
| Field       | Type          | Null | Key | Default           | Extra          |
+-------------+---------------+------+-----+-------------------+----------------+
| id          | int           | NO   | PRI | NULL              | auto_increment |
| name        | varchar(100)  | NO   |     | NULL              |                |
| email       | varchar(100)  | NO   | UNI | NULL              |                |
| phone       | varchar(20)   | YES  |     | NULL              |                |
| course      | varchar(50)   | NO   |     | Full Stack Python |                |
| fee_paid    | decimal(10,2) | NO   |     | 0.00              |                |
| enrolled_on | date          | NO   |     | NULL              |                |
+-------------+---------------+------+-----+-------------------+----------------+
```

| Task | Syntax |
|------|--------|
| Add a column | `ALTER TABLE t ADD COLUMN col TYPE [AFTER other];` |
| Change type or constraints | `ALTER TABLE t MODIFY COLUMN col NEW_TYPE;` |
| Rename a column | `ALTER TABLE t RENAME COLUMN old TO new;` |
| Remove a column | `ALTER TABLE t DROP COLUMN col;` |
| Rename a table | `RENAME TABLE old TO new;` |
| Add a constraint | `ALTER TABLE t ADD CONSTRAINT name CHECK (...);` |

!!! warning "ALTER on big tables"
    On a table with millions of rows, some `ALTER` operations rebuild the whole table and can lock it for minutes. In production, schema changes are planned, tested on a copy, and released through **migration** tools (Django migrations, Alembic for FastAPI, Flyway or Liquibase for Spring Boot).

## DROP vs TRUNCATE vs DELETE

Three ways to remove things, with very different effects:

| Command | Type | Removes | Structure kept? | `WHERE` allowed? | Rollback? | AUTO_INCREMENT |
|---------|------|---------|-----------------|------------------|-----------|----------------|
| `DELETE FROM t WHERE ...` | DML | Matching rows | ✅ | ✅ | ✅ (in a transaction) | Continues |
| `TRUNCATE TABLE t` | DDL | **All** rows | ✅ | ❌ | ❌ | Resets to 1 |
| `DROP TABLE t` | DDL | The whole table | ❌ | ❌ | ❌ | Gone |

```sql
INSERT INTO students (name, email, enrolled_on)
VALUES ('Ravi Kumar', 'ravi@example.com', '2026-01-12');

TRUNCATE TABLE students;           -- all rows gone, table still exists

INSERT INTO students (name, email, enrolled_on)
VALUES ('Kiran Rao', 'kiran@example.com', '2026-02-01');

SELECT id, name FROM students;     -- id restarted at 1
```

```{ .text .output }
+----+-----------+
| id | name      |
+----+-----------+
|  1 | Kiran Rao |
+----+-----------+
```

```sql
DROP TABLE students;
SELECT * FROM students;
```

```{ .text .output }
ERROR 1146 (42S02): Table 'ksr_practice.students' doesn't exist
```

!!! danger "There is no undo"
    `DROP TABLE` and `TRUNCATE` are permanent. In production, databases are backed up regularly, and dangerous commands are run only after double-checking which server you're connected to. Many real outages started with `DROP TABLE` on the wrong database.

## Common Mistakes

| Mistake | Error | Fix |
|---------|-------|-----|
| Creating a table that exists | `ERROR 1050 (42S01): Table '...' already exists` | `CREATE TABLE IF NOT EXISTS` |
| Missing a required value | `ERROR 1048 (23000): Column '...' cannot be null` | Provide it, or add a `DEFAULT` |
| Duplicate value in a `UNIQUE` column | `ERROR 1062 (23000): Duplicate entry '...' for key ...` | Use a different value, or update the existing row |
| Breaking a `CHECK` | `ERROR 3819 (HY000): Check constraint '...' is violated.` | Send a valid value |
| Wrong date format | `ERROR 1292 (22007): Incorrect date value` | `'YYYY-MM-DD'` |
| Text longer than `VARCHAR(n)` | `ERROR 1406 (22001): Data too long for column` | Shorten the value or widen the column |
| Reserved word as a name (`order`, `desc`) | `ERROR 1064 (42000): You have an error in your SQL syntax` | Rename it (`orders`), or wrap it in backticks `` `order` `` |
| `FLOAT` for money | Rounding errors | `DECIMAL(10, 2)` |
| Missing comma between column definitions | `ERROR 1064` | Check every line except the last ends with `,` |

## Practice Exercises

Work in `ksr_practice`.

**Easy**

1. Create a table `courses` with `id` (auto-increment primary key), `title` (required, unique), `duration_weeks` (number) and `fee` (money).
2. Run `DESCRIBE courses;` and identify the primary key and the columns that allow NULL.
3. Insert two courses, then try inserting a third with the same title. What error do you get?

**Medium**

4. Add a `CHECK` so `duration_weeks` must be between 1 and 52, and a `DEFAULT` of `12` for it. (Hint: `ALTER TABLE ... MODIFY COLUMN`.)
5. Add a column `level` that can only be `'beginner'`, `'intermediate'` or `'advanced'`, with default `'beginner'`.
6. Choose data types (with reasons) for: Aadhaar number, product weight in kg, account balance, blog post body, order timestamp, PIN code, is_active flag.

**Challenge**

7. Design and create a `bank_accounts` table: account number (exactly 12 characters, primary key), holder name, account type (`savings` or `current`), balance (≥ 0, default 0), opened_on date, and a `created_at` timestamp that defaults to the current time. Insert one valid and three invalid rows, and note each error code.

??? success "Solutions (click to expand)"

    ```{ .sql .no-run }
    -- 1
    CREATE TABLE courses (
        id             INT PRIMARY KEY AUTO_INCREMENT,
        title          VARCHAR(100) NOT NULL UNIQUE,
        duration_weeks INT,
        fee            DECIMAL(10, 2)
    );

    -- 2
    DESCRIBE courses;   -- id is PRI; duration_weeks and fee allow NULL

    -- 3
    INSERT INTO courses (title, duration_weeks, fee) VALUES ('Full Stack Python', 24, 45000);
    INSERT INTO courses (title, duration_weeks, fee) VALUES ('Full Stack Java', 24, 45000);
    INSERT INTO courses (title, duration_weeks, fee) VALUES ('Full Stack Python', 20, 40000);
    -- ERROR 1062 (23000): Duplicate entry 'Full Stack Python' for key 'courses.title'

    -- 4
    ALTER TABLE courses
        MODIFY COLUMN duration_weeks INT NOT NULL DEFAULT 12 CHECK (duration_weeks BETWEEN 1 AND 52);

    -- 5
    ALTER TABLE courses
        ADD COLUMN level ENUM('beginner', 'intermediate', 'advanced') NOT NULL DEFAULT 'beginner';

    -- 6
    -- Aadhaar: CHAR(12) (identifier, fixed length; never maths)
    -- weight in kg: DECIMAL(6, 3) (exact, 3 decimals)
    -- balance: DECIMAL(12, 2) (money must be exact)
    -- blog body: TEXT (long text)
    -- order timestamp: DATETIME or TIMESTAMP
    -- PIN code: CHAR(6) (keeps leading zeros)
    -- is_active: BOOLEAN

    -- 7
    CREATE TABLE bank_accounts (
        account_no   CHAR(12) PRIMARY KEY,
        holder_name  VARCHAR(100) NOT NULL,
        account_type ENUM('savings', 'current') NOT NULL,
        balance      DECIMAL(12, 2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
        opened_on    DATE NOT NULL,
        created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    INSERT INTO bank_accounts (account_no, holder_name, account_type, opened_on)
    VALUES ('123456789012', 'Asha Reddy', 'savings', '2026-01-10');            -- OK
    INSERT INTO bank_accounts (account_no, holder_name, account_type, opened_on)
    VALUES ('123456789012', 'Ravi', 'savings', '2026-01-11');                  -- ERROR 1062
    INSERT INTO bank_accounts (account_no, holder_name, account_type, balance, opened_on)
    VALUES ('999999999999', 'Ravi', 'savings', -10, '2026-01-11');             -- ERROR 3819
    INSERT INTO bank_accounts (account_no, holder_name, account_type, opened_on)
    VALUES ('888888888888', 'Ravi', 'fixed', '2026-01-11');                    -- ERROR 1265 Data truncated
    ```

!!! note "Mini Assignment"
    Design the tables for a **training institute**: `trainers`, `courses`, `batches` and `students`. For every column, choose a data type and constraints and write one sentence explaining your choice. Create the tables in `ksr_practice`, insert two rows each, and deliberately trigger the `NOT NULL`, `UNIQUE` and `CHECK` errors. (You'll link these tables with foreign keys in the Database Design lesson.)

## Interview Questions

!!! interview "1. What are DDL, DML, DQL, TCL and DCL? Give examples."
    DDL defines structure (`CREATE`, `ALTER`, `DROP`, `TRUNCATE`); DML changes data (`INSERT`, `UPDATE`, `DELETE`); DQL reads data (`SELECT`); TCL manages transactions (`COMMIT`, `ROLLBACK`, `SAVEPOINT`); DCL manages permissions (`GRANT`, `REVOKE`).

!!! interview "2. What is the difference between CHAR and VARCHAR?"
    `CHAR(n)` is fixed-length: values are padded to exactly n characters, which suits fixed-size codes. `VARCHAR(n)` is variable-length and stores only the characters used plus a length byte, which suits most text such as names and emails.

!!! interview "3. Why use DECIMAL instead of FLOAT for money?"
    `DECIMAL` stores exact values, while `FLOAT`/`DOUBLE` store binary approximations that cause rounding errors (0.1 + 0.2 ≠ 0.3). For financial data, exactness is mandatory.

!!! interview "4. What is the difference between DELETE, TRUNCATE and DROP?"
    `DELETE` (DML) removes selected rows with `WHERE`, can be rolled back inside a transaction, and doesn't reset AUTO_INCREMENT. `TRUNCATE` (DDL) removes all rows quickly, can't be rolled back, and resets AUTO_INCREMENT. `DROP` (DDL) removes the entire table, structure and data.

!!! interview "5. What is the difference between PRIMARY KEY and UNIQUE?"
    Both enforce uniqueness. A table has only **one** primary key and it can't be NULL; it identifies the row. A table can have **many** UNIQUE constraints, and UNIQUE columns can contain NULLs (in MySQL, multiple NULLs are allowed).

!!! interview "Scenario: an app stores phone numbers as INT and some customers' numbers show wrong values. What happened and how do you fix it?"
    INT drops leading zeros and can't store `+` or numbers above its range (~2.1 billion), so 10-digit mobile numbers overflow or are mangled. Phone numbers are identifiers, not quantities: change the column to `VARCHAR(15)` with `ALTER TABLE ... MODIFY COLUMN`, then repair the affected data from a reliable source.

## Summary

| Concept | Remember |
|---------|----------|
| Categories | DDL structure · DML data · DQL read · TCL transactions · DCL permissions |
| Create | `CREATE TABLE [IF NOT EXISTS] t (col TYPE constraints, ...)` |
| Inspect | `DESCRIBE t;`, `SHOW CREATE TABLE t;` |
| Numbers | `INT` for counts and IDs, `DECIMAL(p, s)` for money, never `FLOAT` for money |
| Text | `VARCHAR(n)` most text, `CHAR(n)` fixed codes, `TEXT` long text, `ENUM` fixed choices |
| Dates | `DATE`, `DATETIME`, `TIMESTAMP`; always `'YYYY-MM-DD'` |
| Constraints | `PRIMARY KEY`, `AUTO_INCREMENT`, `NOT NULL`, `UNIQUE`, `DEFAULT`, `CHECK` |
| Alter | `ADD`, `MODIFY`, `RENAME COLUMN`, `DROP COLUMN` |
| Remove | `DELETE` rows · `TRUNCATE` all rows · `DROP` the table |

**Next lesson:** [CRUD: Insert, Select, Update, Delete](04-crud-operations.md), working with the data inside tables.
