---
lesson: true
category: Functions & Modules
short: Modules
description: Importing modules, the standard library (math, random, datetime, os, json), creating your own modules and packages, and the __name__ == "__main__" pattern.
---

# Modules & Packages

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Import modules in different ways and know when to use each
    - Use popular standard library modules: `math`, `random`, `datetime`, `os`, `pathlib`, `json`
    - Create your own module and import it from another file
    - Use `if __name__ == "__main__":` correctly
    - Organise code into packages with `__init__.py`

**Prerequisites:** [Functions](01-functions.md)

## What is a Module?

A **module** is simply a **`.py` file** containing functions, variables and classes that other files can use.

As programs grow, keeping everything in one file becomes unmanageable. Modules let you split code into logical files and **reuse** code written by you, by Python's developers, or by the open-source community.

!!! example "Real-life analogy: a toolbox with drawers"
    A big toolbox has separate drawers: one for screwdrivers, one for spanners, one for measuring tools. When you need a screwdriver, you open just that drawer. Modules are the drawers; `import` opens one.

There are three kinds of modules:

| Kind | Example | Where it comes from |
|------|---------|---------------------|
| **Built-in / standard library** | `math`, `random`, `datetime`, `json`, `os` | Comes with Python, no install needed |
| **Your own** | `utils.py`, `billing.py` | Files you write |
| **Third-party** | `requests`, `django`, `fastapi`, `pandas` | Installed with `pip` (next lesson) |

## Importing Modules

### `import module`

```python
import math

print(math.sqrt(144))
print(math.pi)
print(math.ceil(4.2), math.floor(4.8))
```

```{ .text .output }
12.0
3.141592653589793
5 4
```

You access things with `module.name`, so it's always clear where `sqrt` came from.

### `from module import name`

```python
from math import sqrt, pi

print(sqrt(81))
print(round(pi, 2))
```

```{ .text .output }
9.0
3.14
```

Shorter to type, but you lose the `math.` prefix that shows where the name came from.

### `import module as alias`

```python
import datetime as dt

print(dt.date(2026, 10, 31).strftime("%d %b %Y"))
```

```{ .text .output }
31 Oct 2026
```

Common community aliases: `import numpy as np`, `import pandas as pd`.

### Avoid `from module import *`

```python
from math import *     # imports everything; don't do this
```

It dumps every name into your file. You can't tell where names came from, and it can silently overwrite your own variables.

| Style | Use when |
|-------|----------|
| `import math` | Default choice; clearest |
| `from math import sqrt` | You use one or two names many times |
| `import pandas as pd` | Long module names with a standard alias |
| `from x import *` | Avoid |

!!! tip "See what a module offers"
    In the REPL: `import math`, then `dir(math)` lists its contents and `help(math.sqrt)` shows the documentation.

## The Standard Library

Python comes "batteries included": hundreds of ready-made modules. Here are the ones you'll use most.

### `math`

```python
import math

print(math.factorial(5))
print(math.pow(2, 10))
print(math.gcd(48, 36))
print(round(math.log10(1000)))
```

```{ .text .output }
120
1024.0
12
3
```

### `random`

```python
import random

print(random.randint(1, 6))                       # dice roll
print(random.choice(["Asha", "Ravi", "Kiran"]))   # pick one
print(random.sample(range(1, 50), 6))             # 6 unique numbers

cards = ["A", "K", "Q", "J"]
random.shuffle(cards)
print(cards)
```

```{ .text .output }
4
Ravi
[17, 3, 42, 28, 9, 35]
['Q', 'A', 'J', 'K']
```

Your output will differ every run; that's the point of random.

!!! warning "Not for security"
    `random` is fine for games and test data, but **never** for passwords, OTPs or tokens. Use the `secrets` module: `secrets.token_hex(16)` or `secrets.randbelow(1_000_000)`.

### `datetime`

```python
from datetime import datetime, date, timedelta

today = date(2026, 10, 31)
print(today)
print(today.strftime("%d/%m/%Y"))
print(today.strftime("%A, %d %B %Y"))

due = today + timedelta(days=15)
print("Fee due on:", due)

joined = date(2026, 8, 1)
print("Days in course:", (today - joined).days)

meeting = datetime.strptime("2026-11-05 10:30", "%Y-%m-%d %H:%M")
print(meeting.hour, meeting.minute)
```

```{ .text .output }
2026-10-31
31/10/2026
Saturday, 31 October 2026
Fee due on: 2026-11-15
Days in course: 91
10 30
```

Use `date.today()` and `datetime.now()` to get the current date and time.

| Code | Meaning | Example |
|------|---------|---------|
| `%d` / `%m` / `%Y` | Day / month / 4-digit year | `31` / `10` / `2026` |
| `%b` / `%B` | Short / full month name | `Oct` / `October` |
| `%A` | Weekday name | `Saturday` |
| `%H:%M` | 24-hour time | `14:30` |

### `os` and `pathlib`: files and folders

```python
import os
from pathlib import Path

print(os.getcwd())                     # current folder

project = Path("reports")
project.mkdir(exist_ok=True)           # create a folder if it doesn't exist
file = project / "summary.txt"         # build paths safely on any OS
file.write_text("Total students: 42")
print(file.read_text())
print(file.exists(), file.suffix, file.name)
```

```{ .text .output }
/Users/ravi/python-course
Total students: 42
True .txt summary.txt
```

!!! realworld "In Real Projects"
    `os.environ` reads **environment variables**, which is how real apps get secrets like database passwords without hard-coding them: `db_password = os.environ.get("DB_PASSWORD")`. You'll use this in Django and FastAPI settings.

### `json`

```python
import json

student = {"name": "Asha", "skills": ["Python", "SQL"], "placed": False}

text = json.dumps(student, indent=2)     # Python → JSON text
print(text)

data = json.loads('{"id": 7, "active": true}')   # JSON text → Python
print(data["id"], data["active"])
```

```{ .text .output }
{
  "name": "Asha",
  "skills": [
    "Python",
    "SQL"
  ],
  "placed": false
}
7 True
```

Notice that JSON uses `true`/`false`/`null`, while Python uses `True`/`False`/`None`. The `json` module converts between them.

Other useful modules to know: `collections` (`Counter`, `defaultdict`), `csv`, `re` (regular expressions), `time`, `statistics`, `secrets`, `logging`.

```python
from collections import Counter

votes = ["Python", "Java", "Python", "React", "Python", "Java"]
print(Counter(votes).most_common(2))
```

```{ .text .output }
[('Python', 3), ('Java', 2)]
```

## Creating Your Own Module

Any `.py` file is a module. Create two files in the **same folder**:

```python title="billing.py"
GST_RATE = 0.18

def subtotal(prices):
    return sum(prices)

def gst(amount):
    return round(amount * GST_RATE, 2)

def total(prices):
    sub = subtotal(prices)
    return sub + gst(sub)
```

```python title="main.py"
import billing

cart = [1200, 850, 399]
print("Subtotal:", billing.subtotal(cart))
print("GST     :", billing.gst(billing.subtotal(cart)))
print("Total   :", billing.total(cart))
print("Rate    :", billing.GST_RATE)
```

Run `python main.py`:

```{ .text .output }
Subtotal: 2449
GST     : 440.82
Total   : 2889.82
Rate    : 0.18
```

When Python imports `billing`, it looks for `billing.py` in the current folder first, then in the standard library and installed packages.

!!! mistake "Common Mistake: naming your file like a standard module"
    If you name your own file `random.py`, `math.py` or `json.py`, then `import random` imports **your** file instead of Python's, and you get errors like `AttributeError: module 'random' has no attribute 'randint'`. Rename your file (and delete any `__pycache__` folder next to it).

## The `if __name__ == "__main__":` Pattern

Every module has a built-in variable `__name__`:

- When you **run** a file directly (`python billing.py`), its `__name__` is `"__main__"`.
- When the file is **imported**, its `__name__` is the module name (`"billing"`).

This lets a file contain test or demo code that runs only when executed directly, not when imported:

```python title="billing.py"
GST_RATE = 0.18

def gst(amount):
    return round(amount * GST_RATE, 2)

if __name__ == "__main__":
    # Runs only with: python billing.py
    print("Testing gst():", gst(1000))
```

```bash
python billing.py
```

```{ .text .output }
Testing gst(): 180.0
```

When `main.py` does `import billing`, the test line does **not** run.

!!! tip "Standard structure for a script"
    ```python
    def main():
        # program logic here
        ...

    if __name__ == "__main__":
        main()
    ```

    You'll see this pattern in almost every professional Python project.

## Packages

A **package** is a **folder of modules**. It lets you group related modules, like folders on your computer.

```text
ecommerce/
├── main.py
└── shop/                 ← package
    ├── __init__.py       ← marks the folder as a package (can be empty)
    ├── products.py
    ├── cart.py
    └── payments/         ← sub-package
        ├── __init__.py
        └── upi.py
```

```python title="shop/cart.py"
def add_item(cart, item, price):
    cart.append((item, price))
    return cart

def cart_total(cart):
    return sum(price for _, price in cart)
```

```python title="main.py"
from shop.cart import add_item, cart_total
from shop.payments import upi

cart = []
add_item(cart, "Laptop", 55000)
add_item(cart, "Mouse", 799)
print(cart_total(cart))
```

```{ .text .output }
55799
```

Imports use **dots** for folders: `shop.payments.upi` means `shop/payments/upi.py`.

!!! realworld "In Real Projects"
    A Django project is a set of packages. Each app (`users`, `products`, `orders`) is a folder with `__init__.py`, `models.py`, `views.py` and `urls.py`, and you'll write imports like `from products.models import Product` every day.

### Absolute vs relative imports

Inside a package, modules can import each other:

```python
# inside shop/cart.py
from shop.products import get_price     # absolute: full path from the project root
from .products import get_price         # relative: "." means the same package
```

Prefer **absolute** imports. They're clearer and work the same everywhere.

## Common Mistakes

| Mistake | Error | Fix |
|---------|-------|-----|
| Typo or missing module | `ModuleNotFoundError: No module named 'requets'` | Fix the spelling, or `pip install` third-party packages |
| Your file is named `random.py` / `json.py` | `AttributeError: module 'random' has no attribute ...` | Rename your file, delete `__pycache__` |
| Running from the wrong folder | `ModuleNotFoundError` for your own module | Run Python from the project root |
| `from math import *` | Names clash silently | Import only what you need |
| Test code runs on import | Unexpected prints when importing | Put it under `if __name__ == "__main__":` |
| Two modules importing each other | `ImportError: cannot import name ... (most likely due to a circular import)` | Move shared code into a third module |

## Practice Exercises

**Easy**

1. Use `math` to print the square root of 625 and the value of π rounded to 4 decimals.
2. Use `random` to simulate rolling two dice and print their sum.
3. Use `datetime` to print today's date in the format `31-Oct-2026`.

**Medium**

4. Create a module `converters.py` with `km_to_miles()`, `kg_to_pounds()` and `celsius_to_fahrenheit()`. Import and use it from `main.py`.
5. Add an `if __name__ == "__main__":` block to `converters.py` that tests each function. Confirm it doesn't run when imported.
6. Write a program that asks for a date of birth (`DD-MM-YYYY`) and prints the person's age in years and the weekday they were born on.

**Challenge**

7. Create a package `school/` with modules `students.py` (functions to add and list students stored in a dict), `grades.py` (`get_grade(marks)`) and `reports.py` (uses both to print a report). Write `main.py` that imports from the package, adds three students and prints the report. Save the data to `students.json` with the `json` module and load it back.

??? success "Solutions (click to expand)"

    ```python
    # 1
    import math
    print(math.sqrt(625), round(math.pi, 4))       # 25.0 3.1416

    # 2
    import random
    d1, d2 = random.randint(1, 6), random.randint(1, 6)
    print(d1, d2, "sum =", d1 + d2)

    # 3
    from datetime import date
    print(date.today().strftime("%d-%b-%Y"))
    ```

    ```python title="converters.py"
    # 4 and 5
    def km_to_miles(km):
        return round(km * 0.621371, 2)

    def kg_to_pounds(kg):
        return round(kg * 2.20462, 2)

    def celsius_to_fahrenheit(c):
        return c * 9 / 5 + 32

    if __name__ == "__main__":
        print(km_to_miles(10), kg_to_pounds(70), celsius_to_fahrenheit(37))
    ```

    ```python title="main.py"
    import converters
    print(converters.km_to_miles(42.2))            # 26.22
    ```

    ```python
    # 6
    from datetime import datetime, date

    dob = datetime.strptime(input("DOB (DD-MM-YYYY): "), "%d-%m-%Y").date()
    today = date.today()
    age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
    print(f"Age: {age}, born on a {dob.strftime('%A')}")
    ```

    ```python title="school/grades.py"
    # 7
    def get_grade(marks):
        if marks >= 90: return "A"
        if marks >= 75: return "B"
        if marks >= 60: return "C"
        if marks >= 35: return "D"
        return "F"
    ```

    ```python title="school/students.py"
    import json

    def add_student(db, roll, name, marks):
        db[roll] = {"name": name, "marks": marks}

    def save(db, path="students.json"):
        with open(path, "w") as f:
            json.dump(db, f, indent=2)

    def load(path="students.json"):
        with open(path) as f:
            return json.load(f)
    ```

    ```python title="school/reports.py"
    from school.grades import get_grade

    def print_report(db):
        for roll, s in db.items():
            print(f"{roll}  {s['name']:<8} {s['marks']:>3}  {get_grade(s['marks'])}")
    ```

    ```python title="main.py"
    from school.students import add_student, save, load
    from school.reports import print_report

    db = {}
    add_student(db, 101, "Asha", 88)
    add_student(db, 102, "Ravi", 72)
    add_student(db, 103, "Kiran", 95)
    save(db)
    print_report(load())
    ```

    Create an empty `school/__init__.py` too. Note: JSON keys are always strings, so roll `101` comes back as `"101"`.

!!! note "Mini Assignment"
    Split your `student_manager.py` (from the Functions lesson) into a package: `student_manager/storage.py` (load/save JSON), `student_manager/logic.py` (percentage and grade functions), `student_manager/menu.py` (the input loop), plus a top-level `main.py` with the `if __name__ == "__main__":` pattern. Data should persist between runs in a JSON file.

## Interview Questions

!!! interview "1. What is the difference between a module and a package?"
    A module is a single `.py` file. A package is a directory of modules (traditionally containing an `__init__.py`) that can also contain sub-packages. Packages organise modules into a hierarchy, imported with dots: `shop.payments.upi`.

!!! interview "2. What does `if __name__ == \"__main__\":` do?"
    It checks whether the file is being run directly. `__name__` is `"__main__"` when executed as a script and the module's name when imported. Code under this check, typically a `main()` call or tests, runs only when the file is executed directly.

!!! interview "3. What is `__init__.py` for?"
    It marks a directory as a regular package and runs when the package is first imported. It can be empty, or it can expose a convenient API by importing names from submodules. (Python 3.3+ also supports namespace packages without it, but regular packages still use it.)

!!! interview "4. What is the difference between `import x` and `from x import y`?"
    `import x` binds the module name, so you write `x.y`, which keeps the origin clear. `from x import y` binds `y` directly into your namespace. It's shorter, but can cause name clashes and hides where names came from.

!!! interview "5. How does Python find a module when you import it?"
    It searches the directories in `sys.path`, in order: the script's directory (or the current directory), `PYTHONPATH` entries, the standard library, then site-packages where pip installs third-party packages. The first match wins, which is why a local `random.py` shadows the standard one.

!!! interview "Scenario: `import requests` works on your laptop but fails on the server with `ModuleNotFoundError`. Why?"
    `requests` is a third-party package installed only on your machine, or in a different virtual environment. Install it on the server, ideally from a `requirements.txt`, inside the project's virtual environment. That's the topic of the next lesson.

## Summary

| Concept | Remember |
|---------|----------|
| Module | Any `.py` file |
| Import styles | `import m`, `from m import x`, `import m as alias`; avoid `*` |
| Standard library | `math`, `random`, `datetime`, `os`, `pathlib`, `json`, `collections` |
| Own module | Put `utils.py` next to your script and `import utils` |
| Name clashes | Never name files `random.py`, `json.py` etc. |
| `__name__` | `"__main__"` when run directly; module name when imported |
| Package | Folder of modules + `__init__.py`; import with dots |
| Secrets | Use `secrets`, not `random`; read config from `os.environ` |

**Next lesson:** [Virtual Environments & pip](06-virtual-environments-and-pip.md), installing third-party packages the professional way.
