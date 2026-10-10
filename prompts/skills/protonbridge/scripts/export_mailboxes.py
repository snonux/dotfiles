#!/usr/bin/env python3
"""Export every Proton Bridge IMAP mailbox into a directory tree of .eml files.

Usage: export_mailboxes.py DEST_DIR   (credentials come from the environment,
loaded with `set -a; . ~/.protonbridge; set +a`).

Layout: DEST/<mailbox path>/<date>_<uid>_<subject>.eml plus a manifest.tsv per
mailbox (uid, sha256, flags, filename). Proton shows one message in several
mailboxes (its folder, All Mail, labels, Starred), so identical bodies are
hardlinked instead of stored twice. Messages are fetched with BODY.PEEK so
nothing gets marked as read. Re-running resumes: UIDs already in a manifest
are skipped.
"""
import email
import email.utils
import hashlib
import imaplib
import os
import re
import ssl
import subprocess
import sys
import time
from email.header import decode_header

RETRIES = 5
# The kubectl port-forward in front of the Bridge sometimes wedges on large
# messages: it keeps listening but every new connection gets EOF. Restarting
# the user service that owns it is the only thing that clears that.
TUNNEL_UNIT = 'protonbridge-k3s-tunnel.service'
# Bridge serves large attachments slowly through the k3s port-forward.
TIMEOUT_SECONDS = 300


def connect():
    """Log in to the Bridge. It needs STARTTLS and has a self-signed cert."""
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    conn = imaplib.IMAP4(os.environ['IMAP_HOST'], int(os.environ['IMAP_PORT']),
                         timeout=TIMEOUT_SECONDS)
    conn.starttls(ssl_context=ctx)
    conn.login(os.environ['IMAP_USER'], os.environ['IMAP_PASS'])
    return conn


def reconnect(mailbox):
    """Open a fresh session on mailbox, restarting the tunnel if it is wedged."""
    for attempt in range(1, RETRIES + 1):
        try:
            conn = connect()
            conn.select(f'"{mailbox}"', readonly=True)
            return conn
        except Exception as err:
            print(f'  reconnect attempt {attempt}: {err!r}, restarting tunnel', flush=True)
            subprocess.run(['systemctl', '--user', 'restart', TUNNEL_UNIT], check=False)
            time.sleep(15 * attempt)
    raise RuntimeError('Bridge unreachable even after restarting the tunnel')


def list_mailboxes(conn):
    """Return the names of all selectable mailboxes."""
    _, lines = conn.list()
    names = []
    for line in lines:
        flags, name = re.match(r'\((.*?)\) ".*?" (.*)', line.decode()).groups()
        if '\\Noselect' not in flags:
            names.append(name.strip('"'))
    return sorted(names)


def subject_slug(raw):
    """Short filesystem-safe version of the subject, for browsable filenames."""
    header = email.message_from_bytes(raw[:65536]).get('Subject', '')
    try:
        text = ''.join(
            part.decode(charset or 'utf-8', errors='replace')
            if isinstance(part, bytes) else part
            for part, charset in decode_header(header))
    except Exception:  # malformed encoded-words: the name is only cosmetic
        text = ''
    return re.sub(r'[^\w.-]+', '_', text).strip('_.')[:60] or 'no_subject'


def fetch_message(conn, uid):
    """Return (raw bytes, internal date as epoch, flags string) for one UID."""
    typ, data = conn.uid('FETCH', uid, '(BODY.PEEK[] INTERNALDATE FLAGS)')
    bodies = [item for item in data if isinstance(item, tuple)]
    if typ != 'OK' or not bodies:
        raise RuntimeError(f'empty FETCH response for UID {uid}')
    # Metadata may sit before or after the literal, so search all of it.
    meta = b' '.join(item[0] if isinstance(item, tuple) else item
                     for item in data if item)
    date = re.search(rb'INTERNALDATE "([^"]+)"', meta)
    stamp = time.time()
    if date:
        stamp = email.utils.parsedate_to_datetime(date.group(1).decode()).timestamp()
    flags = re.search(rb'FLAGS \(([^)]*)\)', meta)
    return bodies[0][1], stamp, flags.group(1).decode() if flags else ''


def store_message(path, raw, stamp, seen):
    """Write raw to path, hardlinking to an identical already exported file."""
    digest = hashlib.sha256(raw).hexdigest()
    if digest in seen:
        os.link(seen[digest], path)
    else:
        tmp = path + '.part'
        with open(tmp, 'wb') as out:
            out.write(raw)
        os.utime(tmp, (stamp, stamp))
        os.replace(tmp, path)
        seen[digest] = path
    return digest


def load_manifest(folder_dir, seen):
    """Return UIDs already exported for a mailbox and register their hashes."""
    done = set()
    manifest = os.path.join(folder_dir, 'manifest.tsv')
    if not os.path.exists(manifest):
        return done
    with open(manifest, encoding='utf-8') as lines:
        for line in lines:
            uid, digest, _flags, name = line.rstrip('\n').split('\t')
            path = os.path.join(folder_dir, name)
            if os.path.exists(path):
                done.add(uid)
                seen.setdefault(digest, path)
    return done


def export_one(conn, folder_dir, uid, seen, manifest):
    """Fetch one message, store it and record it in the mailbox manifest."""
    raw, stamp, flags = fetch_message(conn, uid)
    day = time.strftime('%Y-%m-%d', time.gmtime(stamp))
    name = f'{day}_{int(uid):07d}_{subject_slug(raw)}.eml'
    digest = store_message(os.path.join(folder_dir, name), raw, stamp, seen)
    manifest.write(f'{uid}\t{digest}\t{flags}\t{name}\n')
    manifest.flush()


def export_with_retry(conn, mailbox, folder_dir, uid, seen, manifest):
    """Export one UID, reconnecting between attempts.

    Returns (connection, success); the connection is replaced when a fetch
    error forced a reconnect.
    """
    for attempt in range(1, RETRIES + 1):
        try:
            export_one(conn, folder_dir, uid, seen, manifest)
            return conn, True
        except Exception as err:
            print(f'  {mailbox} UID {uid} attempt {attempt}: {err!r}', flush=True)
            time.sleep(5 * attempt)
            conn = reconnect(mailbox)
    return conn, False


def export_mailbox(conn, dest, mailbox, seen):
    """Export all not yet exported messages of one mailbox.

    Returns (connection, exported, failed).
    """
    folder_dir = os.path.join(dest, *mailbox.split('/'))
    os.makedirs(folder_dir, exist_ok=True)
    done = load_manifest(folder_dir, seen)
    conn.select(f'"{mailbox}"', readonly=True)
    _, data = conn.uid('SEARCH', None, 'ALL')
    uids = [u.decode() for u in data[0].split() if u.decode() not in done]
    print(f'{mailbox}: {len(uids)} to fetch, {len(done)} already there', flush=True)
    exported = failed = 0
    with open(os.path.join(folder_dir, 'manifest.tsv'), 'a', encoding='utf-8') as manifest:
        for uid in uids:
            conn, ok = export_with_retry(conn, mailbox, folder_dir, uid, seen, manifest)
            if not ok:
                failed += 1
                continue
            exported += 1
            if exported % 500 == 0:
                print(f'  {mailbox}: {exported}/{len(uids)}', flush=True)
    return conn, exported, failed


def main():
    dest = sys.argv[1]
    os.makedirs(dest, exist_ok=True)
    conn = connect()
    mailboxes = list_mailboxes(conn)
    # Register every existing manifest first so that a resumed run still
    # hardlinks against mailboxes that sort later.
    seen = {}
    for mailbox in mailboxes:
        load_manifest(os.path.join(dest, *mailbox.split('/')), seen)
    total = total_failed = 0
    for mailbox in mailboxes:
        conn, exported, failed = export_mailbox(conn, dest, mailbox, seen)
        total += exported
        total_failed += failed
    conn.logout()
    print(f'DONE: {total} exported, {total_failed} failed, {len(seen)} unique messages',
          flush=True)
    sys.exit(1 if total_failed else 0)


if __name__ == '__main__':
    main()
