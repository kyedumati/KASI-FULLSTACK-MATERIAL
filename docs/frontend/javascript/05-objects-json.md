---
lesson: true
category: JavaScript
short: Objects
description: JavaScript objects - literals, dot and bracket notation, adding, changing and deleting properties, methods and this, shorthand properties, object destructuring with defaults and renaming, spread and rest, Object.keys/values/entries, references vs copies, JSON.stringify and JSON.parse, and dates - modelling products, carts and API responses.
---

# Objects, Destructuring & JSON

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Create objects and read, add, change and delete properties with **dot** and **bracket** notation
    - Write **methods** and explain `this` in a method
    - **Destructure** objects (with defaults and renaming) and use **spread** / **rest**
    - Loop over objects with `Object.keys`, `Object.values` and `Object.entries`
    - Convert between objects and **JSON** with `JSON.stringify` and `JSON.parse`, and format **dates**

**Prerequisites:** [Arrays & Array Methods](04-arrays.md)

## Object Basics

An **object** groups related values under named **keys** (also called properties):

```js
const product = {
  id: 7,
  name: "Running Shoes",
  brand: "Puma",
  price: 4299,
  inStock: true,
  sizes: [7, 8, 9, 10],
  "release-year": 2025,           // keys with special characters need quotes
};

console.log(product.name);        // dot notation
console.log(product["price"]);    // bracket notation
const key = "brand";
console.log(product[key]);        // brackets let you use a variable as the key
console.log(product["release-year"]);
console.log(product.sizes[2], product.sizes.length);
console.log(product.color);       // missing property: undefined, not an error
```

```{ .text .output }
Running Shoes
4299
Puma
2025
9 4
undefined
```

Use dot notation normally. Use brackets when the key is in a variable or isn't a valid name.

### Adding, changing and deleting

```js
const cartItem = { productId: 7, qty: 1 };

cartItem.qty = 2;                 // change
cartItem.size = 9;                // add
cartItem["giftWrap"] = true;      // add with brackets
delete cartItem.giftWrap;         // remove

console.log(cartItem);
console.log("size" in cartItem, "color" in cartItem);   // does the key exist?
```

```{ .text .output }
{ productId: 7, qty: 2, size: 9 }
true false
```

Like arrays, a `const` object can still be modified: `const` only prevents assigning a different object to the variable.

!!! tip "Coming from Python?"
    A JavaScript object looks like a Python dictionary: `{ "name": "iPhone" }` becomes `{ name: "iPhone" }` (quotes on keys are optional). You can write `product.name` instead of `product["name"]`, and a missing key gives `undefined` instead of a `KeyError`.

## Methods and `this`

A function stored in an object is a **method**. Inside a method, **`this`** is the object the method was called on:

```js
const cart = {
  owner: "Asha",
  items: [
    { name: "Airdopes 141", price: 1299, qty: 2 },
    { name: "Atomic Habits", price: 499, qty: 1 },
  ],
  total() {                                         // method shorthand
    return this.items.reduce((sum, item) => sum + item.price * item.qty, 0);
  },
  add(name, price, qty = 1) {
    this.items.push({ name, price, qty });
    return this;                                    // returning this allows chaining
  },
  summary() {
    return `${this.owner}'s cart: ${this.items.length} items, ₹${this.total()}`;
  },
};

console.log(cart.total());
cart.add("USB-C Cable", 299, 3).add("Yoga Mat", 999);
console.log(cart.summary());
```

```{ .text .output }
3097
Asha's cart: 4 items, ₹4993
```

!!! warning "Arrow functions and `this`"
    Don't write methods as arrow functions (`total: () => this.items...`): arrow functions don't have their own `this`, so `this` wouldn't be the cart. Arrow functions **inside** a method (like the `reduce` callback above) are fine: they use the method's `this`.

## Shorthand Properties and Computed Keys

```js
const name = "Cricket Bat";
const price = 2499;

const product = { name, price };                   // same as { name: name, price: price }
console.log(product);

const field = "rating";
const updated = { ...product, [field]: 4.4 };      // [ ] computes the key from a variable
console.log(updated);
```

```{ .text .output }
{ name: 'Cricket Bat', price: 2499 }
{ name: 'Cricket Bat', price: 2499, rating: 4.4 }
```

## Destructuring Objects

**Destructuring** pulls properties into variables in one line:

```js
const order = {
  id: "KSR10421",
  status: "shipped",
  customer: { name: "Asha Reddy", city: "Hyderabad" },
  items: [{ name: "Airdopes 141", qty: 2 }],
};

const { id, status } = order;
console.log(id, status);

const { status: orderStatus } = order;              // rename
const { coupon = "none" } = order;                  // default when missing
console.log(orderStatus, coupon);

const { customer: { city } } = order;               // nested
console.log(city);

const { id: orderId, ...rest } = order;             // rest: everything else
console.log(orderId, Object.keys(rest));
```

```{ .text .output }
KSR10421 shipped
shipped none
Hyderabad
KSR10421 [ 'status', 'customer', 'items' ]
```

It's especially useful in function **parameters**: the function says exactly which properties it needs.

```js
function productLabel({ name, brand, price, discount = 0 }) {
  const final = Math.round(price * (1 - discount / 100));
  return `${name} by ${brand}: ₹${final}${discount ? ` (${discount}% off)` : ""}`;
}

console.log(productLabel({ name: "Denim Jacket", brand: "Levis", price: 3499 }));
console.log(productLabel({ name: "Running Shoes", brand: "Puma", price: 4299, discount: 20 }));
```

```{ .text .output }
Denim Jacket by Levis: ₹3499
Running Shoes by Puma: ₹3439 (20% off)
```

React components receive their data exactly like this: `function ProductCard({ name, price }) { ... }`.

## Spread: Copying and Merging

```js
const defaults = { qty: 1, giftWrap: false, size: null };
const choice = { size: 9, qty: 2 };

const item = { ...defaults, ...choice, productId: 7 };   // later properties win
console.log(item);

const product = { name: "Atomic Habits", price: 499 };
const discounted = { ...product, price: 449 };          // copy with one change
console.log(product, discounted);
```

```{ .text .output }
{ qty: 2, giftWrap: false, size: 9, productId: 7 }
{ name: 'Atomic Habits', price: 499 } { name: 'Atomic Habits', price: 449 }
```

"Copy with a change" (instead of modifying the original) is called working **immutably**. It's how state is updated in React.

## References vs Copies

Objects and arrays are stored **by reference**: a variable holds the **address** of the object, not the object itself.

```js
const original = { name: "iPhone 15", specs: { storage: "128 GB" } };

const sameObject = original;                // NOT a copy: both point to one object
sameObject.name = "iPhone 15 Pro";
console.log(original.name);

const shallow = { ...original };            // copies the top level only
shallow.specs.storage = "256 GB";           // the nested object is still shared!
console.log(original.specs.storage);

const deep = structuredClone(original);     // a full, independent copy
deep.specs.storage = "512 GB";
console.log(original.specs.storage, deep.specs.storage);

console.log({ a: 1 } === { a: 1 });         // two different objects, even if they look the same
```

```{ .text .output }
iPhone 15 Pro
256 GB
256 GB 512 GB
false
```

- `=` copies the **reference**. Changing one changes "both".
- Spread makes a **shallow** copy: nested objects are still shared.
- `structuredClone()` makes a **deep** copy.
- `===` on objects compares references, not contents.

## Looping Over Objects

```js
const stock = { "iPhone 15": 25, "Airdopes 141": 200, "Yoga Mat": 0 };

console.log(Object.keys(stock));
console.log(Object.values(stock));
console.log(Object.entries(stock));

for (const [name, qty] of Object.entries(stock)) {
  console.log(`${name.padEnd(13)} ${qty > 0 ? qty : "sold out"}`);
}

const totalUnits = Object.values(stock).reduce((sum, n) => sum + n, 0);
console.log("Total units:", totalUnits);

const inStockOnly = Object.fromEntries(Object.entries(stock).filter(([, qty]) => qty > 0));
console.log(inStockOnly);
```

```{ .text .output }
[ 'iPhone 15', 'Airdopes 141', 'Yoga Mat' ]
[ 25, 200, 0 ]
[ [ 'iPhone 15', 25 ], [ 'Airdopes 141', 200 ], [ 'Yoga Mat', 0 ] ]
iPhone 15     25
Airdopes 141  200
Yoga Mat      sold out
Total units: 225
{ 'iPhone 15': 25, 'Airdopes 141': 200 }
```

`Object.entries` turns an object into an array of `[key, value]` pairs, so you can use every array method on it, and `Object.fromEntries` turns the pairs back into an object.

## JSON

**JSON** (JavaScript Object Notation) is the text format APIs use to send data. It looks like JavaScript objects, with stricter rules: keys and strings in **double quotes**, no functions, no `undefined`, no comments, no trailing commas.

```js
const order = {
  id: "KSR10421",
  total: 3097,
  paid: true,
  items: [{ productId: 3, qty: 2 }, { productId: 9, qty: 1 }],
  note: undefined,                       // dropped: JSON has no undefined
  placedAt: new Date("2026-10-31T10:30:00+05:30"),
};

const text = JSON.stringify(order);      // object -> JSON text
console.log(text);
console.log(typeof text);

console.log(JSON.stringify({ name: "Atomic Habits", price: 499 }, null, 2));   // pretty-printed

const fromApi = '{"id": 9, "name": "Atomic Habits", "price": 499, "tags": ["bestseller"]}';
const product = JSON.parse(fromApi);     // JSON text -> object
console.log(product.name, product.tags[0], typeof product);

try {
  JSON.parse("{name: 'oops'}");          // single quotes and unquoted keys aren't valid JSON
} catch (error) {
  console.log(error.name, "-", error.message);
}
```

```{ .text .output }
{"id":"KSR10421","total":3097,"paid":true,"items":[{"productId":3,"qty":2},{"productId":9,"qty":1}],"placedAt":"2026-10-31T05:00:00.000Z"}
string
{
  "name": "Atomic Habits",
  "price": 499
}
Atomic Habits bestseller object
SyntaxError - Expected property name or '}' in JSON at position 1
```

| Function | Converts | Used when |
|----------|----------|-----------|
| `JSON.stringify(value)` | Object / array → JSON **text** | Sending data to an API, saving to `localStorage` |
| `JSON.stringify(value, null, 2)` | The same, indented | Debugging, readable files |
| `JSON.parse(text)` | JSON text → object / array | Reading API responses, reading `localStorage` |

Notice the date became a string (`"2026-10-31T05:00:00.000Z"`, in UTC). JSON has no date type, so dates travel as ISO strings and are turned back into `Date` objects when needed.

## Dates

```js
const placed = new Date("2026-10-31T10:30:00+05:30");
const delivery = new Date(placed);
delivery.setDate(delivery.getDate() + 3);            // add 3 days

const opts = { timeZone: "Asia/Kolkata" };
console.log(placed.toLocaleDateString("en-IN", { ...opts, day: "numeric", month: "long", year: "numeric" }));
console.log(delivery.toLocaleDateString("en-IN", { ...opts, weekday: "long", day: "numeric", month: "short" }));
console.log(placed.toLocaleTimeString("en-IN", { ...opts, hour: "2-digit", minute: "2-digit" }));
console.log(placed.toISOString());
console.log("Days between:", (delivery - placed) / (1000 * 60 * 60 * 24));
```

```{ .text .output }
31 October 2026
Tuesday, 3 Nov
10:30 am
2026-10-31T05:00:00.000Z
Days between: 3
```

`new Date()` (no argument) is "now". `toLocaleDateString("en-IN", ...)` formats dates the Indian way. Subtracting dates gives milliseconds. For complex date work, teams use a library such as **date-fns** or **Day.js**.

!!! realworld "In Real Projects"
    Every API you'll call (your Django or Spring Boot backend, payment gateways, maps) sends and receives JSON, which becomes objects and arrays in JavaScript. Frontend code destructures what it needs, uses `?.` and defaults for optional fields, updates state immutably with spread, and converts ISO date strings for display. Bugs from shared references (changing an object that something else is also using) are among the most common in large apps, which is why immutability matters.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `product.release-year` | `NaN` or a `ReferenceError` | `product["release-year"]` |
| Using `product.key` when `key` is a variable | Reads a property literally named "key" | `product[key]` |
| Arrow function as a method | `this` is not the object | Method shorthand: `total() { ... }` |
| `const copy = obj;` | Changes affect the original | `{ ...obj }` or `structuredClone(obj)` |
| Shallow copy of nested data | Nested changes leak back | `structuredClone` |
| `JSON.parse` on invalid JSON (single quotes, trailing commas) | `SyntaxError` | Fix the JSON; wrap risky parses in `try` / `catch` |
| Comparing objects with `===` | `false` for identical-looking objects | Compare specific properties (ids) |
| `JSON.stringify` and expecting a `Date` back after `parse` | You get a string | `new Date(parsed.placedAt)` |

## Practice Exercises

**Easy**

1. Create an object for the Non-stick Pan (id 12, Prestige, ₹1,599, stock 35) and print `"Non-stick Pan - Prestige - ₹1,599"` with destructuring.
2. Add a `rating` of 4.2 to it, change the stock to 30, and delete the `id`.
3. Convert it to pretty-printed JSON, then parse it back and print the brand.

**Medium**

4. Write `updateQty(cartItem, qty)` that returns a **new** object with the new quantity, without changing the original. Prove the original didn't change.
5. Given `const prices = { iphone: 79999, airdopes: 1299, book: 499 }`, create a new object with every price increased by 10%, using `Object.entries`, `map` and `Object.fromEntries`.
6. Write a `wallet` object with a `balance`, a method `pay(amount)` that refuses (returns `false`) when the balance is too low, and a method `addMoney(amount)`.

**Challenge**

7. Given an array of orders `{ id, customer, total, placedAt }` (with ISO date strings), produce a summary object `{ "Asha": { orders: 2, spent: 5394, lastOrder: "1 Nov 2026" }, ... }`.

??? success "Solutions (click to expand)"

    ```{ .js .no-run }
    // 1
    const pan = { id: 12, name: "Non-stick Pan", brand: "Prestige", price: 1599, stock: 35 };
    const { name, brand, price } = pan;
    console.log(`${name} - ${brand} - ₹${price.toLocaleString("en-IN")}`);

    // 4
    const updateQty = (cartItem, qty) => ({ ...cartItem, qty });

    // 5
    const prices = { iphone: 79999, airdopes: 1299, book: 499 };
    const raised = Object.fromEntries(Object.entries(prices).map(([k, v]) => [k, Math.round(v * 1.1)]));

    // 6
    const wallet = {
      balance: 1000,
      pay(amount) {
        if (amount > this.balance) return false;
        this.balance -= amount;
        return true;
      },
      addMoney(amount) { this.balance += amount; },
    };

    // 7
    const summary = orders.reduce((acc, { customer, total, placedAt }) => {
      const entry = (acc[customer] ??= { orders: 0, spent: 0, lastOrder: null });
      entry.orders += 1;
      entry.spent += total;
      const date = new Date(placedAt);
      if (!entry.lastOrder || date > entry.lastOrder) entry.lastOrder = date;
      return acc;
    }, {});
    for (const entry of Object.values(summary)) {
      entry.lastOrder = entry.lastOrder.toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" });
    }
    ```

!!! note "Mini Assignment"
    Model a **booking** for your own business as an object: customer details (nested), a list of services with prices, a booking date, and methods `total()` and `summary()`. Convert it to JSON and back, update it immutably (change the date and add a service with spread), and print a formatted confirmation with destructuring, `Object.entries` and an Indian-formatted date.

## Interview Questions

!!! interview "1. What is the difference between dot and bracket notation?"
    Dot notation (`obj.name`) needs a valid identifier written literally. Bracket notation (`obj["release-year"]`, `obj[key]`) accepts any string, including keys with special characters, and expressions or variables.

!!! interview "2. What does `this` refer to in a method?"
    In a regular function called as a method (`cart.total()`), `this` is the object before the dot. Arrow functions don't have their own `this`; they use the `this` of the surrounding scope, so they shouldn't be used as object methods.

!!! interview "3. What is the difference between a shallow and a deep copy?"
    A shallow copy (`{ ...obj }`, `Object.assign`) duplicates only the top-level properties; nested objects are still shared. A deep copy (`structuredClone(obj)`) duplicates every level, so changes to nested data don't affect the original.

!!! interview "4. What is the difference between JSON and a JavaScript object?"
    JSON is a text format: keys and strings must use double quotes, and it supports only strings, numbers, booleans, null, arrays and objects (no functions, `undefined`, dates or comments). A JavaScript object is a live value in memory. `JSON.stringify` and `JSON.parse` convert between them.

!!! interview "5. What is destructuring, and where is it useful?"
    Syntax that unpacks properties or array items into variables: `const { name, price = 0 } = product`. It's useful for reading function parameters, API responses, imports and React props and hooks, with support for defaults, renaming, nesting and rest.

!!! interview "Scenario: editing a product in a form also changes it in the product list before the user clicks Save. Why?"
    The form received a reference to the same object as the list, so editing it mutated the shared object. Give the form a copy (`{ ...product }` or `structuredClone(product)`), and replace the item in the list with the edited copy only on Save.

## Summary

| Concept | Syntax |
|---------|--------|
| Object | `const p = { name: "Bat", price: 2499 };` |
| Access | `p.name` · `p["release-year"]` · `p[key]` |
| Change | `p.qty = 2` · `delete p.qty` · `"qty" in p` |
| Method | `total() { return this.items.length; }` |
| Shorthand | `{ name, price }` · computed key `{ [field]: value }` |
| Destructuring | `const { name, price: cost, qty = 1, ...rest } = p;` |
| Spread | `{ ...defaults, ...choice }` · copy with change `{ ...p, price: 449 }` |
| Deep copy | `structuredClone(obj)` |
| Iterate | `Object.keys`, `Object.values`, `Object.entries`, `Object.fromEntries` |
| JSON | `JSON.stringify(obj, null, 2)` · `JSON.parse(text)` |
| Dates | `new Date(iso)`, `toLocaleDateString("en-IN", {...})`, `toISOString()` |

**Next lesson:** [The DOM](06-dom.md), where JavaScript finally changes the page: rendering the KSR Store catalogue from data.
