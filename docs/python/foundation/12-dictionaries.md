---
lesson: true
category: Python Foundation
short: Dictionaries
description: Storing data as key-value pairs: creating, reading, updating and deleting entries, looping, nested dictionaries and real-world JSON-style data.
---

# Dictionaries in Python

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Create dictionaries and explain key-value pairs
    - Read values safely with `[]` and `get()`
    - Add, update and delete entries
    - Loop through keys, values and items
    - Work with nested dictionaries and lists of dictionaries (JSON-style data)

**Prerequisites:** [Lists in Python](09-lists.md), [Tuples](10-tuples.md) and [Sets](11-sets.md)

## What is a Dictionary?

A **dictionary** (`dict`) stores data as **key-value pairs**. Instead of looking up items by position (like a list), you look them up by a **key**.

```python
student = {
    "name": "Priya",
    "age": 22,
    "course": "Full Stack Python",
    "is_placed": False,
}

print(student["name"])
print(student["course"])
print(len(student))
```

```{ .text .output }
Priya
Full Stack Python
4
```

!!! example "Real-life analogy: a phone's contact list"
    You don't remember that Ravi is "contact number 47". You search by **name** (the key) and get the **phone number** (the value). A dictionary works the same way: fast lookup by a meaningful key.

Compare with a list:

=== "List (by position)"

    ```python
    student = ["Priya", 22, "Full Stack Python"]
    print(student[2])     # what was index 2 again?
    ```

=== "Dictionary (by key)"

    ```python
    student = {"name": "Priya", "age": 22, "course": "Full Stack Python"}
    print(student["course"])     # self-explanatory
    ```

**At a glance**

| Property | Meaning |
|----------|---------|
| Key-value pairs | Each key maps to one value |
| Keys are unique | Assigning to an existing key replaces its value |
| Keys must be immutable | `str`, `int`, `tuple`: yes; `list`: no |
| Values can be anything | Numbers, strings, lists, even other dicts |
| Ordered | Keeps insertion order (Python 3.7+) |
| Mutable | Add, change, remove entries freely |

## Creating Dictionaries

```python
# Curly braces
product = {"id": 101, "name": "Laptop", "price": 55000}

# dict() with keyword arguments
config = dict(host="localhost", port=3306, user="root")

# From a list of pairs
pairs = [("a", 1), ("b", 2)]
letters = dict(pairs)

# From two lists with zip()
keys = ["name", "city"]
values = ["Ravi", "Pune"]
person = dict(zip(keys, values))

# Empty
empty = {}

print(config)
print(letters)
print(person)
```

```{ .text .output }
{'host': 'localhost', 'port': 3306, 'user': 'root'}
{'a': 1, 'b': 2}
{'name': 'Ravi', 'city': 'Pune'}
```

Duplicate keys: the last value wins.

```python
d = {"x": 1, "x": 2}
print(d)
```

```{ .text .output }
{'x': 2}
```

## Accessing Values

### Square brackets `[]`

```python
product = {"id": 101, "name": "Laptop", "price": 55000}
print(product["price"])
print(product["discount"])
```

```{ .text .output }
55000
KeyError: 'discount'
```

### `get()`: the safe way

`get()` returns `None` (or a default you choose) instead of crashing:

```python
print(product.get("price"))
print(product.get("discount"))
print(product.get("discount", 0))
```

```{ .text .output }
55000
None
0
```

!!! tip "When to use which"
    Use `d["key"]` when the key **must** exist; a `KeyError` then tells you about a real bug. Use `d.get("key", default)` when the key is **optional**, like an optional form field or API field.

Check if a key exists with `in` (it checks **keys**, not values):

```python
print("name" in product)
print("Laptop" in product)
print("Laptop" in product.values())
```

```{ .text .output }
True
False
True
```

## Adding, Updating and Deleting

```python
user = {"name": "Kiran", "city": "Pune"}

user["email"] = "kiran@ksr.com"     # add a new key
user["city"] = "Hyderabad"          # update an existing key
print(user)

user.update({"age": 25, "city": "Chennai"})   # add/update several at once
print(user)
```

```{ .text .output }
{'name': 'Kiran', 'city': 'Hyderabad', 'email': 'kiran@ksr.com'}
{'name': 'Kiran', 'city': 'Chennai', 'email': 'kiran@ksr.com', 'age': 25}
```

The same syntax `d[key] = value` **adds** if the key is new and **updates** if it exists.

### Deleting

| Method | What it does |
|--------|--------------|
| `pop(key)` | Removes the key and **returns** its value (`KeyError` if missing) |
| `pop(key, default)` | Same, but returns `default` if missing |
| `del d[key]` | Removes the key |
| `popitem()` | Removes and returns the **last** inserted pair |
| `clear()` | Empties the dictionary |

```python
user = {"name": "Kiran", "city": "Chennai", "email": "kiran@ksr.com", "age": 25}

email = user.pop("email")
print("Removed:", email)

del user["age"]
print(user)

last = user.popitem()
print("Popped:", last, "| Now:", user)
```

```{ .text .output }
Removed: kiran@ksr.com
{'name': 'Kiran', 'city': 'Chennai'}
Popped: ('city', 'Chennai') | Now: {'name': 'Kiran'}
```

### `setdefault()`

Returns the value if the key exists; otherwise adds the key with a default and returns that default:

```python
stock = {"pen": 10}
print(stock.setdefault("pen", 0))
print(stock.setdefault("pencil", 0))
print(stock)
```

```{ .text .output }
10
0
{'pen': 10, 'pencil': 0}
```

## Looping Through Dictionaries

```python
marks = {"Maths": 88, "Science": 92, "English": 79}

for subject in marks:              # keys (default)
    print(subject)

for score in marks.values():       # values
    print(score)

for subject, score in marks.items():   # both
    print(f"{subject:<8}: {score}")
```

```{ .text .output }
Maths
Science
English
88
92
79
Maths   : 88
Science : 92
English : 79
```

| Method | Returns |
|--------|---------|
| `keys()` | All keys |
| `values()` | All values |
| `items()` | All `(key, value)` pairs as tuples |

Useful operations on the values:

```python
print("Total:", sum(marks.values()))
print("Best subject:", max(marks, key=marks.get))
print("Sorted by marks:", sorted(marks.items(), key=lambda pair: pair[1], reverse=True))
```

```{ .text .output }
Total: 259
Best subject: Science
Sorted by marks: [('Science', 92), ('Maths', 88), ('English', 79)]
```

`lambda pair: pair[1]` means "sort by the second element of each pair" (the score). Lambdas are covered in the Functions module.

### Counting with a dictionary (a classic pattern)

```python
text = "python is easy and python is powerful"
counts = {}

for word in text.split():
    counts[word] = counts.get(word, 0) + 1

print(counts)
```

```{ .text .output }
{'python': 2, 'is': 2, 'easy': 1, 'and': 1, 'powerful': 1}
```

### Dictionary comprehension

```python
prices = {"pen": 10, "notebook": 50, "bag": 800}
with_gst = {item: price * 1.18 for item, price in prices.items()}
expensive = {item: price for item, price in prices.items() if price > 40}

print(with_gst)
print(expensive)
```

```{ .text .output }
{'pen': 11.799999999999999, 'notebook': 59.0, 'bag': 944.0}
{'notebook': 50, 'bag': 800}
```

(The `11.799999999999999` is the float precision issue from the [Data Types](03-data-types.md) lesson. Use `round(price * 1.18, 2)` for display.)

## Nested Dictionaries and JSON-style Data

Real data is rarely flat. Dictionaries can contain lists and other dictionaries:

```python
student = {
    "id": 1,
    "name": "Asha",
    "contact": {
        "email": "asha@ksr.com",
        "phone": "9876543210",
    },
    "skills": ["Python", "SQL", "React"],
}

print(student["contact"]["email"])
print(student["skills"][0])
print(len(student["skills"]))

student["skills"].append("Django")
student["contact"]["city"] = "Hyderabad"
print(student)
```

```{ .text .output }
asha@ksr.com
Python
3
{'id': 1, 'name': 'Asha', 'contact': {'email': 'asha@ksr.com', 'phone': '9876543210', 'city': 'Hyderabad'}, 'skills': ['Python', 'SQL', 'React', 'Django']}
```

### A list of dictionaries: how most real data looks

```python
products = [
    {"id": 1, "name": "Laptop", "price": 55000, "in_stock": True},
    {"id": 2, "name": "Mouse", "price": 799, "in_stock": False},
    {"id": 3, "name": "Keyboard", "price": 1499, "in_stock": True},
]

for p in products:
    status = "✅" if p["in_stock"] else "❌"
    print(f"{p['id']}. {p['name']:<10} ₹{p['price']:>7,} {status}")

available = [p["name"] for p in products if p["in_stock"]]
print("Available:", available)
```

```{ .text .output }
1. Laptop     ₹ 55,000 ✅
2. Mouse      ₹    799 ❌
3. Keyboard   ₹  1,499 ✅
Available: ['Laptop', 'Keyboard']
```

!!! realworld "In Real Projects"
    Dictionaries are the backbone of web development:

    - **APIs** send and receive **JSON**, which maps directly to Python dicts and lists. A FastAPI endpoint that returns `{"id": 1, "name": "Laptop"}` sends exactly that JSON to the React frontend.
    - **Django** passes data to HTML templates as a dict: `render(request, "home.html", {"products": products})`.
    - **Config and settings** (database host, port, credentials) are stored as dicts.
    - **Caching:** `cache[user_id] = user_data` gives instant lookups.

```python
import json

order = {"order_id": "ORD101", "items": ["Laptop", "Mouse"], "total": 55799}
as_json = json.dumps(order)          # dict → JSON text (to send in an API)
back = json.loads(as_json)           # JSON text → dict (to read an API response)

print(as_json)
print(back["items"])
```

```{ .text .output }
{"order_id": "ORD101", "items": ["Laptop", "Mouse"], "total": 55799}
['Laptop', 'Mouse']
```

### Copying dictionaries

Same trap as lists: `b = a` is not a copy.

```python
original = {"a": 1}
alias = original
real_copy = original.copy()

alias["b"] = 2
print(original)
print(real_copy)
```

```{ .text .output }
{'a': 1, 'b': 2}
{'a': 1}
```

For nested dicts, use `copy.deepcopy()`.

### Merging dictionaries

```python
defaults = {"theme": "light", "language": "en", "notifications": True}
user_prefs = {"theme": "dark"}

settings = defaults | user_prefs      # Python 3.9+
print(settings)
```

```{ .text .output }
{'theme': 'dark', 'language': 'en', 'notifications': True}
```

When both have the same key, the right-hand dict wins.

## Common Mistakes

| Mistake | Error / Result | Fix |
|---------|---------------|-----|
| `d["missing"]` | `KeyError: 'missing'` | `d.get("missing", default)` or check `in` first |
| `{}` expecting an empty set | Creates a dict | `set()` for sets |
| Using a list as a key | `TypeError: unhashable type: 'list'` | Use a tuple |
| `"value" in d` | Checks **keys** only | `"value" in d.values()` |
| `for k, v in d:` | `ValueError: too many values to unpack` | `for k, v in d.items():` |
| Changing dict size while looping | `RuntimeError: dictionary changed size during iteration` | Loop over `list(d)` |
| `b = a` to copy | Both change together | `a.copy()` or `copy.deepcopy(a)` |
| `f"{p["name"]}"` (same quotes inside f-string) | `SyntaxError` before Python 3.12 | Use different quotes: `f"{p['name']}"` |

## Practice Exercises

**Easy**

1. Create a dictionary for a book with `title`, `author`, `year` and `price`. Print each value.
2. Add a `publisher` key, update the `price`, and delete the `year`. Print the dictionary after each step.
3. Use `get()` to print the book's `rating`, showing `"Not rated"` if it doesn't exist.

**Medium**

4. Count the frequency of each character in `"programming"` using a dictionary.
5. Given `marks = {"Asha": 85, "Ravi": 72, "Kiran": 91, "Meena": 64}`, print the topper, the class average, and the students who scored above 75.
6. Invert a dictionary: `{"a": 1, "b": 2, "c": 3}` → `{1: "a", 2: "b", 3: "c"}`.

**Challenge**

7. **Inventory system:** start with `inventory = {"apple": 50, "banana": 20, "mango": 0}`. Write a menu loop with options to: view stock, add stock for an item (create it if new), sell an item (reduce the quantity; refuse if there isn't enough), list out-of-stock items, and exit.

??? success "Solutions (click to expand)"

    ```python
    # 1
    book = {"title": "Atomic Habits", "author": "James Clear", "year": 2018, "price": 499}
    for key, value in book.items():
        print(key, ":", value)

    # 2
    book["publisher"] = "Penguin"
    print(book)
    book["price"] = 399
    print(book)
    del book["year"]
    print(book)

    # 3
    print(book.get("rating", "Not rated"))

    # 4
    freq = {}
    for ch in "programming":
        freq[ch] = freq.get(ch, 0) + 1
    print(freq)
    # {'p': 1, 'r': 2, 'o': 1, 'g': 2, 'a': 1, 'm': 2, 'i': 1, 'n': 1}

    # 5
    marks = {"Asha": 85, "Ravi": 72, "Kiran": 91, "Meena": 64}
    print("Topper:", max(marks, key=marks.get))                     # Kiran
    print("Average:", sum(marks.values()) / len(marks))             # 78.0
    print("Above 75:", [name for name, m in marks.items() if m > 75])  # ['Asha', 'Kiran']

    # 6
    d = {"a": 1, "b": 2, "c": 3}
    print({v: k for k, v in d.items()})

    # 7
    inventory = {"apple": 50, "banana": 20, "mango": 0}
    while True:
        print("\n1. View  2. Add  3. Sell  4. Out of stock  5. Exit")
        choice = input("Choose: ")
        if choice == "1":
            for item, qty in inventory.items():
                print(f"{item:<10}{qty:>5}")
        elif choice == "2":
            item = input("Item: ").strip().lower()
            qty = int(input("Quantity to add: "))
            inventory[item] = inventory.get(item, 0) + qty
            print(f"{item} stock is now {inventory[item]}")
        elif choice == "3":
            item = input("Item: ").strip().lower()
            qty = int(input("Quantity to sell: "))
            if item not in inventory:
                print("No such item")
            elif inventory[item] < qty:
                print(f"Only {inventory[item]} {item}(s) available")
            else:
                inventory[item] -= qty
                print(f"Sold {qty} {item}(s)")
        elif choice == "4":
            print([item for item, qty in inventory.items() if qty == 0])
        elif choice == "5":
            print("Goodbye!")
            break
        else:
            print("Invalid choice")
    ```

!!! note "Mini Assignment: module capstone"
    Build `student_manager.py`, a menu-driven program that stores students as a **dictionary of dictionaries** keyed by roll number: `{101: {"name": "Asha", "marks": {"Maths": 88, "Science": 92}}}`. Support: add a student, add marks for a subject, view one student's report (total, percentage, grade using the grading rules from the Conditions lesson), list all students ranked by percentage, and exit. This uses everything from the Python Foundation module.

## Interview Questions

!!! interview "1. What is a dictionary in Python?"
    A mutable, insertion-ordered (Python 3.7+) collection of key-value pairs. Keys must be unique and hashable; values can be any object. Lookups by key take roughly constant time because dicts are implemented as hash tables.

!!! interview "2. What is the difference between `d[key]` and `d.get(key)`?"
    `d[key]` raises `KeyError` if the key doesn't exist. `d.get(key)` returns `None`, or a supplied default (`d.get(key, 0)`), instead of raising an error.

!!! interview "3. Can a list be a dictionary key? Why or why not?"
    No. Keys must be hashable, meaning their hash value must never change, and lists are mutable. Tuples (of immutable items), strings, numbers and frozensets can be keys.

!!! interview "4. How do you merge two dictionaries?"
    `merged = a | b` (Python 3.9+), `{**a, **b}`, or `a.update(b)` to modify `a` in place. On duplicate keys, the value from `b` wins.

!!! interview "5. Are dictionaries ordered?"
    Since Python 3.7, dictionaries officially preserve **insertion order**. Before that, order was not guaranteed.

!!! interview "Scenario: an API response sometimes lacks the `\"discount\"` field and your code crashes with `KeyError`. How do you fix it?"
    Treat the field as optional: `discount = data.get("discount", 0)`. Use `[]` only for fields that must always be present, so that a missing required field still fails loudly.

## Summary

| Task | Code |
|------|------|
| Create | `{"k": v}`, `dict(k=v)`, `dict(zip(keys, values))`; empty `{}` |
| Read | `d["k"]` (errors if missing), `d.get("k", default)` (safe) |
| Check key | `"k" in d` |
| Add / Update | `d["k"] = v`, `d.update({...})`, `d.setdefault(k, v)` |
| Delete | `pop(k)`, `del d[k]`, `popitem()`, `clear()` |
| Loop | `for k in d`, `d.values()`, `for k, v in d.items()` |
| Count pattern | `counts[x] = counts.get(x, 0) + 1` |
| Comprehension | `{k: v for k, v in d.items() if ...}` |
| Nested | `d["contact"]["email"]`, lists of dicts = JSON |
| Copy / Merge | `d.copy()`, `copy.deepcopy(d)`, `a | b` |

🎉 **You've completed the Python Foundation module!** Next up: [**Functions & Modules**](../functions/index.md), where you'll learn to organise your code into reusable pieces.
