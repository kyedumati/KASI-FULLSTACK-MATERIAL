---
lesson: true
category: Python Foundation
short: Strings
description: Creating strings, indexing and slicing, common string methods, searching, splitting, joining and formatting text.
---

# Strings in Python

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Create strings and use indexing and slicing
    - Explain why strings are immutable
    - Use the most important string methods
    - Search, split, join and replace text
    - Validate and clean user input

**Prerequisites:** [Input, Output & Type Conversion](05-input-output-type-conversion.md)

## What is a String?

A **string** (`str`) is a sequence of characters: letters, digits, spaces and symbols, written inside quotes.

```python
name = "Ravi Kumar"
email = 'ravi@example.com'
bio = """Career switcher.
Learning Full Stack Python."""
empty = ""

print(len(name))
print(len(empty))
```

```{ .text .output }
10
0
```

`len()` returns the number of characters, including spaces.

!!! example "Real-life analogy: a train"
    A string is like a train where each coach carries **one character**. Coaches are numbered from the front starting at **0**, and you can also count from the back starting at **-1**.

## Indexing

Each character has a position called an **index**.

```text
 String:   P   y   t   h   o   n
 Index:    0   1   2   3   4   5
 Negative: -6  -5  -4  -3  -2  -1
```

```python
word = "Python"

print(word[0])     # first character
print(word[3])
print(word[-1])    # last character
print(word[-2])
```

```{ .text .output }
P
h
n
o
```

!!! mistake "Common Mistake: index out of range"
    ```python
    word = "Python"
    print(word[6])
    ```

    ```{ .text .output }
    IndexError: string index out of range
    ```

    A 6-character string has indexes 0 to 5. The last index is always `len(word) - 1`, or simply use `word[-1]`.

## Slicing

**Slicing** extracts a part of a string: `text[start:stop:step]`.

- `start`: where to begin (included). Default: beginning.
- `stop`: where to end (**not included**). Default: end.
- `step`: how many to jump. Default: 1.

```python
text = "Full Stack Python"

print(text[0:4])      # characters 0, 1, 2, 3
print(text[5:10])
print(text[:4])       # from the start
print(text[11:])      # to the end
print(text[-6:])      # last 6 characters
print(text[::2])      # every 2nd character
print(text[::-1])     # reversed
```

```{ .text .output }
Full
Stack
Full
Python
Python
Fl tc yhn
nohtyP kcatS lluF
```

!!! tip "Remember: stop is excluded"
    `text[0:4]` gives 4 characters (0 to 3). Think of the indexes as pointing **between** characters, like cuts with scissors.

!!! realworld "In Real Projects"
    Slicing is used to mask sensitive data: showing a card number as `"XXXX-XXXX-XXXX-" + card[-4:]`, or a phone number as `"******" + phone[-4:]`.

## Strings are Immutable

You **cannot change** a character inside a string:

```python
city = "hyderabad"
city[0] = "H"
```

```{ .text .output }
TypeError: 'str' object does not support item assignment
```

Instead, create a **new** string:

```python
city = "hyderabad"
city = "H" + city[1:]
print(city)
```

```{ .text .output }
Hyderabad
```

Every string method below **returns a new string**. The original is never modified. To keep the result, assign it: `name = name.strip()`.

## Common String Methods

### Changing case

```python
s = "full STACK python"

print(s.upper())
print(s.lower())
print(s.title())
print(s.capitalize())
print(s.swapcase())
```

```{ .text .output }
FULL STACK PYTHON
full stack python
Full Stack Python
Full stack python
FULL stack PYTHON
```

### Removing spaces

```python
raw = "   ravi@example.com   "

print(f"[{raw.strip()}]")     # both sides
print(f"[{raw.lstrip()}]")    # left only
print(f"[{raw.rstrip()}]")    # right only
```

```{ .text .output }
[ravi@example.com]
[ravi@example.com   ]
[   ravi@example.com]
```

### Searching

```python
msg = "Python is easy. Python is powerful."

print(msg.find("Python"))        # first index, or -1 if not found
print(msg.find("Java"))
print(msg.count("Python"))
print(msg.startswith("Python"))
print(msg.endswith("."))
print("easy" in msg)
```

```{ .text .output }
0
-1
2
True
True
True
```

`index()` works like `find()` but raises a `ValueError` instead of returning `-1` when the text isn't found.

### Replacing

```python
msg = "I love Java. Java is great."
print(msg.replace("Java", "Python"))
print(msg.replace("Java", "Python", 1))   # only the first one
```

```{ .text .output }
I love Python. Python is great.
I love Python. Java is great.
```

### Checking content

| Method | Returns `True` if | `"abc123"` |
|--------|-------------------|-----------|
| `isalpha()` | only letters | `False` |
| `isdigit()` | only digits | `False` |
| `isalnum()` | only letters and digits | `True` |
| `isspace()` | only whitespace | `False` |
| `isupper()` / `islower()` | all letters upper / lower | `False` / `True` |

```python
pin = "500081"
print(pin.isdigit() and len(pin) == 6)
```

```{ .text .output }
True
```

## Splitting and Joining

### `split()`: string → list

```python
skills = "Python,SQL,Django,React"
print(skills.split(","))

sentence = "Learn   Python   step by step"
print(sentence.split())        # no argument: splits on any whitespace
```

```{ .text .output }
['Python', 'SQL', 'Django', 'React']
['Learn', 'Python', 'step', 'by', 'step']
```

### `join()`: list → string

```python
words = ["Full", "Stack", "Python"]
print(" ".join(words))
print("-".join(words))
print("".join(words))
```

```{ .text .output }
Full Stack Python
Full-Stack-Python
FullStackPython
```

The string **before** `.join` is the glue placed between items.

!!! realworld "In Real Projects"
    Websites turn article titles into URL slugs this way: `"Learn Python Fast".lower().split()` gives `['learn', 'python', 'fast']`, and `"-".join(...)` gives `learn-python-fast`.

## String Operations and Formatting

```python
first = "Ravi"
last = "Kumar"

full = first + " " + last      # concatenation
line = "=" * 15                # repetition

print(full)
print(line)
print(f"Initials: {first[0]}.{last[0]}.")
```

```{ .text .output }
Ravi Kumar
===============
Initials: R.K.
```

Loop through each character (loops get their own lesson later):

```python
for ch in "SQL":
    print(ch)
```

```{ .text .output }
S
Q
L
```

### Validating and cleaning user input

Real users type messy data. Clean it before using it:

```python
email = "  Ravi.Kumar@Gmail.COM "
email = email.strip().lower()

print(email)
print("@" in email and email.endswith(".com"))
```

```{ .text .output }
ravi.kumar@gmail.com
True
```

## Common Mistakes

| Mistake | Error / Result | Fix |
|---------|---------------|-----|
| `name.upper()` but `name` didn't change | Original string unchanged | Assign it: `name = name.upper()` |
| `word[10]` on a short string | `IndexError: string index out of range` | Check `len()` or use slicing (slicing never errors) |
| `s[0] = "X"` | `TypeError: 'str' object does not support item assignment` | Build a new string |
| `"Age: " + 25` | `TypeError` | `f"Age: {25}"` |
| `",".join([1, 2, 3])` | `TypeError: sequence item 0: expected str instance, int found` | Convert items first: `",".join(str(n) for n in nums)` |
| Comparing `"Python" == "python"` | `False` | Normalise case: `a.lower() == b.lower()` |

## Practice Exercises

**Easy**

1. Given `s = "Programming"`, print the first character, last character and the length.
2. Print `"KSR Trainings"` in upper case, lower case and reversed.
3. Count how many times `"a"` appears in `"banana"`.

**Medium**

4. Ask the user for their full name and print their initials, e.g. `Ravi Kumar` → `R.K.`
5. Check whether a word is a **palindrome** (reads the same backwards), ignoring case. Test with `"Madam"` and `"Python"`.
6. Mask an email: `ravikumar@gmail.com` → `ra*******@gmail.com` (keep the first 2 characters and the domain).

**Challenge**

7. Write a password validator. A password is valid if it has at least 8 characters, contains at least one digit, at least one upper-case letter and no spaces. Print which rules failed.

??? success "Solutions (click to expand)"

    ```python
    # 1
    s = "Programming"
    print(s[0], s[-1], len(s))            # P g 11

    # 2
    t = "KSR Trainings"
    print(t.upper(), t.lower(), t[::-1])  # KSR TRAININGS ksr trainings sgniniarT RSK

    # 3
    print("banana".count("a"))            # 3

    # 4
    full = input("Full name: ")
    parts = full.split()
    print(".".join(p[0].upper() for p in parts) + ".")

    # 5
    for word in ["Madam", "Python"]:
        w = word.lower()
        print(word, w == w[::-1])         # Madam True / Python False

    # 6
    email = "ravikumar@gmail.com"
    at = email.find("@")
    masked = email[:2] + "*" * (at - 2) + email[at:]
    print(masked)                         # ra*******@gmail.com

    # 7
    pwd = input("Password: ")
    if len(pwd) < 8:
        print("Must be at least 8 characters")
    if not any(ch.isdigit() for ch in pwd):
        print("Must contain a digit")
    if not any(ch.isupper() for ch in pwd):
        print("Must contain an upper-case letter")
    if " " in pwd:
        print("Must not contain spaces")
    ```

    `any()` returns `True` if at least one item is true. You'll use it more after the Loops lesson.

!!! note "Mini Assignment"
    Write `username.py`: ask for a first name, last name and birth year, then generate a username in the format `firstname.lastname` + last 2 digits of the year, all lowercase, with spaces removed. Example: `Ravi`, `Kumar`, `2001` → `ravi.kumar01`. Also print how many characters it has.

## Interview Questions

!!! interview "1. Are strings mutable in Python?"
    No. Strings are immutable. Methods like `upper()` or `replace()` return a **new** string; the original is unchanged. To "modify" a string, create a new one and reassign the variable.

!!! interview "2. How do you reverse a string?"
    With slicing: `s[::-1]`. Alternatively `"".join(reversed(s))`.

!!! interview "3. What is the difference between `find()` and `index()`?"
    Both return the index of the first occurrence. If the substring isn't found, `find()` returns `-1` while `index()` raises a `ValueError`.

!!! interview "4. What is the difference between `split()` and `join()`?"
    `split()` breaks a string into a **list** using a separator. `join()` combines a list of strings into **one string**, with the string it's called on as the separator: `"-".join(["a", "b"])` → `"a-b"`.

!!! interview "5. Why doesn't slicing raise an IndexError?"
    Slicing clamps out-of-range indexes to the string's bounds: `"abc"[1:100]` → `"bc"`, `"abc"[10:]` → `""`. Only single-index access (`s[10]`) raises `IndexError`.

!!! interview "Scenario: users sign up with emails like `\" Ravi@Gmail.com \"` and duplicates slip through. Why, and how do you fix it?"
    The emails differ in spaces and case, so they don't match as strings. Normalise before saving and comparing: `email.strip().lower()`.

## Summary

| Concept | Remember |
|---------|----------|
| Indexing | `s[0]` first, `s[-1]` last |
| Slicing | `s[start:stop:step]`, stop excluded; `s[::-1]` reverses |
| Immutable | Methods return new strings; reassign to keep the result |
| Case | `upper()`, `lower()`, `title()`, `capitalize()` |
| Clean | `strip()`, `lstrip()`, `rstrip()` |
| Search | `find()`, `index()`, `count()`, `startswith()`, `endswith()`, `in` |
| Change | `replace(old, new)` |
| Check | `isdigit()`, `isalpha()`, `isalnum()` |
| Split / Join | `"a,b".split(",")` ↔ `",".join(list)` |

**Next lesson:** [Conditional Statements](07-conditional-statements.md), making decisions with `if`, `elif` and `else`.
