#!/usr/bin/env python3
"""Read-only search of Proton Bridge folders for order, shipping and tracking mail.

Search mode: lists one header line per message matching ANY of the --from,
--to or --subject terms, in every --folder given. Each folder gets its own
connection, because a long run of SEARCH commands can make the Bridge drop the
connection and one lost folder should not lose the others.

Read mode (--read N...): prints the text bodies of those message numbers from
the single --folder given.

Nothing is ever modified: folders are selected read-only and messages are
fetched with BODY.PEEK, so they stay unread.

The password comes from the aerc credential file, which is the one kept
current; override with BRIDGE_PASSWORD_FILE.
"""
import argparse
import email
import html
import imaplib
import os
import re
import socket
import ssl
import sys
from email.header import decode_header

HOST, PORT, USER = "127.0.0.1", 1143, "mail@paul.buetow.org"
PASSWORD_FILE = os.environ.get("BRIDGE_PASSWORD_FILE", "~/.config/aerc/protonbridge-password")


def connect(timeout):
    """Open a STARTTLS session; the Bridge certificate is self-signed."""
    path = os.path.expanduser(PASSWORD_FILE)
    try:
        password = open(path).read().strip()
    except OSError as err:
        sys.exit("cannot read Bridge password file %s: %s" % (path, err))
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    conn = imaplib.IMAP4(HOST, PORT, timeout=timeout)
    conn.starttls(ssl_context=ctx)
    conn.login(USER, password)
    return conn


def decode(value):
    """Decode an RFC 2047 header into one line of text."""
    parts = decode_header(value or "")
    text = "".join(p.decode(c or "utf-8", errors="replace") if isinstance(p, bytes) else p for p, c in parts)
    return " ".join(text.split())


def body_text(message):
    """Return the plain-text part, or the HTML part with tags stripped."""
    plain = markup = None
    for part in message.walk():
        kind = part.get_content_type()
        if kind not in ("text/plain", "text/html"):
            continue
        text = (part.get_payload(decode=True) or b"").decode(part.get_content_charset() or "utf-8", errors="replace")
        if kind == "text/plain" and plain is None:
            plain = text
        if kind == "text/html" and markup is None:
            markup = text
    if plain and plain.strip():
        return plain
    markup = re.sub(r"(?is)<(script|style).*?</\1>", " ", markup or "")
    return html.unescape(re.sub(r"(?s)<[^>]+>", " ", markup))


def quoted(folder):
    """IMAP needs folder names with spaces or slashes quoted."""
    return folder if folder.startswith('"') else '"%s"' % folder


def search_folder(conn, args):
    """Return the message numbers matching any term, in ascending order."""
    hits = set()
    criteria = [("FROM", t) for t in args.sender] + [("TO", t) for t in args.to] + [("SUBJECT", t) for t in args.subject]
    for field, term in criteria:
        query = ["SINCE", args.since] if args.since else []
        query += [field, '"%s"' % term]
        _, data = conn.search(None, *query)
        hits.update(data[0].split())
    return sorted(hits, key=int)


def list_hits(folder, args):
    """Print one header line per hit in a folder, newest last."""
    conn = connect(args.timeout)
    status, count = conn.select(quoted(folder), readonly=True)
    if status != "OK":
        print("== %s: cannot select (%s)" % (folder, count), flush=True)
        return
    numbers = search_folder(conn, args)
    print("== %s: %s messages, %d hits" % (folder, count[0].decode(), len(numbers)), flush=True)
    for number in numbers[-args.max:]:
        _, data = conn.fetch(number, "(BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])")
        head = email.message_from_bytes(data[0][1])
        print("  %s | %s | %s | %s" % (number.decode(), (head["Date"] or "")[5:16],
                                      decode(head["From"])[:32], decode(head["Subject"])[:120]), flush=True)
    conn.logout()


def read_messages(folder, args):
    """Print the bodies of the requested message numbers."""
    conn = connect(args.timeout)
    conn.select(quoted(folder), readonly=True)
    for number in args.read:
        _, data = conn.fetch(number, "(BODY.PEEK[])")
        if not data or data[0] is None:
            print("===== %s: no such message" % number)
            continue
        message = email.message_from_bytes(data[0][1])
        text = re.sub(r"https?://\S{60,}", "<url>", body_text(message))
        text = re.sub(r"(\s*\n\s*)+", "\n", re.sub(r"[ \t ‌͏]+", " ", text)).strip()
        print("===== %s | %s | %s | %s" % (number, message["Date"], decode(message["From"])[:40], decode(message["Subject"])))
        print(text[:args.limit])
    conn.logout()


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--folder", action="append", required=True, help="folder name, repeatable (e.g. Archive, Folders/Kickstarter)")
    parser.add_argument("--from", dest="sender", action="append", default=[], help="FROM term, repeatable")
    parser.add_argument("--to", action="append", default=[], help="TO term, repeatable")
    parser.add_argument("--subject", action="append", default=[], help="SUBJECT term, repeatable")
    parser.add_argument("--since", help="only messages since this date, e.g. 01-Apr-2026")
    parser.add_argument("--max", type=int, default=60, help="header lines to print per folder (newest)")
    parser.add_argument("--read", nargs="+", metavar="N", help="print the bodies of these message numbers instead of searching")
    parser.add_argument("--limit", type=int, default=2500, help="characters of body to print per message")
    parser.add_argument("--timeout", type=int, default=150, help="socket timeout in seconds")
    args = parser.parse_args()
    if args.read and len(args.folder) != 1:
        parser.error("--read needs exactly one --folder")
    if not args.read and not (args.sender or args.to or args.subject):
        parser.error("give at least one of --from, --to, --subject (or use --read)")
    return args


def main():
    args = parse_args()
    for folder in args.folder:
        try:
            if args.read:
                read_messages(folder, args)
            else:
                list_hits(folder, args)
        except (imaplib.IMAP4.error, socket.timeout, OSError) as err:
            # Keep going: the Bridge dropping one folder must not lose the rest.
            print("== %s FAILED: %s" % (folder, err), flush=True)


if __name__ == "__main__":
    main()
