# DRY Across Skills

Apply the DRY principle to a *collection* of skills, not just within one file.
The goal: every piece of shared knowledge has exactly **one canonical home**;
other skills reference it, they do not re-derive it.

## Why DRY across skills matters

Skills are loaded on demand into the agent's context. When the same knowledge
(e.g. the Proton Bridge IMAP connect snippet, or the "be honest about what
actually ran" verification discipline) is copy-pasted into several skills, the
copies drift: one gets updated, the others don't. The agent then follows stale
instructions. A single canonical home + cross-links eliminates drift.

## Principles

1. **One canonical home.** Each piece of shared knowledge lives in exactly one
   skill (or one of its `references/`). That skill "owns" it.
2. **Cross-link, don't duplicate.** Consumers reference the owner via a
   relative path: `../owner-skill/SKILL.md` or
   `../owner-skill/references/x.md`.
3. **Declare prerequisites.** If skill B depends on skill A's knowledge, B's
   `SKILL.md` should state the prerequisite up front (e.g. "Prerequisites: the
   `protonbridge-imap` skill loaded for IMAP access").
4. **Keep skills self-contained where the dependency is loose.** The Agent
   Skills spec prefers self-contained skills. Only centralize when (a) the
   knowledge is genuinely shared by 2+ skills AND (b) it is stable enough that
   drift is a real risk. A one-line safety gotcha duplicated across two
   different-audience skills is fine to keep duplicated.
5. **Move, don't delete.** When extracting shared knowledge into a reference,
   the original skill must keep a pointer so nothing is lost.

## When to centralize vs. keep duplicated

| Situation | Action |
|-----------|--------|
| Stable canonical snippet reused by 2+ skills (e.g. IMAP connect code) | Centralize in the owning skill; consumers reference it. |
| General discipline referenced by a language skill + a process skill (e.g. verification honesty) | Centralize in the process/lifecycle skill (the authority); language skill keeps only its specifics + a link. |
| Shared format conventions used by 3 sibling skills (e.g. foo.zone gemtext rules) | One `references/conventions.md` in the natural owner; others link. |
| 1-2 line gotcha with different audiences (e.g. "audio CD capacity is time") | Keep duplicated — self-containment outweighs micro-DRY. |
| A skill re-inlines its *own* `references/` | Not a cross-skill issue — sub-divide (see [sub-division.md](sub-division.md)). |

## How to cross-link

Relative path from the referencing skill's `SKILL.md`:

```markdown
Connect as shown in the [`protonbridge-imap` skill](../protonbridge-imap/SKILL.md).
The general discipline lives in
[`agent-task-management`](../agent-task-management/references/verification-honesty.md).
Follow the conventions in [`gemtext-conventions.md`](../blog-writing-style/references/gemtext-conventions.md).
```

After editing, verify every cross-link target resolves:
`test -f ../sibling/SKILL.md && echo OK`.

## Conflict resolution

When two skills could each plausibly own a piece of shared knowledge, **do not
silently decide.** Surface the conflict to the user with a recommendation and
let them choose the owner. Criteria for the recommendation:

- The skill whose *purpose* most closely matches the knowledge owns it (e.g.
  task-lifecycle policy → `agent-task-management`; writing-style →
  `blog-writing-style`).
- Prefer the skill that already has a `references/` dir and is referenced by
  the others.
- Avoid making a "utility" skill the owner if an existing domain skill fits.

## Worked examples from this collection

- **Proton Bridge IMAP connect** → owned by `protonbridge-imap/SKILL.md`.
  `check-shopping-status/references/imap-scan-script.md` references it instead
  of re-deriving the STARTTLS/`ssl.CERT_NONE` connect block.
- **Verification honesty discipline** → owned by
  `agent-task-management/references/verification-honesty.md`.
  `go-best-practices/SKILL.md` keeps only the Go-specific actions (errcheck,
  CGO `bpf.h`, build tags, `-short`) and links to the general reference.
- **foo.zone gemtext conventions** → owned by
  `blog-writing-style/references/gemtext-conventions.md`.
  `compose-blog-post` and `update-blog-post` link to it instead of restating
  the structure/TOC/links/images/format rules.
- **f3s host table** → owned by `f3s/SKILL.md`.
  `rocky-vm-setup/references/overview.md` keeps only the rocky-VM-local view.