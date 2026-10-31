---
lesson: true
category: Python Foundation
short: Data Types
description: The built-in data types in Python (numbers, text, booleans, None and collections) and how to check them.
---

# Data Types in Python

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain what a data type is and why it matters
    - Use `int`, `float`, `complex`, `str`, `bool` and `None`
    - Recognise the collection types: `list`, `tuple`, `set`, `dict`
    - Check a value's type with `type()` and `isinstance()`
    - Explain mutable vs immutable types

**Prerequisites:** [Variables in Python](02-variables.md)

## What is a Data Type?

A **data type** tells Python **what kind of value** something is, and therefore **what you can do with it**.

!!! example "Real-life analogy: containers in a kitchen"
    You store milk in a bottle, rice in a jar and eggs in a tray. Each container suits its contents. You can pour milk but not eggs, and you can count eggs but not milk.

    Data types work the same way. You can add two numbers, but you can't divide a name by 2.

```python
print(10 + 5)          # numbers: addition
print("10" + "5")      # text: joining
```

```{ .text .output }
15
105
```

The same `+` gives different results because the **data types** are different. `10` is a number; `"10"` is text.

**Python's built-in data types at a glance**

| Category | Type | Example |
|----------|------|---------|
| Numbers | `int` | `25`, `-3`, `1000000` |
| | `float` | `3.14`, `-0.5`, `2.0` |
| | `complex` | `3 + 4j` |
| Text | `str` | `"Hello"`, `'Python'` |
| Boolean | `bool` | `True`, `False` |
| Nothing | `NoneType` | `None` |
| Collections | `list` | `[1, 2, 3]` |
| | `tuple` | `(1, 2, 3)` |
| | `set` | `{1, 2, 3}` |
| | `dict` | `{"name": "Ravi", "age": 22}` |

## Checking the Type

Use the built-in `type()` function:

```python
print(type(25))
print(type(3.14))
print(type("Python"))
print(type(True))
print(type(None))
```

```{ .text .output }
<class 'int'>
<class 'float'>
<class 'str'>
<class 'bool'>
<class 'NoneType'>
```

To **check** whether a value is a certain type, use `isinstance()`. It returns `True` or `False`:

```python
age = 22
print(isinstance(age, int))
print(isinstance(age, str))
```

```{ .text .output }
True
False
```

## Numbers: int, float, complex

### `int`: whole numbers

```python
students = 45
temperature = -5
population = 1_400_000_000    # underscores make big numbers readable

print(population)
print(type(population))
```

```{ .text .output }
1400000000
<class 'int'>
```

Python integers have **no size limit**. They can be as big as your memory allows:

```python
print(2 ** 100)
```

```{ .text .output }
1267650600228229401496703205376
```

### `float`: decimal numbers

```python
price = 499.99
pi = 3.14159
whole = 10.0          # still a float because of the .0

print(type(whole))
print(10 / 2)         # division always gives a float
```

```{ .text .output }
<class 'float'>
5.0
```

!!! mistake "Common Mistake: float precision"
    ```python
    print(0.1 + 0.2)
    ```

    ```{ .text .output }
    0.30000000000000004
    ```

    Computers store decimals in binary, so some values can't be stored exactly. For display, round the result: `round(0.1 + 0.2, 2)` gives `0.3`. For money in real apps, use Python's `decimal` module.

### `complex`: numbers with an imaginary part

```python
z = 3 + 4j
print(z.real, z.imag)
```

```{ .text .output }
3.0 4.0
```

Used mainly in science and engineering. You will rarely need it in web development.

## Text: str

A **string** is text inside quotes. Single and double quotes work the same:

```python
name = "Ravi"
course = 'Full Stack Python'
message = "It's a great day"          # double quotes let you use ' inside
address = """Flat 201,
Madhapur,
Hyderabad"""                          # triple quotes for multiple lines

print(message)
print(address)
```

```{ .text .output }
It's a great day
Flat 201,
Madhapur,
Hyderabad
```

A number inside quotes is **text**, not a number:

```python
print(type("100"))
```

```{ .text .output }
<class 'str'>
```

Strings get a full lesson of their own: [Strings in Python](06-strings.md).

## Boolean: bool

A **boolean** has only two values: `True` or `False` (capital T and F). Booleans answer yes/no questions.

```python
is_logged_in = True
has_paid = False

print(10 > 5)
print(10 == 5)
print(type(is_logged_in))
```

```{ .text .output }
True
False
<class 'bool'>
```

Every value in Python is either "truthy" or "falsy". These are **falsy** (treated as `False`):

```python
print(bool(0), bool(0.0), bool(""), bool([]), bool(None))
print(bool(5), bool("hi"), bool([1]))
```

```{ .text .output }
False False False False False
True True True
```

Rule of thumb: **zero, empty and `None` are falsy; everything else is truthy.** You'll use this a lot in [Conditional Statements](07-conditional-statements.md).

## None: the absence of a value

`None` means "no value yet" or "nothing here". It is not `0`, and it is not an empty string.

```python
middle_name = None
print(middle_name)
print(middle_name is None)
```

```{ .text .output }
None
True
```

!!! realworld "In Real Projects"
    When you fetch a user from a database and the user doesn't exist, functions typically return `None`. Optional form fields (like a middle name) are stored as `None`, and in MySQL that becomes `NULL`.

## Collection Types (Preview)

Collections hold **many values in one variable**. Each has its own lesson later in this module; for now, just recognise them.

```python
skills = ["Python", "SQL", "React"]           # list: ordered, changeable
location = (17.38, 78.48)                     # tuple: ordered, unchangeable
tags = {"python", "backend", "python"}        # set: unique items only
student = {"name": "Priya", "marks": 92}      # dict: key-value pairs

print(type(skills), skills)
print(type(location), location)
print(type(tags), tags)
print(type(student), student)
```

```{ .text .output }
<class 'list'> ['Python', 'SQL', 'React']
<class 'tuple'> (17.38, 78.48)
<class 'set'> {'backend', 'python'}
<class 'dict'> {'name': 'Priya', 'marks': 92}
```

Notice the set removed the duplicate `"python"`. A set's order may also differ on your computer.

| Type | Brackets | Ordered | Changeable | Duplicates |
|------|----------|---------|------------|------------|
| `list` | `[ ]` | ✅ | ✅ | ✅ |
| `tuple` | `( )` | ✅ | ❌ | ✅ |
| `set` | `{ }` | ❌ | ✅ | ❌ |
| `dict` | `{key: value}` | ✅ | ✅ | Keys: ❌ |

## Mutable vs Immutable

- **Mutable** types can be **changed in place** after creation: `list`, `set`, `dict`.
- **Immutable** types **cannot be changed**. Any "change" creates a new object: `int`, `float`, `str`, `bool`, `tuple`, `None`.

```python
name = "ravi"
upper_name = name.upper()   # creates a NEW string
print(name)                 # original unchanged
print(upper_name)

skills = ["Python"]
skills.append("SQL")        # changes the SAME list
print(skills)
```

```{ .text .output }
ravi
RAVI
['Python', 'SQL']
```

Trying to change a string in place fails:

```python
name = "ravi"
name[0] = "R"
```

```{ .text .output }
TypeError: 'str' object does not support item assignment
```

!!! tip "Why this matters"
    Immutable values are safe to share: nobody can change them behind your back. Only immutable values can be dictionary keys or set items. This question also comes up in almost every Python interview.

## Common Mistakes

| Mistake | Error / Result | Fix |
|---------|---------------|-----|
| `"Age: " + 25` | `TypeError: can only concatenate str (not "int") to str` | Convert: `"Age: " + str(25)` or use `print("Age:", 25)` |
| `true` or `TRUE` | `NameError: name 'true' is not defined` | Booleans are `True` / `False` |
| Expecting `10 / 2` to be `5` | Gives `5.0` | `/` always returns float; use `//` for whole-number division |
| `0.1 + 0.2 == 0.3` | `False` | Compare with `round()` or use `decimal` for money |
| Treating `"5"` as a number | `"5" * 2` gives `"55"` | Convert with `int("5")` |
| Thinking `None == 0` | `False` | `None` is its own type; check with `is None` |

## Practice Exercises

**Easy**

1. Create one variable of each type: `int`, `float`, `str`, `bool`, `None`. Print each value with its `type()`.
2. What does `type(7 / 7)` return? Guess first, then run it.
3. Print `bool("")`, `bool(" ")`, `bool(0)` and `bool(-1)`. Explain each result.

**Medium**

4. Use `isinstance()` to check whether `3.0` is an `int`, and whether it's a `float`.
5. Create a list of 3 cities, a tuple of 2 coordinates and a dict with your name and age. Print their types.
6. Why does `print("5" + "5")` give `55` while `print(5 + 5)` gives `10`?

**Challenge**

7. Write a program that stores product details (name, price, in-stock flag, discount which may be missing) using the correct type for each, then prints each value with its type in a neat table using `print()`.

??? success "Solutions (click to expand)"

    ```python
    # 1
    a = 10
    b = 9.5
    c = "Python"
    d = True
    e = None
    print(a, type(a))
    print(b, type(b))
    print(c, type(c))
    print(d, type(d))
    print(e, type(e))

    # 2
    print(type(7 / 7))      # <class 'float'>: / always returns a float

    # 3
    print(bool(""))         # False: empty string
    print(bool(" "))        # True: a space is a character, so not empty
    print(bool(0))          # False: zero
    print(bool(-1))         # True: any non-zero number

    # 4
    print(isinstance(3.0, int))     # False
    print(isinstance(3.0, float))   # True

    # 5
    cities = ["Hyderabad", "Pune", "Chennai"]
    point = (17.38, 78.48)
    me = {"name": "Ravi", "age": 23}
    print(type(cities), type(point), type(me))

    # 6: "5" is a str, so + joins text. 5 is an int, so + adds numbers.

    # 7
    product_name = "Wireless Mouse"
    price = 799.0
    in_stock = True
    discount = None
    print("name     :", product_name, type(product_name))
    print("price    :", price, type(price))
    print("in_stock :", in_stock, type(in_stock))
    print("discount :", discount, type(discount))
    ```

!!! note "Mini Assignment"
    Design the data for a **food delivery order**: order id, customer name, items (a list), total amount, is_paid, delivery_instructions (may be missing) and restaurant location (latitude, longitude as a tuple). Choose the right type for each, store them in variables and print each with `type()`.

## Interview Questions

!!! interview "1. What are the built-in data types in Python?"
    Numeric (`int`, `float`, `complex`), text (`str`), boolean (`bool`), `NoneType`, sequences (`list`, `tuple`, `range`), set types (`set`, `frozenset`), mapping (`dict`) and binary types (`bytes`, `bytearray`).

!!! interview "2. What is the difference between mutable and immutable types?"
    Mutable objects can be changed in place after creation (`list`, `dict`, `set`). Immutable objects cannot; any modification creates a new object (`int`, `float`, `str`, `tuple`, `bool`). Only immutable (hashable) objects can be dict keys or set elements.

!!! interview "3. What is the difference between `type()` and `isinstance()`?"
    `type(x)` returns the exact class of `x`. `isinstance(x, T)` returns `True` if `x` is of type `T` **or a subclass of it**, and accepts a tuple of types. `isinstance()` is preferred for type checks.

!!! interview "4. What is `None`?"
    `None` is a special constant of type `NoneType` that represents the absence of a value. It is falsy, but it is not equal to `0`, `False` or `""`. Check for it with `is None`.

!!! interview "5. Why does `0.1 + 0.2` not equal `0.3`?"
    Floats are stored in binary floating point (IEEE 754), which cannot represent some decimals exactly, so tiny rounding errors appear. Use `round()`, `math.isclose()` or the `decimal` module for exact decimal arithmetic such as money.

!!! interview "Scenario: a price read from a form is `\"499\"` and `price * 2` shows `499499`. What happened?"
    Form input arrives as a **string**. `"499" * 2` repeats the string. Convert it first: `int(price)` or `float(price)`. Type conversion is covered in [Input, Output & Type Conversion](05-input-output-type-conversion.md).

## Summary

| Type | Example | Notes |
|------|---------|-------|
| `int` | `42` | Whole numbers, no size limit |
| `float` | `3.14` | Decimals; `/` always returns float |
| `complex` | `3 + 4j` | Rarely used in web apps |
| `str` | `"hi"` | Text; immutable |
| `bool` | `True` | Only `True` / `False` |
| `None` | `None` | No value; check with `is None` |
| `list` / `tuple` / `set` / `dict` | `[]` `()` `{}` `{k: v}` | Collections, with full lessons ahead |
| `type()` / `isinstance()` | | Check a value's type |
| Mutable | `list`, `dict`, `set` | Can change in place |
| Immutable | `int`, `float`, `str`, `tuple`, `bool` | Changes create new objects |

**Next lesson:** [Operators in Python](04-operators.md), doing maths, comparisons and logic with these values.
