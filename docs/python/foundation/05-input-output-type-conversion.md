---
lesson: true
category: Python Foundation
short: I/O
description: Taking user input with input(), formatting output with print() and f-strings, and converting between data types.
---

# Input, Output & Type Conversion

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Take input from the user with `input()`
    - Convert input into numbers with `int()` and `float()`
    - Control `print()` output with `sep` and `end`
    - Format output neatly using f-strings
    - Explain implicit vs explicit type conversion

**Prerequisites:** [Operators in Python](04-operators.md)

## Taking Input with input()

So far, every value was written inside the code. Real programs ask the **user** for data. Python's `input()` function pauses the program, waits for the user to type something and press ++enter++, and returns what they typed.

```python
name = input("Enter your name: ")
print("Welcome,", name)
```

```{ .text .output }
Enter your name: Priya
Welcome, Priya
```

The text inside `input("...")` is the **prompt**: the message shown to the user. Always end it with a space or `: ` so the user's typing doesn't stick to it.

!!! example "Real-life analogy: a form"
    `input()` is like a single box on a form. The prompt is the label next to the box ("Name:"), and whatever the user writes in the box is returned to your program.

## input() Always Returns a String

This is the **number one beginner bug** in Python.

```python
age = input("Enter your age: ")
print(type(age))
print(age + 1)
```

```{ .text .output }
Enter your age: 22
<class 'str'>
TypeError: can only concatenate str (not "int") to str
```

Even when the user types `22`, `input()` returns the **text** `"22"`, not the number `22`. To do maths, convert it first:

```python
age = int(input("Enter your age: "))
print("Next year you will be", age + 1)
```

```{ .text .output }
Enter your age: 22
Next year you will be 23
```

`int(input(...))` works from the inside out: first `input()` gets the text, then `int()` converts it to a number.

```python
price = float(input("Enter price: "))
quantity = int(input("Enter quantity: "))
print("Total:", price * quantity)
```

```{ .text .output }
Enter price: 249.50
Enter quantity: 4
Total: 998.0
```

!!! mistake "Common Mistake: converting invalid text"
    ```python
    age = int(input("Enter your age: "))
    ```

    ```{ .text .output }
    Enter your age: twenty
    ValueError: invalid literal for int() with base 10: 'twenty'
    ```

    `int()` can only convert text that looks like a whole number. You'll learn to handle this gracefully with `try`/`except` in the Exception Handling lesson.

## Type Conversion

**Type conversion** (also called **type casting**) means changing a value from one type to another.

| Function | Converts to | Example | Result |
|----------|-------------|---------|--------|
| `int()` | Integer | `int("25")`, `int(9.8)` | `25`, `9` |
| `float()` | Float | `float("3.5")`, `float(7)` | `3.5`, `7.0` |
| `str()` | String | `str(100)` | `"100"` |
| `bool()` | Boolean | `bool(0)`, `bool("hi")` | `False`, `True` |
| `list()` | List | `list("abc")` | `['a', 'b', 'c']` |

```python
print(int(9.99))        # cuts off the decimal (does not round)
print(round(9.99))      # rounds
print(int("  42  "))    # spaces around are fine
print(float("1e3"))     # scientific notation
print(str(3.14) + " is pi")
```

```{ .text .output }
9
10
42
1000.0
3.14 is pi
```

!!! mistake "Common Mistake: int() on a decimal string"
    `int("9.5")` fails with `ValueError: invalid literal for int() with base 10: '9.5'`. Convert in two steps: `int(float("9.5"))` gives `9`.

### Implicit vs explicit conversion

- **Explicit** conversion: **you** call a function like `int()` or `str()`.
- **Implicit** conversion: **Python** converts automatically when it's safe.

```python
result = 10 + 2.5      # int + float: Python makes it a float
print(result, type(result))

total = True + 5       # True counts as 1
print(total)
```

```{ .text .output }
12.5 <class 'float'>
6
```

Python **never** implicitly converts between strings and numbers. `"10" + 5` is always an error, because Python can't guess whether you meant `"105"` or `15`.

## Output with print()

You've used `print()` since lesson one. It has two useful options: `sep` and `end`.

### `sep`: what goes between values

By default, `print()` puts a **space** between values:

```python
print("2026", "10", "31")
print("2026", "10", "31", sep="-")
print("Python", "SQL", "React", sep=" | ")
```

```{ .text .output }
2026 10 31
2026-10-31
Python | SQL | React
```

### `end`: what goes at the end

By default, `print()` ends with a **new line** (`\n`). Change it to keep printing on the same line:

```python
print("Loading", end="")
print("...", end="")
print(" done!")
```

```{ .text .output }
Loading... done!
```

### Escape characters

| Code | Meaning |
|------|---------|
| `\n` | New line |
| `\t` | Tab |
| `\\` | A backslash |
| `\"` | A double quote inside a double-quoted string |

```python
print("Name:\tRavi\nCity:\tPune")
print("She said \"Hello\"")
```

```{ .text .output }
Name:	Ravi
City:	Pune
She said "Hello"
```

## Formatting Output with f-strings

Joining text and variables with commas or `+` gets messy quickly. **f-strings** (formatted strings) are the modern, clean way. Put `f` before the quotes and variables inside `{}`:

```python
name = "Kiran"
marks = 87
print(f"{name} scored {marks} marks")
print(f"Percentage: {marks / 100 * 100}%")
```

```{ .text .output }
Kiran scored 87 marks
Percentage: 87.0%
```

You can put **any expression** inside `{}`, including maths and function calls.

### Number formatting

```python
price = 1234567.891

print(f"{price:.2f}")        # 2 decimal places
print(f"{price:,.2f}")       # thousands separator
print(f"{0.856:.1%}")        # as a percentage
print(f"{7:03d}")            # pad with zeros
```

```{ .text .output }
1234567.89
1,234,567.89
85.6%
007
```

### Alignment for tables

```python
print(f"{'Item':<12}{'Qty':>5}{'Price':>10}")
print(f"{'Keyboard':<12}{2:>5}{1499.0:>10.2f}")
print(f"{'Mouse':<12}{1:>5}{599.0:>10.2f}")
```

```{ .text .output }
Item          Qty     Price
Keyboard        2   1499.00
Mouse           1    599.00
```

`<` aligns left, `>` aligns right, `^` centres, and the number is the width.

!!! tip "Debug trick"
    `print(f"{marks=}")` prints `marks=87`, showing both the name and the value. It's very handy when debugging.

!!! realworld "In Real Projects"
    f-strings are used everywhere: log messages (`f"User {user_id} logged in"`), email templates, invoice generation and building messages for APIs. Older code may use `"{}".format(x)` or `"%s" % x`; you should recognise them, but write f-strings.

## A Complete Program

Let's combine everything into a small billing program:

```python
# Simple billing program
customer = input("Customer name: ")
item = input("Item name: ")
price = float(input("Price per unit: "))
qty = int(input("Quantity: "))

subtotal = price * qty
gst = subtotal * 0.18
total = subtotal + gst

print()
print("=" * 30)
print(f"{'INVOICE':^30}")
print("=" * 30)
print(f"Customer : {customer}")
print(f"Item     : {item} x {qty}")
print(f"Subtotal : ₹{subtotal:,.2f}")
print(f"GST 18%  : ₹{gst:,.2f}")
print(f"Total    : ₹{total:,.2f}")
print("=" * 30)
```

```{ .text .output }
Customer name: Anita
Item name: Headphones
Price per unit: 1999
Quantity: 2

==============================
           INVOICE
==============================
Customer : Anita
Item     : Headphones x 2
Subtotal : ₹3,998.00
GST 18%  : ₹719.64
Total    : ₹4,717.64
==============================
```

## Common Mistakes

| Mistake | Error / Result | Fix |
|---------|---------------|-----|
| Doing maths on `input()` directly | `TypeError: can only concatenate str...` | Wrap with `int()` or `float()` |
| `int("9.5")` | `ValueError: invalid literal for int()` | `int(float("9.5"))` |
| `int("")` when user presses Enter | `ValueError` | Validate input before converting |
| Forgetting the `f` in f-strings | Prints `{name}` literally | Write `f"Hello {name}"` |
| `print("Total: " + 500)` | `TypeError` | Use an f-string: `f"Total: {500}"` |
| No space at end of prompt | `Enter name:Ravi` | `input("Enter name: ")` |

## Practice Exercises

**Easy**

1. Ask the user for their name and city, and print `Hi <name> from <city>!` using an f-string.
2. Ask for two numbers and print their sum, difference and product.
3. Print today's date as `31/10/2026` using `print()` with `sep`.

**Medium**

4. Ask for a temperature in Celsius and print it in Fahrenheit, rounded to 1 decimal. (F = C × 9/5 + 32)
5. Ask for the marks of 3 subjects, then print the total and the percentage formatted to 2 decimals.
6. Ask for a number of days and convert it to years, weeks and days (ignore leap years).

**Challenge**

7. Build a **salary slip**: ask for employee name and basic salary. HRA is 20% of basic, DA is 10%, and PF deduction is 12% of basic. Print a neatly aligned slip with gross salary, deductions and net salary, all with thousands separators.

??? success "Solutions (click to expand)"

    ```python
    # 1
    name = input("Name: ")
    city = input("City: ")
    print(f"Hi {name} from {city}!")

    # 2
    a = float(input("First number: "))
    b = float(input("Second number: "))
    print(f"Sum: {a + b}, Difference: {a - b}, Product: {a * b}")

    # 3
    print("31", "10", "2026", sep="/")

    # 4
    c = float(input("Celsius: "))
    f = c * 9 / 5 + 32
    print(f"{c}°C = {f:.1f}°F")

    # 5
    m1 = float(input("Subject 1: "))
    m2 = float(input("Subject 2: "))
    m3 = float(input("Subject 3: "))
    total = m1 + m2 + m3
    print(f"Total: {total}, Percentage: {total / 300 * 100:.2f}%")

    # 6
    days = int(input("Days: "))
    years = days // 365
    weeks = (days % 365) // 7
    remaining = (days % 365) % 7
    print(f"{years} years, {weeks} weeks, {remaining} days")

    # 7
    name = input("Employee name: ")
    basic = float(input("Basic salary: "))
    hra = basic * 0.20
    da = basic * 0.10
    pf = basic * 0.12
    gross = basic + hra + da
    net = gross - pf
    print("-" * 32)
    print(f"{'SALARY SLIP':^32}")
    print("-" * 32)
    print(f"{'Employee':<14}{name:>18}")
    print(f"{'Basic':<14}{basic:>18,.2f}")
    print(f"{'HRA (20%)':<14}{hra:>18,.2f}")
    print(f"{'DA (10%)':<14}{da:>18,.2f}")
    print(f"{'Gross':<14}{gross:>18,.2f}")
    print(f"{'PF (12%)':<14}{-pf:>18,.2f}")
    print("-" * 32)
    print(f"{'Net Salary':<14}{net:>18,.2f}")
    ```

!!! note "Mini Assignment"
    Write `bmi.py` that asks for name, weight (kg) and height (cm), calculates BMI (`weight / (height_in_metres ** 2)`), and prints a neat report card with the BMI rounded to 1 decimal. You'll add the "Underweight / Normal / Overweight" label after the Conditional Statements lesson.

## Interview Questions

!!! interview "1. What does `input()` return?"
    Always a **string** (`str`), whatever the user types. Convert it with `int()`, `float()` etc. before using it as a number.

!!! interview "2. What is the difference between implicit and explicit type conversion?"
    Implicit conversion is done automatically by Python when it's safe, e.g. `int + float → float`. Explicit conversion (casting) is done by the programmer with functions like `int()`, `float()`, `str()`.

!!! interview "3. What are f-strings and why are they preferred?"
    Formatted string literals (Python 3.6+), written as `f"...{expr}..."`. They are more readable than `%` formatting or `.format()`, support any expression and format specifiers like `{x:.2f}`, and are also the fastest of the three.

!!! interview "4. What do `sep` and `end` do in `print()`?"
    `sep` sets the separator between multiple values (default: a space). `end` sets what is printed after the last value (default: a newline `\n`).

!!! interview "5. What does `int(7.9)` return?"
    `7`. `int()` truncates towards zero; it doesn't round. Use `round(7.9)` to get `8`.

!!! interview "Scenario: a user enters `\"1,500\"` as a price and `float()` fails. How do you fix it?"
    Remove the comma before converting: `float(price.replace(",", ""))`. In real apps, validate and clean all user input before converting it.

## Summary

| Concept | Remember |
|---------|----------|
| `input("prompt: ")` | Waits for the user; **always returns a string** |
| Conversion | `int()`, `float()`, `str()`, `bool()`, `list()` |
| `int(9.8)` | `9`: truncates, doesn't round |
| Implicit | `int + float → float`; never `str + int` |
| `print(sep=, end=)` | Control the separator and the line ending |
| Escapes | `\n` new line, `\t` tab |
| f-strings | `f"{name} has {marks}"`, `{x:.2f}`, `{x:,}`, `{x:>10}` |

**Next lesson:** [Strings in Python](06-strings.md), slicing, searching and transforming text.
