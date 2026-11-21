#!/usr/bin/env python3
"""Print aggregate agent-effectiveness metrics from a scan.jsonl made by scan_sessions.py.

Usage: python3 -I report_sessions.py [scan.jsonl]      (default ./scan.jsonl)

The first section, HEADLINE, prints a fixed set of `name: value` lines that are meant
to be compared between runs (for example before and after a skill change). The
sections after it are the detailed breakdowns the headline numbers come from.

The script only reads the scan file (and the word counts of the skill .md files under
~/git/dotfiles/prompts/skills for one headline number) and writes nothing. It prints
counts and cluster keys, never the human messages stored in the scan. The scan file
itself contains private data and must stay on this machine.
"""
import collections
import json
import os
import re
import statistics
import sys
import time

Counter = collections.Counter
defaultdict = collections.defaultdict

TOOLS = ("claude", "codex", "pi", "cursor")
# Tools whose sub-agents are separate session files worth comparing. cursor
# transcripts have no timestamps, tokens or tool results, so its timing and
# error lines print "n/a".
AGENT_TOOLS = ("claude", "codex", "cursor")
NO_RESULT_TOOLS = ("cursor",)  # transcripts without timestamps and tool results
CORE = ["agent-task-management", "work-on-tasks", "next-auto-task", "auditing-code-quality", "find-code-bugs"]
ALL_SKILLS = CORE + ["solid-principles", "beyond-solid-principles", "go-best-practices", "100-go-mistakes", "audit"]
SKILLS_DIR = os.path.expanduser("~/git/dotfiles/prompts/skills")
START_TASK_FILE = "agent-task-management/references/2-start-task.md"


# ---------------------------------------------------------------- helpers

def load_records(path):
    """Read the scan file: one JSON record per session file (a main session or a sub-agent)."""
    with open(path) as fh:
        return [json.loads(line) for line in fh]


def percentile(values, fraction):
    """Nearest-rank percentile (0 for an empty list); same rule as the original scripts."""
    values = sorted(values)
    return values[min(len(values) - 1, int(len(values) * fraction))] if values else 0


def median_or_none(values):
    """Median of a list, or None when the list is empty."""
    return statistics.median(values) if values else None


def parse_ts(text):
    """Seconds since the epoch for an ISO timestamp such as 2026-11-01T12:30:00Z."""
    return time.mktime(time.strptime(text[:19], "%Y-%m-%dT%H:%M:%S"))


def total(records, key):
    """Sum a numeric field over records, treating missing/None as 0."""
    return sum(r.get(key) or 0 for r in records)


def ran_ask_done(rec):
    """True if the agent ran at least one `ask done` (successful or not)."""
    return any(a["sub"] == "done" for a in rec["ask"])


def agents_of(recs, tool, sub=None):
    """Records of one tool; sub=True/False restricts to sub-agents/main sessions."""
    return [r for r in recs if r["tool"] == tool and (sub is None or r["sub"] == sub)]


# ---------------------------------------------------------------- session grouping

def build_sessions(recs):
    """Group records into root sessions (a main log plus all its sub-agent logs) with sums.

    pi has no shared session id across files, so each pi file is its own session.
    """
    roots = defaultdict(list)
    for r in recs:
        roots[(r["tool"], r["root"] if r["tool"] != "pi" else r["path"])].append(r)
    return [session_summary(tool, group) for (tool, _), group in roots.items()]


def session_summary(tool, group):
    """Aggregate one root session; `main` is its first non-sub-agent record."""
    main = next((r for r in group if not r["sub"]), group[0])
    skills = Counter()
    for r in group:
        for name, count in r["skills"].items():
            skills[name] += count
    return dict(
        tool=tool, skills=skills, nask=sum(len(r["ask"]) for r in group),
        subs=sum(1 for r in group if r["sub"]), active=total(group, "active_s") / 3600,
        main_active=main["active_s"] / 3600, out=total(group, "out_tok"), comp=total(group, "compactions"),
        main_comp=main["compactions"], human=len(main["human"]), intr=main["interrupts"],
        terr=total(group, "tool_errors"), ntool=total(group, "n_tool"), tests=total(group, "go_test"),
        tests_all=total(group, "go_test_all"), race=total(group, "go_test_race"),
        commits=total(group, "commits"), addall=total(group, "add_all"))


def workflow_class(sess):
    """Classify a session by the most specific task workflow skill it touched."""
    skills = sess["skills"]
    if skills.get("auditing-code-quality"):
        return "audit"
    if skills.get("work-on-tasks"):
        return "work-on-tasks"
    if skills.get("next-auto-task"):
        return "next-auto-task"
    if skills.get("agent-task-management") or sess["nask"] >= 3:
        return "tasks-other"
    return "none"


# ---------------------------------------------------------------- task cycle (shared by HEADLINE)

def task_events(recs, tool):
    """Collect timestamps of successful ask start/done/info/annotate/stop per (session, task id)."""
    events = defaultdict(lambda: defaultdict(list))
    for r in agents_of(recs, tool):
        root = r["root"] if tool != "pi" else r["path"]
        for a in r["ask"]:
            if a["sub"] in ("start", "done", "info", "annotate", "stop") and not a["err"]:
                m = re.match(r"([a-z0-9]{2,5})\b", a["args"])
                if m and a["ts"]:
                    events[(root, m.group(1))][a["sub"]].append(parse_ts(a["ts"]))
    return events


def task_cycle_stats(recs, tool):
    """Per-task cycle numbers for one tool: minutes start->done, and info/annotate calls per task."""
    durations, infos, annotations = [], [], []
    started = open_tasks = restarted = 0
    for ev in task_events(recs, tool).values():
        if ev["start"]:
            started += 1
            restarted += len(ev["start"]) > 1
            if ev["done"]:
                durations.append((max(ev["done"]) - min(ev["start"])) / 60)
            else:
                open_tasks += 1
        if ev["done"] or ev["start"]:
            infos.append(len(ev["info"]))
            annotations.append(len(ev["annotate"]))
    return dict(durations=durations, infos=infos, annotations=annotations,
                started=started, open=open_tasks, restarted=restarted)


# ---------------------------------------------------------------- HEADLINE

def skill_words(rel_path, cache={}):
    """Current word count of a skill file under SKILLS_DIR, or None if it is gone or not a file."""
    if rel_path not in cache:
        full = os.path.join(SKILLS_DIR, rel_path)
        try:
            with open(full, errors="replace") as fh:
                cache[rel_path] = len(fh.read().split())
        except (OSError, ValueError):
            cache[rel_path] = None
    return cache[rel_path]


def words_read_by(rec):
    """Words of skill .md files this agent read (each file once), skipping files that no longer exist."""
    counts = (skill_words(f) for f in rec["skill_files"] if f.endswith(".md"))
    return sum(c for c in counts if c)


def error_rate(agents):
    """Tool errors as a percentage of tool calls over a list of agents (None if no calls)."""
    calls = total(agents, "n_tool")
    return 100 * total(agents, "tool_errors") / calls if calls else None


def fmt(value, spec=".1f"):
    """Format a number, or n/a when it could not be computed."""
    return "n/a" if value is None else format(value, spec)


def headline_agent_tool(recs, tool):
    """HEADLINE lines for claude/codex: the numbers compared between runs."""
    subs = agents_of(recs, tool, True)
    ask_agents = agents_of(recs, tool)
    ask_agents = [r for r in ask_agents if r["ask"]]
    ask_subs = [r for r in subs if r["ask"]]
    words = [words_read_by(r) for r in ask_agents]
    worktree = [r for r in subs if "worktree" in (r.get("cwd") or "")]
    other = [r for r in subs if "worktree" not in (r.get("cwd") or "")]
    everyone = agents_of(recs, tool)
    done_ok = sum(1 for r in everyone for a in r["ask"] if a["sub"] == "done" and not a["err"])
    annotate = sum(1 for r in everyone for a in r["ask"] if a["sub"] == "annotate")
    info_sizes = [a["olen"] for r in everyone for a in r["ask"]
                  if a["sub"] == "info" and a.get("solo") and a["olen"] > 0]
    minutes = task_cycle_stats(recs, tool)["durations"]
    read_start = sum(1 for r in ask_subs if START_TASK_FILE in r["skill_files"])
    no_results = tool in NO_RESULT_TOOLS  # errors and durations cannot be measured for these
    return [
        (f"{tool} sub-agents", len(subs)),
        (f"{tool} skill words read per ask-using agent", fmt(sum(words) / len(words) if words else None, ".0f")),
        (f"{tool} share of ask-using sub-agents reading 2-start-task.md",
         fmt(read_start / len(ask_subs) if ask_subs else None, ".3f")),
        (f"{tool} tool error rate % worktree sub-agents", fmt(None if no_results else error_rate(worktree))),
        (f"{tool} tool error rate % other sub-agents", fmt(None if no_results else error_rate(other))),
        (f"{tool} sub-agents that ran ask done", sum(1 for r in subs if ran_ask_done(r))),
        (f"{tool} sub-agents that spawned agents", sum(1 for r in subs if r["spawns"])),
        (f"{tool} ask annotate per finished task", fmt(annotate / done_ok if done_ok else None, ".2f")),
        (f"{tool} median ask info output chars", fmt(median_or_none(info_sizes), ".0f")),
        (f"{tool} median minutes ask start to ask done", fmt(None if no_results else median_or_none(minutes), ".1f")),
    ]


def headline_new_commands(recs):
    """HEADLINE lines for the ask commands added in v0.45.0, across all tools.

    These show whether agents picked up the lighter workflow: parking instead
    of stopping, short re-reads, notes on stop/done, and the worker card.
    """
    calls = [a for r in recs for a in r["ask"]]
    infos = [a for a in calls if a["sub"] == "info"]
    stops = [a for a in calls if a["sub"] == "stop"]
    dones = [a for a in calls if a["sub"] == "done"]
    noted = lambda group: sum(1 for a in group if len(a["args"].split()) > 1)  # noqa: E731
    card_readers = sum(1 for r in recs if any("card-" in name for name in r["skill_files"]))
    return [
        ("all ask park calls", sum(1 for a in calls if a["sub"] == "park")),
        ("all share of ask info calls using last:",
         fmt(sum(1 for a in infos if "last:" in a["args"]) / len(infos) if infos else None, ".3f")),
        ("all share of ask stop calls with a note", fmt(noted(stops) / len(stops) if stops else None, ".3f")),
        ("all share of ask done calls with a note", fmt(noted(dones) / len(dones) if dones else None, ".3f")),
        ("all agents that read a card file", card_readers),
    ]


def headline_pi(recs):
    """HEADLINE lines for pi: sessions, annotate per finished task, share of commits using git add -A."""
    rs = agents_of(recs, "pi")
    done_ok = sum(1 for r in rs for a in r["ask"] if a["sub"] == "done" and not a["err"])
    annotate = sum(1 for r in rs for a in r["ask"] if a["sub"] == "annotate")
    commits = total(rs, "commits")
    return [
        ("pi sessions", len(rs)),
        ("pi ask annotate per finished task", fmt(annotate / done_ok if done_ok else None, ".2f")),
        ("pi share of commits using git add -A", fmt(total(rs, "add_all") / commits if commits else None, ".3f")),
    ]


def section_headline(recs, sessions):
    """HEADLINE: the comparison numbers, one `name: value` per line."""
    print("== HEADLINE")
    lines = headline_agent_tool(recs, "claude") + headline_agent_tool(recs, "codex") + headline_agent_tool(recs, "cursor") + headline_pi(recs) + headline_new_commands(recs)
    for name, value in lines:
        print(f"{name}: {value}")


# ---------------------------------------------------------------- detailed sections

def section_overview(recs, sessions):
    """Per tool: sessions, sub-agents, active hours, output tokens, compactions, ask calls."""
    print("\n== overview per tool")
    for t in TOOLS:
        ss = [s for s in sessions if s["tool"] == t]
        print(f"{t:7} sessions={len(ss):4} subagents={sum(s['subs'] for s in ss):5} "
              f"active_h={sum(s['active'] for s in ss):7.0f} main_active_h={sum(s['main_active'] for s in ss):6.0f} "
              f"out_Mtok={sum(s['out'] for s in ss) / 1e6:6.1f} compactions={sum(s['comp'] for s in ss)} "
              f"ask_calls={sum(s['nask'] for s in ss)}")


def section_skill_sessions(recs, sessions):
    """Root sessions in which any agent of the tree touched each skill."""
    print("\n== sessions using each skill (root sessions; any agent in the tree touched it)")
    for skill in ALL_SKILLS:
        print(f"{skill:26}", {t: sum(1 for s in sessions if s["tool"] == t and s["skills"].get(skill)) for t in TOOLS})
    print("ask used (any):", {t: sum(1 for s in sessions if s["tool"] == t and s["nask"]) for t in TOOLS})


def triple(sessions_in_class, key):
    """'median/p90/max' of one per-session field, formatted for the workflow-class table."""
    values = [s[key] for s in sessions_in_class]
    return f"{statistics.median(values):.1f}/{percentile(values, .9):.1f}/{max(values):.1f}"


def section_workflow_class(recs, sessions):
    """Per tool and workflow class: distribution of effort and counters per root session."""
    print("\n== per workflow class (median / p90 / max per root session)")
    for t in TOOLS:
        for cls in ("work-on-tasks", "next-auto-task", "audit", "tasks-other", "none"):
            ss = [s for s in sessions if s["tool"] == t and workflow_class(s) == cls]
            if not ss:
                continue
            err_pct = 100 * sum(s["terr"] for s in ss) / max(1, sum(s["ntool"] for s in ss))
            print(f"{t:6} {cls:15} n={len(ss):3} active_h={triple(ss, 'active')} subs={triple(ss, 'subs')} "
                  f"compactions(main)={triple(ss, 'main_comp')} human_msgs={triple(ss, 'human')} "
                  f"interrupts={sum(s['intr'] for s in ss)} out_Mtok={sum(s['out'] for s in ss) / 1e6:.1f} "
                  f"tests={sum(s['tests'] for s in ss)} full_suite={sum(s['tests_all'] for s in ss)} "
                  f"race={sum(s['race'] for s in ss)} commits={sum(s['commits'] for s in ss)} "
                  f"add_all={sum(s['addall'] for s in ss)} tool_err%={err_pct:.1f}")


def section_ask_usage(recs, sessions):
    """Calls and failing calls per ask subcommand, per tool."""
    print("\n== ask subcommand usage and error rate")
    for t in TOOLS:
        calls, errors = Counter(), Counter()
        for r in agents_of(recs, t):
            for a in r["ask"]:
                calls[a["sub"]] += 1
                errors[a["sub"]] += a["err"]
        print(t, "total", sum(calls.values()), "errors", sum(errors.values()))
        print("   ", ", ".join(f"{k}:{v}({errors[k]})" for k, v in calls.most_common(22)))


def error_cluster_key(output):
    """Reduce an ask error output to a short key: first error-looking line with ids masked."""
    m = re.search(r"(?im)^.*(error|usage|unknown|invalid|not found|no such|cannot|failed|ambiguous|blocked|already)[^\n]{0,110}", output)
    line = (m.group(0) if m else output[:90]).strip()
    return re.sub(r"\b[0-9a-f]{6,}\b|\b[a-z0-9]{3}\b(?=[ :\"'])", "X", line)[:120]


def section_ask_errors(recs, sessions):
    """Failing ask calls grouped by (subcommand, normalised error line), per tool."""
    print("\n== ask error outputs (clustered)")
    clusters = defaultdict(Counter)
    for r in recs:
        for a in r["ask"]:
            if a["err"]:
                clusters[r["tool"]][(a["sub"], error_cluster_key(a["out"]))] += 1
    for t in clusters:
        print(t)
        for (sub, key), count in clusters[t].most_common(18):
            print(f"  {count:4} ask {sub}: {key}")


def section_skill_files(recs, sessions):
    """Number of agents that read each core skill file (not raw read counts), per tool."""
    print("\n== skill files read (top), per tool")
    for t in TOOLS:
        readers = Counter()
        for r in agents_of(recs, t):
            for path in r["skill_files"]:
                if path.split("/")[0] in CORE:
                    readers[path] += 1
        print(t, readers.most_common(24))


def section_suites(recs, sessions):
    """Test, full-suite, -race, commit and `git add -A` counts for main vs sub-agents."""
    print("\n== who runs full suites / -race / git add -A (main vs sub-agent; worktree = cwd under a worktree)")
    for t in TOOLS:
        for sub in (False, True):
            rs = agents_of(recs, t, sub)
            if not rs:
                continue
            wt = [r for r in rs if r.get("cwd") and "worktree" in r["cwd"]]
            print(f"{t:6} sub={sub!s:5} agents={len(rs):4} tests={total(rs, 'go_test'):5} "
                  f"full_suite={total(rs, 'go_test_all'):4} race={total(rs, 'go_test_race'):4} "
                  f"commits={total(rs, 'commits'):4} add_all={total(rs, 'add_all'):3} "
                  f"(in worktree: agents={len(wt)} add_all={total(wt, 'add_all')}) pushes={total(rs, 'pushes')}")


def spawn_kind(name):
    """Bucket a sub-agent launch by the first keyword found in its task name."""
    name = (name or "").lower()
    for kind in ("review", "verif", "fix", "implement", "audit", "test", "research", "explor", "plan"):
        if kind in name:
            return kind
    return "other"


def review_round(name):
    """Round number encoded in a review sub-agent's name (1 when none is given)."""
    m = re.search(r"round[_ -]?(\d+)|r(\d)\b", (name or "").lower())
    return int(next(g for g in m.groups() if g)) if m else 1


def review_task_key(name):
    """Rough task key of a review launch, to count reviews per task."""
    cleaned = re.sub(r"review|round\d*|task", "", (name or "").lower())
    m = re.search(r"\b([a-z0-9]{3})\b", cleaned)
    return m.group(1) if m else name


def section_spawn_kinds(recs, sessions):
    """Sub-agent launches by kind, review rounds, reviews per task and prompt lengths."""
    print("\n== sub-agent launches by kind")
    for t in AGENT_TOOLS:
        kinds, rounds, per_task, prompt_lens = Counter(), Counter(), defaultdict(int), []
        for r in agents_of(recs, t):
            for s in r["spawns"]:
                kind = spawn_kind(s["name"])
                kinds[kind] += 1
                prompt_lens.append(s.get("plen") or 0)
                if kind == "review":
                    rounds[review_round(s["name"])] += 1
                    per_task[(r["root"], review_task_key(s["name"]))] += 1
        print(t, dict(kinds.most_common()), "review round numbers in names:", dict(sorted(rounds.items())))
        counts = list(per_task.values())
        if counts:
            print("   reviews per (session,task-ish key): median", statistics.median(counts), "p90", percentile(counts, .9),
                  "max", max(counts), " keys with >2 reviews:", sum(1 for x in counts if x > 2), "of", len(counts))
        if prompt_lens:
            print("   prompt length chars: median", statistics.median(prompt_lens), "p90", percentile(prompt_lens, .9),
                  "max", max(prompt_lens))
    iso = Counter((s.get("iso"), s.get("type")) for r in agents_of(recs, "claude") for s in r["spawns"])
    print("claude isolation/type:", iso.most_common(8))


def section_task_cycle(recs, sessions):
    """Time and effort per task between `ask start` and `ask done` within one root session."""
    print("\n== task cycle (ask start -> ask done within one root session)")
    for t in TOOLS:
        st = task_cycle_stats(recs, t)
        dur, infos, annos = st["durations"], st["infos"], st["annotations"]
        if not dur:
            continue
        print(f"{t:6} tasks started={st['started']} done-in-session={len(dur)} left-open={st['open']} "
              f"started>1x={st['restarted']} | minutes start->done median={statistics.median(dur):.0f} "
              f"p75={percentile(dur, .75):.0f} p90={percentile(dur, .9):.0f} max={max(dur):.0f} | per task: "
              f"info median={statistics.median(infos)} p90={percentile(infos, .9)} max={max(infos)}; "
              f"annotate median={statistics.median(annos)} p90={percentile(annos, .9)} max={max(annos)}")


def section_info_size(recs, sessions):
    """Size of `ask info` output (chars; codex ~tokens*4) and how often annotate args hit the 160 char cap."""
    print("\n== ask info output size (chars; codex ~tokens*4)")
    for t in TOOLS:
        asks = [a for r in agents_of(recs, t) for a in r["ask"]]
        sizes = [a["olen"] for a in asks if a["sub"] == "info" and a.get("solo") and a["olen"]]
        if sizes:
            print(f"{t:6} n={len(sizes)} median={statistics.median(sizes):.0f} p75={percentile(sizes, .75)} "
                  f"p90={percentile(sizes, .9)} p99={percentile(sizes, .99)} max={max(sizes)} "
                  f"total_Mchars={sum(sizes) / 1e6:.1f}")
        lens = [len(a["args"]) for a in asks if a["sub"] == "annotate"]
        if lens:
            print(f"       annotate args (capped at 160 chars) share at cap: {100 * sum(1 for x in lens if x >= 158) / len(lens):.0f}%")


def section_subagents(recs, sessions):
    """Sub-agent runtime, context size and ask/skill/commit behaviour, per tool."""
    print("\n== sub-agents")
    for t in AGENT_TOOLS:
        rs = agents_of(recs, t, True)
        active = [r["active_s"] / 60 for r in rs]
        ctx = [r["max_ctx"] for r in rs]
        print(f"{t:6} n={len(rs)} active_min median={statistics.median(active):.0f} p90={percentile(active, .9):.0f} "
              f"max={max(active):.0f} | compacted={sum(1 for r in rs if r['compactions'])} | "
              f"max_ctx median={statistics.median(ctx):.0f} p90={percentile(ctx, .9)} max={max(ctx)} | "
              f"used ask={sum(1 for r in rs if r['ask'])} "
              f"loaded ATM skill={sum(1 for r in rs if r['skills'].get('agent-task-management'))} "
              f"ran `ask done`={sum(1 for r in rs if ran_ask_done(r))} "
              f"spawned agents={sum(1 for r in rs if r['spawns'])} | no commit={sum(1 for r in rs if not r['commits'])}")


def section_orchestrators(recs, sessions):
    """Main sessions that launched sub-agents: polling, compactions and context size."""
    print("\n== orchestrator (main) polling and context")
    for t in AGENT_TOOLS:
        rs = [r for r in agents_of(recs, t, False) if r["spawns"]]
        print(f"{t:6} orchestrating mains={len(rs)} spawns={sum(len(r['spawns']) for r in rs)} "
              f"waits/sleeps={total(rs, 'waits')} compactions={total(rs, 'compactions')} "
              f"max_ctx p90={percentile([r['max_ctx'] for r in rs], .9)} "
              f"mains that ran tests themselves={sum(1 for r in rs if r['go_test'])} "
              f"mains with `ask done`={sum(1 for r in rs if ran_ask_done(r))}")


def section_models(recs, sessions):
    """Most used models per tool (assistant message counts)."""
    print("\n== models")
    for t in TOOLS:
        models = Counter()
        for r in agents_of(recs, t):
            for name, count in r["models"].items():
                models[name] += count
        print(t, models.most_common(10))


SECTIONS = [section_headline, section_overview, section_skill_sessions, section_workflow_class,
            section_ask_usage, section_ask_errors, section_skill_files, section_suites,
            section_spawn_kinds, section_task_cycle, section_info_size, section_subagents,
            section_orchestrators, section_models]


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "scan.jsonl"
    recs = load_records(path)
    sessions = build_sessions(recs)
    for section in SECTIONS:
        section(recs, sessions)


if __name__ == "__main__":
    main()
