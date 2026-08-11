---
name: gemtexter
description: "Manage the Gemtexter-powered foo.zone site: generate output, publish content branches, troubleshoot publish issues, and verify changes on https://foo.zone. Also covers publishing book notes — sourcing highlights from Supernote/KOReader (or any location the user names), authoring note pages under gemtext/notes, and promoting them to the gemfeed. Use when working on gemtexter, foo.zone-content, republishing the site, or creating/publishing book notes."
---

# Gemtexter

Manage the `gemtexter` static site workflow for `foo.zone`: generate, preview,
publish, verify, and troubleshoot. Also the home for publishing book notes.

## When to Use

- Generate, publish, preview, or troubleshoot `foo.zone`.
- Working in `~/git/gemtexter` or `~/git/foo.zone-content`.
- Verifying whether published content is live on `https://foo.zone`.
- Creating or publishing book notes (highlights from Supernote/KOReader or
  another source the user points to).

## Key Paths

- `~/git/gemtexter`: generator repo and CLI script.
- `~/git/foo.zone-content/gemtext`: source content to edit.
- `~/git/foo.zone-content/html`: generated HTML output.
- `~/git/foo.zone-content/md`: generated Markdown output.

## Rules

1. Edit source content in `~/git/foo.zone-content/gemtext`.
2. Prefer editing `.gmi.tpl` template files when a page is template-driven. Do not hand-edit generated `.gmi`, `.html`, or `.md` files unless the user explicitly asks for a generated-file fix.
3. Run commands from `~/git/gemtexter`.
4. If `gemtexter` output is too noisy for the terminal wrapper, redirect it to a log file in `/tmp/` and inspect with `tail`.
5. If you use filtered generation for previewing, run a full `./gemtexter --generate` before publishing.

## Reference Files

Detail lives in `references/`; load only the one that matches the task:

- [Commands](references/commands.md) — full/filtered generate, drafts, publish, low-noise logged runs, preview in Firefox.
- [Verification](references/verification.md) — confirming a change is live on https://foo.zone with `curl` (not a browser fetch), `Last-Modified`, comparing against local generated files.
- [Troubleshooting](references/troubleshooting.md) — what `--publish` does internally, stale-site debugging, config/lib/theme files to inspect.
- [Book Notes](references/book-notes.md) — end-to-end publishing of book notes: sourcing highlights from Supernote/KOReader `.sdr` (with a Lua extractor) or any location the user names, authoring the standalone note page, recording the book in the reading list, and promoting a note to a gemfeed post. Cross-links `blog-writing-style` for gemtext format rules and the compose-blog-post reference for the gemfeed-post promotion step.
- [Compose Blog Post](references/compose-blog-post.md) — authoring a new gemfeed post (title/date/TOC/links/closing), adding to the gemfeed index, and the include-line pattern for promoting a raw `notes/` note into a blogged "book notes" post without duplicating text. Formerly a standalone skill, now a sub-reference here.

## Quick Reference

```bash
cd ~/git/gemtexter
./gemtexter --generate                       # full generate
./gemtexter --generate 'about|notes|gemfeed' # filtered generate for one area
./gemtexter --publish                       # publish (also generates + git sync)
./gemtexter --generate >/tmp/gemtexter-generate.log 2>&1; tail -40 /tmp/gemtexter-generate.log
```

## Useful Repo References

- `~/git/gemtexter/README.md`
- `~/git/gemtexter/gemtexter.conf`
- `~/git/gemtexter/lib/`