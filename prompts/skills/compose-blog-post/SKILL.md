---
name: compose-blog-post
description: Compose a blog post in gemtext format for foo.zone. Use this skill when the user wants to write or draft a new post for the gemfeed; follow existing style (title, date, TOC, optional ASCII art, images, links, closing) and add the post to the gemfeed index. Only create or edit .gmi.tpl template files—never write or modify .gmi files.
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

5. **Add to index.** After saving the post template, add one line at the top of `~/git/foo.zone-content/gemtext/gemfeed/index.gmi.tpl` only (do not edit `index.gmi`):  
   `=> ./YYYY-MM-DD-slug.gmi YYYY-MM-DD - Post title`

6. **Preview and confirm.** Show a short preview (e.g. title, TOC, and first section) before writing the file. After saving, confirm that only `.gmi.tpl` files were created or modified (post template and index template) and that no `.gmi` files were changed.

7. **Optional publish.** If the user wants the new post published after it is written, use the `gemtexter` skill to run the publish workflow and verify the live page on `https://foo.zone`.

8. **Apply human writing style.** Use the `blog-writing-style` skill to ensure the content sounds authentically human — casual, personal, without corporate/marketing language or LLM-generated patterns.