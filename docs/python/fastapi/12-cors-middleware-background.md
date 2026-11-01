---
lesson: true
category: FastAPI
short: CORS
api_app: app.main:app
api_db: true
description: Getting the AcmeHR API ready for a browser frontend — CORS, middleware for request IDs and timing, an HR dashboard endpoint, document uploads with UploadFile, background tasks that notify HR after the response, and calling the API from JavaScript and React.
---

# CORS, Middleware & Background Tasks

!!! abstract "Learning Objectives"
    By the end of this lesson, you can:

    - Explain why browsers block requests to other origins, and fix it with **CORS**
    - Write **middleware** that runs for every request (timing, logging, request IDs)
    - Accept **file uploads** safely with `UploadFile`: type, size and content checks
    - Run slow work (notifications) with **background tasks** after responding
    - Build a dashboard endpoint for a frontend, and call the API from plain JavaScript and React

**Prerequisites:** [Testing FastAPI](11-testing-fastapi.md) and the [Frontend](../../frontend/index.md) module basics (HTML and JavaScript).

## The Problem: The Browser Blocks Your API

Acme's HR portal will be a React app running at `http://localhost:5173` during development, and your API runs at `http://127.0.0.1:8000`. The first time the portal calls the API, the browser console shows:

```{ .text .output }
Access to fetch at 'http://127.0.0.1:8000/dashboard' from origin 'http://localhost:5173'
has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present
on the requested resource.
```

The API worked perfectly with curl. What happened?

An **origin** is the combination of **scheme + host + port**. `http://localhost:5173` and `http://127.0.0.1:8000` are **different origins**. For security, browsers follow the **Same-Origin Policy**: JavaScript on one origin can't read responses from another origin **unless that server explicitly allows it**. That permission system is **CORS** (Cross-Origin Resource Sharing).

!!! example "Real-life analogy: the visitors' register"
    Acme's reception (the browser) protects the building. Visitors from another company (another origin) only get in if the employee they're visiting (your API) has added them to the day's **visitors' register**. Couriers who use the goods entrance (curl, Postman) don't pass through reception at all. That's why your API "worked in curl".

```mermaid
sequenceDiagram
  participant B as Browser (localhost:5173)
  participant A as API (127.0.0.1:8000)
  B->>A: OPTIONS /employees/E-1042/documents (preflight)<br/>Origin: http://localhost:5173<br/>Access-Control-Request-Method: POST
  A-->>B: 200 Access-Control-Allow-Origin: http://localhost:5173<br/>Access-Control-Allow-Methods: ...
  B->>A: POST /employees/E-1042/documents (the real request)
  A-->>B: 201 + Access-Control-Allow-Origin
  Note over B: JavaScript may read the response
```

For "non-simple" requests (JSON bodies, `Authorization` headers, `PUT`/`PATCH`/`DELETE`), the browser first sends a **preflight** `OPTIONS` request asking for permission.

## The Complete Example

```python title="app/main.py"
import logging
import os
import pathlib
import time
import uuid
from datetime import date
from enum import Enum
from typing import Annotated

from fastapi import BackgroundTasks, FastAPI, File, Form, HTTPException, Path, Query, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from sqlalchemy import create_engine, text

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("acmehr")

engine = create_engine(os.environ.get("DATABASE_URL", "mysql+mysqlconnector://root:password@localhost:3306/acmehr"),
                       pool_pre_ping=True)

app = FastAPI(title="AcmeHR API")

# ---- CORS: which browser origins may call this API ----
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "https://hr.acme.example"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)


# ---- Custom middleware: request id + timing + access log ----
@app.middleware("http")
async def add_request_context(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID", uuid.uuid4().hex[:8])
    start = time.perf_counter()
    response = await call_next(request)                   # run the endpoint
    elapsed_ms = (time.perf_counter() - start) * 1000
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Process-Time-Ms"] = f"{elapsed_ms:.1f}"
    logger.info("%s %s -> %s (%.1f ms) id=%s", request.method, request.url.path,
                response.status_code, elapsed_ms, request_id)
    return response


EmployeeCode = Annotated[str, Path(pattern=r"^E-\d{4}$")]


# ---- The HR dashboard (BRD: "HR sees today's headcount, attendance, leave and pending approvals") ----
@app.get("/dashboard")
def dashboard(day: Annotated[date, Query(alias="date")]):
    p = {"d": day}
    with engine.connect() as conn:
        headcount = conn.execute(text("SELECT COUNT(*) FROM employees WHERE status <> 'exited'")).scalar()
        present = conn.execute(text("SELECT COUNT(*) FROM attendance WHERE work_date = :d"), p).scalar()
        late = conn.execute(text("""
            SELECT COUNT(*) FROM attendance a
            JOIN employees e ON e.id = a.employee_id JOIN shifts s ON s.id = e.shift_id
            WHERE a.work_date = :d AND a.check_in > ADDTIME(s.start_time, SEC_TO_TIME(s.grace_minutes * 60))
        """), p).scalar()
        on_leave = conn.execute(text("""
            SELECT CONCAT(e.first_name, ' ', e.last_name) FROM leave_requests r
            JOIN employees e ON e.id = r.employee_id
            WHERE r.status = 'approved' AND :d BETWEEN r.start_date AND r.end_date
            ORDER BY e.first_name
        """), p).scalars().all()
        pending = conn.execute(text("SELECT COUNT(*) FROM leave_requests WHERE status = 'pending'")).scalar()
        by_location = dict(conn.execute(text("""
            SELECT l.city, COUNT(*) FROM employees e JOIN locations l ON l.id = e.location_id
            WHERE e.status <> 'exited' GROUP BY l.city ORDER BY COUNT(*) DESC
        """)).all())
        holidays = [{"date": d, "name": name} for d, name in conn.execute(
            text("SELECT holiday_date, name FROM holidays WHERE holiday_date > :d ORDER BY holiday_date LIMIT 2"), p)]
    return {"date": day, "headcount": headcount, "present": present, "late": late, "on_leave": on_leave,
            "pending_approvals": pending, "by_location": by_location, "upcoming_holidays": holidays}


# ---- Documents: upload + background notification ----
class DocType(str, Enum):
    id_proof = "id_proof"
    address_proof = "address_proof"
    education = "education"
    agreement = "agreement"
    tax = "tax"


UPLOAD_DIR = pathlib.Path("uploads")
MAX_BYTES = 2 * 1024 * 1024                                   # 2 MB
SIGNATURES = {".pdf": b"%PDF", ".png": b"\x89PNG", ".jpg": b"\xff\xd8\xff", ".jpeg": b"\xff\xd8\xff"}


def notify_hr(employee: str, doc_type: str, file_name: str) -> None:
    time.sleep(1)                                             # pretend: talking to an email service
    with open("notifications.log", "a", encoding="utf-8") as log:
        log.write(f"To HR: please verify {employee}'s {doc_type} ({file_name})\n")


def find_employee(conn, code: str):
    row = conn.execute(text("SELECT id, CONCAT(first_name, ' ', last_name) AS name FROM employees "
                            "WHERE employee_code = :code"), {"code": code}).first()
    if row is None:
        raise HTTPException(status_code=404, detail=f"Employee {code} not found")
    return row


@app.post("/employees/{code}/documents", status_code=201)
def upload_document(code: EmployeeCode, background_tasks: BackgroundTasks,
                    doc_type: Annotated[DocType, Form()], file: Annotated[UploadFile, File()]):
    suffix = pathlib.Path(file.filename or "").suffix.lower()
    if suffix not in SIGNATURES:
        raise HTTPException(status_code=415, detail="Only PDF, PNG or JPG files are accepted")
    content = file.file.read(MAX_BYTES + 1)                   # never read more than we'd accept
    if len(content) > MAX_BYTES:
        raise HTTPException(status_code=413, detail="The file is larger than 2 MB")
    if not content.startswith(SIGNATURES[suffix]):
        raise HTTPException(status_code=415, detail=f"The file's contents don't match its {suffix} extension")

    with engine.begin() as conn:                              # one transaction: the row and the file
        employee = find_employee(conn, code)
        size_kb = -(-len(content) // 1024)                    # round up
        result = conn.execute(text(
            "INSERT INTO documents (employee_id, doc_type, file_name, size_kb, verified, uploaded_at) "
            "VALUES (:emp, :type, :name, :size, FALSE, NOW())"),
            {"emp": employee.id, "type": doc_type.value, "name": file.filename, "size": size_kb})
        doc_id = result.lastrowid
        folder = UPLOAD_DIR / code
        folder.mkdir(parents=True, exist_ok=True)
        (folder / f"{doc_id}{suffix}").write_bytes(content)  # stored under our own name, never the user's

    background_tasks.add_task(notify_hr, employee.name, doc_type.value, file.filename)
    return {"id": doc_id, "employee": employee.name, "doc_type": doc_type, "file_name": file.filename,
            "size_kb": size_kb, "verified": False}


@app.get("/employees/{code}/documents")
def list_documents(code: EmployeeCode):
    with engine.connect() as conn:
        employee = find_employee(conn, code)
        rows = conn.execute(text("SELECT id, doc_type, file_name, size_kb, verified FROM documents "
                                 "WHERE employee_id = :emp ORDER BY id"), {"emp": employee.id})
        return [{**row._asdict(), "verified": bool(row.verified)} for row in rows]


# ---- A tiny demo page served by the API itself ----
@app.get("/demo", response_class=HTMLResponse)
def demo_page():
    return """
    <!doctype html>
    <html>
      <body>
        <h1>AcmeHR dashboard</h1>
        <ul id="tiles"></ul>
        <script>
          fetch("/dashboard?date=2026-10-05")
            .then((r) => r.json())
            .then((d) => {
              document.getElementById("tiles").innerHTML = `
                <li>Headcount: ${d.headcount}</li>
                <li>Present: ${d.present} (${d.late} late)</li>
                <li>On leave: ${d.on_leave.join(", ") || "nobody"}</li>
                <li>Pending approvals: ${d.pending_approvals}</li>`;
            });
        </script>
      </body>
    </html>
    """
```

The dashboard and document endpoints use SQLAlchemy Core's `text()` with bound `:parameters`, a quick way to run hand-written SQL safely when you don't need ORM models. Install the upload dependency if `fastapi[standard]` didn't already bring it:

```bash
pip install python-multipart
```

## Fixing CORS with CORSMiddleware

```{ .python .no-run }
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "https://hr.acme.example"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
```

| Option | Meaning |
|--------|---------|
| `allow_origins` | Exact origins allowed (scheme + host + port, no trailing slash) |
| `allow_methods` | HTTP methods the browser may use |
| `allow_headers` | Request headers the browser may send (`Authorization` for tokens) |
| `allow_credentials` | Allow cookies / `Authorization` with cross-origin requests |
| `expose_headers` | Response headers JavaScript may read (e.g. `X-Request-ID`) |

Simulate the browser's preflight with curl, from the HR portal's origin:

```bash
curl -s -i -X OPTIONS http://127.0.0.1:8000/dashboard \
  -H "Origin: http://localhost:5173" \
  -H "Access-Control-Request-Method: GET" \
  | grep -iE "^HTTP|^access-control-allow-(origin|methods|credentials)"
```

```{ .text .output }
HTTP/1.1 200 OK
access-control-allow-methods: GET, POST, PUT, PATCH, DELETE
access-control-allow-credentials: true
access-control-allow-origin: http://localhost:5173
```

From an origin that **isn't** on the list:

```bash
curl -s -i -X OPTIONS http://127.0.0.1:8000/dashboard \
  -H "Origin: http://evil.example" \
  -H "Access-Control-Request-Method: GET" \
  | grep -iE "^HTTP|^access-control-allow-origin|^Disallowed"
```

```{ .text .output }
HTTP/1.1 400 Bad Request
Disallowed CORS origin
```

The preflight is refused with **400 Disallowed CORS origin** and no `Access-Control-Allow-Origin` header, so the browser blocks the real request. CORS doesn't stop the request reaching your server (curl still works). It stops **other websites' JavaScript** from reading your API's responses with your employees' credentials.

!!! warning "`allow_origins=[\"*\"]` is not a fix"
    `"*"` allows **any** website to call your API from a visitor's browser. It's acceptable for a fully public, read-only API (a list of public holidays, say). For an HR system with logins and personal data, list the exact frontend origins, and note that browsers refuse `"*"` together with credentials anyway. Load the list from settings so local, staging and production can differ.

## Middleware

**Middleware** is code that wraps **every** request: it runs before the endpoint, and again after it, around the response.

```mermaid
flowchart LR
  R["Request"] --> M1["CORS middleware"] --> M2["timing / logging<br/>middleware"] --> E["Endpoint"]
  E --> M2b["add headers,<br/>log result"] --> M1b["add CORS headers"] --> S["Response"]
```

```{ .python .no-run }
@app.middleware("http")
async def add_request_context(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)      # everything after this line runs after the endpoint
    response.headers["X-Process-Time-Ms"] = f"{(time.perf_counter() - start) * 1000:.1f}"
    return response
```

Every response now carries extra headers. Send our own request id and check:

```bash
curl -s -i "http://127.0.0.1:8000/dashboard?date=2026-10-05" -H "X-Request-ID: demo-123" \
  | grep -iE "^HTTP|^x-request-id|^x-process-time" | sed -E 's/(x-process-time-ms: ).*/\1<time in ms>/I'
```

```{ .text .output }
HTTP/1.1 200 OK
x-request-id: demo-123
x-process-time-ms: <time in ms>
```

(The timing varies on each request, so we replaced the number.) In the server terminal you'll see a log line like:

```{ .text .output }
INFO GET /dashboard -> 200 (6.4 ms) id=demo-123
```

| Use middleware for | Use a dependency for |
|--------------------|---------------------|
| Things that apply to **every** request | Things specific endpoints need |
| Logging, timing, request IDs, CORS, GZip, security headers | DB sessions, current user, pagination, the clock |
| Can't easily see the endpoint's parameters | Gets typed, validated parameters |

FastAPI ships useful middleware: `CORSMiddleware`, `GZipMiddleware` (compress large responses), `TrustedHostMiddleware` (reject unexpected `Host` headers) and `HTTPSRedirectMiddleware`.

!!! realworld "In Real Projects"
    A **request ID** middleware is standard in production: the ID is returned to the client and written into every log line. When an employee reports *"my leave application failed"*, support asks for the request ID shown on the error screen and finds the exact logs across all services in seconds.

## An Endpoint Built for the Frontend

The BRD's HR dashboard wireframe shows tiles: headcount, today's attendance and late arrivals, who's on leave, pending approvals, and upcoming holidays. Rather than make the React app call six endpoints and add things up, the backend offers **one** endpoint shaped exactly like the screen:

```bash
curl -s "http://127.0.0.1:8000/dashboard?date=2026-10-05"
```

```{ .text .output }
{
  "date": "2026-10-05",
  "headcount": 19,
  "present": 18,
  "late": 2,
  "on_leave": ["Fatima Khan"],
  "pending_approvals": 5,
  "by_location": {
    "Hyderabad": 13,
    "Bengaluru": 4,
    "Pune": 2
  },
  "upcoming_holidays": [
    {
      "date": "2026-10-20",
      "name": "Dussehra"
    },
    {
      "date": "2026-11-09",
      "name": "Diwali"
    }
  ]
}
```

That's the same Monday you met in lesson 07: 18 of 19 present, Karthik and Priya late, Fatima on sick leave, and five requests waiting for a decision. Open `http://127.0.0.1:8000/demo`: a page served by the API itself (same origin, so no CORS needed) draws the tiles with `fetch`:

```bash
curl -s http://127.0.0.1:8000/demo | grep -E "<h1>|fetch"
```

```{ .text .output }
<h1>AcmeHR dashboard</h1>
          fetch("/dashboard?date=2026-10-05")
```

!!! tip "Endpoints shaped like screens"
    A "screen endpoint" like `/dashboard` (sometimes called a *backend for frontend*) saves the browser many round trips and keeps the counting logic on the server, where it's tested. Keep the general-purpose endpoints too: the mobile app or a report may need the pieces separately.

## File Uploads with UploadFile

The BRD's document module: *"Employees upload ID, address and education proofs (PDF, PNG or JPG, up to 2 MB). HR verifies each document."* A file upload isn't JSON: the browser sends **multipart form data**, and FastAPI reads it with `File()` and `Form()`:

```{ .python .no-run }
@app.post("/employees/{code}/documents", status_code=201)
def upload_document(code: EmployeeCode, background_tasks: BackgroundTasks,
                    doc_type: Annotated[DocType, Form()], file: Annotated[UploadFile, File()]):
```

| Piece | Meaning |
|-------|---------|
| `UploadFile` | The uploaded file: `.filename`, `.content_type`, `.file` (a file object, spooled to disk if large) |
| `File()` | Read this parameter from the multipart body as a file |
| `Form()` | Read this parameter from the multipart body as a normal form field (validated, here against the `DocType` enum) |

Uploaded files come from strangers, so the endpoint checks three things before saving anything:

1. **The extension** is one we accept (`.pdf`, `.png`, `.jpg`): otherwise **415 Unsupported Media Type**.
2. **The size**: it reads at most 2 MB + 1 byte, so a 2 GB upload can't fill the server's memory: otherwise **413 Content Too Large**.
3. **The first bytes**: every real PDF starts with `%PDF`, every PNG with `\x89PNG`. A file named `.pdf` that isn't one is refused. The extension and `content_type` are just labels the client chose.

Let's create a small "PDF", an impostor, and a 3 MB file to try:

```bash
python -c "open('electricity-bill.pdf', 'wb').write(b'%PDF-1.7\n' + b'0' * 3000)"
echo "definitely not a pdf" > salary-slip.pdf
python -c "open('scan.pdf', 'wb').write(b'%PDF-1.7\n' + b'0' * 3_000_000)"
ls -l *.pdf | awk '{print $5, $9}'
```

```{ .text .output }
3009 electricity-bill.pdf
21 salary-slip.pdf
3000009 scan.pdf
```

Ananya uploads her address proof. With curl, `-F` sends multipart form data, and `@` means "the contents of this file":

```bash
curl -s -X POST http://127.0.0.1:8000/employees/E-1042/documents \
  -F "doc_type=address_proof" -F "file=@electricity-bill.pdf"
```

```{ .text .output }
{
  "id": 7,
  "employee": "Ananya Rao",
  "doc_type": "address_proof",
  "file_name": "electricity-bill.pdf",
  "size_kb": 3,
  "verified": false
}
```

```bash
curl -s http://127.0.0.1:8000/employees/E-1042/documents \
  | python -c "import json,sys; [print(d['id'], d['doc_type'], d['file_name'], d['size_kb'], 'KB', 'verified' if d['verified'] else 'waiting for HR') for d in json.load(sys.stdin)]"
ls uploads/E-1042/
```

```{ .text .output }
1 id_proof ananya-rao-aadhaar.pdf 412 KB verified
2 education ananya-rao-btech-degree.pdf 1280 KB verified
3 agreement ananya-rao-offer-letter.pdf 236 KB verified
7 address_proof electricity-bill.pdf 3 KB waiting for HR
7.pdf
```

The row is in MySQL with the original name, but the file on disk is called `7.pdf`, after the database id. **Never use the uploaded file name as a path**: a name like `../../app/main.py` would overwrite your code. And because the insert and the file write happen inside one `engine.begin()` block, a failed write rolls back the row too.

The three checks in action:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/employees/E-1042/documents \
  -F "doc_type=tax" -F "file=@salary-slip.pdf"
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/employees/E-1042/documents \
  -F "doc_type=education" -F "file=@scan.pdf"
cp electricity-bill.pdf notes.docx
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/employees/E-1042/documents \
  -F "doc_type=education" -F "file=@notes.docx"
```

```{ .text .output }
{"detail":"The file's contents don't match its .pdf extension"}
HTTP 415
{"detail":"The file is larger than 2 MB"}
HTTP 413
{"detail":"Only PDF, PNG or JPG files are accepted"}
HTTP 415
```

And a document type that isn't in the enum is a normal validation error, with `loc` pointing at the form field:

```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST http://127.0.0.1:8000/employees/E-1042/documents \
  -F "doc_type=selfie" -F "file=@electricity-bill.pdf"
```

```{ .text .output }
{
  "detail": [
    {
      "type": "enum",
      "loc": ["body", "doc_type"],
      "msg": "Input should be 'id_proof', 'address_proof', 'education', 'agreement' or 'tax'",
      "input": "selfie",
      "ctx": {
        "expected": "'id_proof', 'address_proof', 'education', 'agreement' or 'tax'"
      }
    }
  ]
}
HTTP 422
```

## Background Tasks

Some work shouldn't make the user wait: notifying HR that a document needs verifying, emailing a manager about a new leave request, generating a payslip PDF. `BackgroundTasks` runs a function **after the response has been sent**:

```{ .python .no-run }
def upload_document(..., background_tasks: BackgroundTasks, ...):
    ...
    background_tasks.add_task(notify_hr, employee.name, doc_type.value, file.filename)
    return {...}                      # sent to the client immediately
```

The notification takes 1 second, but the response comes back right away:

```bash
start=$(python -c "import time; print(time.time())")
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST http://127.0.0.1:8000/employees/E-1050/documents \
  -F "doc_type=education" -F "file=@electricity-bill.pdf;filename=kavya-btech-degree.pdf"
python -c "import time,sys; print('response took', 'under 1 second' if time.time() - float(sys.argv[1]) < 0.9 else 'over 1 second')" "$start"
grep Kavya notifications.log || echo "Kavya's notification: not written yet"
sleep 1.5
grep Kavya notifications.log
```

```{ .text .output }
HTTP 201
response took under 1 second
Kavya's notification: not written yet
To HR: please verify Kavya Srinivasan's education (kavya-btech-degree.pdf)
```

The response arrived immediately, **before** HR was "notified". A moment later the background task finished and wrote its line to the log (Ananya's upload earlier left a line there too). (`;filename=...` in curl sends the file under a different name.)

!!! tip "When to use a real task queue"
    `BackgroundTasks` runs in the same process, so if the server restarts the task is lost, and long jobs compete with requests for resources. For critical or heavy work (month-end payslips for every employee, bulk emails, reports that take minutes), use a dedicated queue such as **Celery** or **RQ** with Redis, or a cloud queue.

## Calling the API from a Frontend

In the [Frontend](../../frontend/index.md) module you used `fetch` against a mock API. Against AcmeHR, with the login from lesson 10, the HR portal's API helper looks like this:

```{ .javascript .no-run }
const API_URL = import.meta.env.VITE_API_URL;           // e.g. http://127.0.0.1:8000

export async function login(email, password) {
  const response = await fetch(`${API_URL}/auth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ username: email, password }),
  });
  if (!response.ok) throw new Error("Incorrect email or password");
  const data = await response.json();
  sessionStorage.setItem("token", data.access_token);
}

function authHeader() {
  return { Authorization: `Bearer ${sessionStorage.getItem("token")}` };
}

export async function approveLeave(requestId) {
  const response = await fetch(`${API_URL}/leave-requests/${requestId}/approve`, {
    method: "POST",
    headers: authHeader(),
  });
  if (response.status === 401) throw new Error("Please log in again");
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.detail ?? "Something went wrong");    // e.g. "Only Meera Iyer's manager..."
  }
  return response.json();
}

export async function uploadDocument(code, docType, file) {
  const form = new FormData();                          // multipart: don't set Content-Type yourself
  form.append("doc_type", docType);
  form.append("file", file);                            // a File from <input type="file">
  const response = await fetch(`${API_URL}/employees/${code}/documents`, {
    method: "POST",
    headers: authHeader(),
    body: form,
  });
  if (!response.ok) throw new Error((await response.json()).detail);
  return response.json();
}
```

These requests send an `Authorization` header from a different origin, so the browser sends a preflight first, and your `CORSMiddleware` configuration must allow that header. With `FormData`, let the browser set the `Content-Type` (it adds the multipart boundary for you).

!!! tip "Development proxy: another way around CORS locally"
    Vite (the React dev server) can forward `/api/*` requests to your backend, making them same-origin during development. You'll still need correct CORS settings in production if the portal (`hr.acme.example`) and the API (`api.acme.example`) live on different domains.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| No `CORSMiddleware` | Browser: "blocked by CORS policy"; curl works | Add it with your frontend origin |
| Origin with a trailing slash or wrong port | Still blocked | Exact match: `http://localhost:5173` |
| `allow_origins=["*"]` with credentials | Browser rejects; or a security hole | List exact origins |
| `Authorization` not in `allow_headers` | Preflight fails for authenticated calls | Add it |
| Thinking CORS protects the API | Bots and curl still call it | Use authentication; CORS only governs browsers |
| `python-multipart` not installed | `RuntimeError: Form data requires "python-multipart" to be installed` | `pip install python-multipart` |
| Trusting the file name or `content_type` | Executables uploaded as "PDFs"; path traversal | Check the first bytes; store under your own name |
| Reading the whole upload with no limit | One huge upload exhausts memory | Read at most the limit + 1 byte |
| Critical jobs in `BackgroundTasks` | Lost on restart | Use Celery / RQ / a cloud queue |

## Practice Exercises

**Easy**

1. Add `http://127.0.0.1:5500` (VS Code Live Server) to `allow_origins` and verify the preflight response with curl.
2. Add `expose_headers=["X-Request-ID"]` to the CORS settings. Why does a React app need this to read the header?
3. Add `on_notice` (the number of employees serving notice) to the dashboard.

**Medium**

4. Move the allowed origins into `Settings` (`CORS_ORIGINS` as a comma-separated string in `.env`), and build the list from it at startup.
5. Add `POST /documents/{document_id}/verify` for HR that sets `verified = TRUE`, and a background task that writes "To <employee>: your <doc_type> has been verified" to `notifications.log`.
6. Add `GET /documents/{document_id}/download` that returns the stored file with `FileResponse`, using the original file name in the download (`filename=`), and 404 if the row or the file is missing.

**Challenge**

7. Build a one-page HTML frontend in a separate folder, served by VS Code Live Server (a different origin), with a login form, the dashboard tiles, and a document upload form, calling your **lesson 10** auth API plus this lesson's endpoints with the `Authorization` header. Make it work by configuring CORS correctly, and document each preflight you see in the browser's Network tab.

??? success "Solutions (click to expand)"

    ```{ .python .no-run }
    from fastapi.responses import FileResponse

    # 2: browsers only expose a few "safe" response headers to JavaScript;
    #    custom headers must be listed in expose_headers to be readable via response.headers.get(...)

    # 3 (in dashboard)
    on_notice = conn.execute(text("SELECT COUNT(*) FROM employees WHERE status = 'on_notice'")).scalar()

    # 4 (config.py)
    class Settings(BaseSettings):
        cors_origins: str = "http://localhost:5173"

        @property
        def cors_origin_list(self) -> list[str]:
            return [o.strip() for o in self.cors_origins.split(",") if o.strip()]
    # main.py: allow_origins=get_settings().cors_origin_list

    # 5
    @app.post("/documents/{document_id}/verify")
    def verify_document(document_id: int, background_tasks: BackgroundTasks):
        with engine.begin() as conn:
            row = conn.execute(text("""SELECT d.doc_type, CONCAT(e.first_name, ' ', e.last_name) AS name
                                       FROM documents d JOIN employees e ON e.id = d.employee_id
                                       WHERE d.id = :id"""), {"id": document_id}).first()
            if row is None:
                raise HTTPException(status_code=404, detail="Document not found")
            conn.execute(text("UPDATE documents SET verified = TRUE WHERE id = :id"), {"id": document_id})
        background_tasks.add_task(write_notification, f"To {row.name}: your {row.doc_type} has been verified")
        return {"id": document_id, "verified": True}

    # 6
    @app.get("/documents/{document_id}/download")
    def download(document_id: int):
        with engine.connect() as conn:
            row = conn.execute(text("""SELECT d.file_name, e.employee_code FROM documents d
                                       JOIN employees e ON e.id = d.employee_id WHERE d.id = :id"""),
                               {"id": document_id}).first()
        if row is None:
            raise HTTPException(status_code=404, detail="Document not found")
        path = UPLOAD_DIR / row.employee_code / f"{document_id}{pathlib.Path(row.file_name).suffix.lower()}"
        if not path.exists():
            raise HTTPException(status_code=404, detail="File not found on the server")
        return FileResponse(path, filename=row.file_name)
    ```

!!! note "Mini Assignment"
    Add to your **AcmeHR API**: `CORSMiddleware` with origins loaded from settings, a request-ID + timing middleware that logs every request, the `/dashboard` endpoint, document upload with the three checks (protected so employees can upload only to their own profile, using lesson 10's `CurrentUser`), and background notifications to the manager when leave is applied and to HR when a document is uploaded. Then build the small HTML/JS page from exercise 7 so you can demo login → dashboard → upload from a browser.

## Interview Questions

!!! interview "1. What is CORS and why do browsers enforce it?"
    Cross-Origin Resource Sharing is a mechanism that lets a server declare which other origins (scheme + host + port) may read its responses from browser JavaScript. Browsers enforce the Same-Origin Policy so that a malicious site can't use a logged-in user's browser to read data from other sites; CORS headers selectively relax it.

!!! interview "2. What is a preflight request?"
    An automatic `OPTIONS` request the browser sends before a "non-simple" cross-origin request (custom headers like `Authorization`, JSON content type, methods like PUT/PATCH/DELETE) to ask whether the real request is allowed. The server answers with `Access-Control-Allow-*` headers.

!!! interview "3. How do you handle file uploads safely in FastAPI?"
    Accept them with `UploadFile` and `File()` (multipart form data, needs `python-multipart`). Limit the size by reading at most the maximum plus one byte; allow-list extensions and check the file's leading bytes (magic numbers) rather than trusting the name or `content_type`; store files under a server-generated name (or in object storage like S3), never the user's file name; and record the metadata in the database in the same transaction.

!!! interview "4. What is middleware in FastAPI? Give examples."
    Code that wraps every request/response: it can inspect or modify the request before the endpoint and the response after it. Examples: CORS, GZip compression, request IDs, timing and access logs, security headers, trusted hosts, rate limiting.

!!! interview "5. When would you use `BackgroundTasks` vs Celery?"
    `BackgroundTasks` suits small, non-critical work that can run in the same process right after the response (a notification email, an audit log line). Celery (or RQ, or cloud queues) suits heavy, long-running or critical jobs that need retries, scheduling, persistence across restarts and separate worker scaling, such as month-end payroll.

!!! interview "Scenario: the HR portal works locally but in production every API call fails with a CORS error. What do you check?"
    That the production portal origin (exact scheme, domain and port, e.g. `https://hr.acme.example`) is in `allow_origins`, typically loaded from production settings; that `Authorization` and `Content-Type` are allowed headers; that a reverse proxy or load balancer isn't stripping CORS headers or blocking `OPTIONS`; and that the portal calls the correct API URL (http vs https mismatches count as different origins).

## Summary

| Concept | Code |
|---------|------|
| CORS | `app.add_middleware(CORSMiddleware, allow_origins=[...], allow_methods=[...], allow_headers=[...])` |
| Origin | Scheme + host + port; must match exactly |
| Preflight | Browser `OPTIONS` before non-simple requests |
| Custom middleware | `@app.middleware("http") async def f(request, call_next): ... await call_next(request)` |
| Upload | `file: Annotated[UploadFile, File()]`, `doc_type: Annotated[DocType, Form()]` |
| Upload safety | Size limit, extension allow-list, magic bytes, server-chosen file name |
| Background task | `background_tasks: BackgroundTasks` → `.add_task(func, *args)` |
| Screen endpoint | One `/dashboard` shaped like the UI |
| Frontend call | `fetch(url, {headers: {Authorization: "Bearer " + token}, body: formData})` |

**Next lesson:** [Deployment & Capstone Project](13-deployment-and-capstone.md), taking the AcmeHR API to production.
