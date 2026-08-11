# Compose blog post

Compose a blog post in gemtext for the foo.zone gemfeed. **Only write or modify
`.gmi.tpl` template files** under `~/git/foo.zone-content/gemtext/gemfeed/`. Do
not create or edit `.gmi` files (those are generated from templates). Keep this
generic so it works for any topic (how-to, review, setup, list, etc.).

This is the authoring reference for new gemfeed posts and for promoting a raw
note into a blogged "book notes" post. For the broader book-notes workflow
(sourcing highlights, authoring the standalone note, the reading list) see
[Book Notes](book-notes.md).

## When to use

- The user wants to write or draft a new blog post for foo.zone.
- The user describes a topic, shares notes, or asks to "write a post about X".
- The user wants to promote a raw `notes/slug.gmi.tpl` into a published gemfeed
  "book notes" post.

## Instructions

1. **Match existing style.** Read 2–3 recent posts from
   `~/git/foo.zone-content/gemtext/gemfeed/*.gmi` or `*.gmi.tpl` (for style only;
   do not modify those `.gmi` files) to mirror title/date format, ASCII art
   usage, section levels, link style, and closing.

2. **Decide filename and date.** Use `YYYY-MM-DD-slug.gmi.tpl` for the template
   file. Ask for the publish date and slug if the user doesn't specify them.

3. **Author the content following the foo.zone gemtext conventions.** All
   format/structure rules live in the shared
   [`blog-writing-style` gemtext conventions](../../blog-writing-style/references/gemtext-conventions.md) —
   follow them for: post structure & order (`# Title`, intro, TOC, body, related
   posts, E-Mail line, back-to-main-site) — do NOT write the `> Published at …`
   line, Gemtexter inserts it automatically on `--generate` (using the file
   mtime) when it is missing; Table of Contents uses the `<< template::inline::toc`
   macro (Gemtexter expands it from the headings — never hand-write the `⇢`
   entries), links (inline project links after the mentioning paragraph), images
   & ASCII diagrams (web resize, Unicode box-drawing, fixed-column `│` divider
   with an `awk` alignment check), multi-part series (cross-links, shared hero,
   `DRAFT-…` handling, dated-filename ordering), and format constraints (no
   Markdown bold/italic; `##`/`###` only; no HTML).

4. **Ask when unclear.** If the topic, date, slug, or need for ASCII art /
   images / related posts is missing, ask the user before writing.

5. **Add to index, if applicable.** Only if
   `~/git/foo.zone-content/gemtext/gemfeed/index.gmi.tpl` exists as a
   hand-maintained file, add one line at the top:
   `=> ./YYYY-MM-DD-slug.gmi YYYY-MM-DD - Post title`.
   In the current foo.zone-content repo, `gemfeed/index.gmi` has no `.gmi.tpl`
   counterpart — Gemtexter auto-generates it from the dated post templates on
   `--generate`, so no manual index edit is needed there. Check for the `.tpl`
   file before assuming otherwise.

6. **Preview and confirm.** Show a short preview (e.g. title, TOC, and first
   section) before writing the file. After saving, confirm that only `.gmi.tpl`
   files were created or modified (post template, and the index template only
   if it exists) and that no `.gmi` files were changed.

7. **Optional publish.** If the user wants the new post published after it is
   written, run the generate/publish/verify workflow described in
   [Commands](commands.md) and [Verification](verification.md).

8. **Apply human writing style.** Use the `blog-writing-style` skill to ensure
   the content sounds authentically human — casual, personal, without
   corporate/marketing language or LLM-generated patterns.

## Book notes: publishing from `./notes` without duplicating text

Book notes have a source of truth on each side of the site that must not
diverge:

- `gemtext/notes/index.gmi` is **auto-generated** by `lib/notes.source.sh` from
  the `*.gmi` files in `notes/` (title = each note's first `#` heading, sorted
  reverse). There is no hand-maintained `index.gmi.tpl` — do not edit it and do
  not add entries by hand; it picks up the note on `--generate`.
- `gemtext/notes/slug.gmi.tpl` starts out as the full raw note (title, intro,
  TOC macro, body, footer).
- `gemtext/gemfeed/YYYY-MM-DD-slug-book-notes.gmi.tpl` is the polished,
  published version — same structure (title / intro / `<< template::inline::toc`
  / body / "Other book notes of mine are:" + `<< template::inline::rindex book-notes`
  / E-Mail line / back-to-main-site).

When a note gets turned into a blog post, the gemfeed template becomes the
**only** copy of the full text. Replace the entire body of `notes/slug.gmi.tpl`
with a single include line instead of leaving the text duplicated in both
places:

```
<< cat ../gemfeed/YYYY-MM-DD-slug-book-notes.gmi | sed 's/....-..-..-//; s/-book-notes//;'
```

This cats the already-generated gemfeed `.gmi` output (not the `.tpl` — the raw
template still contains unexpanded macros) so the note page inherits the real
TOC, the `> Published at …` line, and the current-post rindex footer as-is. The
`sed` rewrites the footer's "Other book notes of mine are:" links from
gemfeed's dated filenames (`./YYYY-MM-DD-slug-book-notes.gmi`) down to the
notes directory's plain filenames (`./slug.gmi`), so they resolve correctly
from `notes/` instead of 404ing. This pattern is already used for 10+ other
book-notes pairs (e.g. `notes/staff-engineer.gmi.tpl`,
`notes/never-split-the-difference.gmi.tpl`) — always apply it for a new one;
never leave the prose duplicated in both `.gmi.tpl` files.

After writing both files, regenerate and spot-check the include actually
resolved before calling the work done:

```bash
cd ~/git/gemtexter && ./gemtexter --generate
```

Then check the tail of the generated `notes/slug.gmi` — it should show the
full footer with notes-relative links and "(You are currently reading this)"
on the current page only.