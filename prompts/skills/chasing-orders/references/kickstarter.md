# Kickstarter

Everything useful is behind the login, and Kickstarter blocks plain HTTP
clients (`403`), so this needs the Chrome extension. Browser mechanics are
owned by the `claude-in-chrome` skill; this file covers the Kickstarter pages.

## Getting in

1. The extension must be connected to the session. If no
   `mcp__claude-in-chrome__*` tools exist, ask Paul to run `/chrome`.
2. Open `https://www.kickstarter.com/profile/backings` in a new tab.
3. A Cloudflare "Performing security verification" page appears first. It
   clears by itself within about 15 seconds. Do not interact with it.
4. If the page redirects to `/login`, ask Paul to sign in in that tab and wait.

## Backed projects

`/profile/backings` has three tables: active pledges, successful pledges,
unsuccessful pledges. Only the first ten successful pledges are rendered; the
"Show more pledges" link loads the rest.

The creator-reported status column reads `Not provided`, `In progress` or
`Shipped`. Most creators never set it, so `Not provided` says nothing.

Load everything and keep only physical rewards:

```js
for (let i = 0; i < 12; i++) {
  const b = [...document.querySelectorAll('a,button')]
    .find(e => /show more pledges/i.test(e.textContent) && e.offsetParent !== null);
  if (!b) break;
  b.click();
  await new Promise(r => setTimeout(r, 2500));
}
const seen = new Set(); window.__rows = [];
for (const a of document.querySelectorAll('main a[href*="/projects/"]')) {
  const key = a.getAttribute('href').split('?')[0].split('/').slice(0, 4).join('/');
  if (seen.has(key)) continue; seen.add(key);
  const t = (a.closest('tr') || a.closest('li')).innerText.replace(/\s+/g, ' ').trim();
  if (/digital|pdf|\bdig\b/i.test(t)) continue;
  const est = (t.match(/Estimated delivery (\w+ \d{4})/) || [, '?'])[1];
  const st = (t.match(/(Not provided|In progress|Shipped)/) || [, '?'])[1];
  window.__rows.push(t.slice(0, 34) + '|' + est + '|' + st + '|' + key.replace('/projects/', ''));
}
window.__rows.slice(0, 9).join('\n')
```

The script tool truncates its result at roughly 1,000 characters. Store the
rows in a `window` variable and read them back in slices of nine or ten.

## One pledge

`https://www.kickstarter.com/projects/<creator>/<slug>/backing/details`

The page shows the reward and add-ons, total pledge, estimated delivery, the
creator-reported status, the latest update's title and date, and the **backer
number** (last field). `get_page_text` returns nothing on this page; read
`document.body.innerText` instead:

```js
const t = document.body.innerText.replace(/\n\s*\n+/g, '\n');
const g = re => (t.match(re) || [''])[0].replace(/\n/g, ' | ');
[g(/Latest update\n[^\n]*\n[^\n]*/), g(/Estimated delivery\n[^\n]*/),
 g(/Status\n[^\n]*\n[^\n]*/), g(/Backer number\n\d+/),
 g(/Total pledge\n[^\n]*/)].join('\n')
```

Several pledges fit in one `browser_batch`: navigate, wait three seconds, run
the snippet, repeat.

Fetching pledge pages with `fetch()` from the page is blocked by the extension
(`[BLOCKED: Cookie/query string data]`); navigate instead.

## Updates and comments

- `…/posts` lists the updates, newest first, including backers-only ones.
- `…/comments` shows what other backers report; the quickest check when a
  creator has gone quiet.

## Pending surveys

Every logged-in page starts with an alert block: `N alerts: Backer Surveys`,
then one "needs some information to fulfill your reward for <project>" line
per unanswered survey. Compare it with the unshipped pledges: an unanswered
survey blocks shipping.

Some creators run their survey through a third party by email instead. Those
never appear in the alert block. If the updates keep saying
"complete your survey" and no survey mail exists, that is the blocker.

## Rules

- Read only. Do not answer surveys, mark rewards received, or post comments
  unless Paul asks for that specific action.
- Close the tabs when done, unless Paul asked for them to stay open.
