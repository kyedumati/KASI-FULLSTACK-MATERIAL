-- =====================================================================
--  Kasi Yedumati · Full Stack Material · acmehr practice database (MySQL 8+)
--  AcmeHR Employee Management System, Phase 1 core (BRD v1.1).
--  Used in the FastAPI module. Sample data only; names follow the BRD wireframes.
--  Safe to re-run: it drops and recreates the acmehr database.
-- =====================================================================

DROP DATABASE IF EXISTS acmehr;
CREATE DATABASE acmehr CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE acmehr;

-- ---------------------------------------------------------------------
-- Organisation: locations, departments (with sub-departments), designations
-- ---------------------------------------------------------------------
CREATE TABLE locations (
    id     INT PRIMARY KEY AUTO_INCREMENT,
    name   VARCHAR(60) NOT NULL,
    city   VARCHAR(60) NOT NULL,
    region VARCHAR(30) NOT NULL
);

CREATE TABLE departments (
    id        INT PRIMARY KEY AUTO_INCREMENT,
    name      VARCHAR(60) NOT NULL UNIQUE,
    parent_id INT NULL,
    head_id   INT NULL,                      -- employee who heads it (FK added after employees)
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    FOREIGN KEY (parent_id) REFERENCES departments (id)
);

CREATE TABLE designations (
    id    INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(60) NOT NULL UNIQUE,
    level TINYINT NOT NULL                   -- 1 = most senior
);

CREATE TABLE shifts (
    id            INT PRIMARY KEY AUTO_INCREMENT,
    name          VARCHAR(30) NOT NULL UNIQUE,
    start_time    TIME NOT NULL,
    end_time      TIME NOT NULL,
    grace_minutes TINYINT NOT NULL DEFAULT 15
);

INSERT INTO locations (name, city, region) VALUES
('HITEC City', 'Hyderabad', 'South'),
('Whitefield', 'Bengaluru', 'South'),
('Hinjewadi', 'Pune', 'West');

INSERT INTO departments (name, parent_id) VALUES
('Leadership', NULL),
('Engineering', NULL),
('Product', NULL),
('Finance', NULL),
('Human Resources', NULL),
('Platform Engineering', 2),
('Quality Assurance', 2),
('IT Operations', NULL);

INSERT INTO designations (title, level) VALUES
('Chief Executive Officer', 1),
('Engineering Manager', 2),
('Product Manager', 2),
('Finance Manager', 2),
('HR Manager', 2),
('QA Lead', 3),
('Senior Software Engineer', 3),
('Software Engineer', 4),
('DevOps Engineer', 4),
('QA Engineer', 4),
('Product Designer', 4),
('Accountant', 4),
('HR Executive', 4),
('IT Administrator', 4);

INSERT INTO shifts (name, start_time, end_time, grace_minutes) VALUES
('General', '09:00:00', '18:00:00', 15),
('Early', '07:00:00', '16:00:00', 10);


-- ---------------------------------------------------------------------
-- employees: the master record. manager_id points to another employee.
-- role drives permissions in the API (BRD section 5).
-- ---------------------------------------------------------------------
CREATE TABLE employees (
    id                      INT PRIMARY KEY AUTO_INCREMENT,
    employee_code           VARCHAR(10)  NOT NULL UNIQUE,
    first_name              VARCHAR(50)  NOT NULL,
    last_name               VARCHAR(50)  NOT NULL,
    email                   VARCHAR(120) NOT NULL UNIQUE,
    phone                   VARCHAR(15)  NOT NULL,
    gender                  ENUM('female', 'male', 'other') NOT NULL,
    date_of_birth           DATE NOT NULL,
    hire_date               DATE NOT NULL,
    department_id           INT NOT NULL,
    designation_id          INT NOT NULL,
    location_id             INT NOT NULL,
    manager_id              INT NULL,
    shift_id                INT NOT NULL,
    status                  ENUM('active', 'on_notice', 'exited') NOT NULL DEFAULT 'active',
    role                    ENUM('employee', 'manager', 'hr_admin', 'sys_admin') NOT NULL DEFAULT 'employee',
    emergency_contact_name  VARCHAR(100) NOT NULL,
    emergency_contact_relation VARCHAR(30) NOT NULL,
    emergency_contact_phone VARCHAR(15)  NOT NULL,
    created_at              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (department_id)  REFERENCES departments (id),
    FOREIGN KEY (designation_id) REFERENCES designations (id),
    FOREIGN KEY (location_id)    REFERENCES locations (id),
    FOREIGN KEY (manager_id)     REFERENCES employees (id),
    FOREIGN KEY (shift_id)       REFERENCES shifts (id),
    CHECK (hire_date > date_of_birth)
);

INSERT INTO employees (employee_code, first_name, last_name, email, phone, gender, date_of_birth, hire_date,
                       department_id, designation_id, location_id, shift_id, status, role,
                       emergency_contact_name, emergency_contact_relation, emergency_contact_phone) VALUES
('E-1001', 'Lakshmi', 'Menon', 'lakshmi.menon@acme.example', '9000001001', 'female', '1975-03-12', '2018-04-01', 1, 1, 1, 1, 'active', 'manager', 'Gopal Menon', 'spouse', '9000011001'),
('E-1002', 'Karthik', 'Menon', 'karthik.menon@acme.example', '9000001002', 'male', '1984-07-21', '2019-06-15', 2, 2, 1, 1, 'active', 'manager', 'Divya Menon', 'spouse', '9000011002'),
('E-1003', 'Neha', 'Kapoor', 'neha.kapoor@acme.example', '9000001003', 'female', '1986-11-02', '2019-09-01', 3, 3, 2, 1, 'active', 'manager', 'Raj Kapoor', 'father', '9000011003'),
('E-1004', 'Rahul', 'Sharma', 'rahul.sharma@acme.example', '9000001004', 'male', '1988-01-30', '2020-01-06', 5, 5, 1, 1, 'active', 'hr_admin', 'Anjali Sharma', 'spouse', '9000011004'),
('E-1005', 'Suresh', 'Babu', 'suresh.babu@acme.example', '9000001005', 'male', '1982-09-09', '2019-11-04', 4, 4, 1, 1, 'active', 'manager', 'Latha Babu', 'spouse', '9000011005'),
('E-1042', 'Ananya', 'Rao', 'ananya.rao@acme.example', '9000001042', 'female', '1994-08-17', '2021-07-12', 2, 7, 1, 1, 'active', 'employee', 'Ravi Rao', 'father', '9000011111'),
('E-1043', 'Arjun', 'Reddy', 'arjun.reddy@acme.example', '9000001043', 'male', '1996-02-25', '2022-01-10', 7, 10, 1, 1, 'active', 'employee', 'Sudha Reddy', 'mother', '9000011043'),
('E-1044', 'Fatima', 'Khan', 'fatima.khan@acme.example', '9000001044', 'female', '1995-12-03', '2021-10-18', 3, 11, 2, 1, 'active', 'employee', 'Salim Khan', 'father', '9000011044'),
('E-1045', 'Meera', 'Iyer', 'meera.iyer@acme.example', '9000001045', 'female', '1993-04-22', '2021-04-05', 4, 12, 1, 1, 'active', 'employee', 'Kumar Iyer', 'brother', '9000011045'),
('E-1046', 'Priya', 'Nair', 'priya.nair@acme.example', '9000001046', 'female', '1997-06-30', '2023-02-13', 2, 8, 1, 1, 'active', 'employee', 'Mohan Nair', 'father', '9000011046'),
('E-1047', 'Vikram', 'Joshi', 'vikram.joshi@acme.example', '9000001047', 'male', '1992-10-11', '2020-08-24', 6, 9, 3, 2, 'active', 'employee', 'Asha Joshi', 'spouse', '9000011047'),
('E-1048', 'Sneha', 'Patil', 'sneha.patil@acme.example', '9000001048', 'female', '1998-01-19', '2024-06-03', 6, 8, 3, 2, 'active', 'employee', 'Anil Patil', 'father', '9000011048'),
('E-1049', 'Imran', 'Shaikh', 'imran.shaikh@acme.example', '9000001049', 'male', '1991-03-08', '2020-11-30', 5, 13, 1, 1, 'active', 'hr_admin', 'Nasreen Shaikh', 'spouse', '9000011049'),
('E-1050', 'Kavya', 'Srinivasan', 'kavya.srinivasan@acme.example', '9000001050', 'female', '1999-09-27', '2025-01-06', 2, 8, 2, 1, 'active', 'employee', 'Srinivasan R', 'father', '9000011050'),
('E-1051', 'Rohan', 'Gupta', 'rohan.gupta@acme.example', '9000001051', 'male', '1990-12-15', '2021-03-01', 2, 7, 2, 1, 'active', 'employee', 'Pooja Gupta', 'spouse', '9000011051'),
('E-1052', 'Deepa', 'Krishnan', 'deepa.krishnan@acme.example', '9000001052', 'female', '1987-07-07', '2019-12-09', 8, 14, 1, 1, 'active', 'sys_admin', 'Hari Krishnan', 'spouse', '9000011052'),
('E-1053', 'Manoj', 'Pillai', 'manoj.pillai@acme.example', '9000001053', 'male', '1995-05-05', '2022-09-19', 4, 12, 1, 1, 'on_notice', 'employee', 'Lekha Pillai', 'mother', '9000011053'),
('E-1054', 'Ritu', 'Kapoor', 'ritu.kapoor@acme.example', '9000001054', 'female', '1993-02-14', '2020-05-11', 3, 11, 2, 1, 'exited', 'employee', 'Sameer Kapoor', 'brother', '9000011054'),
('E-1055', 'Aditya', 'Kumar', 'aditya.kumar@acme.example', '9000001055', 'male', '2000-08-08', '2025-08-04', 7, 10, 1, 1, 'active', 'employee', 'Vijay Kumar', 'father', '9000011055'),
('E-1056', 'Swati', 'Kulkarni', 'swati.kulkarni@acme.example', '9000001056', 'female', '1989-11-23', '2020-07-20', 7, 6, 1, 1, 'active', 'manager', 'Ajay Kulkarni', 'spouse', '9000011056');

-- Reporting lines are set after every employee exists (a manager may be inserted after their reports)
UPDATE employees SET manager_id = CASE id
    WHEN 2 THEN 1
    WHEN 3 THEN 1
    WHEN 4 THEN 1
    WHEN 5 THEN 1
    WHEN 6 THEN 2
    WHEN 7 THEN 20
    WHEN 8 THEN 3
    WHEN 9 THEN 5
    WHEN 10 THEN 2
    WHEN 11 THEN 2
    WHEN 12 THEN 2
    WHEN 13 THEN 4
    WHEN 14 THEN 2
    WHEN 15 THEN 2
    WHEN 16 THEN 1
    WHEN 17 THEN 5
    WHEN 18 THEN 3
    WHEN 19 THEN 20
    WHEN 20 THEN 2
END
WHERE id IN (2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20);

ALTER TABLE departments ADD FOREIGN KEY (head_id) REFERENCES employees (id);
UPDATE departments SET head_id = 1 WHERE id = 1;
UPDATE departments SET head_id = 2 WHERE id = 2;
UPDATE departments SET head_id = 3 WHERE id = 3;
UPDATE departments SET head_id = 5 WHERE id = 4;
UPDATE departments SET head_id = 4 WHERE id = 5;
UPDATE departments SET head_id = 11 WHERE id = 6;
UPDATE departments SET head_id = 20 WHERE id = 7;
UPDATE departments SET head_id = 16 WHERE id = 8;

-- ---------------------------------------------------------------------
-- Leave: types, holidays, requests, and yearly balances
-- ---------------------------------------------------------------------
CREATE TABLE leave_types (
    id            INT PRIMARY KEY AUTO_INCREMENT,
    code          VARCHAR(5)  NOT NULL UNIQUE,
    name          VARCHAR(40) NOT NULL,
    days_per_year SMALLINT NULL,             -- NULL = no yearly limit (loss of pay)
    carry_forward BOOLEAN NOT NULL,
    is_paid       BOOLEAN NOT NULL
);

CREATE TABLE holidays (
    holiday_date DATE PRIMARY KEY,
    name         VARCHAR(60) NOT NULL
);

CREATE TABLE leave_requests (
    id            INT PRIMARY KEY AUTO_INCREMENT,
    employee_id   INT NOT NULL,
    leave_type_id INT NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE NOT NULL,
    duration      ENUM('full', 'first_half', 'second_half') NOT NULL DEFAULT 'full',
    days          DECIMAL(4, 1) NOT NULL,    -- working days, excluding weekends and holidays
    reason        VARCHAR(255) NOT NULL,
    status        ENUM('pending', 'approved', 'rejected', 'cancelled') NOT NULL DEFAULT 'pending',
    approver_id   INT NULL,
    decision_note VARCHAR(255) NULL,
    applied_at    DATETIME NOT NULL,
    decided_at    DATETIME NULL,
    FOREIGN KEY (employee_id)   REFERENCES employees (id),
    FOREIGN KEY (leave_type_id) REFERENCES leave_types (id),
    FOREIGN KEY (approver_id)   REFERENCES employees (id),
    CHECK (end_date >= start_date),
    CHECK (days > 0)
);

CREATE TABLE leave_balances (
    employee_id   INT NOT NULL,
    leave_type_id INT NOT NULL,
    year          SMALLINT NOT NULL,
    allocated     DECIMAL(4, 1) NOT NULL,
    used          DECIMAL(4, 1) NOT NULL DEFAULT 0,
    PRIMARY KEY (employee_id, leave_type_id, year),
    FOREIGN KEY (employee_id)   REFERENCES employees (id),
    FOREIGN KEY (leave_type_id) REFERENCES leave_types (id),
    CHECK (used <= allocated)
);

INSERT INTO leave_types (code, name, days_per_year, carry_forward, is_paid) VALUES
('CL', 'Casual leave', 12, FALSE, TRUE),
('SL', 'Sick leave', 12, FALSE, TRUE),
('EL', 'Earned leave', 15, TRUE, TRUE),
('ML', 'Maternity leave', 182, FALSE, TRUE),
('PL', 'Paternity leave', 10, FALSE, TRUE),
('LOP', 'Loss of pay', NULL, FALSE, FALSE);

INSERT INTO holidays (holiday_date, name) VALUES
('2026-01-26', 'Republic Day'),
('2026-03-04', 'Holi'),
('2026-08-15', 'Independence Day'),
('2026-10-02', 'Gandhi Jayanti'),
('2026-10-20', 'Dussehra'),
('2026-11-09', 'Diwali'),
('2026-12-25', 'Christmas');

INSERT INTO leave_requests (employee_id, leave_type_id, start_date, end_date, duration, days, reason,
                            status, approver_id, decision_note, applied_at, decided_at) VALUES
(6, 1, '2026-03-16', '2026-03-17', 'full', 2.0, 'Family function in Vijayawada', 'approved', 2, NULL, '2026-03-02 10:15:00', '2026-03-02 16:40:00'),
(6, 2, '2026-06-08', '2026-06-09', 'full', 2.0, 'Fever', 'approved', 2, NULL, '2026-06-08 08:05:00', '2026-06-08 11:20:00'),
(6, 1, '2026-08-20', '2026-08-21', 'full', 2.0, 'Personal work', 'approved', 2, NULL, '2026-08-10 09:30:00', '2026-08-10 14:00:00'),
(6, 3, '2026-11-16', '2026-11-20', 'full', 5.0, 'Trip to Goa', 'pending', NULL, NULL, '2026-10-01 11:00:00', NULL),
(7, 1, '2026-10-08', '2026-10-09', 'full', 2.0, 'Sister''s wedding', 'pending', NULL, NULL, '2026-10-03 18:20:00', NULL),
(8, 2, '2026-10-05', '2026-10-05', 'full', 1.0, 'Migraine', 'approved', 3, NULL, '2026-10-05 07:45:00', '2026-10-05 09:10:00'),
(8, 2, '2026-10-12', '2026-10-12', 'full', 1.0, 'Dental appointment', 'pending', NULL, NULL, '2026-10-04 12:00:00', NULL),
(9, 3, '2026-10-19', '2026-10-23', 'full', 4.0, 'Visiting parents in Chennai', 'pending', NULL, NULL, '2026-10-02 15:30:00', NULL),
(10, 1, '2026-09-07', '2026-09-07', 'first_half', 0.5, 'Bank work', 'approved', 2, NULL, '2026-09-04 10:00:00', '2026-09-04 12:30:00'),
(15, 3, '2026-05-04', '2026-05-08', 'full', 5.0, 'Vacation', 'approved', 2, NULL, '2026-04-10 09:00:00', '2026-04-11 10:00:00'),
(15, 1, '2026-07-03', '2026-07-03', 'full', 1.0, 'Long weekend', 'rejected', 2, 'Release week: please pick another date', '2026-07-01 17:00:00', '2026-07-02 09:30:00'),
(11, 1, '2026-10-26', '2026-10-26', 'full', 1.0, 'Moving house', 'cancelled', NULL, NULL, '2026-10-05 13:00:00', NULL),
(12, 6, '2026-09-14', '2026-09-15', 'full', 2.0, 'Extended travel', 'approved', 2, NULL, '2026-09-01 10:00:00', '2026-09-02 10:00:00'),
(14, 2, '2026-02-02', '2026-02-02', 'full', 1.0, 'Cold', 'approved', 2, NULL, '2026-02-02 08:30:00', '2026-02-02 10:00:00'),
(3, 3, '2026-12-21', '2026-12-24', 'full', 4.0, 'Year-end holiday', 'pending', NULL, NULL, '2026-10-05 16:00:00', NULL);

-- 2026 balances for current employees: CL, SL and EL (limited types), with used = approved leave
INSERT INTO leave_balances (employee_id, leave_type_id, year, allocated, used)
SELECT e.id, lt.id, 2026, lt.days_per_year,
       COALESCE((SELECT SUM(lr.days) FROM leave_requests lr
                 WHERE lr.employee_id = e.id AND lr.leave_type_id = lt.id
                   AND lr.status = 'approved' AND YEAR(lr.start_date) = 2026), 0)
FROM employees e
CROSS JOIN leave_types lt
WHERE e.status <> 'exited' AND lt.code IN ('CL', 'SL', 'EL');


-- ---------------------------------------------------------------------
-- attendance: one row per employee per working day they checked in
-- (no row = absent or on leave). Week of Monday 5 October 2026.
-- ---------------------------------------------------------------------
CREATE TABLE attendance (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    employee_id INT NOT NULL,
    work_date   DATE NOT NULL,
    check_in    TIME NOT NULL,
    check_out   TIME NULL,                   -- NULL while the employee is still at work
    source      ENUM('web', 'mobile', 'biometric') NOT NULL,
    UNIQUE (employee_id, work_date),
    FOREIGN KEY (employee_id) REFERENCES employees (id),
    CHECK (check_out IS NULL OR check_out > check_in)
);

INSERT INTO attendance (employee_id, work_date, check_in, check_out, source) VALUES
(1, '2026-10-05', '08:49:00', '17:39:00', 'biometric'),
(1, '2026-10-06', '09:02:00', '18:22:00', 'biometric'),
(1, '2026-10-07', '09:15:00', '18:15:00', 'biometric'),
(1, '2026-10-08', '08:51:00', '17:31:00', 'biometric'),
(1, '2026-10-09', '09:04:00', '18:14:00', 'biometric'),
(2, '2026-10-05', '09:41:00', '18:30:00', 'biometric'),
(2, '2026-10-06', '09:09:00', '17:49:00', 'biometric'),
(2, '2026-10-07', '08:45:00', '17:55:00', 'biometric'),
(2, '2026-10-08', '08:58:00', '17:48:00', 'biometric'),
(2, '2026-10-09', '09:11:00', '18:31:00', 'biometric'),
(3, '2026-10-05', '09:03:00', '18:13:00', 'mobile'),
(3, '2026-10-06', '09:16:00', '18:06:00', 'web'),
(3, '2026-10-07', '08:52:00', '18:12:00', 'mobile'),
(3, '2026-10-08', '09:05:00', '18:05:00', 'web'),
(3, '2026-10-09', '09:18:00', '17:58:00', 'mobile'),
(4, '2026-10-05', '09:10:00', '18:30:00', 'biometric'),
(4, '2026-10-06', '08:46:00', '17:46:00', 'biometric'),
(4, '2026-10-07', '08:59:00', '17:39:00', 'biometric'),
(4, '2026-10-08', '09:12:00', '18:22:00', 'biometric'),
(4, '2026-10-09', '08:48:00', '17:38:00', 'biometric'),
(5, '2026-10-05', '09:10:00', '17:50:00', 'biometric'),
(5, '2026-10-06', '08:53:00', '18:03:00', 'biometric'),
(5, '2026-10-07', '09:06:00', '17:56:00', 'biometric'),
(5, '2026-10-08', '08:42:00', '18:02:00', 'biometric'),
(5, '2026-10-09', '09:20:00', '18:20:00', 'biometric'),
(6, '2026-10-05', '09:02:00', '18:10:00', 'biometric'),
(6, '2026-10-06', '09:00:00', '18:20:00', 'biometric'),
(6, '2026-10-07', '09:13:00', '18:13:00', 'biometric'),
(6, '2026-10-08', '09:14:00', '17:54:00', 'biometric'),
(6, '2026-10-09', '09:02:00', '18:12:00', 'biometric'),
(7, '2026-10-05', '08:55:00', '17:20:00', 'biometric'),
(7, '2026-10-06', '09:07:00', '17:47:00', 'biometric'),
(7, '2026-10-07', '09:08:00', '18:18:00', 'biometric'),
(7, '2026-10-08', '08:56:00', '17:46:00', 'biometric'),
(7, '2026-10-09', '09:09:00', '18:29:00', 'biometric'),
(8, '2026-10-06', '09:39:00', '18:29:00', 'mobile'),
(8, '2026-10-07', '08:50:00', '18:10:00', 'web'),
(8, '2026-10-08', '09:03:00', '18:03:00', 'mobile'),
(8, '2026-10-09', '09:16:00', '17:56:00', 'web'),
(9, '2026-10-05', '09:10:00', '18:30:00', 'biometric'),
(9, '2026-10-06', '08:44:00', '17:44:00', 'biometric'),
(9, '2026-10-07', '08:57:00', '17:37:00', 'biometric'),
(9, '2026-10-08', '09:10:00', '18:20:00', 'biometric'),
(9, '2026-10-09', '08:46:00', '17:36:00', 'biometric'),
(10, '2026-10-05', '10:05:00', '19:00:00', 'biometric'),
(10, '2026-10-06', '08:51:00', '18:01:00', 'biometric'),
(10, '2026-10-07', '09:04:00', '17:54:00', 'biometric'),
(10, '2026-10-08', '09:17:00', '18:37:00', 'biometric'),
(10, '2026-10-09', '08:53:00', '17:53:00', 'biometric'),
(11, '2026-10-05', '06:45:00', '15:35:00', 'mobile'),
(11, '2026-10-06', '06:58:00', '16:18:00', 'web'),
(11, '2026-10-07', '07:11:00', '16:11:00', 'mobile'),
(11, '2026-10-08', '06:47:00', '15:27:00', 'web'),
(11, '2026-10-09', '07:00:00', '16:10:00', 'mobile'),
(12, '2026-10-05', '06:52:00', '15:52:00', 'web'),
(12, '2026-10-06', '07:05:00', '15:45:00', 'mobile'),
(12, '2026-10-08', '06:54:00', '15:44:00', 'mobile'),
(12, '2026-10-09', '07:07:00', '16:27:00', 'web'),
(13, '2026-10-05', '08:59:00', '18:09:00', 'biometric'),
(13, '2026-10-06', '09:12:00', '18:02:00', 'biometric'),
(13, '2026-10-07', '08:48:00', '18:08:00', 'biometric'),
(13, '2026-10-08', '09:01:00', '18:01:00', 'biometric'),
(13, '2026-10-09', '09:14:00', '17:54:00', 'biometric'),
(14, '2026-10-05', '09:06:00', '18:26:00', 'web'),
(14, '2026-10-06', '08:42:00', '17:42:00', 'mobile'),
(14, '2026-10-07', '08:55:00', '17:35:00', 'web'),
(14, '2026-10-08', '09:08:00', '18:18:00', 'mobile'),
(14, '2026-10-09', '09:09:00', '17:59:00', 'web'),
(15, '2026-10-05', '09:10:00', '17:50:00', 'mobile'),
(15, '2026-10-06', '08:49:00', '17:59:00', 'web'),
(15, '2026-10-07', '09:02:00', '17:52:00', 'mobile'),
(15, '2026-10-08', '09:40:00', '19:00:00', 'web'),
(15, '2026-10-09', '08:51:00', '17:51:00', 'mobile'),
(16, '2026-10-05', '08:43:00', '17:33:00', 'biometric'),
(16, '2026-10-06', '08:56:00', '18:16:00', 'biometric'),
(16, '2026-10-07', '09:34:00', '18:34:00', 'biometric'),
(16, '2026-10-08', '08:45:00', '17:25:00', 'biometric'),
(16, '2026-10-09', '08:58:00', '18:08:00', 'biometric'),
(17, '2026-10-05', '08:50:00', '17:50:00', 'biometric'),
(17, '2026-10-06', '09:28:00', '18:08:00', 'biometric'),
(17, '2026-10-07', '09:16:00', '18:26:00', 'biometric'),
(17, '2026-10-08', '08:52:00', '17:42:00', 'biometric'),
(17, '2026-10-09', '09:05:00', '18:25:00', 'biometric'),
(19, '2026-10-05', '09:04:00', '18:24:00', 'biometric'),
(19, '2026-10-06', '09:17:00', '18:17:00', 'biometric'),
(19, '2026-10-07', '08:53:00', '17:33:00', 'biometric'),
(19, '2026-10-08', '09:06:00', '18:16:00', 'biometric'),
(19, '2026-10-09', '08:42:00', '17:32:00', 'biometric'),
(20, '2026-10-05', '09:10:00', '17:50:00', 'biometric'),
(20, '2026-10-06', '08:47:00', '17:57:00', 'biometric'),
(20, '2026-10-07', '09:00:00', '17:50:00', 'biometric'),
(20, '2026-10-08', '09:13:00', '18:33:00', 'biometric'),
(20, '2026-10-09', '08:49:00', '17:49:00', 'biometric');


-- ---------------------------------------------------------------------
-- documents (file metadata; files themselves live in storage) and audit log
-- ---------------------------------------------------------------------
CREATE TABLE documents (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    employee_id INT NOT NULL,
    doc_type    ENUM('id_proof', 'address_proof', 'education', 'agreement', 'tax') NOT NULL,
    file_name   VARCHAR(255) NOT NULL,
    size_kb     INT NOT NULL,
    verified    BOOLEAN NOT NULL DEFAULT FALSE,
    uploaded_at DATETIME NOT NULL,
    FOREIGN KEY (employee_id) REFERENCES employees (id)
);

CREATE TABLE audit_logs (
    id         BIGINT PRIMARY KEY AUTO_INCREMENT,
    actor_id   INT NULL,
    action     VARCHAR(40) NOT NULL,         -- e.g. leave.approved, employee.updated
    entity     VARCHAR(40) NOT NULL,
    entity_id  INT NULL,
    details    JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (actor_id) REFERENCES employees (id)
);

INSERT INTO documents (employee_id, doc_type, file_name, size_kb, verified, uploaded_at) VALUES
(6, 'id_proof', 'ananya-rao-aadhaar.pdf', 412, TRUE, '2021-07-12 10:00:00'),
(6, 'education', 'ananya-rao-btech-degree.pdf', 1280, TRUE, '2021-07-12 10:05:00'),
(6, 'agreement', 'ananya-rao-offer-letter.pdf', 236, TRUE, '2021-07-12 10:10:00'),
(7, 'id_proof', 'arjun-reddy-pan.pdf', 198, TRUE, '2022-01-10 11:00:00'),
(14, 'id_proof', 'kavya-srinivasan-aadhaar.pdf', 405, FALSE, '2025-01-06 09:40:00'),
(19, 'education', 'aditya-kumar-bsc-degree.pdf', 1102, FALSE, '2025-08-04 10:20:00');

