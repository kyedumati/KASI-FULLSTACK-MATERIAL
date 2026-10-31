---
lesson: true
category: Python Foundation
short: Tuples
description: Creating tuples, accessing items, immutability, packing and unpacking, tuple methods and when to choose a tuple over a list.
---

# Tuples in Python

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Create tuples, including single-item tuples
    - Access tuple items with indexing and slicing
    - Explain why tuples are immutable and why that's useful
    - Use packing and unpacking, including `*rest`
    - Choose between a list and a tuple

**Prerequisites:** [Lists in Python](09-lists.md)

## What is a Tuple?

A **tuple** is an ordered collection, just like a list, but it **cannot be changed** after creation.

```python
location = (17.3850, 78.4867)
rgb = (255, 128, 0)
student = ("Ravi", 23, "Full Stack Python")

print(student)
print(type(student))
print(len(student))
```

```{ .text .output }
('Ravi', 23, 'Full Stack Python')
<class 'tuple'>
3
```

!!! example "Real-life analogy: a printed certificate"
    A list is like a **whiteboard**: write, erase, rewrite. A tuple is like a **printed certificate**: name, course and date are fixed once printed. You can read it as often as you like, but you can't edit it.

**At a glance**

| Property | List | Tuple |
|----------|------|-------|
| Brackets | `[ ]` | `( )` |
| Ordered | ✅ | ✅ |
| Mutable | ✅ | ❌ |
| Duplicates | ✅ | ✅ |
| Can be a dict key | ❌ | ✅ (if its items are immutable) |
| Speed and memory | Slightly slower, more memory | Slightly faster, less memory |

## Creating Tuples

```python
days = ("Mon", "Tue", "Wed")
numbers = 1, 2, 3                 # parentheses are optional
from_list = tuple([10, 20, 30])
from_string = tuple("abc")
empty = ()

print(numbers)
print(from_list)
print(from_string)
```

```{ .text .output }
(1, 2, 3)
(10, 20, 30)
('a', 'b', 'c')
```

### The single-item tuple trap

```python
not_a_tuple = ("Python")
real_tuple = ("Python",)

print(type(not_a_tuple))
print(type(real_tuple))
```

```{ .text .output }
<class 'str'>
<class 'tuple'>
```

!!! mistake "Common Mistake: missing comma"
    It's the **comma** that makes a tuple, not the parentheses. `("Python")` is just a string in brackets. A one-item tuple needs a trailing comma: `("Python",)`.

## Accessing Items

Indexing, slicing, `in` and loops work exactly like lists:

```python
months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun")

print(months[0])
print(months[-1])
print(months[1:4])
print("Mar" in months)

for m in months[:3]:
    print(m, end=" ")
```

```{ .text .output }
Jan
Jun
('Feb', 'Mar', 'Apr')
True
Jan Feb Mar
```

Slicing a tuple returns a **new tuple**.

## Tuples are Immutable

```python
point = (10, 20)
point[0] = 15
```

```{ .text .output }
TypeError: 'tuple' object does not support item assignment
```

There's no `append`, `remove` or `sort` either. If you really need to "change" a tuple, create a new one:

```python
point = (10, 20)
point = (15,) + point[1:]
print(point)

colors = ("red", "green")
temp = list(colors)       # convert to list
temp.append("blue")
colors = tuple(temp)      # convert back
print(colors)
```

```{ .text .output }
(15, 20)
('red', 'green', 'blue')
```

!!! tip "Why immutability is a feature"
    - **Safety:** data that shouldn't change (like configuration or coordinates) can't be changed by mistake.
    - **Dictionary keys:** tuples can be used as dict keys and set items; lists can't.
    - **Performance:** Python can store tuples more efficiently than lists.

!!! warning "Immutable, but its contents might not be"
    A tuple can't change *which* objects it holds, but if one item is a list, that list can still change:

    ```python
    t = ("Ravi", [85, 90])
    t[1].append(95)
    print(t)
    ```

    ```{ .text .output }
    ('Ravi', [85, 90, 95])
    ```

## Packing and Unpacking

**Packing:** putting several values into one tuple.
**Unpacking:** taking them out into separate variables.

```python
employee = ("Anita", "Developer", 85000)    # packing

name, role, salary = employee                # unpacking
print(name)
print(role)
print(salary)
```

```{ .text .output }
Anita
Developer
85000
```

The number of variables must match the number of items:

```python
name, role = employee
```

```{ .text .output }
ValueError: too many values to unpack (expected 2)
```

### Collecting the rest with `*`

```python
scores = (95, 88, 76, 64, 52)

top, *others = scores
print(top, others)

first, *middle, last = scores
print(first, middle, last)
```

```{ .text .output }
95 [88, 76, 64, 52]
95 [88, 76, 64] 52
```

The starred variable always becomes a **list**.

### Unpacking in loops

```python
orders = [
    ("ORD101", "Laptop", 55000),
    ("ORD102", "Mouse", 799),
    ("ORD103", "Monitor", 12999),
]

for order_id, product, amount in orders:
    print(f"{order_id}: {product} - ₹{amount:,}")
```

```{ .text .output }
ORD101: Laptop - ₹55,000
ORD102: Mouse - ₹799
ORD103: Monitor - ₹12,999
```

Remember `a, b = b, a` from the Variables lesson? That's packing and unpacking: the right side packs a tuple, and the left side unpacks it.

## Tuple Methods and Operations

Tuples have only two methods:

```python
votes = ("yes", "no", "yes", "yes", "no")

print(votes.count("yes"))
print(votes.index("no"))
```

```{ .text .output }
3
1
```

Other operations:

```python
a = (1, 2)
b = (3, 4)

print(a + b)           # join
print(a * 3)           # repeat
print(len(b), max(b), min(b), sum(b))
print(sorted((5, 1, 3)))   # sorted() returns a LIST
```

```{ .text .output }
(1, 2, 3, 4)
(1, 2, 1, 2, 1, 2)
2 4 3 7
[1, 3, 5]
```

## When to Use a Tuple vs a List

| Use a **list** when | Use a **tuple** when |
|---------------------|----------------------|
| Items will be added, removed or changed | Data is fixed and shouldn't change |
| You have many items of the same kind (all products, all marks) | You have a fixed group of related values (a record) |
| Example: shopping cart, list of students | Example: `(latitude, longitude)`, `(day, month, year)`, RGB colour |

```python
# Tuple as a dictionary key: a list here would fail
distances = {
    ("Hyderabad", "Bangalore"): 570,
    ("Hyderabad", "Chennai"): 630,
}
print(distances[("Hyderabad", "Chennai")])
```

```{ .text .output }
630
```

!!! realworld "In Real Projects"
    When Python reads rows from MySQL using a database connector, each row typically comes back as a **tuple**, e.g. `(1, 'Ravi', 'ravi@example.com')`, because a fetched row is a fixed record. Functions that return several values (`return total, average`) also return tuples.

```python
def stats(numbers):
    return min(numbers), max(numbers), sum(numbers) / len(numbers)

low, high, avg = stats([40, 75, 90])
print(low, high, avg)
```

```{ .text .output }
40 90 68.33333333333333
```

You'll write your own functions like this in the Functions lesson.

## Common Mistakes

| Mistake | Error / Result | Fix |
|---------|---------------|-----|
| `("item")` for a one-item tuple | It's a `str` | `("item",)` |
| `t[0] = 5` | `TypeError: 'tuple' object does not support item assignment` | Create a new tuple, or use a list |
| `t.append(4)` | `AttributeError: 'tuple' object has no attribute 'append'` | Use a list if you need to add items |
| Wrong number of variables when unpacking | `ValueError: too many values to unpack` / `not enough values to unpack` | Match the count, or use `*rest` |
| Expecting `sorted(t)` to return a tuple | Returns a list | `tuple(sorted(t))` |

## Practice Exercises

**Easy**

1. Create a tuple of the 7 days of the week. Print the first day, the last day and the weekend days using slicing.
2. Create a single-item tuple containing `"Python"` and confirm its type.
3. Count how many times `2` appears in `(1, 2, 3, 2, 4, 2)` and find the index of the first `3`.

**Medium**

4. Unpack `("Priya", 24, "Bangalore", "Developer")` into four variables and print a sentence using them.
5. Given `scores = (45, 89, 72, 95, 60)`, use unpacking with `*` to get the first score, the last score and the ones in between.
6. Convert `(5, 2, 9, 1)` to a sorted tuple.

**Challenge**

7. You have a list of `(name, city, salary)` tuples for 5 employees. Print the employees from `"Hyderabad"`, the highest-paid employee, and the average salary, using tuple unpacking in your loops.

??? success "Solutions (click to expand)"

    ```python
    # 1
    days = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
    print(days[0], days[-1], days[-2:])     # Mon Sun ('Sat', 'Sun')

    # 2
    t = ("Python",)
    print(type(t))                          # <class 'tuple'>

    # 3
    nums = (1, 2, 3, 2, 4, 2)
    print(nums.count(2), nums.index(3))     # 3 2

    # 4
    name, age, city, role = ("Priya", 24, "Bangalore", "Developer")
    print(f"{name} ({age}) works as a {role} in {city}.")

    # 5
    scores = (45, 89, 72, 95, 60)
    first, *middle, last = scores
    print(first, middle, last)              # 45 [89, 72, 95] 60

    # 6
    print(tuple(sorted((5, 2, 9, 1))))      # (1, 2, 5, 9)

    # 7
    employees = [
        ("Asha", "Hyderabad", 65000),
        ("Ravi", "Pune", 72000),
        ("Kiran", "Hyderabad", 58000),
        ("Meena", "Chennai", 91000),
        ("Arjun", "Bangalore", 80000),
    ]

    for name, city, salary in employees:
        if city == "Hyderabad":
            print(name)

    top_name, top_salary = "", 0
    total = 0
    for name, city, salary in employees:
        total += salary
        if salary > top_salary:
            top_name, top_salary = name, salary

    print(f"Highest paid: {top_name} (₹{top_salary:,})")
    print(f"Average salary: ₹{total / len(employees):,.2f}")
    ```

!!! note "Mini Assignment"
    Store 5 Indian cities as `(city, state, (latitude, longitude))` tuples in a list. Print a table of city and state, then print the city that is furthest **north** (highest latitude) using unpacking.

## Interview Questions

!!! interview "1. What is the difference between a list and a tuple?"
    Both are ordered and allow duplicates. Lists are **mutable** (`[ ]`, many methods); tuples are **immutable** (`( )`, only `count` and `index`). Tuples use less memory, are slightly faster, and can be used as dict keys or set items when their contents are hashable.

!!! interview "2. How do you create a tuple with one element?"
    Add a trailing comma: `t = (5,)` or `t = 5,`. Without the comma, `(5)` is just the integer 5.

!!! interview "3. Can a tuple contain mutable objects?"
    Yes. A tuple can hold a list, and that list can be modified. The tuple itself still can't be reassigned to hold different objects. Such a tuple is not hashable, so it can't be a dict key.

!!! interview "4. What is tuple unpacking?"
    Assigning the items of a tuple to multiple variables in one statement: `x, y = (10, 20)`. With `*`, one variable can collect the remaining items as a list: `first, *rest = (1, 2, 3)`.

!!! interview "5. Why would you use a tuple instead of a list?"
    For fixed collections of related values (records, coordinates, config), to protect data from accidental changes, to use as dictionary keys, and for slightly better performance.

!!! interview "Scenario: a function returns `name, email` and you call `data = get_user()`. What is `data`?"
    A tuple, e.g. `('Ravi', 'ravi@example.com')`. Returning comma-separated values packs them into a tuple. Unpack directly: `name, email = get_user()`.

## Summary

| Concept | Remember |
|---------|----------|
| Tuple | Ordered, **immutable**, allows duplicates |
| Create | `(1, 2)`, `1, 2`, `tuple(list)`, single item `(x,)` |
| Access | Same as lists: `t[0]`, `t[-1]`, `t[1:3]`, `in` |
| Change | Not allowed; create a new tuple or convert to a list |
| Unpack | `a, b, c = t`, `first, *rest = t` |
| Methods | `count()`, `index()` only |
| Use for | Fixed records, coordinates, dict keys, multiple return values |

**Next lesson:** [Sets in Python](11-sets.md), collections of unique items.
