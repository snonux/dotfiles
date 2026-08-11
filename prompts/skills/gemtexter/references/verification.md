# Verification

How to confirm a change is actually live on `https://foo.zone`.

## Steps

1. Identify the expected changed page URL.
2. Fetch the page directly with `curl`, not just a browser-style fetch, because
   cached views can lag:

   ```bash
   curl -fsSLI https://foo.zone/path/to/page.html
   curl -fsSL https://foo.zone/path/to/page.html | rg 'expected text'
   ```

3. Check `Last-Modified` and confirm the expected new content is present.
4. If the site still looks stale, compare against the local generated file in
   `~/git/foo.zone-content/html/...` and inspect
   `/tmp/gemtexter-publish.log` for push failures.

## Why `curl`, not a browser

Browser-style fetches and CDNs/caches can serve a stale copy even after a
successful publish. A direct `curl` hits the origin and reflects what the
server actually has. Always verify with `curl` before assuming a publish
failed.