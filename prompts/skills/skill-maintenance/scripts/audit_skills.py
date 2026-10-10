#!/usr/bin/env python3
"""Sweep a skills collection for the mechanical findings in audit-checklist.md.

Usage:
    python3 audit_skills.py [SKILLS_DIR] [--extra DIR ...] [--gone NAME ...]

SKILLS_DIR defaults to the collection this script lives in. --extra adds
directories whose markdown files link into the collection (e.g. the commands
directory). --gone lists skill names that were renamed, folded or deleted, so
leftover mentions are reported.

Prints ERROR lines (spec violations, broken links) and WARN lines (judgment
calls), then a summary. Exits 1 when there is at least one ERROR.
"""
import argparse
import glob
import os
import re
import sys

SPEC_KEYS = {"name", "description", "license", "compatibility", "metadata",
             "allowed-tools", "disable-model-invocation"}
MAX_DESCRIPTION = 1024   # spec limit
SOFT_DESCRIPTION = 450   # collection target is ~300; warn well above it
MAX_SKILL_LINES = 500    # spec limit for SKILL.md
SOFT_SKILL_LINES = 200
SOFT_REFERENCE_LINES = 300
# Directories below the collection that are not skills (gitignored sync area).
SKIP_DIRS = {"synced"}
LINK = re.compile(r"\]\(([^)\s]+)\)")
TRIGGER = re.compile(r"\b(use when|use for|triggers?)\b", re.I)
# A top-level frontmatter value written as a plain (unquoted) YAML scalar.
PLAIN_VALUE = re.compile(r"^([A-Za-z-]+):[ \t]+([^\s\"'>|].*)$", re.M)
# What a strict YAML parser will not accept inside a plain scalar: ": " starts
# a nested mapping, " #" starts a comment, and a leading indicator character
# starts another node type altogether.
PLAIN_HAZARD = re.compile(r":\s|:$|\s#|^[\[\]{}&*!%@`,?#-]")


class Report:
    """Collects findings so the checks stay free of printing."""

    def __init__(self):
        self.errors, self.warnings = [], []

    def error(self, where, text):
        self.errors.append(f"ERROR {where}: {text}")

    def warn(self, where, text):
        self.warnings.append(f"WARN  {where}: {text}")


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def slug(heading):
    """GitHub-style anchor for a markdown heading line."""
    text = re.sub(r"^#+\s+", "", heading).strip().lower()
    return re.sub(r"[^\w\- ]", "", text).replace(" ", "-")


def split_frontmatter(text):
    """Return (frontmatter, body); frontmatter is None when missing."""
    if not text.startswith("---\n") or "\n---\n" not in text[4:]:
        return None, text
    front, body = text[4:].split("\n---\n", 1)
    return front, body


def description_of(front):
    """Flatten a plain, quoted or block-scalar description to one line."""
    match = re.search(r"^description:\s*(.*(?:\n[ \t]+.*)*)", front, re.M)
    if not match:
        return ""
    raw = re.sub(r"^[>|]-?\s*", "", match.group(1).strip())
    return re.sub(r"\s+", " ", raw).strip("\"'")


def unsafe_plain_values(front):
    """Keys whose unquoted value breaks a strict YAML parser.

    pi parses frontmatter with a real YAML library and drops the whole skill on
    a parse error ("Nested mappings are not allowed in compact mappings"),
    while Claude Code reads the same line leniently, so the breakage only shows
    up in pi. The usual culprit is a description with "Triggers on: ...".
    """
    return [key for key, value in PLAIN_VALUE.findall(front)
            if PLAIN_HAZARD.search(value.strip())]


def load_skills(root):
    """Map skill name -> dict(front, body, description, manual, lines)."""
    skills = {}
    for path in sorted(glob.glob(os.path.join(root, "*", "SKILL.md"))):
        name = os.path.basename(os.path.dirname(path))
        if name in SKIP_DIRS:
            continue
        text = read(path)
        front, body = split_frontmatter(text)
        skills[name] = {
            "path": path, "front": front, "body": body,
            "description": description_of(front or ""),
            "manual": bool(front and re.search(r"^disable-model-invocation:\s*true\s*$", front, re.M)),
            "lines": text.count("\n"),
        }
    return skills


def markdown_files(root, extra):
    files = []
    for path in glob.glob(os.path.join(root, "**", "*.md"), recursive=True):
        if os.path.relpath(path, root).split(os.sep)[0] not in SKIP_DIRS:
            files.append(path)
    for directory in extra:
        files += glob.glob(os.path.join(directory, "*.md"))
    return sorted(files)


def check_frontmatter(skills, report):
    for name, skill in skills.items():
        front, desc = skill["front"], skill["description"]
        if front is None:
            report.error(name, "SKILL.md has no frontmatter")
            continue
        declared = re.search(r"^name:\s*(.+)$", front, re.M)
        if not declared or declared.group(1).strip() != name:
            report.error(name, "frontmatter name does not match the directory")
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name) or len(name) > 64:
            report.error(name, "name must be lowercase a-z/0-9/hyphens, at most 64 chars")
        extra = set(re.findall(r"^([A-Za-z-]+):", front, re.M)) - SPEC_KEYS
        if extra:
            report.error(name, f"non-spec frontmatter keys {sorted(extra)} (move under metadata)")
        for key in unsafe_plain_values(front):
            report.error(name, f"{key} is an unquoted YAML value containing ': ', ' #' or a leading indicator; "
                               "wrap it in double quotes (pi fails to parse it and skips the skill)")
        if not desc:
            report.error(name, "no description (the skill will not load)")
        elif len(desc) > MAX_DESCRIPTION:
            report.error(name, f"description is {len(desc)} chars (limit {MAX_DESCRIPTION})")
        elif len(desc) > SOFT_DESCRIPTION and not skill["manual"]:
            # manual-only skills keep their description out of the context
            report.warn(name, f"description is {len(desc)} chars; say what/when/triggers, not the workflow")
        if desc and not TRIGGER.search(desc):
            report.warn(name, "description has no when-to-use or trigger wording")


def check_sizes(root, skills, report):
    for name, skill in skills.items():
        refs = glob.glob(os.path.join(root, name, "references", "**", "*.md"), recursive=True)
        if skill["lines"] > MAX_SKILL_LINES:
            report.error(name, f"SKILL.md is {skill['lines']} lines (limit {MAX_SKILL_LINES})")
        elif skill["lines"] > SOFT_SKILL_LINES:
            report.warn(name, f"SKILL.md is {skill['lines']} lines; consider moving detail to references/")
        for ref in refs:
            count = read(ref).count("\n")
            if count > SOFT_REFERENCE_LINES:
                report.warn(os.path.relpath(ref, root), f"{count} lines; consider splitting into sibling topic files")


def check_links(root, files, report):
    """Every relative link must resolve; anchors must match a heading."""
    for path in files:
        body = re.sub(r"```.*?```", "", read(path), flags=re.S)
        for match in LINK.finditer(body):
            target = match.group(1)
            if re.match(r"[a-z]+:", target):
                continue
            rel, _, anchor = target.partition("#")
            dest = os.path.normpath(os.path.join(os.path.dirname(path), rel)) if rel else path
            where = os.path.relpath(path, root)
            if not os.path.exists(dest):
                report.error(where, f"broken link {target}")
            elif anchor and dest.endswith(".md"):
                headings = {slug(line) for line in read(dest).split("\n") if re.match(r"#{1,6} ", line)}
                if anchor not in headings:
                    report.error(where, f"anchor not found {target}")


def check_reference_coverage(root, skills, report):
    """Reference and script files nobody links, and area topics missing from their index."""
    for name in skills:
        base = os.path.join(root, name)
        text = "".join(read(p) for p in glob.glob(os.path.join(base, "**", "*"), recursive=True)
                       if os.path.isfile(p) and p.endswith((".md", ".sh", ".py")))
        for sub in ("references", "scripts"):
            for path in glob.glob(os.path.join(base, sub, "**", "*"), recursive=True):
                if os.path.isfile(path) and os.path.basename(path) not in text:
                    report.warn(os.path.relpath(path, root), "not mentioned anywhere in its skill")
        for index in glob.glob(os.path.join(base, "references", "*.md")):
            area = os.path.basename(index)[:-3]
            index_text = read(index)
            for topic in glob.glob(os.path.join(base, "references", area, "*.md")):
                if f"({area}/{os.path.basename(topic)}" not in index_text:
                    report.error(os.path.relpath(topic, root), f"not listed in its area index references/{area}.md")


def check_duplication(root, skills, report):
    """SKILL.md lines repeated verbatim in the skill's own references."""
    for name, skill in skills.items():
        refs = "\n".join(read(p) for p in glob.glob(os.path.join(root, name, "references", "**", "*.md"), recursive=True))
        repeated = [line.strip() for line in skill["body"].split("\n")
                    if len(line.strip()) >= 60 and line.strip() in refs]
        if len(repeated) >= 3:
            report.warn(name, f"{len(repeated)} SKILL.md lines repeat its references, e.g. {repeated[0][:70]!r}")


def check_manual_only(root, skills, files, report):
    """The frontmatter flag and Codex policy file go together; callers link by path."""
    manual = {name for name, skill in skills.items() if skill["manual"]}
    for name in skills:
        policy = os.path.join(root, name, "agents", "openai.yaml")
        has_policy = os.path.exists(policy) and "allow_implicit_invocation: false" in read(policy)
        if (name in manual) != has_policy:
            report.error(name, "disable-model-invocation and agents/openai.yaml (allow_implicit_invocation: false) must both be set or both be absent")
    call = re.compile(r"\b(load|invoke|use)\b[^.]{0,40}\bskill\b|\bskill\b[^.]{0,40}\b(load|invoke)\b", re.I)
    for path in files:
        owner = os.path.relpath(path, root).split(os.sep)[0]
        for number, line in enumerate(read(path).split("\n"), 1):
            for name in manual - {owner}:
                named = re.search(r"(?<![\w/-])" + re.escape(name) + r"(?![\w/-])", line)
                if named and call.search(line) and f"{name}/" not in line:
                    report.warn(f"{os.path.relpath(path, root)}:{number}",
                                f"asks for manual-only skill '{name}' without a file path")


def check_gone(root, files, gone, report):
    for path in files:
        for number, line in enumerate(read(path).split("\n"), 1):
            for name in gone:
                if re.search(r"(?<![\w/.-])" + re.escape(name) + r"(?![\w.-])", line):
                    report.warn(f"{os.path.relpath(path, root)}:{number}", f"mentions removed skill '{name}'")


def summary(skills):
    manual = [s for s in skills.values() if s["manual"]]
    auto = sum(len(s["description"]) for s in skills.values() if not s["manual"])
    return (f"{len(skills)} skills, {len(manual)} manual-only; "
            f"auto-loaded description text: {auto} chars (~{auto // 4} tokens per session)")


def main():
    default_root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", default=default_root)
    parser.add_argument("--extra", nargs="*", default=[])
    parser.add_argument("--gone", nargs="*", default=[])
    args = parser.parse_args()
    if not os.path.isdir(args.root):
        sys.exit(f"not a directory: {args.root}")
    skills = load_skills(args.root)
    if not skills:
        sys.exit(f"no */SKILL.md found under {args.root}")
    files = markdown_files(args.root, args.extra)
    report = Report()
    check_frontmatter(skills, report)
    check_sizes(args.root, skills, report)
    check_links(args.root, files, report)
    check_reference_coverage(args.root, skills, report)
    check_duplication(args.root, skills, report)
    check_manual_only(args.root, skills, files, report)
    check_gone(args.root, files, args.gone, report)
    print("\n".join(report.errors + report.warnings))
    print(f"\n{len(report.errors)} errors, {len(report.warnings)} warnings. {summary(skills)}")
    sys.exit(1 if report.errors else 0)


if __name__ == "__main__":
    main()
