---
lesson: true
category: MySQL
short: Setup
description: Install MySQL 8 and MySQL Workbench on Windows or macOS, connect from the terminal and Workbench, load the ksr_shop practice database and learn the essential commands.
---

# MySQL Setup & First Database

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Install MySQL Server 8 and MySQL Workbench on Windows or macOS
    - Connect to MySQL from the terminal and from Workbench
    - Load the `ksr_shop` practice database used in every lesson
    - Use essential commands: `SHOW DATABASES`, `USE`, `SHOW TABLES`, `DESCRIBE`
    - Fix the most common installation and connection problems

**Prerequisites:** [Introduction to Databases](01-introduction-to-databases.md)

## What You Will Install

| Tool | What it is | Why you need it |
|------|-----------|-----------------|
| **MySQL Server** | The database itself; runs in the background | Stores data and runs your SQL |
| **MySQL Workbench** | A free graphical tool from Oracle | Write queries, see results as tables, design diagrams |
| **mysql CLI** | Command-line client (installed with the server) | Quick access from any terminal; used on servers |

!!! example "Real-life analogy: a bank and its counters"
    The **MySQL Server** is the bank vault where everything is stored. **Workbench** and the **CLI** are two different counters where you can go and make requests. Both talk to the same vault.

## Installing MySQL

=== "Windows"

    1. Go to **dev.mysql.com/downloads/installer** and download **MySQL Installer for Windows** (the larger "full" file is easiest).
    2. Run it and choose **Custom** (or **Developer Default**). Select:
        - **MySQL Server 8.x**
        - **MySQL Workbench**
    3. Keep the defaults: **Standalone server**, port **3306**, *Use Strong Password Encryption*.
    4. Set a **root password** and write it down. You'll need it every time.
    5. Keep **Start the MySQL Server at System Startup** ticked, then finish the installer.
    6. Add MySQL to your PATH so `mysql` works in Command Prompt: add `C:\Program Files\MySQL\MySQL Server 8.4\bin` to the **Path** environment variable (adjust the version number to yours).

=== "macOS (installer)"

    1. Go to **dev.mysql.com/downloads/mysql** and download the **DMG** for your Mac (ARM for Apple Silicon M1/M2/M3/M4, x86 for Intel).
    2. Open it and follow the steps. Choose **Use Strong Password Encryption** and set a **root password**.
    3. MySQL appears in **System Settings → MySQL**, where you can start and stop it.
    4. Add the CLI to your PATH by running this once in Terminal:

    ```bash
    echo 'export PATH="/usr/local/mysql/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
    ```

    5. Download **MySQL Workbench** separately from **dev.mysql.com/downloads/workbench**.

=== "macOS (Homebrew)"

    ```bash
    brew install mysql
    brew services start mysql
    mysql_secure_installation
    ```

    `mysql_secure_installation` lets you set the root password. Install Workbench with `brew install --cask mysqlworkbench`.

=== "Docker (any OS)"

    If you already use Docker, this runs MySQL without installing it:

    ```bash
    docker run -d --name ksr-mysql -e MYSQL_ROOT_PASSWORD=yourpassword -p 3306:3306 mysql:8.4
    ```

    Connect with `docker exec -it ksr-mysql mysql -uroot -p`, or point Workbench at `127.0.0.1:3306`.

!!! warning "Remember your root password"
    The `root` user is the all-powerful admin account. If you forget its password, resetting it is painful. Store it in a password manager. In real projects your application never connects as `root`; you create a separate user with limited permissions (covered later in this lesson).

## Connecting to MySQL

### From the terminal (CLI)

=== "Windows"

    ```bash
    mysql -u root -p
    ```

=== "macOS / Linux"

    ```bash
    mysql -u root -p
    ```

`-u root` means "log in as root" and `-p` means "ask for my password". You'll see the MySQL prompt:

```{ .text .output }
Welcome to the MySQL monitor.  Commands end with ; or \g.
Server version: 8.4.13 MySQL Community Server - GPL

mysql>
```

Type `exit` (or `\q`) to leave.

!!! tip "Every SQL statement ends with a semicolon"
    In the CLI, pressing ++enter++ without a `;` just starts a new line (`->`) and waits. Type `;` and press ++enter++ to run the statement.

### From MySQL Workbench

1. Open Workbench. Under **MySQL Connections**, click the **Local instance** tile (or **+** to create one: host `127.0.0.1`, port `3306`, user `root`).
2. Enter your root password (tick *Save password in keychain* if you like).
3. A **query tab** opens. Type SQL in the editor and run it:
    - ++ctrl+enter++ (++cmd+enter++ on macOS) runs the statement under the cursor
    - ++ctrl+shift+enter++ (++cmd+shift+enter++) runs everything in the tab
4. Results appear in a grid below the editor; the **Schemas** panel on the left lists databases and tables.

## Loading the ksr_shop Database

Every lesson in this module uses the same practice database, **ksr_shop**: a small online store with categories, products, customers, orders, order items and employees.

[:material-download: Download ksr_shop.sql](../../assets/sql/ksr_shop.sql){ .md-button .md-button--primary download }

=== "Workbench"

    1. **File → Open SQL Script…** and choose `ksr_shop.sql`.
    2. Click the ⚡ (**Execute all**) button.
    3. Right-click the **Schemas** panel → **Refresh All**. `ksr_shop` appears.

=== "CLI"

    Run this from the folder where you saved the file (not inside the `mysql>` prompt):

    ```bash
    mysql -u root -p < ksr_shop.sql
    ```

The script is **safe to re-run**: it deletes and recreates `ksr_shop`, so if you mess up your data while practising, just run it again to reset everything.

```mermaid
erDiagram
  CATEGORIES ||--o{ PRODUCTS : groups
  CUSTOMERS ||--o{ ORDERS : places
  ORDERS ||--|{ ORDER_ITEMS : contains
  PRODUCTS ||--o{ ORDER_ITEMS : "ordered as"
  EMPLOYEES ||--o{ EMPLOYEES : manages
```

| Table | Rows | Holds |
|-------|------|-------|
| `categories` | 6 | Product categories (Toys has no products yet) |
| `products` | 15 | Name, brand, price, stock, rating |
| `customers` | 10 | Name, email, city, phone (some missing) |
| `orders` | 12 | Who ordered, when, and status |
| `order_items` | 17 | Which products are in each order, quantity and price |
| `employees` | 10 | Staff, departments, salaries and managers |

## Essential Commands

List all databases on the server:

```{ .sql .no-run }
SHOW DATABASES;
```

```{ .text .output }
+--------------------+
| Database           |
+--------------------+
| information_schema |
| ksr_shop           |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
```

`information_schema`, `mysql`, `performance_schema` and `sys` are MySQL's own system databases. **Never modify them.**

Choose the database to work in:

```{ .sql .no-run }
USE ksr_shop;
```

```{ .text .output }
Database changed
```

After `USE`, every query runs against `ksr_shop` until you switch again. Confirm which database is active:

```sql
SELECT DATABASE();
```

```{ .text .output }
+------------+
| DATABASE() |
+------------+
| ksr_shop   |
+------------+
```

List the tables:

```sql
SHOW TABLES;
```

```{ .text .output }
+--------------------+
| Tables_in_ksr_shop |
+--------------------+
| categories         |
| customers          |
| employees          |
| order_items        |
| orders             |
| products           |
+--------------------+
```

See a table's structure (its columns, types and keys):

```sql
DESCRIBE customers;
```

```{ .text .output }
+-----------+--------------+------+-----+---------+----------------+
| Field     | Type         | Null | Key | Default | Extra          |
+-----------+--------------+------+-----+---------+----------------+
| id        | int          | NO   | PRI | NULL    | auto_increment |
| name      | varchar(100) | NO   |     | NULL    |                |
| email     | varchar(100) | NO   | UNI | NULL    |                |
| city      | varchar(50)  | NO   |     | NULL    |                |
| phone     | varchar(15)  | YES  |     | NULL    |                |
| joined_on | date         | NO   |     | NULL    |                |
+-----------+--------------+------+-----+---------+----------------+
```

| Column in the output | Meaning |
|----------------------|---------|
| `Field` | Column name |
| `Type` | Data type (`int`, `varchar(100)`, `date`) |
| `Null` | `YES` if the column can be empty (NULL) |
| `Key` | `PRI` = primary key, `UNI` = unique, `MUL` = part of an index or foreign key |
| `Default` | Value used when you don't provide one |
| `Extra` | e.g. `auto_increment` |

And your first real query, the first five products:

```sql
SELECT * FROM products LIMIT 5;
```

```{ .text .output }
+----+--------------------+-------------+---------+----------+-------+--------+------------+
| id | name               | category_id | brand   | price    | stock | rating | added_on   |
+----+--------------------+-------------+---------+----------+-------+--------+------------+
|  1 | iPhone 15          |           1 | Apple   | 79999.00 |    25 |    4.7 | 2025-09-20 |
|  2 | Galaxy S24         |           1 | Samsung | 74999.00 |    30 |    4.5 | 2025-08-11 |
|  3 | Airdopes 141       |           1 | boAt    |  1299.00 |   200 |    4.1 | 2025-06-02 |
|  4 | Inspiron 15 Laptop |           1 | Dell    | 58999.00 |    12 |    4.3 | 2025-07-15 |
|  5 | USB-C Cable        |           1 | NULL    |   299.00 |   500 |    3.9 | 2025-05-01 |
+----+--------------------+-------------+---------+----------+-------+--------+------------+
```

**Quick reference**

| Command | What it does |
|---------|--------------|
| `SHOW DATABASES;` | List databases |
| `CREATE DATABASE name;` | Create a new database |
| `USE name;` | Switch to a database |
| `SELECT DATABASE();` | Show the current database |
| `SHOW TABLES;` | List tables in the current database |
| `DESCRIBE table;` | Show a table's columns |
| `SHOW CREATE TABLE table;` | Show the full `CREATE TABLE` statement |
| `DROP DATABASE name;` | Delete a database and **everything in it** |
| `SELECT VERSION();` | Show the MySQL version |

!!! mistake "Common Mistake: ERROR 1046 No database selected"
    ```{ .sql .no-run }
    SELECT * FROM products;
    ```

    ```{ .text .output }
    ERROR 1046 (3D000): No database selected
    ```

    Run `USE ksr_shop;` first, or write the database name before the table: `SELECT * FROM ksr_shop.products;`. In Workbench you can also double-click the schema name to make it the default (it turns bold).

## Creating an Application User

Applications should never log in as `root`. Create a separate user that can only work with `ksr_shop`:

```{ .sql .no-run }
CREATE USER 'ksr_app'@'localhost' IDENTIFIED BY 'Str0ng#Pass2026';
GRANT SELECT, INSERT, UPDATE, DELETE ON ksr_shop.* TO 'ksr_app'@'localhost';
```

Now `mysql -u ksr_app -p ksr_shop` logs in with only those permissions. This user can't drop tables, create databases or see other databases. You'll learn more about `GRANT` and `REVOKE` in [Transactions, Indexes & Users](12-transactions-indexes-users.md).

!!! realworld "In Real Projects"
    Backend apps read their database settings (host, port, user, password, database name) from **environment variables**, never from code committed to GitHub. A typical FastAPI or Spring Boot project has a connection string like `mysql://ksr_app:password@localhost:3306/ksr_shop` stored in a `.env` file or the server's configuration.

## Troubleshooting

| Problem | Likely cause | Fix |
|---------|--------------|-----|
| `'mysql' is not recognized` (Windows) / `command not found: mysql` (macOS) | MySQL's `bin` folder isn't on your PATH | Add it to PATH (see the install steps), then open a new terminal |
| `ERROR 1045 (28000): Access denied for user 'root'@'localhost'` | Wrong password | Retype carefully; check Caps Lock; reset the root password if needed |
| `ERROR 2002 (HY000): Can't connect to local MySQL server` | The server isn't running | Windows: Services → start **MySQL84**. macOS: System Settings → MySQL → Start, or `brew services start mysql` |
| `ERROR 2003 ... (10061)` / connection refused | Wrong port, or a firewall | Check the port (default 3306) |
| Port 3306 already in use | Another MySQL or MariaDB is running | Stop the other service, or install on port 3307 |
| `ERROR 1046 (3D000): No database selected` | No `USE` statement | `USE ksr_shop;` |
| Workbench can't find tables after loading the script | Schema list not refreshed | Right-click Schemas → **Refresh All** |

## Practice Exercises

1. Install MySQL Server and Workbench, and connect with both the CLI and Workbench.
2. Download and run `ksr_shop.sql`. Run `SHOW TABLES;` and confirm you see 6 tables.
3. Run `DESCRIBE products;`. Which columns can be NULL? Which column is the primary key?
4. Use `SHOW CREATE TABLE orders;` and find the line that defines the foreign key.
5. Run `SELECT * FROM employees;` and count how many employees work in Engineering.
6. Create a database called `my_practice`, switch to it with `USE`, confirm with `SELECT DATABASE();`, then drop it.

??? success "Solutions (click to expand)"

    ```{ .sql .no-run }
    -- 2
    USE ksr_shop;
    SHOW TABLES;            -- categories, customers, employees, order_items, orders, products

    -- 3
    DESCRIBE products;      -- brand and rating allow NULL; id is PRI

    -- 4
    SHOW CREATE TABLE orders;
    -- ... FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`)

    -- 5
    SELECT * FROM employees;   -- 4 in Engineering (Suresh, Farhan, Pooja, Nikhil)

    -- 6
    CREATE DATABASE my_practice;
    USE my_practice;
    SELECT DATABASE();
    DROP DATABASE my_practice;
    ```

## Interview Questions

!!! interview "1. What is the default port for MySQL?"
    3306.

!!! interview "2. What is the difference between MySQL Server and MySQL Workbench?"
    MySQL Server is the database engine that stores data and executes SQL. Workbench is a graphical client for connecting to a server to write queries, view results, design schemas and administer users. The CLI client (`mysql`) is another way to connect.

!!! interview "3. Why shouldn't an application connect as root?"
    Root has unrestricted privileges. If the application is compromised (for example through SQL injection), an attacker could drop databases or read everything. Following the principle of least privilege, create an application user with only the permissions it needs on its own database.

!!! interview "4. What does `DESCRIBE table_name` show?"
    The table's columns with their data types, whether they allow NULL, key information (PRI, UNI, MUL), default values and extras such as `auto_increment`.

!!! interview "5. What are `information_schema` and `performance_schema`?"
    System databases. `information_schema` holds metadata about all databases, tables, columns and privileges (read-only views). `performance_schema` collects server performance statistics. They should not be modified.

!!! interview "Scenario: a teammate gets `ERROR 2002: Can't connect to local MySQL server` after restarting their laptop. What do you check?"
    That the MySQL service is running (Services on Windows, System Settings or `brew services list` on macOS); that they're connecting to the right host and port; and whether another service took port 3306. Start the service and retry.

## Summary

| Task | Command |
|------|---------|
| Connect (CLI) | `mysql -u root -p` |
| Load the practice DB | `mysql -u root -p < ksr_shop.sql` or Workbench ⚡ |
| List / switch databases | `SHOW DATABASES;` / `USE ksr_shop;` |
| Current database | `SELECT DATABASE();` |
| List tables / structure | `SHOW TABLES;` / `DESCRIBE customers;` |
| Run in Workbench | ++ctrl+enter++ (one statement), ++ctrl+shift+enter++ (all) |
| App user | `CREATE USER ...; GRANT ... ON ksr_shop.* TO ...;` |
| Reset practice data | Re-run `ksr_shop.sql` |

**Next lesson:** [Creating Tables & Data Types](03-creating-tables.md), designing your own tables with the right types and constraints.
