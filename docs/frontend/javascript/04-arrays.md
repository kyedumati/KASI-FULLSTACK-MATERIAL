---
lesson: true
category: JavaScript
short: Arrays
description: Working with lists in JavaScript - creating arrays, indexes and length, adding and removing items (push, pop, shift, unshift, splice), copying with slice and spread, searching (includes, indexOf, find, findIndex, some, every), the core array methods forEach, map, filter and reduce, sorting safely, chaining, and array destructuring - applied to the KSR Store product catalogue.
---

# Arrays & Array Methods

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Create arrays, read items by **index**, and use `length`
    - Add and remove items with `push`, `pop`, `shift`, `unshift` and `splice`, and copy with `slice` and **spread**
    - Search with `includes`, `find`, `findIndex`, `some` and `every`
    - Transform data with **`map`**, **`filter`** and **`reduce`**, and **chain** them
    - Sort numbers and text correctly, and destructure arrays

**Prerequisites:** [Functions & Scope](03-functions-scope.md). Arrow functions and callbacks are used in every example.

## Creating Arrays

An **array** is an ordered list of values:

```js
const categories = ["Electronics", "Fashion", "Books"];
const prices = [79999, 1299, 3499];
const empty = [];
const mixed = ["iPhone 15", 79999, true];   // allowed, but keep arrays to one kind of value

console.log(categories[0], categories[2]);  // indexes start at 0
console.log(categories.length);
console.log(categories[categories.length - 1], categories.at(-1));   // last item, two ways
console.log(categories[5]);                 // no error, just undefined

categories[1] = "Clothing";                 // replace an item (const arrays can still change)
console.log(categories);
```

```{ .text .output }
Electronics Books
3
Books Books
undefined
[ 'Electronics', 'Clothing', 'Books' ]
```

`const` stops you assigning a **new** array to the variable, but the array's contents can still change.

Most real arrays hold **objects**. Here's the KSR Store catalogue we'll use for the rest of the lesson:

```js title="js/products-data.js"
const products = [
  { id: 1, name: "iPhone 15", category: "Electronics", brand: "Apple", price: 79999, stock: 25, rating: 4.7 },
  { id: 3, name: "Airdopes 141", category: "Electronics", brand: "boAt", price: 1299, stock: 200, rating: 4.1 },
  { id: 6, name: "Denim Jacket", category: "Fashion", brand: "Levis", price: 3499, stock: 40, rating: 4.4 },
  { id: 7, name: "Running Shoes", category: "Fashion", brand: "Puma", price: 4299, stock: 60, rating: 4.2 },
  { id: 9, name: "Atomic Habits", category: "Books", brand: "Penguin", price: 499, stock: 80, rating: 4.8 },
  { id: 10, name: "Wings of Fire", category: "Books", brand: "Universities Press", price: 350, stock: 0, rating: 4.7 },
  { id: 12, name: "Non-stick Pan", category: "Home & Kitchen", brand: "Prestige", price: 1599, stock: 35, rating: 4.2 },
  { id: 15, name: "Cricket Bat", category: "Sports", brand: "SG", price: 2499, stock: 22, rating: 4.4 },
];

export default products;
```

`export default` makes the array available to other files. Each example below starts with `import products from "./js/products-data.js";` (you'll learn modules properly in lesson 11; for now, it's "load the catalogue").

For Node to understand `import` and `export` in `.js` files, add a small `package.json` to the `ksr-store` folder:

```json title="package.json"
{
  "name": "ksr-store",
  "type": "module"
}
```

`"type": "module"` tells Node to treat `.js` files as modern JavaScript modules, the same way browsers load `<script type="module">`.

## Adding and Removing Items

| Method | Does | Returns | Changes the array? |
|--------|------|---------|--------------------|
| `push(x)` | Add to the **end** | New length | Yes |
| `pop()` | Remove from the **end** | The removed item | Yes |
| `unshift(x)` | Add to the **start** | New length | Yes |
| `shift()` | Remove from the **start** | The removed item | Yes |
| `splice(i, n, ...items)` | Remove `n` items at index `i`, optionally insert | Removed items | Yes |
| `slice(start, end)` | Copy part of the array | A **new** array | No |

```js
const recentlyViewed = ["Atomic Habits", "Airdopes 141"];

recentlyViewed.push("Cricket Bat");
recentlyViewed.unshift("iPhone 15");
console.log(recentlyViewed);

const last = recentlyViewed.pop();
const first = recentlyViewed.shift();
console.log("removed", first, "and", last, "->", recentlyViewed);

const cart = ["Airdopes 141", "Atomic Habits", "USB-C Cable", "Yoga Mat"];
const removed = cart.splice(1, 2);                 // remove 2 items from index 1
console.log(removed, cart);
cart.splice(1, 0, "Running Shoes");                // insert without removing
console.log(cart);

console.log(cart.slice(0, 2), "| original:", cart);
```

```{ .text .output }
[ 'iPhone 15', 'Atomic Habits', 'Airdopes 141', 'Cricket Bat' ]
removed iPhone 15 and Cricket Bat -> [ 'Atomic Habits', 'Airdopes 141' ]
[ 'Atomic Habits', 'USB-C Cable' ] [ 'Airdopes 141', 'Yoga Mat' ]
[ 'Airdopes 141', 'Running Shoes', 'Yoga Mat' ]
[ 'Airdopes 141', 'Running Shoes' ] | original: [ 'Airdopes 141', 'Running Shoes', 'Yoga Mat' ]
```

### Copying and combining with spread

```js
const electronics = ["iPhone 15", "Airdopes 141"];
const books = ["Atomic Habits"];

const all = [...electronics, ...books, "Cricket Bat"];   // spread: unpack the items
const copy = [...electronics];
copy.push("Galaxy S24");

console.log(all);
console.log(electronics, copy);                          // the copy changed, the original didn't
```

```{ .text .output }
[ 'iPhone 15', 'Airdopes 141', 'Atomic Habits', 'Cricket Bat' ]
[ 'iPhone 15', 'Airdopes 141' ] [ 'iPhone 15', 'Airdopes 141', 'Galaxy S24' ]
```

!!! warning "Arrays are copied by reference"
    `const copy = electronics;` doesn't copy the array: both names point to the **same** array, so changing one changes the other. Use `[...electronics]` (or `slice()`) for a real copy.

## Searching

```js
import products from "./js/products-data.js";

const names = products.map(p => p.name);          // map is explained in the next section
console.log(names.includes("Cricket Bat"), names.indexOf("Atomic Habits"), names.indexOf("Yoga Mat"));

const book = products.find(p => p.category === "Books");          // first match, or undefined
console.log(book.name);
console.log(products.find(p => p.price > 100000));

const index = products.findIndex(p => p.id === 7);
console.log("Running Shoes is at index", index);

console.log("Anything out of stock?", products.some(p => p.stock === 0));
console.log("All rated 4+?", products.every(p => p.rating >= 4));
```

```{ .text .output }
true 4 -1
Atomic Habits
undefined
Running Shoes is at index 3
Anything out of stock? true
All rated 4+? true
```

| Method | Returns |
|--------|---------|
| `includes(value)` | `true` / `false` |
| `indexOf(value)` | The index, or `-1` |
| `find(test)` | The **first item** that passes the test, or `undefined` |
| `findIndex(test)` | Its index, or `-1` |
| `some(test)` | `true` if **at least one** passes |
| `every(test)` | `true` if **all** pass |

`includes` and `indexOf` compare values with `===`, so they work for strings and numbers. For objects, use `find` / `findIndex` with a test function.

## The Big Three: `map`, `filter`, `reduce`

These three methods replace most loops. Each takes a **callback** that's called for every item.

```{ .text .no-run }
map:     [🍎, 🍌, 🍇]  -- turn each into something else -->  [🧃, 🥤, 🍷]   same length
filter:  [🍎, 🍌, 🍇]  -- keep the ones that pass       -->  [🍎, 🍇]       same or fewer
reduce:  [🍎, 🍌, 🍇]  -- combine into ONE value        -->  🥗
```

### `map`: transform every item

```js
import products from "./js/products-data.js";

const names = products.map(p => p.name);
console.log(names);

const withGst = products.slice(0, 3).map(p => ({ name: p.name, priceWithGst: Math.round(p.price * 1.18) }));
console.log(withGst);

const labels = products.slice(0, 3).map((p, i) => `${i + 1}. ${p.name} - ₹${p.price.toLocaleString("en-IN")}`);
console.log(labels.join("\n"));
```

```{ .text .output }
[
  'iPhone 15',
  'Airdopes 141',
  'Denim Jacket',
  'Running Shoes',
  'Atomic Habits',
  'Wings of Fire',
  'Non-stick Pan',
  'Cricket Bat'
]
[
  { name: 'iPhone 15', priceWithGst: 94399 },
  { name: 'Airdopes 141', priceWithGst: 1533 },
  { name: 'Denim Jacket', priceWithGst: 4129 }
]
1. iPhone 15 - ₹79,999
2. Airdopes 141 - ₹1,299
3. Denim Jacket - ₹3,499
```

`map` always returns a **new array of the same length**. The callback receives the item and its index. (Returning an object from an arrow function needs parentheses: `p => ({ ... })`.)

### `filter`: keep the items that pass

```js
import products from "./js/products-data.js";

const inStock = products.filter(p => p.stock > 0);
console.log(inStock.length, "of", products.length, "in stock");

const affordableFashion = products.filter(p => p.category === "Fashion" && p.price < 4000);
console.log(affordableFashion.map(p => p.name));

const search = "o";
const matches = products.filter(p => p.name.toLowerCase().includes(search));
console.log(matches.map(p => p.name));
```

```{ .text .output }
7 of 8 in stock
[ 'Denim Jacket' ]
[
  'iPhone 15',
  'Airdopes 141',
  'Running Shoes',
  'Atomic Habits',
  'Wings of Fire',
  'Non-stick Pan'
]
```

That last `filter` is exactly what a **search box** does. You'll connect it to a real input in lesson 7.

### `reduce`: combine everything into one value

```js
import products from "./js/products-data.js";

// Total value of all stock: start at 0, add price × stock for each product
const stockValue = products.reduce((sum, p) => sum + p.price * p.stock, 0);
console.log("Stock value:", stockValue.toLocaleString("en-IN"));

// A cart total
const cart = [
  { name: "Airdopes 141", price: 1299, qty: 2 },
  { name: "Atomic Habits", price: 499, qty: 1 },
];
const total = cart.reduce((sum, item) => sum + item.price * item.qty, 0);
console.log("Cart total:", total);

// Count products per category: the accumulator is an object
const perCategory = products.reduce((counts, p) => {
  counts[p.category] = (counts[p.category] ?? 0) + 1;
  return counts;
}, {});
console.log(perCategory);
```

```{ .text .output }
Stock value: 28,08,538
Cart total: 3097
{
  Electronics: 2,
  Fashion: 2,
  Books: 2,
  'Home & Kitchen': 1,
  Sports: 1
}
```

`reduce(callback, initialValue)`: the callback gets the **accumulator** (the running result) and the current item, and returns the new accumulator. Always pass the initial value (`0`, `{}`, `[]`).

### `forEach`: just do something with each item

```js
import products from "./js/products-data.js";

products.slice(0, 3).forEach((p, i) => {
  console.log(`#${i + 1} ${p.name} (${p.brand})`);
});
```

```{ .text .output }
#1 iPhone 15 (Apple)
#2 Airdopes 141 (boAt)
#3 Denim Jacket (Levis)
```

`forEach` returns nothing (`undefined`). Use it for **side effects** (logging, updating the page); use `map` when you want a new array.

## Chaining

Because `map` and `filter` return arrays, you can **chain** them into a readable pipeline:

```js
import products from "./js/products-data.js";

// Names and prices of in-stock products under ₹5,000, cheapest first
const deals = products
  .filter(p => p.stock > 0)
  .filter(p => p.price < 5000)
  .sort((a, b) => a.price - b.price)
  .map(p => `${p.name}: ₹${p.price}`);

console.log(deals);

const booksValue = products
  .filter(p => p.category === "Books")
  .reduce((sum, p) => sum + p.price, 0);
console.log("Books total:", booksValue);
```

```{ .text .output }
[
  'Atomic Habits: ₹499',
  'Airdopes 141: ₹1299',
  'Non-stick Pan: ₹1599',
  'Cricket Bat: ₹2499',
  'Denim Jacket: ₹3499',
  'Running Shoes: ₹4299'
]
Books total: 849
```

Read it top to bottom like a sentence: "take the products, keep those in stock, keep those under ₹5,000, sort by price, turn each into a label".

## Sorting

`sort()` sorts **in place** (it changes the array), and by default it compares items **as text**:

```js
const prices = [1299, 499, 79999, 350, 2499];
console.log([...prices].sort());                     // wrong for numbers: compared as text
console.log([...prices].sort((a, b) => a - b));      // ascending
console.log([...prices].sort((a, b) => b - a));      // descending

const names = ["iPhone 15", "Airdopes 141", "atomic habits", "Cricket Bat"];
console.log([...names].sort());                      // capital letters sort before lowercase
console.log([...names].sort((a, b) => a.localeCompare(b)));   // human order

console.log(prices.toSorted((a, b) => a - b), prices);        // toSorted: returns a new array
```

```{ .text .output }
[ 1299, 2499, 350, 499, 79999 ]
[ 350, 499, 1299, 2499, 79999 ]
[ 79999, 2499, 1299, 499, 350 ]
[ 'Airdopes 141', 'Cricket Bat', 'atomic habits', 'iPhone 15' ]
[ 'Airdopes 141', 'atomic habits', 'Cricket Bat', 'iPhone 15' ]
[ 350, 499, 1299, 2499, 79999 ] [ 1299, 499, 79999, 350, 2499 ]
```

- The **compare function** returns a negative number if `a` comes first, positive if `b` comes first, `0` if equal. `a - b` sorts numbers ascending.
- `localeCompare` sorts text the way people expect, ignoring case differences.
- `sort()` changes the original array; copy first (`[...arr].sort()`) or use the newer **`toSorted()`**, which returns a new array.

To sort objects, compare a property: `products.toSorted((a, b) => b.rating - a.rating)`.

## Destructuring Arrays

```js
const [first, second, ...others] = ["iPhone 15", "Airdopes 141", "Atomic Habits", "Cricket Bat"];
console.log(first, "|", second, "|", others);

const [, , third] = ["gold", "silver", "bronze"];       // skip items
console.log(third);

let a = 1, b = 2;
[a, b] = [b, a];                                          // swap two variables
console.log(a, b);
```

```{ .text .output }
iPhone 15 | Airdopes 141 | [ 'Atomic Habits', 'Cricket Bat' ]
bronze
2 1
```

You'll see this pattern constantly in React: `const [count, setCount] = useState(0);`.

!!! realworld "In Real Projects"
    Almost every screen shows a list: products, orders, messages, search results. Data arrives from an API as an array of objects, and the frontend uses `filter` (search, filters), `toSorted` (sort options), `map` (turn data into HTML or React components) and `reduce` (totals, counts). Teams prefer these methods to manual loops because they're shorter, don't change the original data, and read like a description of the result.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `arr[arr.length]` for the last item | `undefined` | `arr[arr.length - 1]` or `arr.at(-1)` |
| `[10, 9, 100].sort()` | `[10, 100, 9]` | `sort((a, b) => a - b)` |
| `sort()` on the original data | The original order is lost | `toSorted()` or `[...arr].sort()` |
| Expecting `forEach` to return an array | `undefined` | Use `map` |
| `map` with braces but no `return` | An array of `undefined` | `p => p.name` or `p => { return p.name; }` |
| `reduce` without an initial value | Errors on empty arrays, wrong types | Always pass one: `reduce(fn, 0)` |
| `const b = a;` as a "copy" | Changing `b` changes `a` | `const b = [...a];` |
| `includes` with objects | Always `false` | `some(p => p.id === 7)` |

## Practice Exercises

**Easy**

1. Get an array of all brands.
2. Get the products with a rating of 4.5 or more.
3. Find the product with `id` 12 and print its name.

**Medium**

4. Calculate the average price of the Electronics products, rounded.
5. Build an array of strings like `"Atomic Habits (Books)"` for products under ₹1,000, sorted by name.
6. Use `reduce` to group product **names** by category: `{ Electronics: ["iPhone 15", "Airdopes 141"], ... }`.

**Challenge**

7. Write `paginate(items, page, perPage)` returning `{ items, page, totalPages }` using `slice`, and print page 2 of the catalogue with 3 products per page.

??? success "Solutions (click to expand)"

    ```{ .js .no-run }
    // 1
    const brands = products.map(p => p.brand);

    // 2
    const topRated = products.filter(p => p.rating >= 4.5);

    // 3
    console.log(products.find(p => p.id === 12)?.name);

    // 4
    const electronics = products.filter(p => p.category === "Electronics");
    const avg = Math.round(electronics.reduce((s, p) => s + p.price, 0) / electronics.length);

    // 5
    const cheap = products
      .filter(p => p.price < 1000)
      .toSorted((a, b) => a.name.localeCompare(b.name))
      .map(p => `${p.name} (${p.category})`);

    // 6
    const grouped = products.reduce((groups, p) => {
      (groups[p.category] ??= []).push(p.name);
      return groups;
    }, {});

    // 7
    function paginate(items, page, perPage) {
      const start = (page - 1) * perPage;
      return { items: items.slice(start, start + perPage), page, totalPages: Math.ceil(items.length / perPage) };
    }
    console.log(paginate(products, 2, 3));
    ```

!!! note "Mini Assignment"
    Create a data file for your own business with at least eight items (objects with id, name, category, price, and two more properties). Write a script that prints: the cheapest and most expensive item, the items in one category sorted by price, the average price per category, a search for a word in the names, and the total of a sample order. Use `map`, `filter`, `reduce`, `find` and `toSorted`, and no `for` loops.

## Interview Questions

!!! interview "1. What is the difference between `map`, `filter` and `forEach`?"
    `map` returns a new array with each item transformed (same length). `filter` returns a new array containing only the items that pass a test. `forEach` runs a function for each item and returns `undefined`; it's for side effects.

!!! interview "2. How does `reduce` work?"
    It calls a callback for each item with an accumulator and the current item, and the callback's return value becomes the accumulator for the next item. The final accumulator is the result. An initial value should always be provided.

!!! interview "3. Why does `[10, 9, 100].sort()` return `[10, 100, 9]`?"
    Without a compare function, `sort` converts items to strings and compares them character by character, so `"100"` comes before `"9"`. Pass `(a, b) => a - b` to sort numbers.

!!! interview "4. Which array methods mutate the array?"
    `push`, `pop`, `shift`, `unshift`, `splice`, `sort`, `reverse` and `fill`. Non-mutating alternatives include `slice`, spread, `concat`, `map`, `filter`, and the newer `toSorted`, `toReversed` and `toSpliced`.

!!! interview "5. What is the difference between `find` and `filter`?"
    `find` returns the first matching item (or `undefined`) and stops searching. `filter` checks every item and returns an array of all matches (possibly empty).

!!! interview "Scenario: after sorting products by price on the "Price: low to high" button, the "Relevance" option no longer shows the original order. Why?"
    `sort()` mutated the original array, so the original order was lost. Keep the original data unchanged and sort a copy (`toSorted()` or `[...products].sort(...)`) each time an option is chosen.

## Summary

| Task | Code |
|------|------|
| Create / read | `const arr = [a, b]` · `arr[0]` · `arr.at(-1)` · `arr.length` |
| Add / remove | `push`, `pop`, `unshift`, `shift`, `splice(i, n)` |
| Copy / combine | `slice()`, `[...a, ...b]` |
| Search | `includes`, `indexOf`, `find`, `findIndex`, `some`, `every` |
| Transform | `map(p => p.name)` |
| Select | `filter(p => p.stock > 0)` |
| Combine | `reduce((sum, p) => sum + p.price, 0)` |
| Side effects | `forEach(p => console.log(p))` |
| Sort | `toSorted((a, b) => a.price - b.price)` · `localeCompare` for text |
| Destructure | `const [first, ...rest] = arr` |

**Next lesson:** [Objects, Destructuring & JSON](05-objects-json.md), the shape of every product, cart and API response.
