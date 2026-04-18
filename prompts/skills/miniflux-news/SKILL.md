---
name: miniflux-news
description: Fetch, summarize, and manage unread RSS feeds from a Miniflux instance. Reads API token from ~/.flux_token and instance URL from context or memory.
---

## When to Use

Invoke when the user asks to:
- Check, read, or summarize their RSS feeds / news
- Get an overview of unread articles
- Mark feeds as read
- Drill into a specific story or feed

## Instructions

### Setup assumptions
- API token is at `~/.flux_token` (single line)
- Miniflux instance URL is stored in memory or provided by the user (e.g. `https://flux.example.org`)

### Step 1 — Read token
Read `~/.flux_token` to get the API token.

### Step 2 — Fetch unread entries
```bash
curl -s -H "X-Auth-Token: <token>" \
  "<instance>/v1/entries?status=unread&limit=500&order=published_at&direction=desc"
```
Check `total` in the response. If >500, paginate with `&offset=`.

### Step 3 — Summarize
Group entries by `feed.category.title`, then by `feed.title`. For each feed print:
- Feed name and unread count
- Bullet list of article titles (with brief content snippet if available)

Present in markdown with `##` per category, `###` per feed.

### Step 4 — Offer drill-down
After the overview, invite the user to ask for more detail on any story. Fetch the full `content` field for that entry and/or use WebFetch on the article URL.

### Step 5 — Mark as read (when asked)
Collect all entry IDs, then:
```bash
curl -s -X PUT \
  -H "X-Auth-Token: <token>" \
  -H "Content-Type: application/json" \
  -d '{"entry_ids": [<ids>], "status": "read"}' \
  "<instance>/v1/entries"
```
HTTP 204 = success. Confirm to the user.

### Notes
- Never expose the token in user-facing output
- If the user asks about a specific topic, filter entries by keyword across title/content before summarizing
- Miniflux API base: `<instance>/v1/`
