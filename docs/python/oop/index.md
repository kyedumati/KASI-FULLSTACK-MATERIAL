---
hide:
  - toc
---

# OOP & Advanced Python

Model real-world things with classes, write programs that don't crash, work with files, and talk to web APIs. These are the skills every FastAPI and Django project is built on.

!!! abstract "By the end of this module, you can"
    - Design classes with attributes, methods and protected data
    - Reuse and extend classes with inheritance, and explain the four pillars of OOP
    - Handle errors gracefully and create your own exceptions
    - Read and write text, CSV and JSON files
    - Write decorators and generators, and call REST APIs with `requests`

## The Four Pillars of OOP: Your Roadmap

Object-oriented programming rests on four ideas. The first four lessons teach them one at a time, and interviewers ask about them more than anything else in this module. Keep this table in mind as you go.

| Pillar | In one line | Everyday picture | Lesson |
|--------|-------------|------------------|--------|
| **Encapsulation** | Keep data and its rules together, and protect the data | An ATM: you use the buttons, not the vault | [Class Members & Encapsulation](02-class-members-and-encapsulation.md) |
| **Inheritance** | Build a new class on top of an existing one | A child inherits family traits and adds their own | [Inheritance](03-inheritance.md) |
| **Polymorphism** | One method name, different behaviour per object | One Power button works on a TV, an AC and a speaker | [Polymorphism, Abstraction & Composition](04-polymorphism-abstraction-composition.md) |
| **Abstraction** | Show what something does, hide how it does it | You drive with a steering wheel, not the engine | [Polymorphism, Abstraction & Composition](04-polymorphism-abstraction-composition.md) |

Before the pillars, [Classes & Objects](01-classes-and-objects.md) gives you the building blocks: what a class is and how an object holds its own data.

<div class="grid cards ksr-topics" markdown>

-   Lessons

    1. [Classes & Objects](01-classes-and-objects.md)
    1. [Class Members & Encapsulation](02-class-members-and-encapsulation.md)
    1. [Inheritance](03-inheritance.md)
    1. [Polymorphism, Abstraction & Composition](04-polymorphism-abstraction-composition.md)
    1. [Exception Handling](05-exception-handling.md)
    1. [File Handling](06-file-handling.md)
    1. [Decorators & Generators](07-decorators-and-generators.md)
    1. [Working with JSON & APIs](08-working-with-json-and-apis.md)

</div>

!!! tip "How to study this module"
    - Lessons 1 to 4 are split into **Part A** and **Part B**. Each part fits one sitting.
    - Try every **checkpoint** before expanding the answer. Predicting the output is the fastest way to find out what you haven't understood yet.
    - One project, `student_manager`, grows across the module. Do each mini assignment before starting the next lesson.

!!! info "Python version"
    The examples and error messages in this module are from **Python 3.12 or newer**. On older versions the code behaves the same, but the wording of some error messages differs slightly.
