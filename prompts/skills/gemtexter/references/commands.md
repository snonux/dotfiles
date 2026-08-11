# Commands

Run from `~/git/gemtexter`.

## Full generate

```bash
./gemtexter --generate
```

## Filtered generate for one area

```bash
./gemtexter --generate 'about|notes|gemfeed'
```

## Generate and preview drafts

`--draft` only processes files with a `DRAFT-` prefix. For non-draft posts
(date-prefixed files), use filtered generate instead.

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

## Publish everything

```bash
./gemtexter --publish
```

`--publish` already runs generate, git add, and git sync — you do not need to
generate first.

## Low-noise logged runs

If output is too noisy for the terminal wrapper, redirect to a log in `/tmp/`
and inspect with `tail`:

```bash
./gemtexter --generate >/tmp/gemtexter-generate.log 2>&1
./gemtexter --publish >/tmp/gemtexter-publish.log 2>&1
tail -40 /tmp/gemtexter-generate.log
tail -60 /tmp/gemtexter-publish.log
```

If you used filtered generation to preview, run a full `./gemtexter --generate`
before publishing.