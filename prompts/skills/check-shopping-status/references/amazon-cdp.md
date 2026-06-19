# Amazon lookup via Chrome DevTools Protocol

For Amazon.de (or .com) tracking URLs that require login, use a headless
Chrome instance controlled via the remote-debugging WebSocket protocol.

```bash
# Start Chrome with remote debugging
pkill -f 'remote-debugging-port=9222' || true
google-chrome \
  --headless=new --disable-gpu --no-sandbox --disable-dev-shm-usage \
  --disable-blink-features=AutomationControlled \
  --window-size=1400,2400 \
  --user-agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36' \
  --remote-debugging-port=9222 --user-data-dir=/tmp/amazon-profile \
  about:blank
```

Create a tab via `PUT http://localhost:9222/json/new?about:blank`, connect
with `websocat <wsUrl>`, then send CDP commands in line-delimited JSON:

1. `Page.enable` — subscribe to page events.
2. `Page.navigate` — load `https://www.amazon.de/ap/signin`.
3. `Runtime.evaluate` — set `#ap_email` to `~/.amazon` user and click `#continue`.
4. `Runtime.evaluate` — set `#ap_password` to `~/.amazon` pass and click `#signInSubmit`.
5. `Page.navigate` — load the progress-tracker URL from the email.
6. `Runtime.evaluate` — return `document.body.innerText` for status extraction.

Important interaction details:
- Dispatch `input` and `change` events on form fields after setting `.value`.
- Click the submit button, then call `form.submit()` as fallback.
- Amazon sign-in often redirects to `openid` flow; the final URL after step
  5 should match the original progress-tracker URL.

Then strip tags and grep for status keywords:
`deliver|delivered|in transit|out for delivery|zugestellt|unterwegs|abgeholt|
expected|arrived|departed|customs`.

If the screenshot is < 60 KB or contains the words "Cloudflare", "security
verification", "Bot Manager", "Pardon Our Interruption", or "blocked" →
mark the lookup as **blocked**, do *not* keep retrying with the same client.

## Example Amazon CDP helper

```python
import json, subprocess, time, urllib.request

def start_chrome():
    subprocess.run(['pkill','-f','remote-debugging-port=9222'], capture_output=True)
    time.sleep(1)
    p = subprocess.Popen([
        'google-chrome',
        '--headless=new','--disable-gpu','--no-sandbox','--disable-dev-shm-usage',
        '--disable-blink-features=AutomationControlled',
        '--window-size=1400,2400',
        '--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        '--remote-debugging-port=9222','--user-data-dir=/tmp/amazon-profile',
        'about:blank'
    ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    for _ in range(30):
        time.sleep(0.5)
        try:
            with urllib.request.urlopen('http://localhost:9222/json/version', timeout=2) as r:
                if json.loads(r.read()).get('Browser'):
                    return p
        except: pass
    p.kill()
    raise RuntimeError('Chrome did not start')

def get_page_ws():
    req = urllib.request.Request('http://localhost:9222/json/new?about:blank', method='PUT')
    with urllib.request.urlopen(req, timeout=5) as r:
        return json.loads(r.read()).get('webSocketDebuggerUrl','')

def send_cmd(ws, cid, method, params=None):
    ws.stdin.write((json.dumps({'id':cid,'method':method,'params':params or {}},ensure_ascii=False)+'\n').encode())
    ws.stdin.flush()

def amazon_login_and_track(ws, user, pwd, tracker_url):
    send_cmd(ws, 1, 'Page.enable')
    send_cmd(ws, 2, 'Runtime.evaluate', {'expression': 'navigator.webdriver'})
    time.sleep(0.5)
    send_cmd(ws, 3, 'Page.navigate', {'url':'https://www.amazon.de/ap/signin'})
    time.sleep(7)
    send_cmd(ws, 4, 'Runtime.evaluate', {
        'expression': f"""
            var e=document.querySelector('#ap_email');
            var c=document.querySelector('#continue');
            if(e){{ e.focus(); e.value='{user}'; e.dispatchEvent(new Event('input',{{bubbles:true}})); e.dispatchEvent(new Event('change',{{bubbles:true}})); }}
            if(c){{ c.focus(); c.click(); }}
            JSON.stringify({{found:!!e}});
        """, 'returnByValue': True
    })
    time.sleep(7)
    send_cmd(ws, 5, 'Runtime.evaluate', {
        'expression': f"""
            var p=document.querySelector('#ap_password');
            var b=document.querySelector('#signInSubmit');
            if(p){{ p.focus(); p.value='{pwd}'; p.dispatchEvent(new Event('input',{{bubbles:true}})); }}
            if(b){{ b.focus(); b.click(); var f=p?p.closest('form'):null; if(f)f.submit(); }}
            JSON.stringify({{found:!!p}});
        """, 'returnByValue': True
    })
    time.sleep(9)
    send_cmd(ws, 6, 'Runtime.evaluate', {'expression':'location.href','returnByValue':True})
    time.sleep(1)
    send_cmd(ws, 7, 'Page.navigate', {'url': tracker_url})
    time.sleep(7)
    send_cmd(ws, 8, 'Runtime.evaluate', {'expression':'document.body.innerText','returnByValue':True})
    time.sleep(1)
    ws.stdin.close()
    out=[]; err=[]
    while True:
        line=ws.stdout.readline()
        if not line: break
        try: out.append(json.loads(line.decode()))
        except: pass
    while True:
        line=ws.stderr.readline()
        if not line: break
        err.append(line.decode())
    ws.wait()
    return out
```
