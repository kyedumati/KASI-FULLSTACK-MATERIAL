---
lesson: true
category: Python Foundation
short: Operators
description: Arithmetic, comparison, logical, assignment, membership and identity operators in Python, plus operator precedence.
---

# Operators in Python

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Do calculations with arithmetic operators, including `//`, `%` and `**`
    - Compare values with comparison operators
    - Combine conditions with `and`, `or`, `not`
    - Use membership (`in`) and identity (`is`) operators
    - Predict results using operator precedence

**Prerequisites:** [Data Types in Python](03-data-types.md)

## What is an Operator?

An **operator** is a symbol that performs an action on values. The values it works on are called **operands**.

```python
result = 10 + 5
#        ^^ ^ ^
#  operand  |  operand
#        operator
```

!!! example "Real-life analogy: a calculator"
    The buttons `+ − × ÷` on a calculator are operators. The numbers you type are operands. Python has the same buttons, plus extra ones for comparing values and making decisions.

| Category | Operators | Used for |
|----------|-----------|----------|
| Arithmetic | `+ - * / // % **` | Maths |
| Comparison | `== != > < >= <=` | Comparing values (gives `True`/`False`) |
| Logical | `and or not` | Combining conditions |
| Assignment | `= += -= *= /= //= %= **=` | Storing values |
| Membership | `in`, `not in` | Checking if a value is inside a collection |
| Identity | `is`, `is not` | Checking if two names point to the same object |

## Arithmetic Operators

```python
a = 17
b = 5

print("Addition       :", a + b)
print("Subtraction    :", a - b)
print("Multiplication :", a * b)
print("Division       :", a / b)
print("Floor division :", a // b)
print("Modulus        :", a % b)
print("Exponent       :", a ** 2)
```

```{ .text .output }
Addition       : 22
Subtraction    : 12
Multiplication : 85
Division       : 3.4
Floor division : 3
Modulus        : 2
Exponent       : 289
```

The three that confuse beginners:

| Operator | Name | What it gives | `17 ? 5` |
|----------|------|---------------|----------|
| `/` | Division | Exact answer, **always a float** | `3.4` |
| `//` | Floor division | Whole part only (rounded **down**) | `3` |
| `%` | Modulus | The **remainder** | `2` |

!!! example "Real-life analogy: sharing chocolates"
    17 chocolates shared among 5 friends: each friend gets `17 // 5 = 3`, and `17 % 5 = 2` are left over.

### Practical uses of `%` and `//`

```python
# Is a number even or odd?
number = 14
print(number % 2 == 0)        # True means even

# Convert 135 minutes to hours and minutes
minutes = 135
print(minutes // 60, "hours", minutes % 60, "minutes")

# Last digit of a number
print(4729 % 10)
```

```{ .text .output }
True
2 hours 15 minutes
9
```

!!! realworld "In Real Projects"
    Pagination on websites like Amazon uses these operators. With 95 products and 10 per page: the number of full pages is `95 // 10 = 9`, and `95 % 10 = 5` products go on the last page, so there are 10 pages.

### Arithmetic with strings and lists

`+` joins and `*` repeats:

```python
print("Py" + "thon")
print("-" * 20)
print([1, 2] + [3])
```

```{ .text .output }
Python
--------------------
[1, 2, 3]
```

## Comparison Operators

Comparison operators compare two values and always return a **boolean** (`True` or `False`).

```python
marks = 72

print(marks == 72)    # equal to
print(marks != 72)    # not equal to
print(marks > 35)     # greater than
print(marks < 35)     # less than
print(marks >= 72)    # greater than or equal to
print(marks <= 50)    # less than or equal to
```

```{ .text .output }
True
False
True
False
True
False
```

Python lets you **chain** comparisons, just like in maths:

```python
age = 25
print(18 <= age <= 60)
```

```{ .text .output }
True
```

Strings are compared alphabetically (by character code), and case matters:

```python
print("apple" < "banana")
print("Apple" == "apple")
```

```{ .text .output }
True
False
```

!!! mistake "Common Mistake: `=` vs `==`"
    `=` **assigns** a value. `==` **compares** two values.

    ```python
    if marks = 72:
        print("Equal")
    ```

    ```{ .text .output }
    SyntaxError: invalid syntax. Maybe you meant '==' or ':=' instead of '='?
    ```

    Use `if marks == 72:`

## Logical Operators

Logical operators combine conditions.

| Operator | Result is `True` when | Example |
|----------|-----------------------|---------|
| `and` | **both** sides are true | `age >= 18 and has_id` |
| `or` | **at least one** side is true | `is_admin or is_owner` |
| `not` | the condition is false | `not is_blocked` |

```python
age = 22
has_id = True
is_blocked = False

print(age >= 18 and has_id)       # both true
print(age >= 60 or has_id)        # one is true
print(not is_blocked)             # flips False to True
```

```{ .text .output }
True
True
True
```

**Truth table**

| A | B | `A and B` | `A or B` | `not A` |
|---|---|-----------|----------|---------|
| True | True | True | True | False |
| True | False | False | True | False |
| False | True | False | True | True |
| False | False | False | False | True |

!!! realworld "In Real Projects"
    A login check is logical operators in action: `if email_exists and password_correct and not account_locked:` allow the user in.

### Short-circuit evaluation

Python stops evaluating as soon as it knows the answer:

- `False and ...` is always `False`, so the right side is **not checked**.
- `True or ...` is always `True`, so the right side is **not checked**.

```python
items = []
print(len(items) > 0 and items[0] == "pen")
```

```{ .text .output }
False
```

Without short-circuiting, `items[0]` would crash on an empty list. Because the left side is `False`, Python never evaluates it.

## Assignment Operators

You met these in [Variables](02-variables.md). They update a variable using its current value.

```python
x = 10
x += 5     # 15
x -= 3     # 12
x *= 2     # 24
x //= 5    # 4
x **= 3    # 64
x %= 10    # 4
print(x)
```

```{ .text .output }
4
```

Python has no `++` or `--`. Use `x += 1` and `x -= 1`.

## Membership and Identity Operators

### Membership: `in`, `not in`

Checks whether a value exists inside a string, list, tuple, set or dict (keys).

```python
skills = ["Python", "SQL", "React"]

print("SQL" in skills)
print("Java" not in skills)
print("thon" in "Python")
```

```{ .text .output }
True
True
True
```

### Identity: `is`, `is not`

Checks whether two names point to the **same object in memory**, not just equal values.

```python
a = [1, 2, 3]
b = [1, 2, 3]
c = a

print(a == b)    # same values?
print(a is b)    # same object?
print(a is c)
```

```{ .text .output }
True
False
True
```

!!! tip "When to use `is`"
    Use `is` almost only for `None`: `if value is None:`. For comparing values, always use `==`.

## Operator Precedence

When an expression has several operators, Python follows an order, like BODMAS in maths.

| Priority | Operators |
|----------|-----------|
| 1 (highest) | `()` parentheses |
| 2 | `**` exponent |
| 3 | `+x`, `-x` (unary plus/minus) |
| 4 | `*`, `/`, `//`, `%` |
| 5 | `+`, `-` |
| 6 | Comparisons `==`, `!=`, `>`, `<`, `>=`, `<=`, `in`, `is` |
| 7 | `not` |
| 8 | `and` |
| 9 (lowest) | `or` |

```python
print(10 + 2 * 3)
print((10 + 2) * 3)
print(2 ** 3 ** 2)       # ** goes right to left: 2 ** 9
print(-3 ** 2)           # ** before unary minus: -(3 ** 2)
```

```{ .text .output }
16
36
512
-9
```

!!! tip "When in doubt, use parentheses"
    `(a + b) * c` is clearer than relying on memory. Readable code beats clever code.

## Common Mistakes

| Mistake | Result | Fix |
|---------|--------|-----|
| `if x = 5:` | `SyntaxError` | Use `==` for comparison |
| Expecting `7 / 2` to be `3` | Gives `3.5` | Use `//` for whole-number division |
| `x++` | `SyntaxError: invalid syntax` | Use `x += 1` |
| `10 / 0` | `ZeroDivisionError: division by zero` | Check the divisor before dividing |
| Using `is` to compare numbers or strings | Sometimes works, sometimes not | Use `==` for values; `is` only for `None` |
| `"Total: " + 100` | `TypeError` | `"Total: " + str(100)` |
| `-7 // 2` expected `-3` | Gives `-4` | `//` rounds **down** (towards negative infinity) |

## Practice Exercises

**Easy**

1. Given `a = 25` and `b = 4`, print the result of all seven arithmetic operators.
2. Check whether 1234 is even or odd using `%`.
3. Print `True` if `age = 17` is between 13 and 19 (inclusive), using a chained comparison.

**Medium**

4. Convert 3725 seconds into hours, minutes and seconds.
5. Given `num = 5823`, print the sum of its first and last digits using `//` and `%`.
6. A user can watch a movie if `age >= 18` **or** `has_parent_permission` is `True`, **and** `ticket_booked` is `True`. Write the expression and test it with different values.

**Challenge**

7. A restaurant bill is 1850. Add 5% GST, then split the total equally among 4 friends. Print each person's share rounded to 2 decimals. If each friend pays only whole rupees (use `//`), how much of the bill is left unpaid?

??? success "Solutions (click to expand)"

    ```python
    # 1
    a, b = 25, 4
    print(a + b, a - b, a * b, a / b, a // b, a % b, a ** b)
    # 29 21 100 6.25 6 1 390625

    # 2
    print("Even" if 1234 % 2 == 0 else "Odd")   # Even

    # 3
    age = 17
    print(13 <= age <= 19)                      # True

    # 4
    total = 3725
    hours = total // 3600
    minutes = (total % 3600) // 60
    seconds = total % 60
    print(hours, "h", minutes, "m", seconds, "s")   # 1 h 2 m 5 s

    # 5
    num = 5823
    last = num % 10        # 3
    first = num // 1000    # 5
    print(first + last)    # 8

    # 6
    age = 16
    has_parent_permission = True
    ticket_booked = True
    print((age >= 18 or has_parent_permission) and ticket_booked)   # True

    # 7
    bill = 1850
    total = bill + bill * 5 / 100          # 1942.5
    share = total / 4
    print("Each pays:", round(share, 2))   # Each pays: 485.62
    whole = total // 4                     # 485.0 rupees each, paid in whole rupees
    print("Left over:", total - whole * 4) # Left over: 2.5
    ```

!!! note "Mini Assignment"
    Write `emi.py`: for a loan of 5,00,000 at 10% simple interest per year for 3 years, calculate the total interest, total payable amount and monthly EMI. Then print whether the EMI is affordable for someone whose salary is 40,000, if the EMI must be **at most 40%** of salary.

## Interview Questions

!!! interview "1. What is the difference between `/` and `//`?"
    `/` is true division and always returns a float (`7 / 2 = 3.5`). `//` is floor division; it returns the largest whole number less than or equal to the result (`7 // 2 = 3`, `-7 // 2 = -4`). With two ints it returns an int.

!!! interview "2. What is the difference between `==` and `is`?"
    `==` checks whether two values are **equal**. `is` checks whether two names refer to the **same object** in memory. Two separate lists with the same items are `==` but not `is`. Use `is` mainly for `None`.

!!! interview "3. What is short-circuit evaluation?"
    In `A and B`, if `A` is false, `B` is not evaluated. In `A or B`, if `A` is true, `B` is not evaluated. This avoids unnecessary work and prevents errors, e.g. `items and items[0]`.

!!! interview "4. Does Python support `++` and `--`?"
    No. Use `x += 1` and `x -= 1`. `++x` is valid syntax but just means `+(+x)`, which doesn't change `x`.

!!! interview "5. What does `2 ** 3 ** 2` return and why?"
    `512`. The exponent operator is **right-associative**, so it is evaluated as `2 ** (3 ** 2) = 2 ** 9`.

!!! interview "Scenario: how would you check if a year is a leap year using operators?"
    `(year % 4 == 0 and year % 100 != 0) or year % 400 == 0`. Divisible by 4 but not by 100, unless also divisible by 400.

## Summary

| Category | Key points |
|----------|------------|
| Arithmetic | `/` gives a float, `//` whole part (rounded down), `%` remainder, `**` power |
| Comparison | `== != > < >= <=` return `True`/`False`; can be chained (`1 < x < 10`) |
| Logical | `and` (both), `or` (either), `not` (flip); short-circuit evaluation |
| Assignment | `+= -= *= /= //= %= **=`; no `++` |
| Membership | `in`, `not in` |
| Identity | `is`, `is not`, mainly for `None` |
| Precedence | `()` → `**` → `* / // %` → `+ -` → comparisons → `not` → `and` → `or` |

**Next lesson:** [Input, Output & Type Conversion](05-input-output-type-conversion.md), taking input from the user.
