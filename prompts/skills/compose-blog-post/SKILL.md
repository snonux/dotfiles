---
name: compose-blog-post
description: Compose a blog post in gemtext format for foo.zone. Use this skill when the user wants to write or draft a new post for the gemfeed; follow existing style (title, date, TOC, optional ASCII art, images, links, closing) and add the post to the gemfeed index. Also use when turning a raw book note from ./notes into a blogged "book notes" post — the note file must become a single include line pointing at the gemfeed post, never a duplicated copy. Only create or edit .gmi.tpl template files—never write or modify .gmi files.
---

# Compose blog post

Compose a blog post in gemtext for the foo.zone gemfeed. **Only write or modify `.gmi.tpl` template files** under `~/git/foo.zone-content/gemtext/gemfeed/`. Do not create or edit `.gmi` files (those are generated from templates). Keep the skill generic so it works for any topic (how-to, review, setup, list, etc.).

## When to Use

- Use when the user wants to write or draft a new blog post for foo.zone.
- Use when they describe a topic, share notes, or ask to "write a post about X".

## Instructions

1. **Match existing style.** Read 2–3 recent posts from `~/git/foo.zone-content/gemtext/gemfeed/*.gmi` or `*.gmi.tpl` (for style only; do not modify those .gmi files) to mirror title/date format, ASCII art usage, section levels, link style, and closing.

2. **Decide filename and date.** Use `YYYY-MM-DD-slug.gmi.tpl` for the template file. Ask for the publish date and slug if the user doesn't specify them.

3. **Author the content following the foo.zone gemtext conventions.** All format/structure rules live in the shared [`blog-writing-style` gemtext conventions](../blog-writing-style/references/gemtext-conventions.md) — follow them for: post structure & order (`# Title`, intro, TOC, body, related posts, E-Mail line, back-to-main-site) — do NOT write the `> Published at …` line, Gemtexter inserts it automatically on `--generate` (using the file mtime) when it is missing; Table of Contents uses the `<< template::inline::toc` macro (Gemtexter expands it from the headings — never hand-write the `⇢` entries), links (inline project links after the mentioning paragraph), images & ASCII diagrams (web resize, Unicode box-drawing, fixed-column `│` divider with an `awk` alignment check), multi-part series (cross-links, shared hero, `DRAFT-…` handling, dated-filename ordering), and format constraints (no Markdown bold/italic; `##`/`###` only; no HTML).

4. **Ask when unclear.** If the topic, date, slug, or need for ASCII art / images / related posts is missing, ask the user before writing.

5. **Add to index, if applicable.** Only if `~/git/foo.zone-content/gemtext/gemfeed/index.gmi.tpl` exists as a hand-maintained file, add one line at the top:  
   `=> ./YYYY-MM-DD-slug.gmi YYYY-MM-DD - Post title`  
   In the current foo.zone-content repo, `gemfeed/index.gmi` has no `.gmi.tpl` counterpart — Gemtexter auto-generates it from the dated post templates on `--generate`, so no manual index edit is needed there. Check for the `.tpl` file before assuming otherwise.

6. **Preview and confirm.** Show a short preview (e.g. title, TOC, and first section) before writing the file. After saving, confirm that only `.gmi.tpl` files were created or modified (post template, and the index template only if it exists) and that no `.gmi` files were changed.

7. **Optional publish.** If the user wants the new post published after it is written, use the `gemtexter` skill to run the publish workflow and verify the live page on `https://foo.zone`.

8. **Apply human writing style.** Use the `blog-writing-style` skill to ensure the content sounds authentically human — casual, personal, without corporate/marketing language or LLM-generated patterns.

## Book notes: publishing from `./notes` without duplicating text

Book notes have a source of truth on each side of the site that must not diverge:

- `gemtext/notes/index.gmi.tpl` is a hand-maintained queue of every book note (`=> ./slug.gmi 'Title' book notes`). Entries stay listed even after a book gets blogged — never remove one just because it shipped.
- `gemtext/notes/slug.gmi.tpl` starts out as the full raw note (title, intro, TOC macro, body, footer).
- `gemtext/gemfeed/YYYY-MM-DD-slug-book-notes.gmi.tpl` is the polished, published version — same structure (title / intro / `<< template::inline::toc` / body / "Other book notes of mine are:" + `<< template::inline::rindex book-notes` / E-Mail line / back-to-main-site).

When a note gets turned into a blog post, the gemfeed template becomes the **only** copy of the full text. Replace the entire body of `notes/slug.gmi.tpl` with a single include line instead of leaving the text duplicated in both places:

```
<< cat ../gemfeed/YYYY-MM-DD-slug-book-notes.gmi | sed 's/....-..-..-//; s/-book-notes//;'
```

This cats the already-generated gemfeed `.gmi` output (not the `.tpl` — the raw template still contains unexpanded macros) so the note page inherits the real TOC, the `> Published at …` line, and the current-post rindex footer as-is. The `sed` rewrites the footer's "Other book notes of mine are:" links from gemfeed's dated filenames (`./YYYY-MM-DD-slug-book-notes.gmi`) down to the notes directory's plain filenames (`./slug.gmi`), so they resolve correctly from `notes/` instead of 404ing. This pattern is already used for 10+ other book-notes pairs (e.g. `notes/staff-engineer.gmi.tpl`, `notes/never-split-the-difference.gmi.tpl`) — always apply it for a new one; never leave the prose duplicated in both `.gmi.tpl` files.

After writing both files, regenerate and spot-check the include actually resolved before calling the work done:

```
cd ~/git/gemtexter && ./gemtexter --generate
```

Then check the tail of the generated `notes/slug.gmi` — it should show the full footer with notes-relative links and "(You are currently reading this)" on the current page only.