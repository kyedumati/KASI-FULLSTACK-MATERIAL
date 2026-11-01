---
lesson: true
category: JavaScript
short: Control flow
description: Making decisions with if/else, else if, the ternary operator and switch, truthy and falsy values, short-circuit evaluation, nullish coalescing (??) and optional chaining (?.), and repeating work with for, while, do...while, for...of and for...in, break and continue - applied to delivery charges, discounts and carts.
---

# Conditions & Loops

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Make decisions with `if` / `else if` / `else`, the **ternary operator** and `switch`
    - Predict which values are **truthy** and **falsy**
    - Use **short-circuit** operators, **`??`** (nullish coalescing) and **`?.`** (optional chaining)
    - Repeat work with `for`, `while`, `do...while`, **`for...of`** and `for...in`
    - Control loops with `break` and `continue`

**Prerequisites:** [Introduction, Variables & Data Types](01-introduction-variables-data-types.md)

## `if`, `else if`, `else`

The KSR Store's delivery rule: free above ₹499, ₹40 otherwise, and ₹99 for express delivery whatever the total.

```js
const total = 650;
const express = false;
let delivery;

if (express) {
  delivery = 99;
} else if (total >= 499) {
  delivery = 0;
} else {
  delivery = 40;
}

console.log(`Total ₹${total}, delivery ₹${delivery}`);
```

```{ .text .output }
Total ₹650, delivery ₹0
```

- The condition goes in **parentheses**, the code in **braces** `{ }`.
- JavaScript checks the conditions **top to bottom** and runs only the first block whose condition is true.
- `else if` and `else` are optional.

!!! tip "Coming from Python?"
    Python uses `elif` and indentation; JavaScript uses `else if` and braces. Indent anyway: it's for humans.

## The Ternary Operator

For a simple either/or **value**, use `condition ? valueIfTrue : valueIfFalse`:

```js
const stock = 0;
const label = stock > 0 ? "In stock" : "Out of stock";
console.log(label);

const qty = 1;
console.log(`${qty} item${qty === 1 ? "" : "s"} in your cart`);
```

```{ .text .output }
Out of stock
1 item in your cart
```

Great inside template literals. Don't nest ternaries: use `if` / `else` when there are more than two outcomes.

## `switch`

When you compare **one value** against many fixed options, `switch` reads well:

```js
function statusMessage(status) {
  switch (status) {
    case "pending":
      return "We've received your order.";
    case "shipped":
      return "Your order is on the way.";
    case "delivered":
      return "Delivered. Enjoy!";
    case "cancelled":
    case "refunded":                     // two cases share one result
      return "This order was cancelled.";
    default:
      return "Unknown status.";
  }
}

for (const s of ["pending", "shipped", "refunded", "lost"]) {
  console.log(s.padEnd(10), "->", statusMessage(s));
}
```

```{ .text .output }
pending    -> We've received your order.
shipped    -> Your order is on the way.
refunded   -> This order was cancelled.
lost       -> Unknown status.
```

`switch` compares with `===`. Each `case` needs a `return` or `break`, otherwise execution **falls through** into the next case (which is useful only on purpose, as with `cancelled` / `refunded`). We used a function and a loop here to try several values at once; both are coming up properly.

## Truthy and Falsy

In a condition, JavaScript converts any value to `true` or `false`. These eight values are **falsy**; **everything else is truthy**:

| Falsy values |
|--------------|
| `false`, `0`, `-0`, `0n`, `""` (empty string), `null`, `undefined`, `NaN` |

```js
const values = [0, 1, "", "0", " ", null, undefined, NaN, [], {}, "false"];
const labels = ["0", "1", '""', '"0"', '" "', "null", "undefined", "NaN", "[]", "{}", '"false"'];
for (let i = 0; i < values.length; i++) {
  console.log(labels[i].padEnd(9), "->", values[i] ? "truthy" : "falsy");
}
```

```{ .text .output }
0         -> falsy
1         -> truthy
""        -> falsy
"0"       -> truthy
" "       -> truthy
null      -> falsy
undefined -> falsy
NaN       -> falsy
[]        -> truthy
{}        -> truthy
"false"   -> truthy
```

The surprises: `"0"`, `" "` and `"false"` are non-empty strings, so they're **truthy**; empty arrays `[]` and objects `{}` are truthy too. (The `labels` array only exists to print each value readably, quotes included.)

This makes checks short:

```{ .js .no-run }
if (couponCode) { ... }          // runs when the string isn't empty
if (!user) { ... }               // runs when user is null or undefined
```

## Short-circuit, `??` and `?.`

`&&` and `||` don't just return `true` / `false`: they return one of their **operands**, and stop as soon as the result is known.

```js
const user = null;
const guestName = user || "Guest";               // || : first truthy value
console.log("Hello,", guestName);

const savedQty = 0;
console.log("|| gives:", savedQty || 1);          // 0 is falsy, so || replaces it (often wrong!)
console.log("?? gives:", savedQty ?? 1);          // ?? only replaces null or undefined

const cart = { customer: { name: "Asha", address: null } };
console.log(cart.customer?.name);                 // optional chaining: safe access
console.log(cart.customer.address?.city);         // address is null -> undefined, no error
console.log(cart.coupon?.code ?? "no coupon");

const isAdmin = true;
isAdmin && console.log("Showing the admin menu"); // && : run only if the left side is truthy
```

```{ .text .output }
Hello, Guest
|| gives: 1
?? gives: 0
Asha
undefined
no coupon
Showing the admin menu
```

| Operator | Returns | Use for |
|----------|---------|---------|
| `a \|\| b` | `a` if truthy, else `b` | Defaults when **any** falsy value should be replaced |
| `a ?? b` | `a` unless it's `null` / `undefined`, else `b` | Defaults where `0` or `""` are valid (quantities, prices) |
| `a?.b` | `undefined` if `a` is `null` / `undefined`, else `a.b` | Reading nested data that might be missing (API responses) |
| `a && b` | `a` if falsy, else `b` | "Do b only if a" |

Without `?.`, reading `cart.customer.address.city` when `address` is `null` crashes with `TypeError: Cannot read properties of null`. You'll meet that error often when working with API data.

## Loops

### `for`: count a fixed number of times

```js
for (let i = 1; i <= 5; i++) {
  console.log(`Day ${i}: order ${100 + i} delivered`);
}
```

```{ .text .output }
Day 1: order 101 delivered
Day 2: order 102 delivered
Day 3: order 103 delivered
Day 4: order 104 delivered
Day 5: order 105 delivered
```

The three parts: **start** (`let i = 1`), **keep going while** (`i <= 5`), **after each round** (`i++`).

### `for...of`: each item of a list

The loop you'll use most. It goes through the **values** of an array (or the characters of a string):

```js
const cart = [
  { name: "Airdopes 141", price: 1299, qty: 2 },
  { name: "Atomic Habits", price: 499, qty: 1 },
  { name: "USB-C Cable", price: 299, qty: 3 },
];

let subtotal = 0;
for (const item of cart) {
  const line = item.price * item.qty;
  subtotal += line;
  console.log(`${item.name.padEnd(14)} ${item.qty} x ₹${item.price} = ₹${line}`);
}
console.log("Subtotal:", subtotal.toLocaleString("en-IN"));
```

```{ .text .output }
Airdopes 141   2 x ₹1299 = ₹2598
Atomic Habits  1 x ₹499 = ₹499
USB-C Cable    3 x ₹299 = ₹897
Subtotal: 3,994
```

(The `{ name: ..., price: ... }` items are **objects** and `[...]` is an **array**; lessons 4 and 5 cover both in depth.)

### `while` and `do...while`

Use `while` when you don't know in advance how many times you'll loop:

```js
// How many months of saving ₹1,500 to afford the ₹7,999 headphones?
const goal = 7999;
let saved = 0;
let months = 0;
while (saved < goal) {
  saved += 1500;
  months++;
}
console.log(`${months} months (saved ₹${saved})`);

let attempts = 0;
do {
  attempts++;                     // a do...while always runs at least once
} while (attempts < 1);
console.log("Attempts:", attempts);
```

```{ .text .output }
6 months (saved ₹9000)
Attempts: 1
```

!!! mistake "Infinite loops"
    If the condition never becomes false (you forget `saved += 1500`), the loop runs forever and the browser tab freezes. Close the tab, fix the code, and reopen it.

### `break` and `continue`

```js
const prices = [499, 1299, 0, 350, 79999, 2499];

for (const price of prices) {
  if (price === 0) {
    console.log("skip a free item");
    continue;                   // skip to the next item
  }
  if (price > 50000) {
    console.log("found an expensive item, stop");
    break;                      // leave the loop completely
  }
  console.log("price", price);
}
```

```{ .text .output }
price 499
price 1299
skip a free item
price 350
found an expensive item, stop
```

### `for...in`: the keys of an object

```js
const stock = { iphone: 25, airdopes: 200, yogaMat: 0 };
for (const key in stock) {
  console.log(key, "->", stock[key] > 0 ? stock[key] : "sold out");
}
```

```{ .text .output }
iphone -> 25
airdopes -> 200
yogaMat -> sold out
```

Use `for...in` for **objects** and `for...of` for **arrays**. (`for...in` on an array gives you the indexes as strings, which is rarely what you want.) In lesson 4 you'll also meet array methods like `forEach`, `map` and `filter`, which replace many loops.

## Putting It Together: An Order Summary

```js
const items = [
  { name: "Running Shoes", price: 4299, qty: 1, category: "Fashion" },
  { name: "Cotton T-Shirt", price: 799, qty: 3, category: "Fashion" },
  { name: "Atomic Habits", price: 499, qty: 2, category: "Books" },
];
const couponCode = "BOOKS10";           // 10% off books
const isMember = false;

let subtotal = 0;
let discount = 0;
for (const item of items) {
  const line = item.price * item.qty;
  subtotal += line;
  if (couponCode === "BOOKS10" && item.category === "Books") {
    discount += line * 0.1;
  }
}

const afterDiscount = subtotal - discount;
const delivery = afterDiscount >= 499 || isMember ? 0 : 40;
const total = afterDiscount + delivery;

console.log("Subtotal:", subtotal);
console.log("Discount:", discount);
console.log("Delivery:", delivery === 0 ? "Free" : delivery);
console.log("Total:   ", total.toLocaleString("en-IN", { style: "currency", currency: "INR" }));
```

```{ .text .output }
Subtotal: 7694
Discount: 99.80000000000001
Delivery: Free
Total:    ₹7,594.20
```

See `Discount: 99.80000000000001`? That's the floating-point rounding from lesson 1 again (`998 * 0.1`). The raw number is fine for calculating; just format it for display, as the total line does.

!!! realworld "In Real Projects"
    Business rules like delivery charges, coupons and stock checks are full of conditions. Teams keep them readable: early `return`s instead of deep nesting, named constants (`FREE_DELIVERY_MIN = 499`) instead of magic numbers, `??` and `?.` for API data that may be missing, and array methods instead of manual loops where possible. And the same rules are always checked again on the server: never trust a total calculated in the browser.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `if (total = 499)` | Always true; `total` gets overwritten | Compare with `===` |
| `value \|\| default` when `0` is valid | A quantity of `0` becomes the default | `value ?? default` |
| `obj.a.b` on missing data | `TypeError: Cannot read properties of undefined` | `obj.a?.b` |
| Missing `break` in `switch` | Several cases run | `break` or `return` in every case |
| `for...in` over an array | Indexes as strings, possible extra keys | `for...of` |
| Loop condition never false | The tab freezes | Make sure the loop variable changes |
| Off-by-one (`i <= arr.length`) | `undefined` at the end | `i < arr.length` |

## Practice Exercises

**Easy**

1. Print "Bestseller" if a product's rating is 4.5 or more, "Popular" if 4.0 or more, otherwise "New".
2. Use a ternary to print "1 review" or "N reviews" correctly for 0, 1 and 5 reviews.
3. Print the multiplication table of 7 (7 x 1 to 7 x 10) with a `for` loop.

**Medium**

4. Loop over `[1299, 499, 79999, 350, 2499]` and print the most expensive price **without** `Math.max`.
5. Write a `switch` on a day name (`"sat"`, `"sun"`, other) that returns the delivery promise: "Monday", "Monday" or "Tomorrow".
6. Given `const order = { customer: { address: { city: "Pune" } } }` and `const order2 = {}`, print the city for both safely, with "Unknown" as a fallback.

**Challenge**

7. FizzBuzz, shop edition: for order numbers 1 to 20, print "Gift" if divisible by 3, "Coupon" if divisible by 5, "Gift + Coupon" if divisible by both, otherwise the number.

??? success "Solutions (click to expand)"

    ```{ .js .no-run }
    // 1
    const rating = 4.3;
    if (rating >= 4.5) console.log("Bestseller");
    else if (rating >= 4.0) console.log("Popular");
    else console.log("New");

    // 4
    let max = -Infinity;
    for (const p of [1299, 499, 79999, 350, 2499]) {
      if (p > max) max = p;
    }
    console.log(max);

    // 6
    console.log(order.customer?.address?.city ?? "Unknown");
    console.log(order2.customer?.address?.city ?? "Unknown");

    // 7
    for (let n = 1; n <= 20; n++) {
      if (n % 15 === 0) console.log("Gift + Coupon");
      else if (n % 3 === 0) console.log("Gift");
      else if (n % 5 === 0) console.log("Coupon");
      else console.log(n);
    }
    ```

!!! note "Mini Assignment"
    Write `js/pricing.js` for your own business: an array of three or four purchased items, a membership flag, a coupon code and a delivery or service rule. Loop over the items to compute the subtotal, apply the coupon with an `if` or `switch`, decide the delivery charge with a ternary, and print an itemised bill. Use `??` for at least one optional value.

## Interview Questions

!!! interview "1. What are truthy and falsy values?"
    In a boolean context, the falsy values are `false`, `0`, `-0`, `0n`, `""`, `null`, `undefined` and `NaN`. Every other value, including `"0"`, `"false"`, `[]` and `{}`, is truthy.

!!! interview "2. What is the difference between `||` and `??`?"
    `a || b` returns `b` whenever `a` is falsy (including `0` and `""`). `a ?? b` returns `b` only when `a` is `null` or `undefined`, so valid values like `0` and empty strings are kept.

!!! interview "3. What does optional chaining (`?.`) do?"
    It stops and returns `undefined` if the value before it is `null` or `undefined`, instead of throwing a `TypeError`. It works for properties (`a?.b`), indexes (`a?.[0]`) and calls (`a.fn?.()`).

!!! interview "4. What is the difference between `for...of` and `for...in`?"
    `for...of` iterates over the values of an iterable (arrays, strings, Maps, Sets). `for...in` iterates over the enumerable property keys of an object (as strings), including inherited ones, so it's meant for plain objects, not arrays.

!!! interview "5. What happens if you forget `break` in a `switch` case?"
    Execution falls through into the following cases until it reaches a `break`, a `return` or the end of the switch. It's occasionally used deliberately to group cases, but usually it's a bug.

!!! interview "Scenario: a user's cart shows quantity 1 although they set it to 0 to remove the item. What's the likely bug?"
    Code like `const qty = savedQty || 1;` treats `0` as falsy and replaces it with the default. Use `savedQty ?? 1`, and handle a quantity of 0 explicitly by removing the item.

## Summary

| Concept | Syntax |
|---------|--------|
| Conditions | `if (...) { } else if (...) { } else { }` |
| Ternary | `stock > 0 ? "In stock" : "Out of stock"` |
| Switch | `switch (status) { case "shipped": ...; break; default: ... }` |
| Falsy values | `false`, `0`, `""`, `null`, `undefined`, `NaN` (and `-0`, `0n`) |
| Defaults | `a \|\| b` (any falsy) · `a ?? b` (only null / undefined) |
| Safe access | `order.customer?.address?.city` |
| Counting loop | `for (let i = 0; i < n; i++) { }` |
| Array values | `for (const item of cart) { }` |
| Object keys | `for (const key in stock) { }` |
| Unknown repeats | `while (cond) { }` · `do { } while (cond)` |
| Loop control | `break`, `continue` |

**Next lesson:** [Functions & Scope](03-functions-scope.md), packaging logic like "calculate delivery" into reusable functions.
