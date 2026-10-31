---
lesson: true
category: Functions & Modules
short: Functions
description: Defining and calling functions, parameters, return values, docstrings and variable scope in Python.
---

# Functions

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain what a function is and why programs are built from functions
    - Define and call your own functions
    - Pass data in with parameters and get results out with `return`
    - Document functions with docstrings
    - Explain local and global scope

**Prerequisites:** The [Python Foundation](../foundation/index.md) module, especially [Loops](../foundation/08-loops.md) and [Lists](../foundation/09-lists.md).

## What is a Function?

A **function** is a named block of code that does one job. You write it once and **call** it whenever you need that job done.

You've already used many built-in functions:

```python
print("Hello")
print(len("Python"))
print(max([4, 9, 2]))
print(round(3.14159, 2))
```

```{ .text .output }
Hello
6
9
3.14
```

Someone at Python wrote the code for `len()` once, and millions of programmers call it every day without knowing how it works inside. In this lesson you'll write **your own** functions.

!!! example "Real-life analogy: a mixer grinder"
    You put ingredients **in** (inputs), press a button, and get chutney **out** (output). You don't rebuild the grinder every time you cook; you reuse it. A function is the same: inputs go in, it does its job, and a result comes out.

## Why Use Functions?

Without functions, the same logic gets copy-pasted:

```python
# Calculating GST in three places, copy-pasted
price1 = 1000
print("Total:", price1 + price1 * 0.18)

price2 = 2500
print("Total:", price2 + price2 * 0.18)

price3 = 499
print("Total:", price3 + price3 * 0.18)
```

If the GST rate changes to 12%, you must find and fix **every** copy. With a function, you fix it in **one** place:

```python
def total_with_gst(price):
    return round(price + price * 0.18, 2)

print("Total:", total_with_gst(1000))
print("Total:", total_with_gst(2500))
print("Total:", total_with_gst(499))
```

```{ .text .output }
Total: 1180.0
Total: 2950.0
Total: 588.82
```

| Benefit | Meaning |
|---------|---------|
| **Reuse** | Write once, use many times |
| **Readability** | `send_welcome_email(user)` explains itself |
| **Easy fixes** | A bug is fixed in one place |
| **Testing** | Each function can be tested on its own |
| **Teamwork** | Different developers can work on different functions |

The principle is called **DRY**: **D**on't **R**epeat **Y**ourself.

## Defining and Calling a Function

```python
def greet():
    print("Welcome to Kasi Yedumati · Full Stack Training!")
    print("Let's learn Python.")

greet()
greet()
```

```{ .text .output }
Welcome to Kasi Yedumati · Full Stack Training!
Let's learn Python.
Welcome to Kasi Yedumati · Full Stack Training!
Let's learn Python.
```

**Anatomy of a function**

```python
def greet():        # def keyword, function name, parentheses, colon
    print("Hi")     # body: indented 4 spaces
```

| Part | Meaning |
|------|---------|
| `def` | Keyword that starts a function **definition** |
| `greet` | The function's name (snake_case, usually a verb: `calculate_total`, `send_email`) |
| `()` | Parentheses for parameters (empty here) |
| `:` | Starts the body |
| Indented block | The code that runs when the function is called |

**Defining** a function only creates it; nothing runs yet. The body runs only when you **call** it with `greet()`.

!!! mistake "Common Mistake: calling before defining"
    ```python
    greet()

    def greet():
        print("Hi")
    ```

    ```{ .text .output }
    NameError: name 'greet' is not defined
    ```

    Python reads top to bottom. Define the function first, then call it.

!!! mistake "Common Mistake: forgetting the parentheses"
    `greet` (without `()`) doesn't call the function; it just refers to it. `print(greet)` shows something like `<function greet at 0x10...>`. Always write `greet()` to run it.

## Parameters and Arguments

**Parameters** are the input variables in the definition. **Arguments** are the actual values you pass when calling.

```python
def greet(name):              # name is a PARAMETER
    print(f"Hello, {name}!")

greet("Priya")                # "Priya" is an ARGUMENT
greet("Ravi")
```

```{ .text .output }
Hello, Priya!
Hello, Ravi!
```

Multiple parameters are separated by commas, and arguments are matched **in order**:

```python
def introduce(name, course, city):
    print(f"I am {name}, learning {course} in {city}.")

introduce("Kiran", "Full Stack Python", "Pune")
```

```{ .text .output }
I am Kiran, learning Full Stack Python in Pune.
```

Passing the wrong number of arguments is an error:

```python
introduce("Kiran", "Python")
```

```{ .text .output }
TypeError: introduce() missing 1 required positional argument: 'city'
```

The next lesson, [Arguments & Return Values](02-arguments-and-return-values.md), covers keyword arguments, default values, `*args` and `**kwargs`.

## Returning Values

`print()` inside a function only **shows** a value on screen. `return` **sends the value back** to the caller so the program can use it.

```python
def area_of_rectangle(length, width):
    return length * width

a = area_of_rectangle(10, 4)
b = area_of_rectangle(5, 3)

print("Total area:", a + b)
```

```{ .text .output }
Total area: 55
```

### `print` vs `return`

=== "Using print (can't reuse the result)"

    ```python
    def add(a, b):
        print(a + b)

    result = add(2, 3)
    print("Result is", result)
    ```

    ```{ .text .output }
    5
    Result is None
    ```

=== "Using return (result can be reused)"

    ```python
    def add(a, b):
        return a + b

    result = add(2, 3)
    print("Result is", result)
    ```

    ```{ .text .output }
    Result is 5
    ```

A function without a `return` statement returns `None` automatically.

!!! tip "Rule of thumb"
    Functions that **calculate** something should `return` it. Let the caller decide whether to print it, save it to a database or send it in an API response.

`return` also **ends the function immediately**. Any code after it doesn't run:

```python
def check_age(age):
    if age < 0:
        return "Invalid age"
    if age >= 18:
        return "Adult"
    return "Minor"

print(check_age(25))
print(check_age(12))
print(check_age(-3))
```

```{ .text .output }
Adult
Minor
Invalid age
```

## Docstrings

A **docstring** is a string written as the first line of a function to explain what it does. It's documentation that lives inside the code.

```python
def calculate_emi(principal, annual_rate, months):
    """Return the monthly EMI for a loan.

    principal: loan amount in rupees
    annual_rate: yearly interest rate in percent, e.g. 10.5
    months: loan tenure in months
    """
    r = annual_rate / 12 / 100
    return principal * r * (1 + r) ** months / ((1 + r) ** months - 1)

print(round(calculate_emi(500000, 10, 36), 2))
print(calculate_emi.__doc__.splitlines()[0])
```

```{ .text .output }
16133.59
Return the monthly EMI for a loan.
```

VS Code shows the docstring when you hover over the function name, and `help(calculate_emi)` prints it in the REPL.

!!! realworld "In Real Projects"
    In Django and FastAPI projects, each **view** or **API endpoint** is a function. FastAPI even reads your docstrings and shows them in the auto-generated API documentation that frontend developers use.

## Variable Scope

**Scope** is the region of code where a variable can be used.

- A variable created **inside** a function is **local**: it exists only while the function runs.
- A variable created **outside** all functions is **global**: it can be read anywhere.

```python
company = "Kasi Yedumati Training"   # global

def show_details():
    course = "Full Stack Python"   # local
    print(company, "-", course)    # can READ the global

show_details()
print(course)
```

```{ .text .output }
Kasi Yedumati Training - Full Stack Python
NameError: name 'course' is not defined
```

`course` disappeared when `show_details()` finished.

### Same name, different variables

```python
count = 10

def update():
    count = 99              # creates a NEW local variable
    print("Inside:", count)

update()
print("Outside:", count)
```

```{ .text .output }
Inside: 99
Outside: 10
```

### The `global` keyword

To **change** a global variable inside a function, declare it with `global`:

```python
visitors = 0

def new_visit():
    global visitors
    visitors += 1

new_visit()
new_visit()
print(visitors)
```

```{ .text .output }
2
```

Without `global`, `visitors += 1` would raise `UnboundLocalError: cannot access local variable 'visitors' where it is not associated with a value`.

!!! tip "Avoid `global` in real code"
    Functions that secretly change global variables are hard to test and debug. Prefer passing values in as **parameters** and getting results back with **return**:

    ```python
    def new_visit(visitors):
        return visitors + 1

    visitors = 0
    visitors = new_visit(visitors)
    ```

Python looks up names in the **LEGB** order: **L**ocal → **E**nclosing (a function inside a function) → **G**lobal → **B**uilt-in (like `print`, `len`).

## Common Mistakes

| Mistake | Error / Result | Fix |
|---------|---------------|-----|
| Calling before defining | `NameError: name 'x' is not defined` | Define functions at the top |
| `greet` instead of `greet()` | Function not called | Add parentheses |
| Wrong number of arguments | `TypeError: f() missing 1 required positional argument` | Match the parameters |
| Using `print` instead of `return` | Caller gets `None` | `return` the value |
| Code after `return` | Never runs | Move it before `return` |
| Changing a global without `global` | `UnboundLocalError` | Pass it as a parameter and return the new value |
| Missing colon or indentation | `SyntaxError` / `IndentationError` | `def f():` + 4-space indented body |

## Practice Exercises

**Easy**

1. Write a function `square(n)` that returns `n * n`. Print the squares of 3, 7 and 12.
2. Write `is_even(n)` that returns `True` or `False`.
3. Write `greet_student(name, course)` that **returns** a welcome message string. Print it for two students.

**Medium**

4. Write `celsius_to_fahrenheit(c)` and `fahrenheit_to_celsius(f)`. Test that converting 37 °C there and back gives 37.
5. Write `get_grade(marks)` that returns `"A"`, `"B"`, `"C"`, `"D"` or `"F"` using the grading rules from the Conditions lesson.
6. Write `count_vowels(text)` that returns the number of vowels in a string.

**Challenge**

7. Write three functions: `calculate_subtotal(prices)` returns the sum of a list of prices; `calculate_discount(subtotal)` returns a 10% discount if the subtotal is above ₹2000, otherwise 0; `calculate_total(prices)` uses the other two plus 18% GST on the discounted amount. Print a bill for `[1200, 850, 399]`.

??? success "Solutions (click to expand)"

    ```python
    # 1
    def square(n):
        return n * n

    print(square(3), square(7), square(12))       # 9 49 144

    # 2
    def is_even(n):
        return n % 2 == 0

    print(is_even(10), is_even(7))                # True False

    # 3
    def greet_student(name, course):
        return f"Welcome {name}! Enjoy learning {course}."

    print(greet_student("Asha", "Python"))
    print(greet_student("Ravi", "React"))

    # 4
    def celsius_to_fahrenheit(c):
        return c * 9 / 5 + 32

    def fahrenheit_to_celsius(f):
        return (f - 32) * 5 / 9

    print(celsius_to_fahrenheit(37))                         # 98.6
    print(round(fahrenheit_to_celsius(celsius_to_fahrenheit(37)), 2))   # 37.0

    # 5
    def get_grade(marks):
        if marks >= 90:
            return "A"
        if marks >= 75:
            return "B"
        if marks >= 60:
            return "C"
        if marks >= 35:
            return "D"
        return "F"

    print(get_grade(82), get_grade(30))           # B F

    # 6
    def count_vowels(text):
        count = 0
        for ch in text.lower():
            if ch in "aeiou":
                count += 1
        return count

    print(count_vowels("Full Stack Python"))      # 3

    # 7
    def calculate_subtotal(prices):
        return sum(prices)

    def calculate_discount(subtotal):
        return subtotal * 0.10 if subtotal > 2000 else 0

    def calculate_total(prices):
        subtotal = calculate_subtotal(prices)
        discount = calculate_discount(subtotal)
        gst = (subtotal - discount) * 0.18
        return subtotal - discount + gst

    cart = [1200, 850, 399]
    print("Subtotal:", calculate_subtotal(cart))                     # 2449
    print("Discount:", calculate_discount(calculate_subtotal(cart)))  # 244.9
    print("Total   :", round(calculate_total(cart), 2))              # 2600.84
    ```

!!! note "Mini Assignment"
    Refactor the `student_manager.py` capstone from the Python Foundation module into functions: `add_student()`, `add_marks()`, `calculate_percentage(marks)`, `get_grade(percentage)`, `show_report(roll_no)` and `main()` (the menu loop). Each function should do **one** job, and calculation functions must `return` values instead of printing.

## Interview Questions

!!! interview "1. What is a function and why do we use it?"
    A function is a named, reusable block of code that performs a specific task. Functions avoid code duplication (DRY), make programs readable and modular, and let each piece be tested and maintained independently.

!!! interview "2. What is the difference between a parameter and an argument?"
    A parameter is the variable listed in the function definition (`def greet(name)`). An argument is the actual value passed when calling it (`greet("Ravi")`).

!!! interview "3. What does a function return if it has no `return` statement?"
    `None`.

!!! interview "4. What is the difference between `print` and `return` in a function?"
    `print` only displays a value on the screen. `return` sends a value back to the caller, which can store it, use it in calculations or pass it to another function. `return` also ends the function.

!!! interview "5. What is the LEGB rule?"
    The order in which Python looks up a name: **L**ocal (inside the current function), **E**nclosing (outer functions), **G**lobal (module level), then **B**uilt-in (like `len`, `print`).

!!! interview "Scenario: a teammate's function prints the correct total, but the variable that stores its result is `None`. What's wrong?"
    The function uses `print(total)` instead of `return total`. Without a return statement the function returns `None`. Replace the print with a return, and print at the call site if needed.

## Summary

| Concept | Remember |
|---------|----------|
| Define | `def name(params):` + indented body |
| Call | `name(args)`; define before calling |
| Parameters / Arguments | Variables in the definition / values passed in |
| `return` | Sends a value back and ends the function; default is `None` |
| `print` vs `return` | Show vs give back; calculation functions should return |
| Docstring | `"""Explain what it does."""` as the first line |
| Local scope | Variables inside a function vanish after it ends |
| `global` | Lets a function change a global; avoid it |
| LEGB | Local → Enclosing → Global → Built-in |

**Next lesson:** [Arguments & Return Values](02-arguments-and-return-values.md), with keyword and default arguments, `*args`, `**kwargs` and returning multiple values.
