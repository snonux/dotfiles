---
name: compose-blog-post
description: Compose a blog post in gemtext format for foo.zone.
---

# Compose blog post

Compose a blog post in ~/git/foo.zone-content/gemtext/gemfeed/ in gemtext format.

## When to Use

- Use this skill when the user wants to write or draft a new blog post for foo.zone.

## Instructions

1. Read 2-3 recent blog posts from the gemfeed directory to match the existing style (title, published date, TOC, links, closing).
2. Use the filename format: `YYYY-MM-DD-slug.gmi.tpl` (ask for the date and slug if not specified).
3. Follow the gemtext conventions from existing posts:
   - `# Title` as first line
   - `> Published at` with ISO 8601 timestamp and timezone
   - `<< template::inline::toc` after the intro paragraph
   - `=> ./slug/image.ext Description` for images (create an asset directory named after the slug if images are needed)
   - `=> URL Description` for external links
   - Section headers with `##` and `###`
   - Code blocks with triple backticks
   - Closing with `E-Mail your comments to paul@nospam.buetow.org :-)` and related posts index
   - `=> ../ Back to the main site` as the last line
4. Ask what the blog post should be about if no topic is given.
5. Show a preview before writing the file.
