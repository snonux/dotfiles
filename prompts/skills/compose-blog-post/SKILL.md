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

1. **Match existing style.** Read 2–3 recent posts from `~/git/foo.zone-content/gemtext/gemfeed/*.gmi` or `*.gmi.tpl` (for style only; do not modify those .gmi files) to mirror:
   - Title and published date format
   - Optional ASCII art
   - Table of Contents format
   - Section levels and link style
   - Closing (related posts, E-Mail, Back to main site)

2. **Decide filename and date.** Use `YYYY-MM-DD-slug.gmi.tpl` for the template file. Ask for the publish date and slug if the user doesn't specify them.

3. **Structure the post** in this order:
   - `# Title` (first line)
   - `> Published at YYYY-MM-DDTHH:MM:SS+02:00` (ISO 8601 with timezone)
   - Optional: ASCII art in a fenced code block (triple backticks). Suggest only if it fits the topic (e.g. diagram, device, logo).
   - Short intro paragraph(s)
   - First image (if any) and/or main product/external links
   - **Table of Contents** (see below)
   - Body with `##` and `###` sections
   - Optional: "Other related posts:" with `=> ./YYYY-MM-DD-slug.gmi YYYY-MM-DD Title` lines
   - `E-Mail your comments to \`paul@nospam.buetow.org\` :-)`
   - `=> ../ Back to the main site` (last line)

4. **Table of Contents.** Add a hand-written TOC after the intro/first image, before the first `##`:
   - Heading: `## Table of Contents` then a blank line
   - List with `* ⇢` and indentation by section level:
     - `* ⇢ Post title` (one arrow = document title)
     - `* ⇢ ⇢ Section name` (two arrows = each `##` section)
     - `* ⇢ ⇢ ⇢ Subsection name` (three arrows = each `###` subsection)
   - List every `##` and `###` in the same order as in the body.

5. **Images and diagrams.**
   - Store images in a subfolder under the gemfeed (e.g. `gemfeed/slug-name/` or a name the user gives). Reference them as `=> ./slug-name/filename.jpg Description`.
   - If the user provides or points to large image files (e.g. multi‑MB or very high resolution), suggest or perform resizing for web (e.g. longest side 1200px, JPEG quality 85) so the post stays fast to load.
   - **Image density.** Prose-heavy posts with long `##` sections benefit from at least one image or diagram per major section. Walls of text without visual anchors feel dense; when a section runs to several screens of prose, propose a diagram or screenshot to break it up.
   - **ASCII diagrams.** Use a fenced code block (triple backticks). Use Unicode box-drawing characters — `─`, `│`, `▼`, `▶`, `┼`, `┌`, `└`, `┐`, `┘` — for cleaner output than `|` / `-` / `+`.
     - For two-section comparison diagrams (e.g. kernel vs userspace, before vs after, mode A vs B), place a vertical `│` divider at a single fixed column on every row, rather than relying on whitespace alone to separate the sides. Without a divider, the header label drifts away from the content underneath it.
     - After drafting a multi-column diagram, verify the divider column is identical on every line (e.g. with a small `awk` check) before accepting it. Misaligned dividers are the most common rendering bug.
     - Anchor labels above content: each section header should sit visually over the column it describes, not floating off to one side.

6. **Links.** Use gemtext link lines: `=> URL Description` for external links, `=> ./path Description` for internal/images. Include product or reference links when the post mentions specific items.
   - **Inline project links.** When the body first mentions an external tool, project, or library by name (e.g. eBPF, libbpf, ClickHouse), add a `=> URL Description` line immediately after that paragraph rather than waiting for a bottom-of-post link block. Bottom blocks are reserved for source repos and related posts.

7. **Gemtext conventions.**
   - Sections: `##` and `###` (no `#` except the title).
   - Code blocks: triple backticks; list blocks with `*` or `-`.
   - No HTML; plain gemtext only.

8. **Ask when unclear.** If the topic, date, slug, or need for ASCII art / images / related posts is missing, ask the user before writing.

9. **Add to index.** After saving the post template, add one line at the top of `~/git/foo.zone-content/gemtext/gemfeed/index.gmi.tpl` only (do not edit `index.gmi`):  
   `=> ./YYYY-MM-DD-slug.gmi YYYY-MM-DD - Post title`

10. **Preview and confirm.** Show a short preview (e.g. title, TOC, and first section) before writing the file. After saving, confirm that only `.gmi.tpl` files were created or modified (post template and index template) and that no `.gmi` files were changed.

11. **Optional publish.** If the user wants the new post published after it is written, use the `gemtexter` skill to run the publish workflow and verify the live page on `https://foo.zone`.

12. **Apply human writing style.** Use the `blog-writing-style` skill to ensure the content sounds authentically human — casual, personal, without corporate/marketing language or LLM-generated patterns.

13. **Multi-part series.** When a post is part of a series (Part 1 / Part 2 / Part 3 …):
    - Cross-link to siblings near the top (right after the intro paragraph) and again at the bottom, using the dated filename: `=> ./YYYY-MM-DD-slug-part-N.gmi Part N: short subtitle`.
    - **Shared hero image.** Use the same hero image at the same position (typically immediately after the intro) in every part. Store hero and other shared assets in one subfolder, e.g. `gemfeed/series-slug/`.
    - **Drafts.** Unpublished parts can live as `DRAFT-slug-part-N.gmi.tpl`; their cross-references use `=> ./DRAFT-slug-part-N.gmi`. Promoting a draft to a dated post requires (a) renaming the `.gmi.tpl` and removing the stale generated `.gmi`, then (b) updating every `=> ./DRAFT-…` or `=> ./old-date-…` reference in every OTHER `.gmi.tpl` in the series to point at the new filename. Search with `grep -rn "old-filename" gemtext/` to catch them all.
    - The dated filename controls gemfeed ordering. Fix the filename first, then propagate to references — never the other way around.
