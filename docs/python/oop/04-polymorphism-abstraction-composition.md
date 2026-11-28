---
lesson: true
category: OOP & Advanced Python
short: Polymorphism
description: "Polymorphism, duck typing, operator overloading, abstraction with abstract base classes, composition and the four pillars of OOP in Python."
---

# Polymorphism, Abstraction & Composition

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Use polymorphism to treat different objects the same way
    - Explain duck typing and make your classes work with `len()` and `+`
    - Explain abstraction and enforce a contract with an abstract base class
    - Choose between inheritance ("is-a") and composition ("has-a")
    - Explain the four pillars of OOP with your own examples

**Prerequisites:** [Inheritance](03-inheritance.md)

!!! info "How this lesson is organised"
    **Part A** (sections 1 to 3) covers **polymorphism**, the third pillar.
    **Part B** (sections 4 to 7) covers **abstraction**, the fourth pillar, then composition, and ends with all four pillars side by side.

## What is Polymorphism?

**Polymorphism** ("many forms") means the **same method call** behaves differently depending on the object it's called on.

You've already written polymorphic code. In the last lesson, `User`, `Student` and `Admin` each had their own `dashboard()`:

```python
class User:
    def __init__(self, name: str) -> None:
        self.name = name

    def dashboard(self) -> str:
        return f"Welcome {self.name}"

class Student(User):
    def dashboard(self) -> str:
        return f"Welcome {self.name}: your courses and assignments"

class Admin(User):
    def dashboard(self) -> str:
        return f"Welcome {self.name}: users, payments, reports"

people = [User("Guest"), Student("Asha"), Admin("Ravi")]

for person in people:
    print(person.dashboard())        # same call, three behaviours
```

```{ .text .output }
Welcome Guest
Welcome Asha: your courses and assignments
Welcome Ravi: users, payments, reports
```

The loop never asks "is this a student or an admin?". It calls `dashboard()` and each object answers in its own way. That is polymorphism.

!!! example "Real-life analogy: a universal remote"
    You press the same **Power** button on a TV, an AC and a music system. Each device responds in its own way. The button (method name) is the same; the behaviour depends on the device (object).

### Why it matters

Here is the same idea in a checkout. First, the version **without** polymorphism:

```python
def checkout(method: str, amount: float) -> None:
    if method == "upi":
        print(f"Paid ₹{amount} via UPI")
    elif method == "card":
        print(f"Paid ₹{amount} via card (2% fee: ₹{amount * 0.02:.2f})")
    elif method == "wallet":
        print(f"Paid ₹{amount} from wallet")

checkout("card", 1500)
```

```{ .text .output }
Paid ₹1500 via card (2% fee: ₹30.00)
```

Every new payment type means editing `checkout()` and adding another `elif`. Now the polymorphic version:

```python
class PaymentMethod:
    def pay(self, amount: float) -> str:
        return f"Paid ₹{amount}"

class UPIPayment(PaymentMethod):
    def pay(self, amount: float) -> str:
        return f"Paid ₹{amount} via UPI"

class CardPayment(PaymentMethod):
    def pay(self, amount: float) -> str:
        return f"Paid ₹{amount} via card (2% fee: ₹{amount * 0.02:.2f})"

class WalletPayment(PaymentMethod):
    def pay(self, amount: float) -> str:
        return f"Paid ₹{amount} from wallet"

def checkout(method: PaymentMethod, amount: float) -> None:
    print(method.pay(amount))            # no if / elif

for method in [UPIPayment(), CardPayment(), WalletPayment()]:
    checkout(method, 1500)
```

```{ .text .output }
Paid ₹1500 via UPI
Paid ₹1500 via card (2% fee: ₹30.00)
Paid ₹1500 from wallet
```

`checkout()` has no `if` for each payment type. Adding `NetBankingPayment` tomorrow needs a new class and **no change** to `checkout()`. Code that already works stays untouched.

## Duck Typing

In the example above, every payment class inherits from `PaymentMethod`. In Python, that isn't required:

```python
class UPIPayment:
    def pay(self, amount: float) -> str:
        return f"Paid ₹{amount} via UPI"

class CashOnDelivery:                    # no shared parent
    def pay(self, amount: float) -> str:
        return f"Collect ₹{amount} at the door"

def checkout(method, amount: float) -> None:
    print(method.pay(amount))

checkout(UPIPayment(), 1500)
checkout(CashOnDelivery(), 1500)
```

```{ .text .output }
Paid ₹1500 via UPI
Collect ₹1500 at the door
```

Python doesn't check what class an object **is**. It only checks whether the object **has** the method being called. This is **duck typing**: "If it walks like a duck and quacks like a duck, it's a duck."

| | Polymorphism through inheritance | Duck typing |
|---|---|---|
| Classes share a parent | Yes | Not needed |
| What makes it work | Child overrides the parent's method | Object simply has the method |
| If the method is missing | The parent's version runs | `AttributeError` when the call is reached |
| Good for | Related classes with shared code | Unrelated classes that offer the same action |

!!! mistake "Common Mistake: an object without the method"
    ```python
    class GiftCard:
        def redeem(self, amount: float) -> str:      # named redeem, not pay
            return f"Redeemed ₹{amount}"

    def checkout(method, amount: float) -> None:
        print(method.pay(amount))

    checkout(GiftCard(), 500)
    ```

    ```{ .text .output }
    AttributeError: 'GiftCard' object has no attribute 'pay'
    ```

    Duck typing is flexible, but the mistake only shows up when that line runs, possibly in front of a customer. Part B shows how to catch it earlier.

## Polymorphism in Built-ins: Operator Overloading

Python's built-in functions and operators are polymorphic too:

```python
print(len("Python"), len([10, 20, 30]), len({"a": 1}))
print(5 + 3, "5" + "3", [5] + [3])
```

```{ .text .output }
6 3 1
8 53 [5, 3]
```

`len()` works on strings, lists and dicts. `+` adds numbers but joins strings and lists. How? Each type defines dunder methods: `len(x)` calls `x.__len__()`, and `a + b` calls `a.__add__(b)`.

Define them in your own class and your objects work with the same built-ins. Giving an operator a meaning for your class is called **operator overloading**.

```python
class Playlist:
    def __init__(self, songs: list[str]) -> None:
        self.songs = songs

    def __len__(self) -> int:                        # len(playlist)
        return len(self.songs)

    def __add__(self, other: "Playlist") -> "Playlist":     # playlist + playlist
        return Playlist(self.songs + other.songs)

    def __contains__(self, song: str) -> bool:       # "Song A" in playlist
        return song in self.songs

morning = Playlist(["Song A", "Song B"])
evening = Playlist(["Song C"])

combined = morning + evening
print(len(combined), combined.songs)
print("Song C" in combined, "Song Z" in combined)
```

```{ .text .output }
3 ['Song A', 'Song B', 'Song C']
True False
```

| You write | Python calls | You've seen it in |
|-----------|--------------|-------------------|
| `print(obj)` | `obj.__str__()` | Classes & Objects |
| `a == b` | `a.__eq__(b)` | Class Members & Encapsulation |
| `len(obj)` | `obj.__len__()` | This lesson |
| `a + b` | `a.__add__(b)` | This lesson |
| `x in obj` | `obj.__contains__(x)` | This lesson |
| `a < b` | `a.__lt__(b)` | Used by `sorted()` and `min()` |
| `obj[key]` | `obj.__getitem__(key)` | How lists and dicts do indexing |

??? question "Checkpoint A: predict the output before you expand this"
    ```python
    class Shape:
        def area(self) -> float:
            return 0

        def describe(self) -> str:
            return f"{type(self).__name__} with area {self.area()}"

    class Square(Shape):
        def __init__(self, side: float) -> None:
            self.side = side

        def area(self) -> float:
            return self.side ** 2

    class Dot(Shape):
        pass

    for shape in [Square(4), Dot()]:
        print(shape.describe())
    ```

    **Answer:**

    ```{ .text .output }
    Square with area 16
    Dot with area 0
    ```

    `describe()` is written once in `Shape`. `self.area()` runs `Square.area()` for the square, and falls back to `Shape.area()` for the dot, which doesn't override it.

    **Think about it:** is "area 0" a sensible answer for a shape whose author forgot to write `area()`? It hides a mistake. Part B fixes exactly this.

!!! info "End of Part A"
    You can now write code that works with many kinds of objects through one method name. This is a good place to pause in class.

## What is Abstraction?

**Abstraction** means showing **what** an object can do and hiding **how** it does it.

!!! example "Real-life analogy: driving a car"
    To drive, you use a steering wheel, an accelerator and a brake. You don't need to know how fuel injection or the gearbox works. And when you switch from a petrol car to an electric one, the controls are the same, even though everything under the bonnet has changed.

    The controls are the **interface** (the *what*). The engine is the **implementation** (the *how*).

You already rely on abstraction every day in Python. `sorted(marks)` gives you a sorted list, and you've never needed to know which sorting algorithm runs inside.

In your own code, abstraction means agreeing on **which methods a kind of object must offer**, separately from how each class implements them. In the checkout example, the agreement is: "every payment method has `pay(amount)`". `checkout()` depends only on that agreement.

!!! tip "Abstraction vs encapsulation"
    These two are easy to mix up, and interviewers know it.

    | | Encapsulation | Abstraction |
    |---|---|---|
    | Question it answers | How do I **protect** the data? | What should the outside world **see**? |
    | Focus | Hiding **data** behind methods | Hiding **complexity** behind a simple interface |
    | Python tools | `_name`, `@property` | Abstract base classes, well-named methods |
    | Example | `_balance` changes only through `deposit()` | `checkout()` only knows `pay()` exists |

## Abstract Base Classes

So far the agreement "every payment method has `pay()`" is only a promise. Nothing enforces it. Two things can go wrong:

- Someone creates a plain `PaymentMethod()`, which isn't a real payment type.
- Someone writes a child class and forgets `pay()`. The parent's version runs silently, or with duck typing the program crashes later.

Python's `abc` module turns the promise into a **contract**:

```python
from abc import ABC, abstractmethod

class PaymentMethod(ABC):                 # ABC = Abstract Base Class
    @abstractmethod
    def pay(self, amount: float) -> str:
        """Every payment method must implement this."""

    def receipt(self, amount: float) -> str:      # a normal method: children inherit it
        return f"Receipt: {self.pay(amount)}"

class UPIPayment(PaymentMethod):
    def pay(self, amount: float) -> str:
        return f"Paid ₹{amount} via UPI"

class BrokenPayment(PaymentMethod):
    pass                                  # forgot to implement pay()

print(UPIPayment().receipt(500))
BrokenPayment()
```

```{ .text .output }
Receipt: Paid ₹500 via UPI
TypeError: Can't instantiate abstract class BrokenPayment without an implementation for abstract method 'pay'
```

- A class that inherits from `ABC` and has at least one `@abstractmethod` is an **abstract class**. You cannot create objects from it: `PaymentMethod()` raises the same `TypeError`.
- A child must implement **every** abstract method before it can be instantiated.
- An abstract class can still contain normal methods, like `receipt()`, which children inherit.
- The mistake is caught the moment the object is **created**, not later when `pay()` happens to be called.

| | Normal parent class | Abstract base class |
|---|---|---|
| Can create objects from it | Yes | No |
| Child forgets a method | Parent's version runs silently | `TypeError` on creation |
| Purpose | Share working code | Define a contract, and optionally share code |

!!! realworld "In Real Projects"
    Payment gateways, notification channels, file storage (local disk, Amazon S3) and report exporters (PDF, Excel, CSV) are almost always written as one abstract base class with several implementations. The rest of the application depends only on the base class, so a new gateway or storage provider can be added without touching existing code.

## Composition: "has-a" Instead of "is-a"

Not everything should be inheritance. A `Car` **has an** `Engine`; it **isn't an** engine. Model "has-a" relationships by storing objects as attributes. This is called **composition**.

```python
class Address:
    def __init__(self, city: str, pincode: str) -> None:
        self.city = city
        self.pincode = pincode

    def __str__(self) -> str:
        return f"{self.city} - {self.pincode}"

class Customer:
    def __init__(self, name: str, address: Address) -> None:
        self.name = name
        self.address = address            # Customer HAS an Address

c = Customer("Asha", Address("Hyderabad", "500081"))
print(f"{c.name} lives in {c.address}")
print(c.address.city)
```

```{ .text .output }
Asha lives in Hyderabad - 500081
Hyderabad
```

Composition and polymorphism work well together. An order **has a** payment method, and it doesn't care which one:

```python
class UPIPayment:
    def pay(self, amount: float) -> str:
        return f"Paid ₹{amount} via UPI"

class WalletPayment:
    def pay(self, amount: float) -> str:
        return f"Paid ₹{amount} from wallet"

class Order:
    def __init__(self, amount: float, payment) -> None:
        self.amount = amount
        self.payment = payment            # Order HAS a payment method

    def complete(self) -> str:
        return "Order complete. " + self.payment.pay(self.amount)

print(Order(1500, UPIPayment()).complete())
print(Order(800, WalletPayment()).complete())
```

```{ .text .output }
Order complete. Paid ₹1500 via UPI
Order complete. Paid ₹800 from wallet
```

| Use | When | Example |
|-----|------|---------|
| **Inheritance** | "is-a" | `Student` is a `User` |
| **Composition** | "has-a" | `Order` has `OrderItem`s, `Customer` has an `Address` |

!!! tip "Prefer composition when in doubt"
    Deep inheritance chains are hard to change: a small edit in a grandparent can break every class below it. Many experienced developers follow the rule **"favour composition over inheritance"**. Use inheritance when "is-a" is clearly true and the child really is a specialised version of the parent.

## The Four Pillars of OOP

You've now learned all four. This table is the one to remember for interviews.

| Pillar | Meaning | One-line example | Lesson |
|--------|---------|------------------|--------|
| **Encapsulation** | Bundle data with methods and protect it | `_balance` changes only through `deposit()` | [Class Members & Encapsulation](02-class-members-and-encapsulation.md) |
| **Inheritance** | Reuse and extend an existing class | `class Student(User)` | [Inheritance](03-inheritance.md) |
| **Polymorphism** | Same call, different behaviour | `method.pay(amount)` works for UPI, card and wallet | This lesson |
| **Abstraction** | Show what, hide how | `PaymentMethod(ABC)` with an abstract `pay()` | This lesson |

All four in one small example:

```python
from abc import ABC, abstractmethod

class Account(ABC):                                   # abstraction: a contract
    def __init__(self, owner: str, balance: float) -> None:
        self.owner = owner
        self._balance = balance                       # encapsulation: protected data

    @property
    def balance(self) -> float:
        return self._balance

    @abstractmethod
    def monthly_interest(self) -> float:
        """Each account type calculates interest its own way."""

class SavingsAccount(Account):                        # inheritance
    def monthly_interest(self) -> float:
        return self._balance * 0.04 / 12

class CurrentAccount(Account):                        # inheritance
    def monthly_interest(self) -> float:
        return 0.0

accounts = [SavingsAccount("Asha", 60000), CurrentAccount("Ravi", 60000)]
for account in accounts:                              # polymorphism
    print(f"{account.owner}: ₹{account.monthly_interest():.2f}")
```

```{ .text .output }
Asha: ₹200.00
Ravi: ₹0.00
```

??? question "Checkpoint B: predict the output before you expand this"
    ```python
    from abc import ABC, abstractmethod

    class Notifier(ABC):
        @abstractmethod
        def send(self, message: str) -> str:
            ...

    class EmailNotifier(Notifier):
        def send(self, message: str) -> str:
            return f"EMAIL: {message}"

    class SMSNotifier(Notifier):
        def send_sms(self, message: str) -> str:
            return f"SMS: {message}"

    print(EmailNotifier().send("Class at 7 PM"))
    print(SMSNotifier().send_sms("Class at 7 PM"))
    ```

    **Answer:**

    ```{ .text .output }
    EMAIL: Class at 7 PM
    TypeError: Can't instantiate abstract class SMSNotifier without an implementation for abstract method 'send'
    ```

    `SMSNotifier` wrote `send_sms()` instead of `send()`, so the abstract method is still missing. The error appears at `SMSNotifier()`, before `send_sms` is ever called. That early failure is the whole point of an abstract class.

## Common Mistakes

| Mistake | Error / Result | Fix |
|---------|----------------|-----|
| `if isinstance(...)` / `elif` chains for each type | Every new type means editing old code | Give each class the same method and just call it |
| Method name differs between classes (`pay` vs `make_payment`) | `AttributeError` at the call | Agree on one name; enforce it with an ABC |
| Instantiating an abstract class | `TypeError: Can't instantiate abstract class ...` | Create objects from a concrete child |
| Child forgets one abstract method | Same `TypeError` when the child is instantiated | Implement **every** `@abstractmethod` |
| `@abstractmethod` without inheriting from `ABC` | No enforcement; objects are created anyway | `class Base(ABC):` |
| Using inheritance for "has-a" (`class Car(Engine)`) | Awkward, fragile design | Store the object as an attribute |
| `__add__` that changes `self` and returns nothing | `a + b` gives `None` and `a` is modified | Return a **new** object |

## Practice Exercises

**Easy**

1. Create classes `Dog`, `Cat` and `Cow`, each with a `speak()` method returning its sound. Loop over a list containing one of each and print what it says.
2. Create a class `Team` that holds a list of member names. Add `__len__` so `len(team)` returns the number of members.
3. Create an `Engine` class with a `start()` method and a `Car` class that **has an** engine. `car.start()` should call the engine's `start()` and add the car's name.

**Medium**

4. Create `Shape` with a method `area()` returning 0, and children `Circle`, `Rectangle` and `Triangle` that override `area()`. Loop over a list of shapes and print each class name and area.
5. Make `Shape` an abstract class so `area()` must be implemented. Show what happens if a child forgets.
6. Create a class `Money` with `rupees`. Add `__add__` so two `Money` objects can be added, `__eq__` so they can be compared, and `__str__` so they print as `₹1,500`.

**Challenge**

7. Model a notification system: an abstract `Notifier` with `send(user, message)`, and `EmailNotifier`, `SMSNotifier` and `WhatsAppNotifier` implementations (each prints its own format). Create a `User` class that **has a** list of preferred notifiers (composition) and a method `notify(message)` that sends through all of them.

??? success "Solution 1: animals"

    ```python
    class Dog:
        def speak(self) -> str:
            return "Woof"

    class Cat:
        def speak(self) -> str:
            return "Meow"

    class Cow:
        def speak(self) -> str:
            return "Moo"

    for animal in [Dog(), Cat(), Cow()]:
        print(type(animal).__name__, "says", animal.speak())
    # Dog says Woof / Cat says Meow / Cow says Moo
    ```

??? success "Solution 2: Team"

    ```python
    class Team:
        def __init__(self, members: list[str]) -> None:
            self.members = members

        def __len__(self) -> int:
            return len(self.members)

    print(len(Team(["Asha", "Ravi", "Meena"])))     # 3
    ```

??? success "Solution 3: Car has an Engine"

    ```python
    class Engine:
        def __init__(self, kind: str) -> None:
            self.kind = kind

        def start(self) -> str:
            return f"{self.kind} engine started"

    class Car:
        def __init__(self, name: str, engine: Engine) -> None:
            self.name = name
            self.engine = engine              # composition

        def start(self) -> str:
            return f"{self.name}: {self.engine.start()}"

    print(Car("Nexon", Engine("Electric")).start())     # Nexon: Electric engine started
    ```

??? success "Solution 4 and 5: Shape"

    ```python
    import math
    from abc import ABC, abstractmethod

    class Shape(ABC):
        @abstractmethod
        def area(self) -> float:
            ...

    class Circle(Shape):
        def __init__(self, r: float) -> None:
            self.r = r

        def area(self) -> float:
            return round(math.pi * self.r ** 2, 2)

    class Rectangle(Shape):
        def __init__(self, length: float, width: float) -> None:
            self.length = length
            self.width = width

        def area(self) -> float:
            return self.length * self.width

    class Triangle(Shape):
        def __init__(self, base: float, height: float) -> None:
            self.base = base
            self.height = height

        def area(self) -> float:
            return 0.5 * self.base * self.height

    for shape in [Circle(3), Rectangle(4, 5), Triangle(6, 2)]:
        print(type(shape).__name__, shape.area())
    # Circle 28.27 / Rectangle 20 / Triangle 6.0

    class Hexagon(Shape):
        pass                                  # forgot area()

    Hexagon()
    # TypeError: Can't instantiate abstract class Hexagon without an implementation for abstract method 'area'
    ```

    For exercise 4 on its own, drop `ABC` and `@abstractmethod` and make `Shape.area()` return `0`.

??? success "Solution 6: Money"

    ```python
    class Money:
        def __init__(self, rupees: int) -> None:
            self.rupees = rupees

        def __add__(self, other: "Money") -> "Money":
            return Money(self.rupees + other.rupees)

        def __eq__(self, other: object) -> bool:
            if not isinstance(other, Money):
                return False
            return self.rupees == other.rupees

        def __str__(self) -> str:
            return f"₹{self.rupees:,}"

    total = Money(1000) + Money(500)
    print(total)                          # ₹1,500
    print(total == Money(1500))           # True
    ```

??? success "Solution 7: notification system"

    ```python
    from abc import ABC, abstractmethod

    class Notifier(ABC):
        @abstractmethod
        def send(self, user: "User", message: str) -> None:
            ...

    class EmailNotifier(Notifier):
        def send(self, user: "User", message: str) -> None:
            print(f"[EMAIL to {user.email}] {message}")

    class SMSNotifier(Notifier):
        def send(self, user: "User", message: str) -> None:
            print(f"[SMS to {user.phone}] {message[:40]}")

    class WhatsAppNotifier(Notifier):
        def send(self, user: "User", message: str) -> None:
            print(f"[WhatsApp to {user.phone}] {message}")

    class User:
        def __init__(self, name: str, email: str, phone: str, notifiers: list[Notifier]) -> None:
            self.name = name
            self.email = email
            self.phone = phone
            self.notifiers = notifiers        # composition

        def notify(self, message: str) -> None:
            for notifier in self.notifiers:   # polymorphism
                notifier.send(self, message)

    asha = User("Asha", "asha@ksr.com", "98765 43210", [EmailNotifier(), WhatsAppNotifier()])
    asha.notify("Your class starts at 7 PM today")
    # [EMAIL to asha@ksr.com] Your class starts at 7 PM today
    # [WhatsApp to 98765 43210] Your class starts at 7 PM today
    ```

!!! note "Mini Assignment"
    Finish the OOP version of `student_manager`. Make `Person` an abstract class with an abstract `describe()` method, implemented by `Student` and `Trainer`. Add a `Batch` class that **has** one trainer and many students (composition), with `__len__` returning the number of students. `Batch.report()` should print the trainer, each student's grade and the batch average, and use polymorphism by calling `describe()` on every person.

## Interview Questions

!!! interview "1. What is polymorphism? Give an example."
    The ability of different objects to respond to the same method call in their own way. Example: `UPIPayment`, `CardPayment` and `WalletPayment` all implement `pay()`, so `checkout(method, amount)` works with any of them. Built-ins like `len()` and `+` are polymorphic too.

!!! interview "2. What is duck typing?"
    Python decides whether an object is suitable by the methods it has, not by its class or parent. If an object has a `pay()` method, it can be used wherever `pay()` is called, with no shared base class required.

!!! interview "3. What is operator overloading?"
    Giving an operator or built-in function a meaning for your own class by defining dunder methods: `__add__` for `+`, `__eq__` for `==`, `__len__` for `len()`, `__lt__` for `<`.

!!! interview "4. What is abstraction? How is it different from encapsulation?"
    Abstraction exposes what an object does and hides how it does it, usually through an interface or abstract class. Encapsulation hides an object's data and allows changes only through controlled methods. Abstraction is about design (what to show); encapsulation is about protection (what to restrict).

!!! interview "5. What is an abstract class? Can you instantiate one?"
    A class that inherits from `ABC` and has one or more `@abstractmethod` methods. It defines a contract for its children and cannot be instantiated. A child can be instantiated only after it implements every abstract method.

!!! interview "6. What is the difference between inheritance and composition?"
    Inheritance models "is-a": the child is a specialised version of the parent and inherits its members. Composition models "has-a": an object holds other objects as attributes and delegates work to them. Composition is more flexible and is preferred when "is-a" is not clearly true.

!!! interview "7. What are the four pillars of OOP?"
    Encapsulation (bundle and protect data), inheritance (reuse and extend classes), polymorphism (same interface, different behaviour) and abstraction (expose what, hide how).

!!! interview "Scenario: your `checkout()` function has a long `if/elif` chain on payment type, and every new gateway breaks something. How would you redesign it?"
    Define an abstract `PaymentMethod` with a `pay()` method and one class per gateway. `checkout()` receives a payment object and calls `pay()` on it. A new gateway becomes a new class, and the existing, tested code is not edited.

## Summary

| Concept | Remember |
|---------|----------|
| Polymorphism | Same call, different behaviour: `person.dashboard()` |
| Why it matters | Replaces `if/elif` chains; new types need no changes to old code |
| Duck typing | An object works if it has the method; no shared parent needed |
| Operator overloading | `__len__`, `__add__`, `__contains__`, `__eq__` hook into built-ins |
| Abstraction | Show what an object does, hide how |
| Abstract class | `ABC` + `@abstractmethod`: a contract children must implement |
| Composition | "has-a": store objects as attributes; often better than deep inheritance |
| 4 pillars | Encapsulation, inheritance, polymorphism, abstraction |

**Next lesson:** [Exception Handling](05-exception-handling.md), dealing with errors gracefully.
