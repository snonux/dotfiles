---
name: iq
description: "Consult or maintain the user's IQ knowledge database for personal routines, household, family, fitness and mind, or f3s homelab infrastructure (hosts, LAN/DHCP, WireGuard, storage, k3s and hosted services). Use when user-specific context from IQ is relevant or the user names IQ/f3s; do not load for unrelated generic questions."
---

# IQ knowledge database

Read `~/git/iq/AGENTS.md` first whenever this skill is selected, unless its
current contents have already been read in this conversation. It is the source
of truth for the database's navigation and maintenance conventions.

Follow progressive disclosure: root index → relevant topic index → needed leaf.
For infrastructure, use `topics/infra.md` → `infra/f3s.md` → one area → one topic.
Read additional files only when the task needs them; stop when the relevant
question is answered. Never preload the database, all area indexes, or unrelated
personal information. Use scoped search if the index does not identify a file.

Keep substantive knowledge in IQ, not in this loader skill. When updating it,
preserve dated evidence, distinguish intended changes from verified state,
update parent links, and run IQ's `./lint.sh`. Reading operational instructions
does not itself authorize deployment or configuration changes.

If the database is unavailable, report the missing path; do not silently use a
removed f3s skill or invent its contents.
