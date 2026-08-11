# Book Notes

End-to-end workflow for publishing book notes on `foo.zone`. This is the
canonical home for the book-notes flow; it cross-links sibling skills for the
parts they own (gemtext format rules, and turning a note into a gemfeed post).

## When to use

- The user asks to write/create/publish "book notes" for a book they read.
- The user mentions highlights from KOReader, Supernote, or another source.

## Where the notes come from

The raw notes/highlights may come from any of these — do not assume; ask the
user where they are if it is not obvious:

- **KOReader sidecar (`.sdr`)** — per-book reading-progress and highlights.
  Most common source for ebooks read on the Supernote Nomad (which runs
  KOReader) or any KOReader install. See [Extracting KOReader
  highlights](#extracting-koreader-highlights) below.
- **Supernote handwriting notes** — `.note` files in the Supernote `Note`
  folder (handwritten notes, not ebook highlights). These are backed up by the
  `usbimport` script at `~/git/dotfiles/scripts/usbimport` into
  `~/Documents/Inbox/Supernote`.
- **Another location the user names** — a folder, file, or message the user
  points to. Use that as the source.

The `usbimport` script backs up both Supernote `Note` (handwriting) and the
KOReader `Document` folder (books + `.sdr` sidecars) to
`~/Documents/Inbox/Supernote/KOReader`.

## Extracting KOReader highlights

For each book, KOReader writes a sidecar directory next to the book file:

```
Document/
  <Book>.epub
  <Book>.sdr/
    metadata.<ext>.lua     # ext matches the book: epub | pdf | txt
    metadata.<ext>.lua.old
```

`metadata.<ext>.lua` is a Lua table (a top-level `return { ... }`). The fields
that matter for book notes:

- `annotations` — array of highlights, each with:
  - `text` — the highlighted passage (use this as the source, not the book text)
  - `chapter` — the book chapter the highlight is in (group notes by this)
  - `pageno` — page number
  - `datetime` / `datetime_updated` — when the highlight was made/edited
  - `note` — the reader's own written note for that highlight, if any
  - `color`, `drawer`, `pos0`/`pos1` — styling/position; ignore for notes
- `summary` — `{ modified, note, rating, status }` (status e.g. `"reading"` /
  `"complete"`; `note` is a free-text review note; `rating` is 1–5).
- `stats` — `{ highlights, notes, pages, authors, title, language }`.
- `percent_finished` — 0..1 reading progress.
- `doc_props` — `{ authors, title, language, identifiers }`.
- `doc_pages` — total pages.

Extract with `lua` (a Lua interpreter is required; `lua` 5.x or `luajit`).
Because the file is a top-level `return { ... }`, load it with `dofile` and an
**explicit** path (with `lua -e`, the path after `-e` lands in `arg[0]`, not
`arg[1]`, so pass the path into the script string or read it from the
environment):

```bash
# Dump every highlight grouped by chapter, plus the reader's written notes.
lua -e '
local src = os.getenv("META") or arg[1]
local d = dofile(src)
io.write("title: "..(d.doc_props and d.doc_props.title or "?").."\n")
io.write("author: "..(d.doc_props and d.doc_props.authors or "?").."\n")
io.write("percent_finished: "..tostring(d.percent_finished)..", pages: "..(d.doc_pages or "?").."\n")
io.write("summary: rating="..(d.summary and d.summary.rating or "?")..", status="..(d.summary and d.summary.status or "?").."\n")
io.write("--- highlights (chapter | text | note) ---\n")
for i,a in ipairs(d.annotations or {}) do
  io.write("["..(a.chapter or "?").."] "..(a.text or ""))
  if a.note then io.write("  // NOTE: "..a.note) end
  io.write("\n")
end
' "$META"
```

Run it like:

```bash
META="$HOME/Documents/Inbox/Supernote/KOReader/As a Man Thinketh - James Allen.sdr/metadata.epub.lua" \
  lua -e '...' "$META"
```

The `chapter` field maps to the book's own chapters, so it gives you the
section structure for free. Deduplicate overlapping highlights (KOReader
sometimes stores a short and a longer version of the same passage).

## Authoring the note page

Book notes start as a **standalone raw note** in
`~/git/foo.zone-content/gemtext/notes/`, file `slug.gmi.tpl` (e.g.
`as-a-man-thinketh.gmi.tpl`). At this stage the note is not yet published to
the gemfeed.

Structure (follow the existing notes, e.g. `influence-wihout-author.gmi.tpl`,
`the-science-of-living.gmi`):

```
# "Title" book notes

> Last updated D.M.YYYY

<intro paragraph — these are my personal notes, for myself, maybe useful to you too>

<< template::inline::toc

## Chapter / theme sections
...

E-Mail your comments to `paul@nospam.buetow.org` :-)

=> ../ Back to the main site
```

Gemtext format rules (no Markdown bold/italic, `##`/`###` only, etc.) live in
[`../../blog-writing-style/references/gemtext-conventions.md`](../../blog-writing-style/references/gemtext-conventions.md) — follow them; do not duplicate here.

### Rephrase, don't copy

Write the notes in your own words. Do not paste the highlights 1:1. Rephrase
each idea so it is easier to understand later; if a passage is too tangled to
paraphrase clearly, leave it out rather than reproduce a confusing fragment.
Keep the reader's own margin notes where they add something. Apply the human
writing style from
[`../../blog-writing-style/SKILL.md`](../../blog-writing-style/SKILL.md) (avoid
the AI-writing signs in `references/signs-of-ai-writing.md`).

A single short epigraph (one line from the book, as a `>` quote) is fine as a
motif; do not render the whole notes as a wall of `>` quotes.

### The notes index regenerates itself

`gemtext/notes/index.gmi` is auto-generated by `lib/notes.source.sh` from the
`*.gmi` files in `notes/` (title = each note's first `#` heading, sorted
reverse). Do **not** hand-edit it and do **not** add an entry by hand — it
picks up the new note automatically on `--generate`.

## Recording the book in the reading list

Optionally add the book to `~/git/foo.zone-content/gemtext/about/self-skills.txt`
(the reading list). One line per book, e.g.:

```
* As a Man Thinketh, James Allen, Project Gutenberg
```

Only edit the `gemtext/` copy — the `html/` and `md/` copies are
auto-generated from it on `--generate`. Match the existing line format (most
recent entries use `* Title, Author, Source/Publisher`; older entries use `;`
separators). Use the real publisher/edition if known; for a Project Gutenberg
epub with no embedded publisher metadata, `Project Gutenberg` is the honest
credit.

## Promoting a note to a published gemfeed post

When the user wants the note blogged (not just stored under `notes/`), move
the full text into a dated gemfeed template and replace the note's body with a
single include line. The authoring conventions for the gemfeed post and the
exact include-line pattern are owned by the compose-blog-post reference — see
the "Book notes: publishing from `./notes` without duplicating text" section of
[`./compose-blog-post.md`](compose-blog-post.md). Do not duplicate that here;
load it when promoting.

Gemtexter-side mechanics for the promotion:

1. Create `gemtext/gemfeed/YYYY-MM-DD-slug-book-notes.gmi.tpl` with the full
   content (per [compose-blog-post](compose-blog-post.md)).
2. Replace the body of `gemtext/notes/slug.gmi.tpl` with the single include
   line from [compose-blog-post](compose-blog-post.md).
3. Run `./gemtexter --generate` (see [Commands](commands.md)). This regenerates
   the note page (via the include), the gemfeed post, and `notes/index.gmi`.
4. Verify the include resolved by checking the tail of the generated
   `gemtext/notes/slug.gmi` — it should show the full footer with
   notes-relative "Other book notes" links.
5. Publish with `./gemtexter --publish` and verify live (see
   [Verification](verification.md)).

Do not blog a note until the user explicitly asks — a note may live
indefinitely as a standalone raw note under `notes/`.