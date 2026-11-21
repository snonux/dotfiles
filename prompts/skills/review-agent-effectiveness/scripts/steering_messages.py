#!/usr/bin/env python3
"""Print what the user typed in task and audit sessions, for local reading.

Reads the scan.jsonl written by scan_sessions.py. The numbers in
report_sessions.py say how often something happened; the user's own follow-up
messages say what bothered them ("why are you so slow", "never just stop
like that"). Both are needed to decide what to change.

PRIVATE: the output is raw user text. Read it in the terminal. Never write it
to a file inside a repository, never send it to a cloud agent or any external
service, and quote at most short phrases in a report.

    python3 -I steering_messages.py [scan.jsonl] [--since YYYY-MM-DD] [--max N]
"""
import argparse
import collections
import json
import re

TASK_SKILLS = ("agent-task-management", "work-on-tasks", "next-auto-task", "auditing-code-quality")
# Harness-generated turns and prompt templates, not something the user typed by hand.
GENERATED = ("<codex_internal", "<send_user", "this session is being continued",
             "base directory for this skill", "<skill", "use the task workflow rules below",
             "briefly inform the user about the task result", "the beginning of the above subagent result",
             "perform any necessary follow-up actions", "# /work-on-tasks", "run the following command: ask")
STEERING = re.compile(
    r"\b(review\w*|sub-?agents?|parallel\w*|memory|swap|oom|annot\w*|blocked|skip|faster|speed|slow|"
    r"tokens|loop|stuck|hang\w*|waste|expensive|too (many|much|long)|stop|why|worktree|"
    r"fresh context|cloud|remote|again|still|status|continue|never|don't|do not)\b", re.I)


def task_sessions(path):
    """Main (non-sub-agent) sessions that used ask or one of the task skills."""
    for line in open(path):
        rec = json.loads(line)
        if rec.get("sub") or "human" not in rec:
            continue
        if rec["ask"] or any(rec["skills"].get(name) for name in TASK_SKILLS):
            yield rec


def collect(path, since):
    """Return (repeat counts, steering follow-ups) across task sessions."""
    repeated, followups = collections.Counter(), []
    for rec in task_sessions(path):
        project = (rec.get("cwd") or "").rstrip("/").split("/")[-1]
        for index, (ts, text) in enumerate(rec["human"]):
            if (ts or "") < since or text.lower().startswith(GENERATED):
                continue
            flat = re.sub(r"\s+", " ", text).strip()
            repeated[(rec["tool"], flat.lower()[:60])] += 1
            if index > 0 and len(flat) > 15 and STEERING.search(flat):
                followups.append((ts[:10], rec["tool"], project, flat))
    return repeated, followups


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("scan", nargs="?", default="scan.jsonl")
    parser.add_argument("--since", default="", help="only messages on or after this date")
    parser.add_argument("--max", type=int, default=150, help="maximum follow-up messages to print")
    args = parser.parse_args()

    repeated, followups = collect(args.scan, args.since)
    print("== messages typed three times or more (what the user keeps having to say)")
    for (tool, text), count in repeated.most_common(40):
        if count >= 3:
            print(f"  {count:4} {tool:6} {text}")

    print("\n== follow-up messages that steer or correct the agent (deduplicated)")
    seen = set()
    for date, tool, project, text in sorted(followups):
        key = re.sub(r"\W+", "", text.lower())[:50]
        if key in seen:
            continue
        seen.add(key)
        if len(seen) > args.max:
            print(f"  ... more than {args.max}; narrow with --since")
            break
        print(f"{date} {tool:6} {project[:14]:14} {text[:300]}")


if __name__ == "__main__":
    main()
