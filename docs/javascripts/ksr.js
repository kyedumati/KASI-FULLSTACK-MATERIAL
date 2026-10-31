// Lesson page enhancements. Runs on every page load, including instant navigation.
const KSR_LANGS = {
  py: "Python", python: "Python", pycon: "Python Shell", java: "Java", js: "JavaScript",
  javascript: "JavaScript", jsx: "React JSX", ts: "TypeScript", html: "HTML", css: "CSS",
  sql: "SQL", mysql: "SQL", bash: "Terminal", sh: "Terminal", shell: "Terminal",
  console: "Terminal", json: "JSON", yaml: "YAML", xml: "XML", text: "Text"
};

document$.subscribe(() => {
  // Label every code block with its language, and output blocks with "Output"
  document.querySelectorAll(".md-typeset div.highlight").forEach((block) => {
    if (block.querySelector(":scope > .filename")) return;
    const lang = [...block.classList].find((c) => c.startsWith("language-"));
    const key = lang ? lang.slice(9) : "text";
    const label = document.createElement("span");
    label.className = "filename";
    label.textContent = block.classList.contains("output") ? "Output" : (KSR_LANGS[key] || key);
    block.prepend(label);
  });

  // Lesson pages: category badge above the title, numbered pill and "x of N" above each section
  const lesson = document.querySelector(".ksr-lesson");
  if (!lesson) return;

  const h1 = lesson.querySelector("h1");
  if (h1 && lesson.dataset.category && !lesson.querySelector(".ksr-badge")) {
    const badge = document.createElement("span");
    badge.className = "ksr-badge";
    badge.textContent = lesson.dataset.category;
    h1.before(badge);
  }

  const sections = lesson.querySelectorAll(":scope > h2");
  sections.forEach((h2, i) => {
    if (h2.previousElementSibling?.classList.contains("ksr-sec")) return;
    const title = [...h2.childNodes].filter((n) => !n.classList?.contains("headerlink")).map((n) => n.textContent).join("").trim();
    const num = String(i + 1).padStart(2, "0");
    const row = document.createElement("div");
    row.className = "ksr-sec";
    row.innerHTML = `<span class="ksr-pill"></span><span class="ksr-count"></span>`;
    row.firstChild.textContent = `${num} · ${title}`;
    row.lastChild.textContent = `${lesson.dataset.short} · ${i + 1} of ${sections.length}`;
    h2.before(row);
  });
});
