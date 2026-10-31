-- =====================================================================
--  Kasi Yedumati · Full Stack Training · ksr_shop practice database (MySQL 8+)
--  Used in every lesson of the MySQL module.
--  Safe to re-run: it drops and recreates the ksr_shop database.
-- =====================================================================

DROP DATABASE IF EXISTS ksr_shop;
CREATE DATABASE ksr_shop;
USE ksr_shop;

-- ---------------------------------------------------------------------
-- categories: product groups (Toys has no products, for LEFT JOIN demos)
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    id   INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO categories (name) VALUES
('Electronics'), ('Fashion'), ('Books'), ('Home & Kitchen'), ('Sports'), ('Toys');

-- ---------------------------------------------------------------------
-- products
-- ---------------------------------------------------------------------
CREATE TABLE products (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(100) NOT NULL,
    category_id INT NOT NULL,
    brand       VARCHAR(50),
    price       DECIMAL(10, 2) NOT NULL CHECK (price > 0),
    stock       INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    rating      DECIMAL(2, 1) CHECK (rating BETWEEN 0 AND 5),
    added_on    DATE NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories (id)
);

INSERT INTO products (name, category_id, brand, price, stock, rating, added_on) VALUES
('iPhone 15',           1, 'Apple',              79999.00,  25, 4.7, '2025-09-20'),
('Galaxy S24',          1, 'Samsung',            74999.00,  30, 4.5, '2025-08-11'),
('Airdopes 141',        1, 'boAt',                1299.00, 200, 4.1, '2025-06-02'),
('Inspiron 15 Laptop',  1, 'Dell',               58999.00,  12, 4.3, '2025-07-15'),
('USB-C Cable',         1, NULL,                   299.00, 500, 3.9, '2025-05-01'),
('Denim Jacket',        2, 'Levis',               3499.00,  40, 4.4, '2025-10-01'),
('Running Shoes',       2, 'Puma',                4299.00,  60, 4.2, '2025-09-05'),
('Cotton T-Shirt',      2, 'Puma',                 799.00, 150, 4.0, '2025-03-12'),
('Atomic Habits',       3, 'Penguin',              499.00,  80, 4.8, '2025-01-20'),
('Wings of Fire',       3, 'Universities Press',   350.00,   0, 4.7, '2024-11-10'),
('Python Crash Course', 3, 'No Starch',           2199.00,  15, 4.6, '2025-04-18'),
('Non-stick Pan',       4, 'Prestige',            1599.00,  35, 4.2, '2025-02-25'),
('Mixer Grinder',       4, 'Bajaj',               3899.00,  18, 4.0, '2025-06-30'),
('Yoga Mat',            5, 'Decathlon',            999.00,   0, 4.3, '2025-08-22'),
('Cricket Bat',         5, 'SG',                  2499.00,  22, 4.4, '2025-07-07');

-- ---------------------------------------------------------------------
-- customers (Vikram and Priya have never ordered; some phones are NULL)
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    id        INT PRIMARY KEY AUTO_INCREMENT,
    name      VARCHAR(100) NOT NULL,
    email     VARCHAR(100) NOT NULL UNIQUE,
    city      VARCHAR(50)  NOT NULL,
    phone     VARCHAR(15),
    joined_on DATE NOT NULL
);

INSERT INTO customers (name, email, city, phone, joined_on) VALUES
('Asha Reddy',   'asha@example.com',   'Hyderabad', '9876500001', '2024-01-15'),
('Ravi Kumar',   'ravi@example.com',   'Bangalore', '9876500002', '2024-03-22'),
('Kiran Rao',    'kiran@example.com',  'Hyderabad', NULL,         '2024-05-10'),
('Meena Iyer',   'meena@example.com',  'Chennai',   '9876500004', '2024-07-01'),
('Arjun Singh',  'arjun@example.com',  'Delhi',     '9876500005', '2024-08-19'),
('Divya Nair',   'divya@example.com',  'Kochi',     NULL,         '2024-11-30'),
('Rahul Verma',  'rahul@example.com',  'Pune',      '9876500007', '2025-01-05'),
('Sneha Patil',  'sneha@example.com',  'Pune',      '9876500008', '2025-02-14'),
('Vikram Joshi', 'vikram@example.com', 'Mumbai',    '9876500009', '2025-06-21'),
('Priya Sharma', 'priya@example.com',  'Bangalore', NULL,         '2025-09-09');

-- ---------------------------------------------------------------------
-- orders
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    order_date  DATE NOT NULL,
    status      ENUM('pending', 'shipped', 'delivered', 'cancelled') NOT NULL DEFAULT 'pending',
    FOREIGN KEY (customer_id) REFERENCES customers (id)
);

INSERT INTO orders (customer_id, order_date, status) VALUES
(1, '2025-06-05', 'delivered'),
(2, '2025-06-18', 'delivered'),
(1, '2025-07-02', 'delivered'),
(3, '2025-07-20', 'cancelled'),
(4, '2025-08-03', 'delivered'),
(5, '2025-08-15', 'shipped'),
(2, '2025-08-28', 'delivered'),
(6, '2025-09-10', 'delivered'),
(7, '2025-09-25', 'pending'),
(1, '2025-10-01', 'shipped'),
(8, '2025-10-05', 'delivered'),
(4, '2025-10-12', 'pending');

-- ---------------------------------------------------------------------
-- order_items (Mixer Grinder and Yoga Mat have never been ordered)
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    id         INT PRIMARY KEY AUTO_INCREMENT,
    order_id   INT NOT NULL,
    product_id INT NOT NULL,
    quantity   INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id)   REFERENCES orders (id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products (id)
);

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
(1,  9, 2,   499.00), (1,  3, 1,  1299.00),
(2,  2, 1, 74999.00),
(3,  7, 1,  4299.00), (3,  8, 3,   799.00),
(4,  4, 1, 58999.00),
(5, 12, 1,  1599.00),
(6, 15, 1,  2499.00),
(7, 11, 1,  2199.00), (7,  9, 1,   499.00),
(8,  6, 1,  3499.00),
(9,  1, 1, 79999.00),
(10, 5, 4,   299.00), (10, 3, 2,  1299.00),
(11, 8, 2,   799.00), (11, 10, 1,  350.00),
(12, 9, 1,   499.00);

-- ---------------------------------------------------------------------
-- employees (self-referencing manager_id; two developers share a salary)
-- ---------------------------------------------------------------------
CREATE TABLE employees (
    id         INT PRIMARY KEY AUTO_INCREMENT,
    name       VARCHAR(100) NOT NULL,
    department VARCHAR(50)  NOT NULL,
    job_title  VARCHAR(50)  NOT NULL,
    salary     DECIMAL(10, 2) NOT NULL,
    manager_id INT,
    hire_date  DATE NOT NULL,
    FOREIGN KEY (manager_id) REFERENCES employees (id)
);

INSERT INTO employees (name, department, job_title, salary, manager_id, hire_date) VALUES
('Lakshmi Menon',  'Management',  'CEO',                 250000.00, NULL, '2018-04-01'),
('Suresh Babu',    'Engineering', 'Engineering Manager', 180000.00, 1,    '2019-06-15'),
('Anita Desai',    'Sales',       'Sales Manager',       150000.00, 1,    '2019-09-01'),
('Farhan Ali',     'Engineering', 'Senior Developer',    120000.00, 2,    '2020-02-10'),
('Pooja Hegde',    'Engineering', 'Developer',            85000.00, 2,    '2022-07-18'),
('Nikhil Jain',    'Engineering', 'Developer',            85000.00, 2,    '2023-01-09'),
('Ritu Kapoor',    'Sales',       'Sales Executive',      60000.00, 3,    '2021-11-22'),
('Manoj Pillai',   'Sales',       'Sales Executive',      55000.00, 3,    '2023-05-30'),
('Swati Kulkarni', 'Support',     'Support Lead',         70000.00, 1,    '2020-08-12'),
('Imran Shaikh',   'Support',     'Support Executive',    40000.00, 9,    '2024-03-04');
