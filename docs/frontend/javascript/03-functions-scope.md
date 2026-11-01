---
lesson: true
category: JavaScript
short: Functions
description: Writing reusable code with functions - declarations, expressions and arrow functions, parameters, default and rest parameters, return values, scope (global, function and block), hoisting, closures, callbacks and higher-order functions, and pure functions - building the KSR Store's pricing helpers.
---

# Functions & Scope

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Write functions as **declarations**, **expressions** and **arrow functions**
    - Use parameters, **default** and **rest** parameters, and return values
    - Explain **scope** (global, function, block) and **hoisting**
    - Create a **closure** and explain why it remembers variables
    - Pass functions as values: **callbacks** and **higher-order functions**

**Prerequisites:** [Conditions & Loops](02-conditions-loops.md)

## Why Functions?

In the last lesson we calculated the delivery charge inline. The cart page, the checkout page and the product page all need the same rule. Copying the code three times means fixing a bug three times. A **function** packages the logic once, under a name:

```js
function deliveryCharge(total) {
  if (total >= 499) {
    return 0;
  }
  return 40;
}

console.log(deliveryCharge(650));
console.log(deliveryCharge(350));
```

```{ .text .output }
0
40
```

- `total` is a **parameter**: a variable that receives a value when the function is called.
- `650` and `350` are **arguments**: the values passed in.
- `return` sends a value back **and stops** the function. Without `return`, a function gives back `undefined`.

## Three Ways to Write a Function

```js
// 1. Function declaration
function addGst(amount) {
  return amount * 1.18;
}

// 2. Function expression: a function stored in a variable
const formatRupees = function (amount) {
  return amount.toLocaleString("en-IN", { style: "currency", currency: "INR" });
};

// 3. Arrow function: shorter syntax
const lineTotal = (price, qty) => price * qty;          // one expression: returned automatically
const isFreeDelivery = total => total >= 499;           // one parameter: brackets optional
const greet = () => "Welcome to KSR Store";             // no parameters: empty brackets
const describe = (name, price) => {                     // several statements: braces + return
  const label = price > 10000 ? "premium" : "budget";
  return `${name} is a ${label} product`;
};

console.log(formatRupees(addGst(1000)));
console.log(lineTotal(1299, 2), isFreeDelivery(450), greet());
console.log(describe("iPhone 15", 79999));
```

```{ .text .output }
₹1,180.00
2598 false Welcome to KSR Store
iPhone 15 is a premium product
```

| Form | Syntax | Notes |
|------|--------|-------|
| Declaration | `function name(a) { ... }` | Hoisted: can be called before the line where it's defined |
| Expression | `const name = function (a) { ... };` | Not callable before its line |
| Arrow | `const name = (a) => a * 2;` | Short; returns automatically without braces; no own `this` (lesson 5) |

Arrow functions are used everywhere in modern code, especially as callbacks (later in this lesson). With **braces**, an arrow function needs an explicit `return`, like any other function.

## Parameters

### Default values

```js
function priceWithTax(amount, rate = 0.18) {
  return Math.round(amount * (1 + rate));
}

console.log(priceWithTax(1000));          // uses the default 18%
console.log(priceWithTax(1000, 0.05));    // books: 5% GST
```

```{ .text .output }
1180
1050
```

### Missing and extra arguments

JavaScript doesn't check how many arguments you pass. Missing ones are `undefined`; extra ones are ignored:

```js
function lineTotal(price, qty) {
  return price * qty;
}
console.log(lineTotal(1299));             // qty is undefined -> NaN
console.log(lineTotal(1299, 2, "extra"));
```

```{ .text .output }
NaN
2598
```

That `NaN` is why default values matter: `qty = 1` would have prevented it.

### Rest parameters: any number of arguments

```js
function cartTotal(...prices) {           // prices is a real array
  let sum = 0;
  for (const p of prices) {
    sum += p;
  }
  return sum;
}

console.log(cartTotal(1299, 499));
console.log(cartTotal(1299, 499, 350, 2499));
console.log(cartTotal());
```

```{ .text .output }
1798
4647
0
```

### Returning several values

A function returns one value, but that value can be an array or an object:

```js
function priceBreakdown(subtotal) {
  const gst = Math.round(subtotal * 0.18);
  return { subtotal, gst, total: subtotal + gst };   // shorthand for { subtotal: subtotal, ... }
}

const bill = priceBreakdown(2000);
console.log(bill);
console.log(bill.total);
```

```{ .text .output }
{ subtotal: 2000, gst: 360, total: 2360 }
2360
```

## Scope: Where Variables Live

**Scope** decides where a variable can be used:

```js
const storeName = "KSR Store";                // global scope: visible everywhere

function checkout() {
  const orderId = "KSR10421";                 // function scope: only inside checkout()
  if (true) {
    const message = `Order ${orderId} placed`; // block scope: only inside these braces
    console.log(message, "at", storeName);
  }
  try {
    console.log(message);
  } catch (error) {
    console.log("Outside the block:", error.message);
  }
}

checkout();
try {
  console.log(orderId);
} catch (error) {
  console.log("Outside the function:", error.message);
}
```

```{ .text .output }
Order KSR10421 placed at KSR Store
Outside the block: message is not defined
Outside the function: orderId is not defined
```

- Code can see variables in its **own** scope and every scope **around** it (inner sees outer).
- Outer code can't see inside a function or a block.
- `let` and `const` are **block-scoped**: an `if`, a loop or any `{ }` creates a new scope. (`var` ignores blocks, which is why we avoid it.)

!!! tip "Keep variables as local as possible"
    Global variables can be changed by any code on the page, including other scripts. Declare variables inside the function or block that needs them.

### Hoisting

Function **declarations** are moved to the top of their scope when the code is loaded, so they can be called before they appear. `let` / `const` variables and function expressions can't be used before their line:

```js
console.log(double(4));                       // works: declarations are hoisted

function double(n) {
  return n * 2;
}

try {
  console.log(triple(4));
} catch (error) {
  console.log(error.name + ":", error.message);
}
const triple = n => n * 3;
```

```{ .text .output }
8
ReferenceError: Cannot access 'triple' before initialization
```

## Closures

A function **remembers the variables of the scope where it was created**, even after that outer function has finished. That's a **closure**:

```js
function createCartCounter() {
  let count = 0;                              // private: nothing outside can touch it
  return {
    add: () => ++count,
    remove: () => (count > 0 ? --count : 0),
    value: () => count,
  };
}

const cart = createCartCounter();
cart.add();
cart.add();
cart.add();
cart.remove();
console.log("Items in cart:", cart.value());
console.log("count from outside:", typeof count);

const wishlist = createCartCounter();         // a separate, independent counter
wishlist.add();
console.log("Wishlist:", wishlist.value(), "| Cart:", cart.value());
```

```{ .text .output }
Items in cart: 2
count from outside: undefined
Wishlist: 1 | Cart: 2
```

`createCartCounter()` finished long ago, yet `add`, `remove` and `value` still share its `count`. Each call creates a **new** `count`, so the cart and the wishlist don't interfere. Closures are how JavaScript keeps data private, and they're behind event handlers, React hooks and much more.

```js
function makeDiscount(percent) {
  return price => Math.round(price * (1 - percent / 100));   // remembers percent
}

const diwaliSale = makeDiscount(20);
const clearance = makeDiscount(50);
console.log(diwaliSale(4299), clearance(4299));
```

```{ .text .output }
3439 2150
```

## Functions Are Values: Callbacks

In JavaScript, functions can be stored in variables, passed as arguments and returned from other functions. A function passed to another function is a **callback**:

```js
function applyToAll(prices, operation) {      // a higher-order function: it takes a function
  const result = [];
  for (const p of prices) {
    result.push(operation(p));                // call the callback for each price
  }
  return result;
}

const prices = [1299, 499, 4299];
console.log(applyToAll(prices, p => p * 2));
console.log(applyToAll(prices, p => Math.round(p * 1.18)));
console.log(applyToAll(prices, makeDiscount(10)));

function makeDiscount(percent) {
  return price => Math.round(price * (1 - percent / 100));
}
```

```{ .text .output }
[ 2598, 998, 8598 ]
[ 1533, 589, 5073 ]
[ 1169, 449, 3869 ]
```

`applyToAll` doesn't know or care **what** happens to each price; the callback decides. Arrays have this built in (`prices.map(p => p * 2)`), as you'll see in the next lesson. Callbacks also power events (`button.addEventListener("click", handler)`) and timers (`setTimeout(callback, 1000)`).

## Pure Functions

A **pure function** returns a value based only on its inputs and changes nothing outside itself:

```js
// Pure: same input, same output, no side effects
const withGst = amount => Math.round(amount * 1.18);

// Impure: changes a variable outside itself
let runningTotal = 0;
function addToTotal(amount) {
  runningTotal += amount;
  return runningTotal;
}

console.log(withGst(1000), withGst(1000));
console.log(addToTotal(1000), addToTotal(1000));
```

```{ .text .output }
1180 1180
1000 2000
```

Pure functions are easy to test and reuse: `withGst(1000)` is always `1180`. The impure one returns different results for the same input. You can't avoid side effects completely (updating the page **is** a side effect), but keep calculations pure and isolate the side effects.

## The KSR Store Pricing Helpers

Collect the reusable functions in one file. You'll import it into the pages later:

```js title="js/pricing.js"
const FREE_DELIVERY_MIN = 499;
const DELIVERY_FEE = 40;

function lineTotal(price, qty = 1) {
  return price * qty;
}

function deliveryCharge(subtotal, isMember = false) {
  return subtotal >= FREE_DELIVERY_MIN || isMember ? 0 : DELIVERY_FEE;
}

const formatRupees = amount =>
  amount.toLocaleString("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 });

function orderSummary(items, isMember = false) {
  let subtotal = 0;
  for (const item of items) {
    subtotal += lineTotal(item.price, item.qty);
  }
  const delivery = deliveryCharge(subtotal, isMember);
  return { subtotal, delivery, total: subtotal + delivery };
}

const summary = orderSummary([
  { name: "Airdopes 141", price: 1299, qty: 2 },
  { name: "Atomic Habits", price: 499 },
]);
console.log("Subtotal:", formatRupees(summary.subtotal));
console.log("Delivery:", summary.delivery === 0 ? "Free" : formatRupees(summary.delivery));
console.log("Total:   ", formatRupees(summary.total));
console.log("Small order:", orderSummary([{ price: 299 }]));
```

```bash
node js/pricing.js
```

```{ .text .output }
Subtotal: ₹3,097
Delivery: Free
Total:    ₹3,097
Small order: { subtotal: 299, delivery: 40, total: 339 }
```

Each function does **one** thing and has a clear name. `orderSummary` is built from the smaller functions, and changing the free-delivery threshold means changing one constant.

!!! realworld "In Real Projects"
    Codebases are mostly small, well-named functions. Teams prefer arrow functions for callbacks, pure functions for business logic (prices, taxes, validation) because they're easy to unit test, and closures to keep state private. In React, every component is a function, and hooks like `useState` rely on closures.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Forgetting `return` | The function gives `undefined` | `return` the result |
| Arrow function with braces but no `return` | `undefined` | `x => x * 2` or `x => { return x * 2; }` |
| Calling instead of passing a callback: `onClick(handle())` | The function runs immediately | Pass it: `handle`, or `() => handle(id)` |
| Missing arguments | `NaN` or `undefined` results | Default parameters |
| Using a `const` function before its line | `ReferenceError: Cannot access ... before initialization` | Define it first, or use a declaration |
| Changing outer variables everywhere | Unpredictable results | Return values instead (pure functions) |
| Returning an object literal from an arrow: `() => { a: 1 }` | `undefined` (the braces are a code block) | Wrap it: `() => ({ a: 1 })` |

## Practice Exercises

**Easy**

1. Write `isInStock(stock)` that returns `true` when stock is above 0, as an arrow function.
2. Write `discountedPrice(price, percent = 10)` that returns the rounded price after the discount.
3. Write `fullName(first, last)` returning `"Last, First"` using a template literal.

**Medium**

4. Write `average(...ratings)` using a rest parameter, returning the average rounded to 1 decimal (and `0` for no ratings).
5. Write `makeGreeting(storeName)` that returns a function `name => "Welcome to <store>, <name>!"`. Create two greeters for two stores.
6. Write `applyCoupon(total, code)` that returns the new total for `"SAVE10"` (10% off), `"FLAT100"` (₹100 off, never below 0) or the same total for unknown codes.

**Challenge**

7. Write `createStockTracker(initial)` returning `{ sell(qty), restock(qty), available() }`, where `sell` refuses (returns `false`) when there isn't enough stock. Show that two trackers are independent.

??? success "Solutions (click to expand)"

    ```{ .js .no-run }
    // 1
    const isInStock = stock => stock > 0;

    // 2
    const discountedPrice = (price, percent = 10) => Math.round(price * (1 - percent / 100));

    // 4
    function average(...ratings) {
      if (ratings.length === 0) return 0;
      let sum = 0;
      for (const r of ratings) sum += r;
      return Math.round((sum / ratings.length) * 10) / 10;
    }

    // 5
    const makeGreeting = storeName => name => `Welcome to ${storeName}, ${name}!`;
    const ksr = makeGreeting("KSR Store");
    console.log(ksr("Asha"));

    // 6
    function applyCoupon(total, code) {
      switch (code) {
        case "SAVE10": return Math.round(total * 0.9);
        case "FLAT100": return Math.max(0, total - 100);
        default: return total;
      }
    }

    // 7
    function createStockTracker(initial) {
      let stock = initial;
      return {
        sell(qty) {
          if (qty > stock) return false;
          stock -= qty;
          return true;
        },
        restock(qty) { stock += qty; },
        available: () => stock,
      };
    }
    ```

!!! note "Mini Assignment"
    Create `js/helpers.js` for your own business with at least five small, pure functions (for example `priceWithTax`, `serviceFee`, `formatRupees`, `isValidPhone`, `applyCoupon`) and one function that combines them into a final bill. Add a closure-based counter for something in your domain (bookings, seats, tickets). Print test calls with `console.log` and run the file with Node.

## Interview Questions

!!! interview "1. What is the difference between a function declaration and a function expression?"
    A declaration (`function f() {}`) is hoisted completely, so it can be called before it appears in the code. An expression (`const f = function () {}` or an arrow function) is assigned when that line runs; using it earlier throws a `ReferenceError` (with `let` / `const`).

!!! interview "2. How are arrow functions different from regular functions?"
    They have a shorter syntax and an implicit return for single expressions, and they don't have their own `this`, `arguments` or `prototype`, so they can't be used as constructors. They take `this` from the surrounding scope, which makes them ideal for callbacks.

!!! interview "3. What is a closure?"
    A function together with the variables from the scope where it was created. The inner function keeps access to those variables even after the outer function has returned, which enables private state, function factories and callbacks that remember context.

!!! interview "4. What is the difference between block scope and function scope?"
    `let` and `const` are block-scoped: they exist only inside the nearest `{ }` (if, loop, block). `var` is function-scoped: it's visible throughout the whole function, ignoring blocks.

!!! interview "5. What is a higher-order function?"
    A function that takes another function as an argument or returns a function. Examples: `map`, `filter`, `addEventListener`, `setTimeout`, and function factories like `makeDiscount(20)`.

!!! interview "Scenario: a button's click handler runs once when the page loads and never on click. What's wrong?"
    The handler was called instead of passed: `button.addEventListener("click", addToCart(5))` runs `addToCart` immediately and registers its return value. Pass a function instead: `button.addEventListener("click", () => addToCart(5))`.

## Summary

| Concept | Syntax |
|---------|--------|
| Declaration | `function total(a, b) { return a + b; }` |
| Expression | `const total = function (a, b) { return a + b; };` |
| Arrow | `const total = (a, b) => a + b;` |
| Default parameter | `function tax(amount, rate = 0.18) { }` |
| Rest parameter | `function sum(...nums) { }` |
| Return many values | `return { subtotal, gst, total };` |
| Scope | Global → function → block (`let` / `const`) |
| Hoisting | Declarations work before their line; `let` / `const` don't |
| Closure | An inner function remembers outer variables (`createCartCounter`) |
| Callback | `applyToAll(prices, p => p * 2)` |

**Next lesson:** [Arrays & Array Methods](04-arrays.md), working with lists of products using `map`, `filter`, `reduce` and friends.
