---
name: gemtexter
description: "Manage the Gemtexter-powered foo.zone site: generate output, publish content branches, troubleshoot publish issues, and verify changes on https://foo.zone. Use when working on gemtexter, foo.zone-content, or republishing the site."
---

# Gemtexter

Manage the `gemtexter` static site workflow for `foo.zone`.

## When to Use

- Use when the user wants to generate, publish, preview, or troubleshoot `foo.zone`.
- Use when working in `~/git/gemtexter` or `~/git/foo.zone-content`.
- Use when verifying whether published content is live on `https://foo.zone`.

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

## Common Commands

### Full generate

```bash
./gemtexter --generate
```

### Filtered generate for one area

```bash
./gemtexter --generate 'about|notes|gemfeed'
```

### Generate and preview drafts

`--draft` only processes files with a `DRAFT-` prefix. For non-draft posts (date-prefixed files), use filtered generate instead.

```bash
# DRAFT-prefixed files only
./gemtexter --draft

# Date-prefixed posts: use filtered generate with a matching pattern
./gemtexter --generate 'my-post-name'
```

Then open the generated HTML in Firefox for preview:

```bash
firefox ~/git/foo.zone-content/html/gemfeed/my-post-name.html
```

### Publish everything

```bash
./gemtexter --publish
```

### Low-noise logged runs

```bash
./gemtexter --generate >/tmp/gemtexter-generate.log 2>&1
./gemtexter --publish >/tmp/gemtexter-publish.log 2>&1
tail -40 /tmp/gemtexter-generate.log
tail -60 /tmp/gemtexter-publish.log
```

## Verification Workflow

1. Identify the expected changed page URL.
2. Fetch the page directly with `curl`, not just a browser-style fetch, because cached views can lag:

```bash
curl -fsSLI https://foo.zone/path/to/page.html
curl -fsSL https://foo.zone/path/to/page.html | rg 'expected text'
```

3. Check `Last-Modified` and confirm the expected new content is present.
4. If the site still looks stale, compare against the local generated file in `~/git/foo.zone-content/html/...` and inspect `/tmp/gemtexter-publish.log` for push failures.

## Troubleshooting

- `./gemtexter --publish` already runs generate, git add, and git sync.
- If publish succeeded but the site is old, inspect the live page with `curl` before assuming publish failed.
- If output branches look wrong, inspect `gemtexter.conf` and `lib/git.source.sh`.
- For HTML theme issues, inspect `extras/html/themes/`.
- For feed issues, inspect `lib/atomfeed.source.sh`.

## Useful References

- `~/git/gemtexter/README.md`
- `~/git/gemtexter/gemtexter.conf`
- `~/git/gemtexter/lib/`
