---
lesson: true
category: JavaScript
short: Basics
description: What JavaScript is and where it runs (browser and Node.js), adding scripts to a page, the console, variables with let and const (and why not var), primitive data types, typeof, strings and template literals, numbers and formatting rupees, type conversion, and arithmetic, comparison and logical operators with strict equality.
---

# Introduction, Variables & Data Types

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain what JavaScript does and run it in the **browser console**, in a page, and with **Node.js**
    - Store values with **`let`** and **`const`**, and explain why `var` is avoided
    - Name the **data types** and check them with `typeof`
    - Work with strings (**template literals**, common methods) and numbers (rounding, formatting **₹**)
    - Use arithmetic, comparison and logical operators, and always choose **`===`** over `==`

**Prerequisites:** the [HTML](../html/01-how-the-web-works.md) and [CSS](../css/01-css-basics.md) modules. If you completed the Python module, many ideas will feel familiar; we'll point out the differences.

## What JavaScript Does

HTML is the structure, CSS the presentation, and **JavaScript the behaviour**: it reacts when the user clicks, types or scrolls, changes the page without reloading, and talks to servers. Everything interactive on the KSR Store (search, add to cart, a cart that remembers its items, products loaded from an API) will be JavaScript.

JavaScript runs in two main places:

| Where | Engine | Used for |
|-------|--------|----------|
| **The browser** | Chrome's V8, Firefox's SpiderMonkey, Safari's JavaScriptCore | Interactive pages (this course) |
| **Node.js** | V8, outside the browser | Servers, tools, scripts (and React's build tools) |

The **language** is the same in both. Browsers add the page (`document`) and window features; Node adds files and networking.

!!! note "JavaScript is not Java"
    Despite the name, JavaScript and Java are completely different languages. The name was a marketing decision in 1995. The official standard is called **ECMAScript**; "ES6" / "ES2015" was the big modern update, and a new version comes out every year.

## Three Ways to Run JavaScript

### 1. The browser console

Open any page, press ++f12++, and choose the **Console** tab. Type an expression and press ++enter++:

```{ .js .no-run }
> 2 + 3
5
> "KSR".toLowerCase()
'ksr'
```

Perfect for quick experiments.

### 2. In a web page

Put your code in a `.js` file and load it with a `<script>` tag. Create `js/hello.js` and `hello-js.html` in your `ksr-store` folder:

```js title="js/hello.js"
console.log("Hello from KSR Store!");
console.log("2 + 3 =", 2 + 3);
```

```html title="hello-js.html"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Hello JavaScript | KSR Store</title>
  <script src="js/hello.js" defer></script>
</head>
<body>
  <h1>Open the console (F12) to see the output</h1>
</body>
</html>
```

Open it with Live Server and look at the Console tab:

```{ .text .output page="hello-js.html" }
Hello from KSR Store!
2 + 3 = 5
```

`defer` tells the browser to download the script without blocking the page and run it **after** the HTML is parsed. Always use it for scripts in `<head>` (you'll see why in the DOM lesson).

### 3. With Node.js

Install **Node.js** (the LTS version) from [nodejs.org](https://nodejs.org/). Then run a file from the terminal (VS Code: *Terminal → New Terminal*):

```bash
node js/hello.js
```

```{ .text .output }
Hello from KSR Store!
2 + 3 = 5
```

In lessons 1 to 5 we focus on the **language**, so the examples show their output as if run with Node. You can paste any of them into the browser console instead: the results are the same.

## Variables: `let` and `const`

A variable is a named box for a value:

```js
const storeName = "KSR Store";    // const: can't be reassigned
let cartCount = 0;                // let: can change

cartCount = cartCount + 1;
cartCount += 2;

console.log(storeName, cartCount);
```

```{ .text .output }
KSR Store 3
```

| Keyword | Reassign? | Scope | Use |
|---------|-----------|-------|-----|
| `const` | No | Block `{ }` | **The default.** Most values never change |
| `let` | Yes | Block `{ }` | Counters, totals, values that change |
| `var` | Yes | Function (ignores blocks) | **Avoid**: old JavaScript with confusing behaviour |

Trying to reassign a `const` is an error:

```js
const deliveryFee = 40;
try {
  deliveryFee = 0;
} catch (error) {
  console.log(error.name + ":", error.message);
}
```

```{ .text .output }
TypeError: Assignment to constant variable.
```

(`try` / `catch` lets the program continue after an error. You'll learn it properly in lesson 11.)

**Naming rules:** names use **camelCase** (`cartCount`, `deliveryFee`), can contain letters, digits, `_` and `$`, can't start with a digit, and are case-sensitive (`price` ≠ `Price`). Choose names that say what the value **means**: `total`, not `x`.

!!! tip "Coming from Python?"
    Python: `cart_count = 0`. JavaScript: `let cartCount = 0;`. JavaScript uses camelCase, declares variables with `let` / `const`, and ends statements with `;` (optional, but recommended). Comments are `//` and `/* ... */` instead of `#`.

## Data Types

| Type | Examples | Notes |
|------|----------|-------|
| `string` | `"iPhone 15"`, `'boAt'`, `` `₹${price}` `` | Text |
| `number` | `79999`, `4.7`, `-10` | One type for integers and decimals |
| `boolean` | `true`, `false` | Yes / no |
| `undefined` | `undefined` | A variable that has no value yet |
| `null` | `null` | "Intentionally empty" |
| `bigint` | `9007199254740993n` | Huge integers (rarely needed) |
| `symbol` | `Symbol("id")` | Unique keys (advanced) |
| `object` | `{ name: "iPhone 15" }`, `[1, 2, 3]` | Everything else: objects, arrays, functions, dates |

The first seven are **primitive** (a single value). `typeof` tells you the type:

```js
let rating;                              // declared, no value yet
const product = { name: "Atomic Habits", price: 499 };

console.log(typeof "Atomic Habits");
console.log(typeof 499);
console.log(typeof true);
console.log(typeof rating, rating);
console.log(typeof null);                // a famous mistake in JavaScript, kept for compatibility
console.log(typeof product);
console.log(typeof [1, 2, 3], Array.isArray([1, 2, 3]));
```

```{ .text .output }
string
number
boolean
undefined undefined
object
object
object true
```

Two surprises worth remembering: `typeof null` is `"object"` (a bug from 1995 that can't be fixed), and arrays are objects too, so use `Array.isArray()` to check for one.

## Strings

```js
const name = "Running Shoes";
const brand = 'Puma';
const price = 4299;

// Template literals: backticks, ${...} inserts any expression
const label = `${name} by ${brand} costs ₹${price}`;
console.log(label);

// Multi-line text is easy with backticks
const message = `Order confirmed!
Delivery in ${2 + 1} days.`;
console.log(message);

console.log(name.length);
console.log(name.toUpperCase(), "|", name.toLowerCase());
console.log(name.includes("Shoes"), name.startsWith("Run"));
console.log(name.slice(0, 7), "|", name.replace("Running", "Walking"));
console.log("  boAt  ".trim() + "!");
console.log("iPhone,Galaxy,Pixel".split(","));
console.log("₹".padStart(4, "*"), "42".padStart(5, "0"));
```

```{ .text .output }
Running Shoes by Puma costs ₹4299
Order confirmed!
Delivery in 3 days.
13
RUNNING SHOES | running shoes
true true
Running | Walking Shoes
boAt!
[ 'iPhone', 'Galaxy', 'Pixel' ]
***₹ 00042
```

- Single quotes, double quotes and backticks all make strings. **Backticks** (template literals) allow `${...}` and line breaks: use them whenever you build text from values.
- Strings are **immutable**: methods like `toUpperCase()` return a **new** string; the original doesn't change.
- Positions start at **0**: `slice(0, 7)` takes characters 0 to 6.

## Numbers

```js
const price = 1299;
const qty = 3;
const gstRate = 0.18;

console.log(price * qty);                       // multiplication
console.log(10 / 4, 10 % 4, 2 ** 10);           // division, remainder, power
console.log(0.1 + 0.2);                         // floating-point surprise
console.log((0.1 + 0.2).toFixed(2));            // round for display (returns a string)
console.log(Math.round(4.5), Math.floor(4.9), Math.ceil(4.1));
console.log(Math.max(499, 1299, 350), Math.min(499, 1299, 350));

const gst = price * qty * gstRate;
console.log("GST:", gst, "->", gst.toFixed(2));

// Format money the Indian way: lakhs and crores
console.log((79999).toLocaleString("en-IN"));
console.log((1234567.5).toLocaleString("en-IN", { style: "currency", currency: "INR" }));
```

```{ .text .output }
3897
2.5 2 1024
0.30000000000000004
0.30
5 4 5
1299 350
GST: 701.4599999999999 -> 701.46
79,999
₹12,34,567.50
```

- `0.1 + 0.2` isn't exactly `0.3`: computers store decimals in binary, as in Python and Java. For display, round with `toFixed()` or format with `toLocaleString()`. Real shops often store money as whole **paise** (integers) to avoid the problem.
- `toLocaleString("en-IN")` uses Indian grouping (12,34,567.50), and `style: "currency"` adds the ₹ symbol.

## Type Conversion

Values from forms and URLs are **always strings**. Convert them before doing maths:

```js
const qtyFromForm = "2";                 // what an <input> gives you

console.log(qtyFromForm + 1);            // string + number = string joining!
console.log(Number(qtyFromForm) + 1);    // convert first
console.log(parseInt("42px"), parseFloat("4.7 stars"));
console.log(Number("abc"), Number(""));  // NaN = "Not a Number"; empty string becomes 0
console.log(Number.isNaN(Number("abc")));
console.log(String(499) + "!", (499).toString());
console.log(Boolean(0), Boolean(""), Boolean("0"), Boolean("hello"));
```

```{ .text .output }
21
3
42 4.7
NaN 0
true
499! 499
false false true true
```

`"2" + 1` gives `"21"`: when one side of `+` is a string, JavaScript **joins** instead of adding. This is the most common beginner bug in shopping-cart code. `Number()` converts explicitly; `NaN` means the conversion failed.

## Operators

### Comparison: always use `===`

```js
console.log(5 === 5, 5 === "5");     // strict: type AND value must match
console.log(5 == "5", 0 == "", null == undefined);   // loose: converts types first (surprising)
console.log(5 !== "5");
console.log(1299 > 499, "apple" < "banana");
```

```{ .text .output }
true false
true true true
true
true true
```

`==` converts types before comparing, which leads to strange results like `0 == ""` being `true`. **Always use `===` and `!==`.** (Many teams' tools flag `==` as an error.)

### Logical operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `&&` | AND | `inStock && price < 1000` |
| `\|\|` | OR | `isMember \|\| total >= 499` |
| `!` | NOT | `!isLoggedIn` |

```js
const total = 650;
const isMember = false;
const freeDelivery = isMember || total >= 499;
console.log("Free delivery?", freeDelivery);

const inStock = true;
const canBuy = inStock && total > 0;
console.log("Can buy?", canBuy, "| Not in stock?", !inStock);
```

```{ .text .output }
Free delivery? true
Can buy? true | Not in stock? false
```

### Assignment shortcuts

`x += 5` (x = x + 5), `x -= 5`, `x *= 2`, `x /= 2`, `x++` (add 1), `x--` (subtract 1).

!!! realworld "In Real Projects"
    Teams write modern JavaScript: `const` by default, `let` when needed, never `var`, always `===`, template literals for text. Tools enforce it automatically: **ESLint** flags `var`, `==` and unused variables, and **Prettier** formats the code consistently. Large projects often add **TypeScript**, which is JavaScript plus type annotations (`let price: number`) checked before the code runs.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `"2" + 1` from form values | `"21"` instead of `3` | Convert first: `Number(value)` |
| `==` instead of `===` | `0 == ""` is `true`; hard-to-find bugs | Always `===` / `!==` |
| Reassigning a `const` | `TypeError: Assignment to constant variable.` | Use `let` if it must change |
| Using `var` | Variables leak out of blocks | `let` / `const` |
| Displaying `0.1 + 0.2` directly | `0.30000000000000004` on the page | `toFixed(2)` or `toLocaleString()` |
| Quotes inside strings (`'Kiran's cart'`) | `SyntaxError` | Use other quotes or backticks: `` `Kiran's cart` `` |
| `typeof x === "array"` | Never true | `Array.isArray(x)` |

## Practice Exercises

**Easy**

1. Store a product name, price and quantity in variables and print `"3 x Airdopes 141 = ₹3,897"` using a template literal and `toLocaleString("en-IN")`.
2. Print the type of each of these: `"499"`, `499`, `false`, `null`, `undefined`, `{}`, `[]`.
3. Convert `"1,299"` (with a comma) into the number `1299`. (Hint: `replace` or `replaceAll`.)

**Medium**

4. Calculate a cart total: two items at ₹1,299 and one at ₹499, plus 18% GST. Print the subtotal, GST and total, each rounded to 2 decimals.
5. Write an expression that is `true` when an order gets free delivery: the total is at least ₹499 **or** the customer is a member, **and** the PIN code isn't empty.
6. Given `const email = "  Asha.Reddy@Example.COM "`, produce a clean lowercase email without spaces, and check it contains `@` and ends with `.com`.

**Challenge**

7. Given a price in paise (`129900`), print it as `₹1,299.00` using integer division and the remainder operator only (no `toFixed`), padding the paise to two digits with `padStart`.

??? success "Solutions (click to expand)"

    ```{ .js .no-run }
    // 1
    const name = "Airdopes 141", price = 1299, qty = 3;
    console.log(`${qty} x ${name} = ₹${(price * qty).toLocaleString("en-IN")}`);

    // 3
    console.log(Number("1,299".replaceAll(",", "")));   // 1299

    // 4
    const subtotal = 2 * 1299 + 499;
    const gst = subtotal * 0.18;
    console.log(subtotal.toFixed(2), gst.toFixed(2), (subtotal + gst).toFixed(2));

    // 5
    const total = 650, isMember = false, pincode = "500016";
    const free = (total >= 499 || isMember) && pincode !== "";

    // 6
    const clean = "  Asha.Reddy@Example.COM ".trim().toLowerCase();
    console.log(clean, clean.includes("@") && clean.endsWith(".com"));

    // 7
    const paise = 129900;
    const rupees = Math.floor(paise / 100);
    const rest = String(paise % 100).padStart(2, "0");
    console.log(`₹${rupees.toLocaleString("en-IN")}.${rest}`);
    ```

!!! note "Mini Assignment"
    Write `js/bill.js` that stores a small restaurant bill in variables (three items with prices and quantities, a 5% GST rate and a 10% tip), computes the subtotal, GST, tip and grand total, and prints a neatly formatted bill with template literals and `toLocaleString("en-IN", { style: "currency", currency: "INR" })`. Run it with Node **and** load it in a page to see the same output in the browser console.

## Interview Questions

!!! interview "1. What is the difference between `let`, `const` and `var`?"
    `let` and `const` are block-scoped; `const` can't be reassigned (though an object it holds can still be modified). `var` is function-scoped, can be redeclared, and is hoisted with the value `undefined`, which causes confusing bugs, so modern code avoids it.

!!! interview "2. What are the primitive data types in JavaScript?"
    `string`, `number`, `boolean`, `undefined`, `null`, `bigint` and `symbol`. Everything else (objects, arrays, functions, dates) is an `object`.

!!! interview "3. What is the difference between `==` and `===`?"
    `===` (strict equality) compares value and type without conversion. `==` (loose equality) converts the operands to a common type first, producing surprising results like `0 == ""` and `"1" == 1`. Use `===`.

!!! interview "4. What is the difference between `null` and `undefined`?"
    `undefined` means a variable has been declared but not assigned (or a property doesn't exist); JavaScript sets it automatically. `null` is assigned deliberately to mean "no value". `typeof null` returns `"object"` for historical reasons.

!!! interview "5. Why does `0.1 + 0.2` not equal `0.3`?"
    Numbers are stored as binary floating point (IEEE 754), which can't represent some decimal fractions exactly, so tiny rounding errors appear. Round for display (`toFixed`, `toLocaleString`), compare with a small tolerance, or store money as integer paise.

!!! interview "Scenario: the cart shows a total of ₹1299499 instead of ₹1,798. What happened?"
    The prices were strings (from form inputs, data attributes or JSON) and `+` concatenated them: `"1299" + "499"`. Convert with `Number()` before adding, then format the result with `toLocaleString("en-IN")`.

## Summary

| Concept | Example |
|---------|---------|
| Run JS | Console (++f12++), `<script src="js/app.js" defer>`, `node js/app.js` |
| Output | `console.log("Total:", total)` |
| Variables | `const name = "KSR";` (default) · `let count = 0;` (changes) · no `var` |
| Types | `string`, `number`, `boolean`, `undefined`, `null`, `bigint`, `symbol`, `object` |
| Check type | `typeof value` · `Array.isArray(value)` |
| Strings | `` `₹${price}` ``, `.length`, `.toUpperCase()`, `.includes()`, `.slice()`, `.split()`, `.trim()` |
| Numbers | `toFixed(2)`, `Math.round()`, `toLocaleString("en-IN", { style: "currency", currency: "INR" })` |
| Conversion | `Number("2")`, `parseInt()`, `String(499)`, `Boolean(0)` |
| Comparison | `===`, `!==`, `>`, `<` (never `==`) |
| Logic | `&&`, `\|\|`, `!` |

**Next lesson:** [Conditions & Loops](02-conditions-loops.md), making decisions (delivery charges, discounts) and repeating work (looping over a cart).
