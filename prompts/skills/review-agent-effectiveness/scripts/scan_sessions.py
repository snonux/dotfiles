#!/usr/bin/env python3
"""Summarise agent session logs, one JSON record per session file.

Reads three kinds of logs (all under the home directory):
  * Claude Code: ~/.claude/projects/**/*.jsonl (sub-agent logs live in "subagents" dirs)
  * Codex CLI:   ~/.codex/sessions/**/*.jsonl
  * pi:          ~/.pi/agent/sessions/**/*.jsonl
  * cursor-agent: ~/.cursor/projects/*/agent-transcripts/**/*.jsonl (no timestamps or
    tool results in these; timing, token and error fields stay empty)
Claude Code and Codex files are limited to those modified in the last --days days;
pi and cursor-agent files are limited by --pi-days and --cursor-days (default: all).

Each output line is one session file as a JSON object. Main fields:
  tool, path, root (session id), sub (is a sub-agent), agent, cwd, project, version,
  start/end timestamps, active_s (time without idle gaps over 10 minutes),
  n_asst, n_tool, tools (name -> count), out_tok, max_ctx, compactions, models,
  human (timestamped, truncated user messages), interrupts, slash (slash commands),
  ask (one entry per `ask` CLI call: ts, sub, args, err, out, olen, solo),
  skills and skill_files (counters of skill names / files seen in commands and tool calls),
  spawns (sub-agents launched: name, type, prompt excerpt, prompt length),
  go_test, go_test_all, go_test_race, commits, add_all, pushes (command counters),
  tool_errors and err_samples, first_prompt, goal, waits.

The scan streams the logs (several GB in total) and stores only counters and short
excerpts (prompts up to 1200 characters, error output up to 300 characters), never
whole conversations. The output still contains private data (user messages, task
text, paths): keep it on this machine and do not commit or upload it.

Usage: python3 -I scan_sessions.py [--days 31] [--pi-days 100000] [--cursor-days 100000] [--out ./scan.jsonl] [--workers 5]
"""
import argparse
import collections
import json
import multiprocessing
import os
import re
import sys
import time

HOME = os.path.expanduser("~")
SKILLS = ["agent-task-management", "auditing-code-quality", "work-on-tasks", "next-auto-task",
          "find-code-bugs", "solid-principles", "beyond-solid-principles", "go-best-practices",
          "100-go-mistakes", "audit"]
SKILL_PATH = re.compile(r"skills/([a-z0-9-]+)/((?:references/|scripts/)?[\w.\-/]*)")
ASK = re.compile(r"(?:^|[\s;&|(`$])(?:~/go/bin/|/home/paul/go/bin/|\$HOME/go/bin/)?ask\s+((?:proj(?:ect)?:\S+\s+)?)([a-z][a-z-]*)\b([^;&|\n]*)")
ASK_SUBS = {"list", "all", "ready", "completed", "add", "info", "start", "stop", "done", "annotate",
            "modify", "delete", "dep", "projects", "denotate", "undo", "blocked", "next", "tags", "help",
            # added with hexai ask v0.45.0 and earlier releases
            "park", "unpark", "parked", "count", "tag", "priority", "urgency", "edit", "watch", "fish"}
CODEX_CMD = re.compile(r'cmd\s*:\s*("(?:[^"\\]|\\.)*"|`(?:[^`\\]|\\.)*`|\'(?:[^\'\\]|\\.)*\')')
EXIT = re.compile(r'exit_code\\?"\s*:\s*(-?\d+)')
NOISE = ("<system-reminder>", "<local-command", "<task-notification", "<command-message>", "Caveat:",
         "# AGENTS.md", "<environment_context", "<user_instructions", "<turn_aborted", "<skill", "<INSTRUCTIONS",
         "<permissions", "<collaboration_mode", "<subagent_notification", "<user_shell_command",
         "<cursor_commands", "<attached_files", "<manually_attached",
         # cursor-agent's own follow-up turns after a sub-agent returns
         "Briefly inform the user about the task result", "The beginning of the above subagent result",
         "Perform any necessary follow-up actions")


def new_rec(tool, path):
    return {"tool": tool, "path": path, "root": None, "sub": False, "agent": None, "cwd": None,
            "start": None, "end": None, "active_s": 0, "n_asst": 0, "n_tool": 0, "tools": collections.Counter(),
            "out_tok": 0, "max_ctx": 0, "compactions": 0, "human": [], "interrupts": 0, "slash": [],
            "ask": [], "skills": collections.Counter(), "skill_files": collections.Counter(),
            "spawns": [], "go_test": 0, "go_test_all": 0, "go_test_race": 0, "commits": 0, "add_all": 0,
            "pushes": 0, "tool_errors": 0, "err_samples": [], "first_prompt": None, "models": collections.Counter(),
            "goal": None, "waits": 0, "version": None}


def tick(rec, ts):
    """Track start/end and 'active' time (gaps over 10 minutes count as idle)."""
    if not ts:
        return
    try:
        t = time.mktime(time.strptime(ts[:19], "%Y-%m-%dT%H:%M:%S"))
    except ValueError:
        return
    if rec["start"] is None:
        rec["start"] = ts
    elif t - rec["_last"] < 600:
        rec["active_s"] += max(0, t - rec["_last"])
    rec["_last"] = t
    rec["end"] = ts


def note_command(rec, cmd, ts, err, out, olen=0):
    """Classify one shell command: ask calls, test runs, git, skill file reads."""
    for m in SKILL_PATH.finditer(cmd):
        rec["skills"][m.group(1)] += 1
        if m.group(2):
            rec["skill_files"][m.group(1) + "/" + m.group(2)] += 1
    for m in ASK.finditer(cmd):
        sub = m.group(2)
        if sub not in ASK_SUBS and not m.group(1):
            sub = "?" + sub  # natural language or unknown subcommand
        rec["ask"].append({"ts": ts, "sub": sub, "args": m.group(3).strip()[:160], "err": bool(err),
                           "out": (out or "")[:300] if err else "", "olen": olen or len(out or ""),
                           "solo": len(ASK.findall(cmd)) == 1 and not re.search(r"&&|;|\|\|", cmd)})
    if re.search(r"\bgo test\b|\bmage test|\bflutter test|\bpytest\b|\bcargo test|\bnpm test", cmd):
        rec["go_test"] += 1
        if re.search(r"go test[^;&|]*\./\.\.\.", cmd):
            rec["go_test_all"] += 1
        if "-race" in cmd:
            rec["go_test_race"] += 1
    rec["commits"] += len(re.findall(r"\bgit (?:-C \S+ )?commit\b", cmd))
    rec["pushes"] += len(re.findall(r"\bgit (?:-C \S+ )?push\b", cmd))
    rec["add_all"] += len(re.findall(r"\bgit (?:-C \S+ )?add (?:-A|\.|--all)(?:\s|$)|git commit -a", cmd))


def note_human(rec, text, ts):
    text = text.strip()
    if not text:
        return
    if "[Request interrupted" in text:
        rec["interrupts"] += 1
        return
    m = re.search(r"<command-name>(/[\w:-]+)</command-name>.*?<command-args>(.*?)</command-args>", text, re.S)
    if m:
        rec["slash"].append((m.group(1) + " " + m.group(2)).strip()[:200])
        for s in SKILLS:
            if s in m.group(1):
                rec["skills"][s] += 1
        return
    if text.startswith(NOISE):
        return
    for s in SKILLS[:4]:
        if re.search(r"[$/]" + s + r"\b", text):
            rec["skills"][s] += 1
    if rec["first_prompt"] is None:
        rec["first_prompt"] = text[:600]
    rec["human"].append((ts, text[:1200]))


def claude_assistant_msg(rec, msg, seen_msgs):
    """Count one assistant message once (Claude Code logs one record per content block)."""
    mid = msg.get("id")
    if mid in seen_msgs:
        return
    seen_msgs.add(mid)
    rec["n_asst"] += 1
    u = msg.get("usage") or {}
    rec["out_tok"] += u.get("output_tokens") or 0
    ctx = sum(u.get(k) or 0 for k in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
    rec["max_ctx"] = max(rec["max_ctx"], ctx)
    if msg.get("model"):
        rec["models"][msg["model"]] += 1


def claude_tool_use(rec, c, ts, pending):
    """Handle one tool_use block: count it, note skill/file reads and sub-agent spawns, remember it for its result."""
    name, inp = c.get("name"), c.get("input") or {}
    rec["n_tool"] += 1
    rec["tools"][name] += 1
    if name == "Bash":
        pending[c["id"]] = ("Bash", inp.get("command") or "", ts)
    elif name == "Skill":
        rec["skills"][str(inp.get("skill"))] += 1
    elif name in ("Read", "Edit", "Write"):
        note_command(rec, inp.get("file_path") or "", ts, False, "")
    elif name in ("Agent", "Task"):
        rec["spawns"].append({"ts": ts, "name": (inp.get("description") or "")[:80],
                              "type": inp.get("subagent_type"), "iso": inp.get("isolation"),
                              "prompt": (inp.get("prompt") or "")[:400],
                              "plen": len(inp.get("prompt") or "")})
        pending[c["id"]] = (name, "", ts)
    else:
        pending[c["id"]] = (name, "", ts)


def claude_tool_result(rec, c, ts, pending):
    """Handle one tool_result block: pair it with its tool_use, count errors, classify Bash commands."""
    name, cmd, cts = pending.pop(c.get("tool_use_id"), ("?", "", ts))
    out = c.get("content")
    if isinstance(out, list):
        out = " ".join(x.get("text", "") for x in out if isinstance(x, dict))
    err = bool(c.get("is_error"))
    if err:
        rec["tool_errors"] += 1
        if len(rec["err_samples"]) < 40:
            rec["err_samples"].append((name, cmd[:160], str(out)[:240]))
    if name == "Bash":
        note_command(rec, cmd, cts, err, str(out))


def claude_user_text(rec, d, text, ts):
    """A user text: a human prompt in the main session; only the first prompt is kept for sub-agents."""
    if not rec["sub"] and not d.get("isMeta"):
        note_human(rec, text, ts)
    elif rec["first_prompt"] is None:
        rec["first_prompt"] = text[:600]


def claude_user(rec, d, content, ts, pending):
    """Handle a user record: plain string content, or a list of text / tool_result blocks."""
    if isinstance(content, str):
        claude_user_text(rec, d, content, ts)
        if d.get("isCompactSummary"):
            rec["compactions"] += 1
        return
    for c in content if isinstance(content, list) else []:
        if c.get("type") == "text":
            # A missing text field counts as an empty string, as for the plain-string form.
            claude_user_text(rec, d, c.get("text") or "", ts)
        elif c.get("type") == "tool_result":
            claude_tool_result(rec, c, ts, pending)


def claude_record(rec, d, pending, seen_msgs):
    """Dispatch one parsed Claude Code record by its type."""
    ts, typ = d.get("timestamp"), d.get("type")
    tick(rec, ts)
    rec["cwd"] = rec["cwd"] or d.get("cwd")
    rec["version"] = d.get("version") or rec["version"]
    if typ == "attachment":
        a = d.get("attachment") or {}
        if a.get("type") == "goal_status" and a.get("condition"):
            rec["goal"] = a["condition"][:300]
        return
    if typ == "system":
        if d.get("subtype") == "compact_boundary":
            rec["compactions"] += 1
        return
    msg = d.get("message") or {}
    content = msg.get("content")
    if typ == "assistant":
        claude_assistant_msg(rec, msg, seen_msgs)
        for c in content if isinstance(content, list) else []:
            if c.get("type") == "tool_use":
                claude_tool_use(rec, c, ts, pending)
    elif typ == "user":
        claude_user(rec, d, content, ts, pending)


def scan_claude(path):
    """Scan one Claude Code log; main-session and sub-agent logs are told apart by their path."""
    rec = new_rec("claude", path)
    parts = path.split("/")
    rec["sub"] = "subagents" in parts
    i = parts.index("projects")
    rec["project"] = parts[i + 1]
    rec["root"] = parts[i + 2].replace(".jsonl", "")
    pending, seen_msgs = {}, set()
    with open(path, errors="replace") as fh:
        for line in fh:
            if not line.startswith('{"parentUuid"'):
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            claude_record(rec, d, pending, seen_msgs)
    return finish(rec)


def codex_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(x.get("text", "") for x in content if isinstance(x, dict))
    return ""


def codex_session_meta(rec, p):
    """session_meta record: session id, sub-agent flag, agent path, cwd and CLI version."""
    rec["root"] = p.get("session_id") or p.get("id")
    rec["sub"] = p.get("thread_source") == "subagent"
    rec["agent"] = p.get("agent_path")
    rec["cwd"] = p.get("cwd")
    rec["version"] = p.get("cli_version")


def codex_message(rec, p, ts):
    """response_item message: count assistant turns, record user text (first prompt only for sub-agents)."""
    if p.get("role") == "assistant":
        rec["n_asst"] += 1
    elif p.get("role") == "user":
        text = codex_text(p.get("content"))
        if rec["sub"]:
            rec["first_prompt"] = rec["first_prompt"] or text[:600]
        else:
            note_human(rec, text, ts)


def codex_tool_call(rec, p, ts, pending):
    """custom_tool_call: count it and extract the shell commands (cmd: "...") from its input for the output record."""
    rec["n_tool"] += 1
    rec["tools"][p.get("name")] += 1
    cmds = []
    for m in CODEX_CMD.finditer(p.get("input") or ""):
        raw = m.group(1)
        try:
            cmds.append(json.loads(raw) if raw[0] == '"' else raw[1:-1])
        except ValueError:
            cmds.append(raw[1:-1])
    pending[p.get("call_id")] = (cmds, ts)


def codex_tool_output(rec, p, ts, pending):
    """custom_tool_call_output: match exit codes / token counts to the commands of the call, count errors, classify."""
    cmds, cts = pending.pop(p.get("call_id"), ([], ts))
    out = codex_text(p.get("output"))
    codes = [int(x) for x in EXIT.findall(out)]
    toks = [int(x) for x in re.findall(r'original_token_count\\?"\s*:\s*(\d+)', out)]
    for i, cmd in enumerate(cmds):
        olen = toks[i] * 4 if len(toks) == len(cmds) else 0  # ~4 chars per token
        err = codes[i] != 0 if len(codes) == len(cmds) else any(codes)
        if err:
            rec["tool_errors"] += 1
            if len(rec["err_samples"]) < 40:
                rec["err_samples"].append(("exec", cmd[:160], out[-240:]))
        note_command(rec, cmd, cts, err, out[-600:], olen)


def codex_function_call(rec, p, ts):
    """function_call: count it; record spawn_agent as a spawn and wait/sleep calls as waits."""
    name = p.get("name")
    rec["n_tool"] += 1
    rec["tools"][name] += 1
    if name == "spawn_agent":
        try:
            a = json.loads(p.get("arguments") or "{}")
        except ValueError:
            a = {}
        rec["spawns"].append({"ts": ts, "name": a.get("task_name"), "type": a.get("agent_type"),
                              "plen": len(a.get("message") or "")})
    elif name in ("wait_agent", "sleep", "wait"):
        rec["waits"] += 1


def codex_response_item(rec, p, ts, pending):
    """Dispatch a response_item payload by its payload type."""
    pt = p.get("type")
    if pt == "message":
        codex_message(rec, p, ts)
    elif pt == "custom_tool_call":
        codex_tool_call(rec, p, ts, pending)
    elif pt == "custom_tool_call_output":
        codex_tool_output(rec, p, ts, pending)
    elif pt == "function_call":
        codex_function_call(rec, p, ts)


def codex_record(rec, d, pending):
    """Dispatch one parsed Codex record by its type; records with a non-dict payload are ignored entirely."""
    typ, p, ts = d.get("type"), d.get("payload") or {}, d.get("timestamp")
    if not isinstance(p, dict):
        return
    tick(rec, ts)
    if typ == "session_meta":
        codex_session_meta(rec, p)
    elif typ == "compacted":
        rec["compactions"] += 1
    elif typ == "turn_context" and p.get("model"):
        rec["models"][p["model"]] += 1
    elif typ == "response_item":
        codex_response_item(rec, p, ts, pending)


def codex_final_tokens(rec, last_tok):
    """Take the token totals from the last token_count line (it holds cumulative usage)."""
    try:
        info = (json.loads(last_tok).get("payload") or {}).get("info") or {}
        tot = info.get("total_token_usage") or {}
        rec["out_tok"] = tot.get("output_tokens") or 0
        rec["in_tok_total"] = tot.get("input_tokens") or 0
        rec["cached_tok_total"] = tot.get("cached_input_tokens") or 0
        rec["max_ctx"] = (info.get("last_token_usage") or {}).get("input_tokens") or 0
    except ValueError:
        pass


def scan_codex(path):
    """Scan one Codex CLI log. Bulky record kinds are skipped by a cheap prefix check before parsing."""
    rec = new_rec("codex", path)
    pending, last_tok = {}, None
    with open(path, errors="replace") as fh:
        for line in fh:
            head = line[:140]
            if '"type":"token_usage_record"' in head or '"type":"world_state"' in head or '"item_completed"' in head:
                continue
            if '"token_count"' in head:
                last_tok = line
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            codex_record(rec, d, pending)
    if last_tok:
        codex_final_tokens(rec, last_tok)
    return finish(rec)


def pi_assistant(rec, msg, items, ts, pending):
    """Assistant message: count it, add usage/model/stop reason, then handle its toolCall blocks."""
    rec["n_asst"] += 1
    u = msg.get("usage") or {}
    rec["out_tok"] += u.get("output") or 0
    rec["max_ctx"] = max(rec["max_ctx"], (u.get("input") or 0) + (u.get("cacheRead") or 0))
    if msg.get("model"):
        rec["models"][msg["model"]] += 1
    if msg.get("stopReason") in ("error", "aborted", "length"):
        rec["tools"]["~stop:" + msg["stopReason"]] += 1
    for c in items:
        if c.get("type") == "toolCall":
            pi_tool_call(rec, c, ts, pending)


def pi_tool_call(rec, c, ts, pending):
    """One toolCall block: count it, remember it for its result, record non-builtin tools as spawns."""
    name, a = c.get("name"), c.get("arguments") or {}
    if not isinstance(a, dict):
        a = {}
    rec["n_tool"] += 1
    rec["tools"][name] += 1
    cmd = a.get("command") or a.get("path") or a.get("file_path") or ""
    pending[c.get("id")] = (name, str(cmd), ts)
    if name not in ("bash", "read", "edit", "write", "grep", "find", "ls"):
        rec["spawns"].append({"ts": ts, "name": name, "type": "pi-tool",
                              "prompt": json.dumps(a)[:400], "plen": len(json.dumps(a))})


def pi_tool_result(rec, msg, items, ts, pending):
    """toolResult message: pair it with its call, count errors, classify the command."""
    name, cmd, cts = pending.pop(msg.get("toolCallId"), (msg.get("toolName"), "", ts))
    out = "\n".join(x.get("text", "") for x in items if isinstance(x, dict))
    err = bool(msg.get("isError"))
    if err:
        rec["tool_errors"] += 1
        if len(rec["err_samples"]) < 40:
            rec["err_samples"].append((name, cmd[:160], out[:240]))
    note_command(rec, cmd, cts, err, out)


def pi_message(rec, d, ts, pending):
    """A "message" entry: dispatch by role (user, assistant, toolResult)."""
    msg = d.get("message") or {}
    role, content = msg.get("role"), msg.get("content")
    items = content if isinstance(content, list) else [{"type": "text", "text": content or ""}]
    if role == "user":
        note_human(rec, "\n".join(x.get("text", "") for x in items if x.get("type") == "text"), ts)
    elif role == "assistant":
        pi_assistant(rec, msg, items, ts, pending)
    elif role == "toolResult":
        pi_tool_result(rec, msg, items, ts, pending)


def pi_record(rec, d, pending):
    """Dispatch one parsed pi entry by its type."""
    typ, ts = d.get("type"), d.get("timestamp")
    tick(rec, ts if isinstance(ts, str) else None)
    if typ == "session":
        rec["root"], rec["cwd"], rec["version"] = d.get("id"), d.get("cwd"), "v%s" % d.get("version")
    elif typ == "model_change":
        rec["models"][str(d.get("modelId"))] += 0
    elif typ != "message":
        if typ and "compact" in typ:
            rec["compactions"] += 1
        else:
            rec["tools"]["~" + str(typ)] += 1  # other entry kinds (branch summaries, custom entries)
    else:
        pi_message(rec, d, ts, pending)


def scan_pi(path):
    """pi.dev sessions: one file per session, messages with role user/assistant/toolResult."""
    rec = new_rec("pi", path)
    pending = {}
    with open(path, errors="replace") as fh:
        for line in fh:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            pi_record(rec, d, pending)
    return finish(rec)


def finish(rec):
    rec.pop("_last", None)
    for k in ("tools", "skills", "skill_files", "models"):
        rec[k] = dict(rec[k])
    return rec


# ---------------------------------------------------------------- cursor-agent
CURSOR_COMMAND = re.compile(r"--- Cursor Command: ([\w-]+) ---")
USER_QUERY = re.compile(r"<user_query>(.*?)</user_query>", re.S)
CURSOR_FILE_TOOLS = ("Read", "ReadFile", "StrReplace", "Write", "ApplyPatch", "Delete")
# A top-level cursor session whose first turn is a worker or reviewer prompt was
# launched by another agent, not typed by the user: it counts as a sub-agent.
CURSOR_WORKER_PROMPT = re.compile(r"\s*You are (implementing|an expert|working in|reviewing|the |a )", re.I)


def cursor_human_text(rec, text):
    """Return what the user typed in a cursor turn.

    cursor wraps the user's words in <user_query> and prepends the text of any
    slash command; the command names are recorded as slash commands and skill
    uses, and only the query body counts as a human message.
    """
    for name in CURSOR_COMMAND.findall(text):
        rec["slash"].append("/" + name)
        if name in SKILLS:
            rec["skills"][name] += 1
    queries = USER_QUERY.findall(text)
    if queries:
        return "\n".join(q.strip() for q in queries)
    return "" if text.lstrip().startswith("<") else text


def cursor_tool_use(rec, item, ts):
    """Record one cursor tool call: shell commands, file paths, sub-agent launches."""
    name, inp = item.get("name"), item.get("input")
    if not isinstance(inp, dict):
        inp = {}  # some tools (rg, ApplyPatch) carry a plain string
    rec["n_tool"] += 1
    rec["tools"][name] += 1
    if name == "Shell":
        note_command(rec, inp.get("command") or "", ts, False, "")
    elif name in CURSOR_FILE_TOOLS:
        note_command(rec, str(inp.get("path") or inp.get("target_file") or ""), ts, False, "")
    elif name in ("Task", "Subagent"):
        prompt = inp.get("prompt") or ""
        rec["spawns"].append({"ts": ts, "name": (inp.get("description") or "")[:80],
                              "type": inp.get("subagent_type"), "prompt": prompt[:400], "plen": len(prompt)})


def cursor_record(rec, d, ts):
    """Handle one transcript line: a user turn or an assistant turn with tool calls."""
    content = (d.get("message") or {}).get("content") or []
    items = content if isinstance(content, list) else [{"type": "text", "text": str(content)}]
    if d.get("role") == "user":
        text = "\n".join(x.get("text", "") for x in items if isinstance(x, dict) and x.get("type") == "text")
        cursor_user_turn(rec, text, ts)
    elif d.get("role") == "assistant":
        rec["n_asst"] += 1
        for item in items:
            if isinstance(item, dict) and item.get("type") == "tool_use":
                cursor_tool_use(rec, item, ts)


def cursor_user_turn(rec, text, ts):
    """Record a user turn, or recognise the session as a launched worker from its first turn."""
    if rec["sub"]:
        rec["first_prompt"] = rec["first_prompt"] or text[:600]
        return
    query = cursor_human_text(rec, text)
    if rec["first_prompt"] is None and not rec["human"] and CURSOR_WORKER_PROMPT.match(query):
        rec["sub"], rec["agent"], rec["first_prompt"] = True, "top-level worker", query[:600]
        return
    note_human(rec, query, ts)


def scan_cursor(path):
    """cursor-agent transcripts (~/.cursor/projects/<project>/agent-transcripts).

    They carry no timestamps and no tool results. The file's modification time
    stands in for every timestamp, and the timing, token and error fields stay
    empty: cursor numbers for those are "n/a", not zero.
    """
    rec = new_rec("cursor", path)
    parts = path.split("/")
    i = parts.index("agent-transcripts")
    rec["project"], rec["root"], rec["sub"] = parts[i - 1], parts[i + 1].replace(".jsonl", ""), "subagents" in parts
    ts = time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(os.path.getmtime(path)))
    rec["start"] = rec["end"] = ts
    with open(path, errors="replace") as fh:
        for line in fh:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            cursor_record(rec, d, ts)
    return finish(rec)


def scan(path):
    try:
        if "/pi/agent/sessions/" in path:
            return scan_pi(path)
        if "/agent-transcripts/" in path:
            return scan_cursor(path)
        return scan_codex(path) if "/.codex/" in path else scan_claude(path)
    except Exception as e:  # keep going; report the file
        return {"path": path, "error": repr(e)}


def recent(root, days):
    """Yield .jsonl files under root modified within the last `days` days."""
    cutoff = time.time() - days * 86400
    for dp, _, fns in os.walk(root):
        for fn in fns:
            p = os.path.join(dp, fn)
            if fn.endswith(".jsonl") and os.path.getmtime(p) >= cutoff:
                yield p


def parse_args():
    """Command line options; defaults reproduce the original one-off scan."""
    ap = argparse.ArgumentParser(description="Scan Claude Code, Codex CLI, pi and cursor-agent session logs into one JSON record per file.")
    ap.add_argument("--days", type=int, default=31, help="only Claude Code/Codex files modified in the last N days (default 31)")
    ap.add_argument("--pi-days", type=int, default=100000, help="same for pi sessions (default 100000, i.e. all)")
    ap.add_argument("--cursor-days", type=int, default=100000, help="same for cursor-agent sessions (default 100000, i.e. all)")
    ap.add_argument("--out", default="./scan.jsonl", help="output JSONL path (default ./scan.jsonl)")
    ap.add_argument("--workers", type=int, default=5, help="parallel worker processes (default 5)")
    return ap.parse_args()


def collect_files(args):
    """List the session files to scan: Claude Code and Codex within --days, pi within --pi-days, biggest first."""
    files = list(recent(HOME + "/.claude/projects", args.days)) + list(recent(HOME + "/.codex/sessions", args.days))
    # pi has its own, normally much longer, window so its whole history is kept by default.
    files += list(recent(os.path.realpath(HOME + "/.pi/agent/sessions"), args.pi_days))
    # cursor-agent: only the transcripts, not the other .jsonl files under ~/.cursor/projects.
    files += [p for p in recent(HOME + "/.cursor/projects", args.cursor_days) if "/agent-transcripts/" in p]
    # Biggest files first so the long tail does not leave one worker busy at the end.
    files.sort(key=os.path.getsize, reverse=True)
    return files


def scan_all(files, args, t0):
    """Scan all files in a worker pool and write one JSON line per file, reporting progress on stderr."""
    with multiprocessing.Pool(args.workers) as pool, open(args.out, "w") as out:
        for i, rec in enumerate(pool.imap_unordered(scan, files, chunksize=4)):
            out.write(json.dumps(rec) + "\n")
            if i % 400 == 0:
                print(i, len(files), int(time.time() - t0), "s", file=sys.stderr)


def main():
    args = parse_args()
    files = collect_files(args)
    t0 = time.time()
    scan_all(files, args, t0)
    print("done", len(files), "files in", int(time.time() - t0), "s")

if __name__ == "__main__":
    main()
