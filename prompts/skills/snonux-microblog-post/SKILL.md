---
name: snonux-microblog-post
description: Create and publish a new microblog post to snonux.foo using the snonux static generator. Handles text, markdown, and images dropped into the inbox directory.
---

# snonux-microblog-post

Create and publish a short microblog post to snonux.foo.

## When to Use

- When the user wants to post something to snonux.foo (the microblog at snonux.foo).
- When they share a thought, photo, link, or short update to publish.
- When they say "post this to snonux" or "add this to the microblog".

## Instructions

1. **Keep it short.** snonux.foo is a microblog — posts are short by design. A sentence or two plus an optional image is the norm. Do not write long-form content here; that goes on foo.zone instead.

2. **Inbox location.** Source files go into `~/.gosdir/snonux/inbox/`. The snonux tool consumes files from there on each run and removes them after processing.

3. **Supported formats:**
   - `.md` — Markdown (GitHub Flavored). Use for text posts, optionally with an embedded image.
   - `.txt` — Plain text, rendered as-is.
   - `.jpg` / `.png` / `.gif` — Standalone image post (auto-downscaled to ≤1024px at 80% quality by snonux).
   - `.mp3` — Audio post with an embedded HTML5 player.

4. **Markdown with an image.** Place both the `.md` file and the image file in the inbox with matching names. Reference the image with standard Markdown syntax:

   ```markdown
   Some short post text here.

   ![alt text](image-filename.jpg)
   ```

   Both files are consumed together. The image is copied into the post's asset directory and the src is rewritten automatically.

5. **Downloading external images.** If the user provides an image URL, download it with `curl -sL <url> -o /tmp/filename.jpg`, then optionally resize if very large (e.g. `magick /tmp/filename.jpg -resize 1024x1024\> -quality 85 /tmp/filename-resized.jpg`), then copy into the inbox.

6. **Preview and confirm.** Before writing any files to the inbox or running snonux, show the user the composed post text (and note any image that will be included). Wait for explicit confirmation ("looks good", "go ahead", etc.) before proceeding. If the user requests changes, revise and show the preview again.

7. **Run snonux.** Only after confirmation, write files to the inbox and run from `~/git/snonux/`:

   ```sh
   cd ~/git/snonux
   ./snonux --input ~/.gosdir/snonux/inbox/ --output ~/.gosdir/snonux/dist/ --sync
   ```

   - `--sync` rsyncs the output to pi0 and pi1, publishing it live. Ask the user before adding `--sync` if unclear.
   - Omit `--sync` for a local preview only.

8. **Verify.** After running, check that a new timestamped directory appeared under `~/.gosdir/snonux/dist/posts/`. The inbox should be empty after a successful run.

9. **Themes.** The theme is chosen randomly by default. The user can pass `--theme NAME` to fix it. Run `./snonux --list-themes` to see available themes.

## Advanced usage

For full documentation on flags, output structure, supported file types, and theme options, read:

=> ~/git/snonux/README.md
