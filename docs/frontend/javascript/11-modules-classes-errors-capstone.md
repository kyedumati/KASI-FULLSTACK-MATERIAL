---
lesson: true
category: JavaScript
short: Capstone
description: Organising JavaScript with ES modules (named and default exports, imports, module scope), classes (constructor, methods, getters, static members, private fields, inheritance), error handling with built-in and custom error classes, debugging with console methods and DevTools breakpoints, and the KSR Store frontend capstone project.
---

# Modules, Classes, Errors & Capstone

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Split code into **ES modules** with named and default exports
    - Write **classes** with a constructor, methods, getters, static members and **private fields**, and extend them
    - **Throw** and **catch** errors, and create **custom error classes**
    - **Debug** with `console` methods, breakpoints and the `debugger` statement
    - Plan, build and present the **KSR Store frontend capstone**

**Prerequisites:** [Fetch & APIs](10-fetch-apis.md)

## ES Modules

Over the last lessons the KSR Store grew into several files: `products-data.js`, `cart-store.js`, `api.js`, `catalog.js`, `cart-page.js`, `checkout.js`. Each file is a **module**: it has its own scope, and shares only what it **exports**.

```{ .text .no-run }
ksr-store/
├── index.html, products.html, cart.html, checkout.html, ...
├── css/style.css
├── images/
├── api/server.js              ← the mock API (Node)
└── js/
    ├── products-data.js       ← data (default export)
    ├── api.js                 ← talks to the server (named exports)
    ├── cart-store.js          ← owns localStorage (named exports)
    ├── catalog.js             ← page script for products.html
    ├── cart-page.js           ← page script for cart.html
    └── checkout.js            ← page script for checkout.html
```

### Exporting and importing

```js title="js/utils/format.js"
export const CURRENCY = "INR";

export function formatRupees(amount) {
  return amount.toLocaleString("en-IN", { style: "currency", currency: CURRENCY, maximumFractionDigits: 0 });
}

export function pluralize(count, word) {
  return `${count} ${word}${count === 1 ? "" : "s"}`;
}

export default function slugify(text) {
  return text.toLowerCase().replaceAll("&", "and").replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
}
```

```js title="js/modules-demo.js"
import slugify, { formatRupees, pluralize as plural, CURRENCY } from "./utils/format.js";
import * as format from "./utils/format.js";
import products from "./products-data.js";

console.log(formatRupees(79999), "| currency:", CURRENCY);
console.log(plural(1, "item"), "|", plural(3, "item"));
console.log(products.map(p => slugify(p.category)).join(", "));
console.log(Object.keys(format).sort());
```

```bash
node js/modules-demo.js
```

```{ .text .output }
₹79,999 | currency: INR
1 item | 3 items
electronics, electronics, fashion, fashion, books, books, home-and-kitchen, sports
[ 'CURRENCY', 'default', 'formatRupees', 'pluralize' ]
```

| Syntax | Meaning |
|--------|---------|
| `export function f() {}` / `export const X = 1` | **Named** export (a module can have many) |
| `export default ...` | The **default** export (at most one per module) |
| `import { f, X } from "./file.js"` | Import named exports (names must match) |
| `import anything from "./file.js"` | Import the default export (you choose the name) |
| `import { f as g } from "./file.js"` | Rename on import |
| `import * as lib from "./file.js"` | Everything as one object (`lib.f`, `lib.default`) |

Rules worth knowing:

- In the browser, a module is loaded with `<script type="module">`, which is **deferred** automatically and runs in **strict mode**.
- Import paths need the **`./`** and the **`.js`** extension in plain browsers and Node (bundlers like Vite relax this).
- Each module runs **once**, however many files import it, and its top-level variables are **private** unless exported. No more accidental global variables.
- Modules need an `http://` page (Live Server); they don't work from `file://`.

!!! tip "Named or default?"
    Many teams prefer **named exports** for everything: the names are checked when importing, and editors can auto-import them. Default exports are common for "the one main thing" in a file, such as a React component or a data array.

## Classes

A **class** is a blueprint for objects that share the same shape and methods. Here's the cart as a class. Instead of using `localStorage` directly, it receives a **storage** object, so the same class works in the browser (`localStorage`) and in Node or tests (a simple in-memory object):

```js title="js/cart.js"
export class Cart {
  #items = {};                         // private field: only code inside the class can see it
  #storage;
  #key;

  static MAX_QTY = 10;                 // static: belongs to the class, not to each cart

  constructor(storage, key = "ksr-cart") {
    this.#storage = storage;
    this.#key = key;
    this.#items = JSON.parse(storage.getItem(key) ?? "{}");
  }

  add(productId, qty = 1) {
    const next = (this.#items[productId] ?? 0) + qty;
    if (next > Cart.MAX_QTY) {
      throw new RangeError(`You can buy at most ${Cart.MAX_QTY} of one product`);
    }
    this.#items[productId] = next;
    this.#save();
    return this;                       // allows cart.add(3).add(9)
  }

  remove(productId) {
    delete this.#items[productId];
    this.#save();
    return this;
  }

  get count() {                        // a getter: used like a property, cart.count
    return Object.values(this.#items).reduce((sum, qty) => sum + qty, 0);
  }

  get lines() {
    return Object.entries(this.#items).map(([id, qty]) => ({ productId: Number(id), qty }));
  }

  #save() {                            // private method
    this.#storage.setItem(this.#key, JSON.stringify(this.#items));
  }
}

// A tiny in-memory storage with the same methods as localStorage
export class MemoryStorage {
  #data = new Map();
  getItem(key) { return this.#data.get(key) ?? null; }
  setItem(key, value) { this.#data.set(key, String(value)); }
  removeItem(key) { this.#data.delete(key); }
}
```

```js
import { Cart, MemoryStorage } from "./js/cart.js";

const storage = new MemoryStorage();
const cart = new Cart(storage);              // new: create an instance; runs the constructor
cart.add(3).add(3).add(9);

console.log("count:", cart.count);
console.log("lines:", JSON.stringify(cart.lines));
console.log("saved:", storage.getItem("ksr-cart"));
console.log("max per product:", Cart.MAX_QTY);
console.log("is a Cart?", cart instanceof Cart);

const reloaded = new Cart(storage);          // a new Cart reads the saved data back
console.log("after 'reload':", reloaded.count);

try {
  reloaded.add(9, 20);
} catch (error) {
  console.log(error.name + ":", error.message);
}

console.log("private field from outside:", cart["#items"]);
```

```{ .text .output }
count: 3
lines: [{"productId":3,"qty":2},{"productId":9,"qty":1}]
saved: {"3":2,"9":1}
max per product: 10
is a Cart? true
after 'reload': 3
RangeError: You can buy at most 10 of one product
private field from outside: undefined
```

| Feature | Syntax | Meaning |
|---------|--------|---------|
| Class | `class Cart { ... }` | A blueprint |
| Instance | `new Cart(storage)` | One object made from it |
| Constructor | `constructor(storage) { ... }` | Runs once per `new`; sets up the instance |
| Method | `add(id) { ... }` | A function every instance shares; `this` is the instance |
| Getter | `get count() { ... }` | Computed property: `cart.count` (no brackets) |
| Static | `static MAX_QTY = 10` | On the class itself: `Cart.MAX_QTY` |
| Private | `#items`, `#save()` | Only accessible inside the class body |

### Inheritance: `extends` and `super`

A class can **extend** another, inheriting its methods and adding or changing some:

```js
import { Cart, MemoryStorage } from "./js/cart.js";

class GiftCart extends Cart {
  constructor(storage, message) {
    super(storage, "ksr-gift-cart");         // call the parent constructor first
    this.message = message;
  }

  get count() {
    return super.count;                      // reuse the parent's getter
  }

  describe() {
    return `Gift with ${this.count} item(s) and the message "${this.message}"`;
  }
}

const gift = new GiftCart(new MemoryStorage(), "Happy Diwali!");
gift.add(9);
console.log(gift.describe());
console.log(gift instanceof GiftCart, gift instanceof Cart);
```

```{ .text .output }
Gift with 1 item(s) and the message "Happy Diwali!"
true true
```

Use inheritance sparingly: one level is common, deep hierarchies are hard to change. Many JavaScript developers prefer plain objects and functions (as in `cart-store.js`) and use classes when there's clear state plus behaviour, as here. Both are valid; React, for example, moved from class components to functions.

!!! tip "Coming from Python or Java?"
    It's the same idea as `class Cart:` in Python or `public class Cart` in Java. Differences: `constructor` instead of `__init__` / the class name, `this` instead of `self` (and it's not a parameter), `#` for truly private fields, and no method overloading.

## Errors

When something goes wrong, JavaScript **throws** an error object, and execution jumps to the nearest `catch`:

| Built-in error | Typical cause |
|----------------|---------------|
| `TypeError` | Using a value the wrong way: `undefined.name`, calling a non-function |
| `ReferenceError` | Using a variable that doesn't exist |
| `SyntaxError` | Invalid code, or invalid JSON in `JSON.parse` |
| `RangeError` | A number outside the allowed range |
| `Error` | The general type you throw yourself |

### Custom errors

For your own failure cases, create error classes so callers can tell them apart:

```js
class OutOfStockError extends Error {
  constructor(product, requested) {
    super(`Only ${product.stock} x ${product.name} left (you asked for ${requested})`);
    this.name = "OutOfStockError";
    this.productId = product.id;
  }
}

class ValidationError extends Error {
  constructor(field, message) {
    super(message);
    this.name = "ValidationError";
    this.field = field;
  }
}

function checkout({ product, qty, pincode }) {
  if (!/^[1-9][0-9]{5}$/.test(pincode)) {
    throw new ValidationError("pincode", "PIN code must be 6 digits");
  }
  if (qty > product.stock) {
    throw new OutOfStockError(product, qty);
  }
  return `Order placed: ${qty} x ${product.name}`;
}

const shoes = { id: 7, name: "Running Shoes", stock: 2 };
const attempts = [
  { product: shoes, qty: 1, pincode: "500016" },
  { product: shoes, qty: 5, pincode: "500016" },
  { product: shoes, qty: 1, pincode: "5000" },
];

for (const attempt of attempts) {
  try {
    console.log(checkout(attempt));
  } catch (error) {
    if (error instanceof OutOfStockError) {
      console.log(`Stock problem (product ${error.productId}): ${error.message}`);
    } else if (error instanceof ValidationError) {
      console.log(`Fix the ${error.field} field: ${error.message}`);
    } else {
      throw error;                           // unknown errors: don't swallow them
    }
  } finally {
    console.log("  (attempt finished)");
  }
}
```

```{ .text .output }
Order placed: 1 x Running Shoes
  (attempt finished)
Stock problem (product 7): Only 2 x Running Shoes left (you asked for 5)
  (attempt finished)
Fix the pincode field: PIN code must be 6 digits
  (attempt finished)
```

Guidelines:

- **Throw** when a function can't do its job; **catch** where you can do something useful (show a message, retry, fall back).
- Catch **specific** errors and re-throw the rest. An empty `catch {}` hides bugs.
- Show users a **friendly** message; log the technical details for developers.
- For errors nobody caught, browsers fire `window.addEventListener("error", ...)` and `"unhandledrejection"` events, which teams connect to an error-tracking service such as Sentry.

## Debugging

### The console, beyond `log`

```js
const cart = [
  { name: "Airdopes 141", price: 1299, qty: 2 },
  { name: "Atomic Habits", price: 499, qty: 1 },
];

console.table(cart);                          // arrays of objects as a table
console.group("Checkout");                    // indent related messages
console.info("validating address");
console.warn("PIN code looks unusual");       // shown in yellow in the browser
console.groupEnd();
console.assert(cart.length > 5, "cart has fewer than 6 items");   // logs only when false
```

```{ .text .output }
┌─────────┬─────────────────┬───────┬─────┐
│ (index) │ name            │ price │ qty │
├─────────┼─────────────────┼───────┼─────┤
│ 0       │ 'Airdopes 141'  │ 1299  │ 2   │
│ 1       │ 'Atomic Habits' │ 499   │ 1   │
└─────────┴─────────────────┴───────┴─────┘
Checkout
  validating address
```

(`console.warn` and failed `console.assert` messages go to **stderr** in Node and appear as yellow and red entries in the browser; the output above shows only the normal log lines. Try the snippet in the browser console to see all of them.)

| Method | Use |
|--------|-----|
| `console.log(a, b)` | General output |
| `console.table(array)` | Arrays of objects |
| `console.error` / `console.warn` | Highlighted messages |
| `console.group` / `groupEnd` | Group related logs |
| `console.time("x")` / `timeEnd("x")` | Measure how long code takes |
| `console.assert(cond, msg)` | Log only when a condition is false |

### Breakpoints

`console.log` is fine for quick checks, but **breakpoints** let you pause the code and look at every variable:

1. Open DevTools → **Sources**, open `js/catalog.js`, and click a line number (for example inside `addToCart`'s handler). A blue marker appears.
2. Click "Add to cart". The page **pauses** on that line.
3. Hover variables to see their values, or look at the **Scope** panel. Use **Step over** (++f10++) to run line by line, and **Resume** (++f8++) to continue.

You can also write `debugger;` in your code: when DevTools is open, execution pauses there.

### Reading error messages

| Message | Usually means |
|---------|---------------|
| `Cannot read properties of null (reading 'addEventListener')` | `querySelector` found nothing: wrong selector, or the script ran before the HTML |
| `Cannot read properties of undefined (reading 'name')` | Data isn't the shape you expected (check the API response) |
| `x is not a function` | A typo, or calling something that isn't a function (`list.map` on a NodeList) |
| `x is not defined` | A typo, a missing `import`, or the variable is in another scope |
| `Unexpected token '<' ... is not valid JSON` | The server returned HTML (often a 404 page) instead of JSON |
| `Failed to fetch` / CORS policy | The server isn't running, or doesn't allow your origin |

The console shows the **file and line** next to every error: click it to jump straight to the code.

!!! realworld "In Real Projects"
    Real frontends are hundreds of modules bundled for production by tools like **Vite** or webpack, which also minify the code and support TypeScript. Teams organise code by feature (`cart/`, `catalog/`, `checkout/`), use classes or plain functions consistently, wrap API calls with typed errors, report uncaught errors to Sentry, and debug with breakpoints and the Network tab far more than with `console.log`. Everything you built in this module is what React and other frameworks are made of.

## Capstone: The KSR Store Frontend

Bring the HTML, CSS and JavaScript modules together into a complete, polished shop frontend.

### Requirements

**Pages and features**

1. **Home**: hero, featured products loaded from the API (top-rated three), categories with counts.
2. **Catalogue**: products from the API with live search, category filter, sort, an "In stock only" toggle, loading / empty / error states, and filters kept in the URL (`?q=&category=`).
3. **Product page** (`product.html?id=9`): details from `GET /api/products/:id`, a quantity selector (limited by stock), "Add to cart", and a "Product not found" state.
4. **Cart**: quantities, remove, clear, subtotal, delivery rule and grand total, persisted in `localStorage`, synced between tabs.
5. **Checkout**: JavaScript validation with accessible messages, `POST /api/orders`, a disabled button while submitting, a confirmation with the order number, and the cart cleared afterwards.
6. A **cart badge** on every page.

**Code quality**

- ES modules: one API module, one cart module (functions or the `Cart` class), one script per page, shared helpers in `js/utils/`.
- No `var`, no `==`, no inline `onclick`, no user data in `innerHTML`.
- Custom error classes or clear error messages for API and validation failures.

**Design and accessibility**

- The CSS module's design system (variables, mobile-first, dark mode), responsive down to 360px.
- Keyboard accessible: visible focus, labels on every field, `aria-live` / `aria-busy` for dynamic content.
- Lighthouse: 90+ for Accessibility and Best Practices.

**Backend**

- Use the mock API from lesson 10, **or** (recommended for full stack students) your own backend: Django REST Framework, FastAPI or Spring Boot, with CORS configured.

### Suggested plan

| Day | Goal |
|-----|------|
| 1 | File structure, modules, API client; catalogue loading from the API |
| 2 | Search, filters, sort, URL parameters, all request states |
| 3 | Product page and the cart module (or `Cart` class) |
| 4 | Cart page and checkout with validation and POST |
| 5 | Home page, badge everywhere, dark mode, responsive checks |
| 6 | Accessibility pass, Lighthouse, error handling, clean-up |
| 7 | Connect to your own backend (optional), rehearse the demo |

### Evaluation rubric

| Area | Weight | Excellent looks like |
|------|--------|----------------------|
| Features | 30% | Every requirement works, including edge cases (empty cart, out of stock, server down) |
| JavaScript quality | 25% | Small functions, clear modules, no duplication, proper async error handling |
| HTML and CSS | 15% | Semantic HTML, clean design system, responsive, dark mode |
| Accessibility | 15% | Keyboard-only checkout works, labels and live regions, Lighthouse 90+ |
| API integration | 15% | All states handled, no trusted client totals, CORS understood |

### Demo script (10 minutes)

1. **Shopping journey** (3 min): search, filter, open a product, add to cart, change quantities, check out, show the order number.
2. **Resilience** (2 min): stop the API and show the error state; submit an invalid form and show the messages; open two tabs and show the cart syncing.
3. **Responsive and accessible** (2 min): phone width, dark mode, complete the checkout with the keyboard only.
4. **Code tour** (2 min): the module structure, the API client, one piece of code you're proud of.
5. **What's next** (1 min): what you'd change if you rebuilt it in React.

## Interview Questions

!!! interview "1. What is the difference between named and default exports?"
    A module can have many named exports, imported with matching names in braces (`import { f } from`). It can have one default export, imported without braces under any name (`import anything from`). Named exports are checked by name and work well with editor auto-imports.

!!! interview "2. What are the benefits of ES modules?"
    Each file has its own scope (no accidental globals), dependencies are explicit through `import`, each module runs once and is shared, the code is easier to organise and test, and bundlers can remove unused exports (tree shaking).

!!! interview "3. What are private class fields?"
    Fields and methods prefixed with `#` (`#items`, `#save()`) that can only be accessed inside the class body. Unlike the old `_name` convention, they're enforced by the language.

!!! interview "4. Why create custom error classes?"
    So callers can distinguish error types with `instanceof` and react appropriately (show a field message for a `ValidationError`, offer alternatives for an `OutOfStockError`), and so errors can carry extra data such as the field name or product id.

!!! interview "5. How do you debug a JavaScript problem in the browser?"
    Read the error message and click its file and line in the console; inspect the DOM in Elements; check requests and responses in the Network tab; set breakpoints in Sources (or use `debugger`) to step through the code and inspect variables; and add targeted `console.log` / `console.table` calls when needed.

!!! interview "Scenario: the cart works in development but users report "Cannot read properties of undefined (reading 'price')" after a product was deleted. How do you fix it?"
    Their saved cart still contains the deleted product's id, so looking it up returns `undefined`. Filter out cart lines whose product no longer exists (as `cartLines()` does in lesson 8), optionally tell the user, and remove the stale id from storage. Always treat stored and API data as possibly out of date.

## Summary

| Concept | Syntax |
|---------|--------|
| Named export / import | `export function f() {}` · `import { f } from "./file.js"` |
| Default export / import | `export default x` · `import x from "./file.js"` |
| Rename / namespace | `import { f as g }` · `import * as lib` |
| Class | `class Cart { constructor() {} add() {} get count() {} static MAX = 10; #items = {}; }` |
| Instance | `const cart = new Cart(localStorage)` · `cart instanceof Cart` |
| Inheritance | `class GiftCart extends Cart { constructor() { super(...); } }` |
| Throw / catch | `throw new Error("...")` · `try { } catch (e) { } finally { }` |
| Custom error | `class OutOfStockError extends Error { constructor(...) { super(msg); this.name = "..."; } }` |
| Debugging | `console.table`, `console.group`, breakpoints, `debugger;`, Network tab |

**You've finished the HTML, CSS & JavaScript module!** Next on the roadmap: **React**, which builds on everything here (modules, functions, arrays, objects, events, fetch) to create interfaces from components.
