# Kasi Yedumati · Full Stack Material

Student-facing material for **Full Stack Python** and **Full Stack Java**, published at
**https://kyedumati.github.io/KASI-FULLSTACK-MATERIAL/**

Built with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/). Every push to `main` deploys automatically via GitHub Actions.

## Write locally

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
mkdocs serve          # preview at http://127.0.0.1:8000
```

## Add a lesson

1. Create a Markdown file under `docs/<section>/` following `docs/getting-started/lesson-template.md`.
2. Add it to `nav:` in `mkdocs.yml`.
3. Commit and push to `main`. The site updates in about a minute.

> This repo is public. Keep trainer-only notes, answer keys you don't want shared, and student data out of it.
