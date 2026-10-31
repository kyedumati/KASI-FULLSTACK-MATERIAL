---
lesson: true
category: OOP & Advanced Python
short: Files
description: Reading and writing text files, file modes, the with statement, working with CSV and JSON files, pathlib and handling file errors.
---

# File Handling

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Open, read and write text files with the right file mode
    - Use the `with` statement so files are always closed
    - Read files line by line, even very large ones
    - Read and write CSV and JSON files
    - Handle file errors and work with paths using `pathlib`

**Prerequisites:** [Exception Handling](03-exception-handling.md)

## Why Files?

Every variable you've created disappears when the program ends. To keep data **between runs** (a to-do list, student records, logs, reports), you need to save it somewhere permanent. The simplest place is a **file**.

!!! example "Real-life analogy: a notebook"
    Your program's memory is like a whiteboard: fast, but wiped clean when you leave. A file is a **notebook**: you open it, read or write, and close it, and the notes are still there tomorrow.

| File type | Extension | Used for |
|-----------|-----------|----------|
| Plain text | `.txt`, `.log` | Notes, logs |
| CSV | `.csv` | Tables: spreadsheets, exports, reports |
| JSON | `.json` | Structured data, config, API data |

Later in the course you'll store data in **MySQL**, which is built for many users and large amounts of data. File handling is still used everywhere for logs, imports, exports, config and reports.

## Opening Files and File Modes

The built-in `open()` function opens a file and returns a file object:

```python
file = open("notes.txt", "w")
file.write("Learning Python file handling\n")
file.close()
```

`open(path, mode)` takes the file path and a **mode**:

| Mode | Meaning | If the file exists | If the file doesn't exist |
|------|---------|--------------------|---------------------------|
| `"r"` | Read (default) | Opens it | `FileNotFoundError` |
| `"w"` | Write | **Erases all content** first | Creates it |
| `"a"` | Append | Adds to the end | Creates it |
| `"x"` | Create | `FileExistsError` | Creates it |
| `"r+"` | Read and write | Opens it | `FileNotFoundError` |

Add `b` for binary files like images or PDFs: `"rb"`, `"wb"`.

!!! mistake "Common Mistake: `\"w\"` erases the file"
    Opening an existing file with `"w"` **deletes everything in it** immediately, even if you write nothing. Use `"a"` to add to a file, and `"r"` when you only need to read.

## The with Statement

If your program crashes before `file.close()`, the file may stay open and data may not be saved. The `with` statement closes the file **automatically**, even if an error occurs:

```python
with open("notes.txt", "w") as file:
    file.write("Line 1: Variables\n")
    file.write("Line 2: Loops\n")
    file.write("Line 3: Functions\n")

# the file is closed here automatically
print(file.closed)
```

```{ .text .output }
True
```

!!! tip "Always use `with`"
    Professional Python code opens files with `with open(...) as f:`. It's shorter, safer, and you never forget to close the file. Objects that work with `with` are called **context managers**; database connections work the same way.

Always specify the **encoding** for text files, so characters like `₹`, `é` or Hindi and Telugu text work on every operating system:

```python
with open("prices.txt", "w", encoding="utf-8") as f:
    f.write("Laptop: ₹55,000\n")
```

## Reading Files

Assume `notes.txt` contains:

```text title="notes.txt"
Line 1: Variables
Line 2: Loops
Line 3: Functions
```

### Three ways to read

```python
with open("notes.txt", encoding="utf-8") as f:
    content = f.read()            # whole file as one string
print(repr(content))

with open("notes.txt", encoding="utf-8") as f:
    lines = f.readlines()         # list of lines (with \n)
print(lines)

with open("notes.txt", encoding="utf-8") as f:
    first = f.readline()          # one line at a time
print(repr(first))
```

```{ .text .output }
'Line 1: Variables\nLine 2: Loops\nLine 3: Functions\n'
['Line 1: Variables\n', 'Line 2: Loops\n', 'Line 3: Functions\n']
'Line 1: Variables\n'
```

### Looping line by line: the best way

```python
with open("notes.txt", encoding="utf-8") as f:
    for number, line in enumerate(f, start=1):
        print(number, line.strip())
```

```{ .text .output }
1 Line 1: Variables
2 Line 2: Loops
3 Line 3: Functions
```

Looping over the file object reads **one line at a time**, so it works even for a 10 GB log file without loading it all into memory. Use `.strip()` to remove the trailing newline `\n`.

| Method | Returns | Memory |
|--------|---------|--------|
| `f.read()` | Whole file as one string | Loads everything |
| `f.readlines()` | List of all lines | Loads everything |
| `f.readline()` | Next single line | One line |
| `for line in f:` | Each line in turn | One line, best for big files |

## Writing and Appending

```python
tasks = ["Revise loops", "Practice functions", "Push code to GitHub"]

with open("todo.txt", "w", encoding="utf-8") as f:
    for task in tasks:
        f.write(task + "\n")              # write() doesn't add \n for you

with open("todo.txt", "a", encoding="utf-8") as f:
    f.write("Attend mock interview\n")    # added at the end

with open("todo.txt", encoding="utf-8") as f:
    print(f.read())
```

```{ .text .output }
Revise loops
Practice functions
Push code to GitHub
Attend mock interview

```

`f.writelines(list_of_strings)` writes several strings at once (again, without adding newlines). You can also use `print("text", file=f)`, which adds the newline for you.

!!! realworld "In Real Projects"
    Every server writes **log files** in append mode: each request, error or login attempt is added as a new line with a timestamp. When something breaks in production, developers search these logs to find out what happened.

## CSV Files

**CSV** (Comma-Separated Values) stores tables as plain text, and Excel and Google Sheets can open it directly.

```text title="students.csv"
name,course,marks
Asha,Python,85
Ravi,Java,72
Kiran,Python,91
```

### Reading CSV with `csv.DictReader`

```python
import csv

with open("students.csv", encoding="utf-8", newline="") as f:
    reader = csv.DictReader(f)            # each row becomes a dict
    for row in reader:
        print(row["name"], row["course"], int(row["marks"]))
```

```{ .text .output }
Asha Python 85
Ravi Java 72
Kiran Python 91
```

!!! warning "CSV values are always strings"
    `row["marks"]` is `"85"`, not `85`. Convert numbers with `int()` or `float()` before doing maths.

### Writing CSV with `csv.DictWriter`

```python
import csv

results = [
    {"name": "Asha", "marks": 85, "grade": "B"},
    {"name": "Kiran", "marks": 91, "grade": "A"},
]

with open("results.csv", "w", encoding="utf-8", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["name", "marks", "grade"])
    writer.writeheader()
    writer.writerows(results)

with open("results.csv", encoding="utf-8") as f:
    print(f.read())
```

```{ .text .output }
name,marks,grade
Asha,85,B
Kiran,91,A

```

Always pass `newline=""` when opening CSV files; otherwise you may get blank lines between rows on Windows. The `csv` module also handles tricky values like commas inside quotes (`"Hyderabad, Telangana"`), which a simple `line.split(",")` would break.

## JSON Files

**JSON** is the standard format for structured data, the same format APIs use.

```python
import json

config = {
    "app_name": "Student Portal",
    "debug": True,
    "max_upload_mb": 10,
    "allowed_types": ["pdf", "png", "jpg"],
}

with open("config.json", "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)          # dict → file

with open("config.json", encoding="utf-8") as f:
    loaded = json.load(f)                   # file → dict

print(loaded["app_name"], loaded["allowed_types"])
print(type(loaded))
```

```{ .text .output }
Student Portal ['pdf', 'png', 'jpg']
<class 'dict'>
```

| Function | Works with | Direction |
|----------|-----------|-----------|
| `json.dump(obj, f)` | A file | Python → file |
| `json.load(f)` | A file | File → Python |
| `json.dumps(obj)` | A string | Python → JSON text |
| `json.loads(text)` | A string | JSON text → Python |

Memory trick: the **s** stands for **string**.

### A complete save/load pattern

```python
import json
from pathlib import Path

DATA_FILE = Path("students.json")

def load_students():
    if not DATA_FILE.exists():
        return {}
    with open(DATA_FILE, encoding="utf-8") as f:
        return json.load(f)

def save_students(students):
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(students, f, indent=2)

students = load_students()
students["101"] = {"name": "Asha", "marks": 85}
save_students(students)
print(load_students())
```

```{ .text .output }
{'101': {'name': 'Asha', 'marks': 85}}
```

Run it again and the data is still there. This is exactly how you'll make your `student_manager` remember its data.

## Paths and File Errors

### Working with paths using `pathlib`

```python
from pathlib import Path

reports = Path("reports")
reports.mkdir(exist_ok=True)

report_file = reports / "october.txt"          # works on Windows, macOS and Linux
report_file.write_text("Total students: 42\n", encoding="utf-8")

print(report_file.read_text(encoding="utf-8").strip())
print(report_file.name, report_file.suffix, report_file.exists())
print([p.name for p in reports.glob("*.txt")])
```

```{ .text .output }
Total students: 42
october.txt .txt True
['october.txt']
```

!!! tip "Relative paths depend on where you run Python"
    `open("data.txt")` looks in the **current working directory**, which is where you ran `python`, not necessarily the folder your script is in. To always find files next to your script, build the path from the script's location: `Path(__file__).parent / "data.txt"`.

### Handling file errors

```python
from pathlib import Path

def read_config(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        print(f"Config file not found: {path}. Using defaults.")
        return ""
    except PermissionError:
        print(f"No permission to read {path}")
        return ""

read_config("missing_config.txt")
```

```{ .text .output }
Config file not found: missing_config.txt. Using defaults.
```

| Exception | Cause |
|-----------|-------|
| `FileNotFoundError` | The path doesn't exist (wrong name, wrong folder) |
| `PermissionError` | No permission, or the file is open in another program (common on Windows) |
| `IsADirectoryError` | You gave a folder path instead of a file |
| `UnicodeDecodeError` | Wrong encoding; add `encoding="utf-8"` |
| `json.JSONDecodeError` | The file isn't valid JSON (empty or corrupted) |

## Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| Opening with `"w"` to add data | Old content erased | Use `"a"` |
| Not using `with` | File may stay open, data not saved | `with open(...) as f:` |
| Forgetting `\n` in `write()` | Everything on one line | `f.write(text + "\n")` |
| Reading a file twice from the same object | Second read returns `""` | Reopen it, or use `f.seek(0)` |
| No `encoding="utf-8"` | `UnicodeDecodeError` on another OS | Always pass the encoding for text files |
| Doing maths on CSV values directly | `TypeError` or string joining | Convert with `int()` / `float()` |
| Running from a different folder | `FileNotFoundError` | Use `Path(__file__).parent / "file"` |
| Backslashes in Windows paths: `"C:\new\test.txt"` | `\n` and `\t` become newline and tab | Use `pathlib`, forward slashes, or `r"C:\new\test.txt"` |

## Practice Exercises

**Easy**

1. Write 5 of your favourite programming topics to `topics.txt`, one per line. Then read and print them with line numbers.
2. Append two more topics to the same file without erasing the existing ones.
3. Count the number of lines, words and characters in a text file.

**Medium**

4. Read `students.csv` (from this lesson) and print the average marks and the topper's name.
5. Write a function `search_log(path, word)` that prints every line (with its line number) containing a word, case-insensitively.
6. Save a dict of settings to `settings.json`, load it back, change one value, and save it again.

**Challenge**

7. **Expense tracker with persistence:** write a program that stores expenses (`date`, `category`, `amount`) in `expenses.csv`. Menu options: add an expense (appended to the CSV), show all expenses, show the total per category, and export a summary to `summary.json`. The data must survive restarts, and missing files must not crash the program.

??? success "Solutions (click to expand)"

    ```python
    import csv, json
    from pathlib import Path

    # 1
    topics = ["Variables", "Loops", "Functions", "OOP", "Files"]
    with open("topics.txt", "w", encoding="utf-8") as f:
        for t in topics:
            f.write(t + "\n")
    with open("topics.txt", encoding="utf-8") as f:
        for i, line in enumerate(f, start=1):
            print(i, line.strip())

    # 2
    with open("topics.txt", "a", encoding="utf-8") as f:
        f.write("Decorators\nGenerators\n")

    # 3
    text = Path("topics.txt").read_text(encoding="utf-8")
    print("Lines:", len(text.splitlines()), "Words:", len(text.split()), "Chars:", len(text))

    # 4
    with open("students.csv", encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    marks = [int(r["marks"]) for r in rows]
    topper = max(rows, key=lambda r: int(r["marks"]))
    print("Average:", sum(marks) / len(marks), "Topper:", topper["name"])

    # 5
    def search_log(path, word):
        with open(path, encoding="utf-8") as f:
            for n, line in enumerate(f, start=1):
                if word.lower() in line.lower():
                    print(f"{n}: {line.rstrip()}")

    search_log("topics.txt", "o")

    # 6
    settings = {"theme": "light", "font_size": 14}
    Path("settings.json").write_text(json.dumps(settings, indent=2), encoding="utf-8")
    settings = json.loads(Path("settings.json").read_text(encoding="utf-8"))
    settings["theme"] = "dark"
    Path("settings.json").write_text(json.dumps(settings, indent=2), encoding="utf-8")
    print(settings)
    ```

    ```python
    # 7
    import csv, json
    from collections import defaultdict
    from datetime import date
    from pathlib import Path

    FILE = Path("expenses.csv")
    FIELDS = ["date", "category", "amount"]

    def add_expense(category, amount):
        new_file = not FILE.exists()
        with open(FILE, "a", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=FIELDS)
            if new_file:
                writer.writeheader()
            writer.writerow({"date": date.today().isoformat(), "category": category, "amount": amount})

    def load_expenses():
        if not FILE.exists():
            return []
        with open(FILE, encoding="utf-8", newline="") as f:
            return list(csv.DictReader(f))

    def totals_by_category():
        totals = defaultdict(float)
        for e in load_expenses():
            totals[e["category"]] += float(e["amount"])
        return dict(totals)

    while True:
        choice = input("\n1 Add  2 Show  3 Totals  4 Export  5 Exit: ")
        if choice == "1":
            category = input("Category: ").strip().lower()
            try:
                amount = float(input("Amount: "))
            except ValueError:
                print("Amount must be a number")
                continue
            add_expense(category, amount)
        elif choice == "2":
            for e in load_expenses():
                print(f"{e['date']}  {e['category']:<12} ₹{float(e['amount']):>9,.2f}")
        elif choice == "3":
            for cat, total in totals_by_category().items():
                print(f"{cat:<12} ₹{total:,.2f}")
        elif choice == "4":
            with open("summary.json", "w", encoding="utf-8") as f:
                json.dump(totals_by_category(), f, indent=2)
            print("Saved summary.json")
        elif choice == "5":
            break
    ```

!!! note "Mini Assignment"
    Give your class-based `student_manager` permanent storage: add `save(path)` and `load(path)` methods to `StudentManager` that store all students in `students.json`. Load automatically at start-up and save after every change. Also add an **Export to CSV** menu option that writes `report.csv` with roll number, name, percentage and grade, ready to open in Excel.

## Interview Questions

!!! interview "1. What are the different file modes in Python?"
    `"r"` read (default; error if missing), `"w"` write (creates or truncates), `"a"` append (creates if missing; writes at the end), `"x"` exclusive create (error if it exists), `"r+"` read/write, plus `"b"` for binary (`"rb"`, `"wb"`) and `"t"` for text (default).

!!! interview "2. Why should you use the `with` statement for files?"
    It's a context manager that guarantees the file is closed when the block ends, even if an exception occurs, which prevents resource leaks and unsaved data. It also makes the code shorter and clearer.

!!! interview "3. What is the difference between `read()`, `readline()` and `readlines()`?"
    `read()` returns the whole file as one string. `readline()` returns the next single line. `readlines()` returns a list of all lines. For large files, iterate over the file object (`for line in f`) to read one line at a time.

!!! interview "4. What is the difference between `json.dump()` and `json.dumps()`?"
    `json.dump(obj, file)` writes JSON directly to a file object. `json.dumps(obj)` returns the JSON as a string. Similarly, `json.load(file)` reads from a file and `json.loads(text)` parses a string.

!!! interview "5. How would you process a 20 GB log file in Python?"
    Never load it all with `read()`. Iterate line by line with `for line in open(path, encoding="utf-8")`, which streams one line at a time with constant memory, optionally using generators to filter and aggregate as you go.

!!! interview "Scenario: a script works on your laptop but gets `FileNotFoundError` when run from another folder or by a scheduler. Why?"
    It uses a relative path, which is resolved against the current working directory, not the script's folder. Build the path from the script's location: `Path(__file__).resolve().parent / "data.csv"`.

## Summary

| Task | Code |
|------|------|
| Open safely | `with open(path, mode, encoding="utf-8") as f:` |
| Modes | `r` read, `w` overwrite, `a` append, `x` create, `b` binary |
| Read | `f.read()`, `f.readlines()`, `for line in f:` (best for big files) |
| Write | `f.write(text + "\n")`, `print(text, file=f)` |
| CSV | `csv.DictReader(f)`, `csv.DictWriter(f, fieldnames=...)`, `newline=""` |
| JSON | `json.dump(obj, f, indent=2)`, `json.load(f)` |
| Paths | `Path("dir") / "file.txt"`, `.exists()`, `.read_text()`, `Path(__file__).parent` |
| Errors | `FileNotFoundError`, `PermissionError`, `json.JSONDecodeError` |

**Next lesson:** [Decorators & Generators](05-decorators-and-generators.md), powerful tools used throughout Python frameworks.
