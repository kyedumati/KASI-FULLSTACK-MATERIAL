---
lesson: true
category: Python Foundation
short: Loops
description: Repeating work in Python with for and while loops, range(), break, continue, loop-else and nested loops.
---

# Loops in Python

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Repeat code with `for` and `while` loops
    - Generate number sequences with `range()`
    - Control loops with `break`, `continue` and `else`
    - Write nested loops for patterns and tables
    - Use common loop patterns: counting, summing, searching

**Prerequisites:** [Conditional Statements](07-conditional-statements.md)

## Why Do We Need Loops?

Print "Welcome" 5 times without a loop:

```python
print("Welcome")
print("Welcome")
print("Welcome")
print("Welcome")
print("Welcome")
```

Now imagine 1,000 times, or sending an email to each of 50,000 customers. A **loop** repeats a block of code as many times as needed.

```python
for i in range(5):
    print("Welcome")
```

!!! example "Real-life analogy: a playlist"
    A `for` loop is like playing **every song in a playlist**, one after another: you know exactly what's coming. A `while` loop is like **"keep playing songs until I say stop"**: you don't know in advance how many.

| Loop | Use when |
|------|----------|
| `for` | You know **what** to go through (a list, a string, a range of numbers) |
| `while` | You repeat **until a condition changes** (user enters "quit", balance runs out) |

## The for Loop

A `for` loop takes each item from a sequence, one at a time:

```python
skills = ["Python", "SQL", "Django", "React"]

for skill in skills:
    print(f"I am learning {skill}")
```

```{ .text .output }
I am learning Python
I am learning SQL
I am learning Django
I am learning React
```

On each round (called an **iteration**), the variable `skill` holds the next item. You can name it anything, but choose a meaningful name: `for student in students`, `for order in orders`.

Strings are sequences too:

```python
for letter in "KSR":
    print(letter)
```

```{ .text .output }
K
S
R
```

## The range() Function

`range()` generates a sequence of numbers: `range(start, stop, step)`. Like slicing, **stop is not included**.

| Code | Numbers produced |
|------|------------------|
| `range(5)` | 0, 1, 2, 3, 4 |
| `range(1, 6)` | 1, 2, 3, 4, 5 |
| `range(0, 11, 2)` | 0, 2, 4, 6, 8, 10 |
| `range(10, 0, -1)` | 10, 9, 8, …, 1 |

```python
for i in range(1, 6):
    print(f"5 x {i} = {5 * i}")
```

```{ .text .output }
5 x 1 = 5
5 x 2 = 10
5 x 3 = 15
5 x 4 = 20
5 x 5 = 25
```

```python
for n in range(10, 0, -3):
    print(n, end=" ")
```

```{ .text .output }
10 7 4 1
```

### Getting the index with `enumerate()`

When you need both the position and the item:

```python
students = ["Asha", "Ravi", "Kiran"]

for position, name in enumerate(students, start=1):
    print(f"{position}. {name}")
```

```{ .text .output }
1. Asha
2. Ravi
3. Kiran
```

## The while Loop

A `while` loop repeats **as long as its condition is True**.

```python
count = 1

while count <= 5:
    print("Count:", count)
    count += 1

print("Done")
```

```{ .text .output }
Count: 1
Count: 2
Count: 3
Count: 4
Count: 5
Done
```

Every `while` loop needs three parts:

1. **Initialise** a variable before the loop (`count = 1`)
2. **Check** a condition (`count <= 5`)
3. **Update** the variable inside the loop (`count += 1`)

!!! mistake "Common Mistake: infinite loop"
    ```python
    count = 1
    while count <= 5:
        print(count)
        # forgot count += 1
    ```

    `count` stays `1` forever, so the loop never ends. Press ++ctrl+c++ in the terminal to stop it, then add the update step.

`while` shines when you **don't know** how many repetitions are needed:

```python
balance = 1000
months = 0

while balance < 2000:
    balance = balance * 1.10      # 10% growth per month
    months += 1

print(f"Doubled in {months} months: ₹{balance:.2f}")
```

```{ .text .output }
Doubled in 8 months: ₹2143.59
```

## break, continue and else

### `break`: exit the loop immediately

```python
numbers = [4, 9, 15, 22, 31]

for n in numbers:
    if n > 20:
        print("Found first number above 20:", n)
        break
    print("Checked", n)
```

```{ .text .output }
Checked 4
Checked 9
Checked 15
Found first number above 20: 22
```

### `continue`: skip to the next round

```python
for i in range(1, 11):
    if i % 3 == 0:
        continue          # skip multiples of 3
    print(i, end=" ")
```

```{ .text .output }
1 2 4 5 7 8 10
```

### Loop `else`: runs if the loop was NOT broken

```python
users = ["asha", "ravi", "kiran"]
search = "meena"

for user in users:
    if user == search:
        print("User found")
        break
else:
    print("User not found")
```

```{ .text .output }
User not found
```

The `else` block runs only when the loop finishes **without** hitting `break`. It's perfect for "search and report if not found".

### A real menu loop: `while True` + `break`

```python
while True:
    choice = input("Enter command (add/list/quit): ").lower()
    if choice == "quit":
        print("Goodbye!")
        break
    elif choice == "add":
        print("Adding item...")
    elif choice == "list":
        print("Listing items...")
    else:
        print("Invalid command")
```

```{ .text .output }
Enter command (add/list/quit): add
Adding item...
Enter command (add/list/quit): hello
Invalid command
Enter command (add/list/quit): quit
Goodbye!
```

!!! realworld "In Real Projects"
    Servers run on a `while True` loop: they wait for a request, handle it, and repeat forever. Retry logic ("try connecting to the database up to 3 times") is a loop with `break` on success.

## Nested Loops

A loop inside a loop. The inner loop runs **completely** for every single round of the outer loop.

```python
for row in range(1, 4):
    for col in range(1, 4):
        print(f"{row * col:3}", end="")
    print()
```

```{ .text .output }
  1  2  3
  2  4  6
  3  6  9
```

### Star patterns (interview favourite)

```python
n = 4
for i in range(1, n + 1):
    print("* " * i)
```

```{ .text .output }
*
* *
* * *
* * * *
```

```python
n = 4
for i in range(1, n + 1):
    print(" " * (n - i) + "* " * i)
```

```{ .text .output }
   *
  * *
 * * *
* * * *
```

## Common Loop Patterns

### Sum and count

```python
marks = [78, 92, 65, 88, 54]
total = 0
passed = 0

for m in marks:
    total += m
    if m >= 60:
        passed += 1

print(f"Total: {total}, Average: {total / len(marks)}, Passed: {passed}")
```

```{ .text .output }
Total: 377, Average: 75.4, Passed: 4
```

### Find maximum

```python
prices = [499, 1299, 799, 2499, 999]
highest = prices[0]

for p in prices:
    if p > highest:
        highest = p

print("Highest price:", highest)
```

```{ .text .output }
Highest price: 2499
```

Python also has built-ins for these: `sum(marks)`, `max(prices)`, `min(prices)`, `len(marks)`. Learn the loop version first so you understand what they do, then use the built-ins in real code.

### Digits of a number

```python
num = 4729
total = 0

while num > 0:
    total += num % 10    # last digit
    num //= 10           # remove last digit

print("Sum of digits:", total)
```

```{ .text .output }
Sum of digits: 22
```

## Common Mistakes

| Mistake | Result | Fix |
|---------|--------|-----|
| Forgetting to update the `while` variable | Infinite loop | Update it inside the loop |
| `range(1, 10)` expecting 10 | Stops at 9 | `range(1, 11)` (stop is excluded) |
| Missing colon after `for`/`while` | `SyntaxError: expected ':'` | `for x in items:` |
| `for i in 10:` | `TypeError: 'int' object is not iterable` | `for i in range(10):` |
| Modifying a list while looping over it | Skipped items, odd results | Loop over a copy: `for x in items[:]` |
| `print()` indented inside the inner loop | Output on wrong lines | Check the indentation level carefully |
| Using `break` outside a loop | `SyntaxError: 'break' outside loop` | `break` only works inside loops |

## Practice Exercises

**Easy**

1. Print numbers from 1 to 20 on one line.
2. Print all even numbers between 1 and 50.
3. Print the multiplication table of a number entered by the user (1 to 10).

**Medium**

4. Find the sum of all numbers from 1 to 100 that are divisible by 3 or 5.
5. Ask for a number and print its factorial. (5! = 5 × 4 × 3 × 2 × 1 = 120)
6. Reverse a number using a `while` loop: `12345` → `54321`.

**Challenge**

7. **Number guessing game:** the secret number is `37`. Let the user guess up to 5 times. After each wrong guess, say "Too high" or "Too low". If they guess correctly, congratulate them and stop. If all 5 attempts are used, reveal the number (use loop `else`).

??? success "Solutions (click to expand)"

    ```python
    # 1
    for i in range(1, 21):
        print(i, end=" ")
    print()

    # 2
    for i in range(2, 51, 2):
        print(i, end=" ")
    print()

    # 3
    n = int(input("Number: "))
    for i in range(1, 11):
        print(f"{n} x {i} = {n * i}")

    # 4
    total = 0
    for i in range(1, 101):
        if i % 3 == 0 or i % 5 == 0:
            total += i
    print(total)                      # 2418

    # 5
    n = int(input("Number: "))
    fact = 1
    for i in range(1, n + 1):
        fact *= i
    print(f"{n}! = {fact}")

    # 6
    num = 12345
    rev = 0
    while num > 0:
        rev = rev * 10 + num % 10
        num //= 10
    print(rev)                        # 54321

    # 7
    SECRET = 37
    for attempt in range(1, 6):
        guess = int(input(f"Attempt {attempt}/5 - your guess: "))
        if guess == SECRET:
            print(f"Correct! You got it in {attempt} attempt(s).")
            break
        elif guess > SECRET:
            print("Too high")
        else:
            print("Too low")
    else:
        print(f"Out of attempts. The number was {SECRET}.")
    ```

!!! note "Mini Assignment"
    Build `expense_tracker.py`: use a `while True` loop that keeps asking for an expense amount. When the user types `done`, stop and print the number of expenses, the total, the average and the highest expense. Ignore invalid entries using `continue` (hint: `value.isdigit()`).

## Interview Questions

!!! interview "1. What is the difference between `for` and `while` loops?"
    `for` iterates over a sequence (list, string, range); the number of iterations is known from the sequence. `while` repeats as long as a condition is true; it's used when the number of iterations isn't known in advance.

!!! interview "2. What is the difference between `break`, `continue` and `pass`?"
    `break` exits the loop entirely. `continue` skips the rest of the current iteration and moves to the next. `pass` does nothing; it's a placeholder where a statement is required.

!!! interview "3. What does `else` on a loop do?"
    The `else` block runs when the loop completes normally, without encountering `break`. It's commonly used in search loops to handle the "not found" case.

!!! interview "4. What does `range(10, 0, -2)` produce?"
    `10, 8, 6, 4, 2`. It starts at 10, steps by -2, and stops **before** reaching 0.

!!! interview "5. What is `enumerate()` used for?"
    It returns pairs of (index, item) while looping, so you don't need a manual counter: `for i, item in enumerate(items, start=1):`.

!!! interview "Scenario: a script that should process 10 records never finishes. What would you check?"
    Look for a `while` loop whose condition never becomes false, usually a missing or wrong update to the loop variable, or a `while True` with no reachable `break`. Add a print inside the loop to see how the variable changes.

## Summary

| Concept | Remember |
|---------|----------|
| `for x in seq:` | Goes through each item of a sequence |
| `range(start, stop, step)` | Number sequence; stop is excluded |
| `enumerate(seq, start=1)` | Index and item together |
| `while cond:` | Repeats while the condition is true; initialise, check, update |
| `break` | Exit the loop now |
| `continue` | Skip to the next iteration |
| Loop `else` | Runs if no `break` happened |
| Nested loops | Inner loop runs fully for each outer iteration |
| Built-ins | `sum()`, `max()`, `min()`, `len()` |

**Next lesson:** [Lists in Python](09-lists.md), storing many values in one variable.
