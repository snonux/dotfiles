---
name: update-blog-post
description: Update an existing blog post in .gmi.tpl format from foo.zone-content, commit, push, and optionally publish.
---

# Update blog post

Update an existing blog post in ~/git/foo.zone-content/gemtext/gemfeed/ in the git repository in ~/git/foo.zone-context/gemtext/

## When to Use

- Use this skill when the user wants to edit or update an existing blog post on foo.zone.

## Instructions

1. Identify the blog post file in `~/git/foo.zone-content/gemtext/gemfeed/` matching the name or slug given by the user. If multiple matches exist, ask which one.
2. Read the matched `.gmi.tpl` file to understand its current content.
3. If the user hasn't specified what to update, ask what changes should be made.
4. Apply the requested changes while preserving the existing gemtext style and structure. Also add an updated note before the new or modified text like this "> Updated Tue 27 Jan: Added SECTION about SHORT DESCRIPTION here"
5. Also add an "last updated" note to the blog post's publishing date, format like this  "> Published at 2025-07-13T16:44:29+03:00, last updated Tue 27 Jan 10:09:08 EET 2026"
6. Show a diff or summary of the changes before writing.
7. After writing, commit and push the changes to git.
8. Ask whether the updated blog post should be published. If yes, run:
   ```
   cd ~/git/gemtexter && ./gemtexter --publish
   ```
9. Once published, verify that the changes appear on https://foo.zone by fetching the post URL.
10. If the content matches, it means that the ./gemtexter --publish command didnt work correctly and investigate it for any errors in the output.
