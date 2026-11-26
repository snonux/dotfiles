# Repository declutter (pass C, sub-step 5)

Checks the shape of the repository itself: what sits in the root, where
build outputs and runtime state land, and whether the docs are laid out so
that each fact has one home. Generalized from real tidy-up rounds: build
tool files scattered in the root, jars and binaries written next to the
sources, a stale test binary nobody referenced, test-run state files at the
top level, a 350-line README, and a finished PLAN.md that still claimed to
be the source of truth.

The [shared finding rules](report.md#shared-finding-rules) apply unchanged:
folder layout is an investigation signal, not a finding. A layout finding
needs a concrete cost, such as an artifact that can be committed by
accident, a clean target that leaves stale files behind, two docs that
disagree, or a contributor who cannot find the entry point. "Looks messy"
alone goes in **Advisory observations**.

## 1. Inventory the root

```sh
ls -A                                   # everything at the top level
git ls-files --others --exclude-standard # untracked, not ignored
git ls-files --others --ignored --exclude-standard --directory
git ls-files | awk -F/ 'NF==1' | wc -l  # tracked files directly in root
```

Sort every root entry into one of:

| Kind | Belongs in root? |
|---|---|
| Entry docs: README, LICENSE, CHANGELOG, AGENTS.md/CLAUDE.md, CONTRIBUTING | yes |
| Toolchain manifests: go.mod, package.json, Cargo.toml, .gitignore, CI config | yes (tool requires it) |
| Build-tool sources: many `Magefile*.go`, `*.mk`, task scripts | no, when the tool supports a subdir (`magefiles/`, `mk/`, `scripts/`) |
| Build outputs: binaries, jars, `*.test`, coverage files | no: one gitignored output dir (`bin/`, `build/`, `dist/`) |
| Runtime/test state: kubeconfigs, `*.state.json`, `*.log`, pid files | no: one hidden gitignored dir, or a temp dir |
| Stale leftovers nothing references | no: delete |
| Design/plan docs (PLAN.md, TODO.md, NOTES.md) | no, once the plan is done: split into `docs/` |

For each "no", grep the repo for the file name before judging it stale or
movable: `git grep -n '<name>'` across code, build scripts, CI, docs,
`.gitignore`, container ignore files and manifests.

## 2. Build outputs and state

Check, and file a finding only where the check fails with a cost:

- **Ignored:** every output and state file is gitignored, ideally by its
  directory rather than one pattern per file. Cost when not: accidental
  commits of binaries or credentials (a kubeconfig is a credential).
- **One place:** all build targets write to the same output dir. Cost when
  not: clean targets and ignore rules have to chase each file by name, and
  they drift.
- **Clean sweeps it:** the project's clean target (`make clean`,
  `mage clean`, `npm run clean`) removes every output it builds and keeps
  what must survive (vendored headers, signed release artifacts); its
  comment says which. Verify by running build, clean, then the inventory
  again.
- **Fresh-clone path works:** after clean (or on a fresh clone), the
  documented test command either builds what it needs or fails with a hint
  that names the right target. A hint naming the wrong target is a bug.
- **Stale artifacts:** an output nothing builds or reads any more is deleted.

### Hardcoded paths are the real cost of moving outputs

Before recommending a move, list every consumer of the current path:
test harness defaults (`../binary`), jar manifest `Class-Path`, "next to
the jar" lookups, container build contexts and ignore files, sudoers or
other privilege rules pinned to an absolute path, CI caches, docs.

Name these in the finding's remedy as the files to change. A pinned path is
a constraint to change on purpose, not a reason to keep clutter forever: an
earlier round kept binaries in the root because of a sudoers pin and test
defaults, and the owner asked for `bin/` the next day. Recommend the move
and list the pins it touches, unless a pin cannot be changed (a published
external contract).

## 3. Build-tool sources

When build targets are many root files (for example `Magefile.go` plus
`magefile_*.go`), check whether the tool supports a dedicated directory
(mage ≥ 1.9: `magefiles/`; once that dir exists mage ignores root
magefiles, so all of them move together). Keep build tags that hide the
files from normal `go build`/`go vet`, keep provenance headers, and confirm
targets still run with the working directory at the repo root.
Verify: the tool lists every target, and the full gate suite passes.

## 4. Documentation layout

- **Lean README:** a pitch, the general idea and architecture in a few
  sentences (one diagram at most), a status line, and an index into
  `docs/` grouped by audience (get started, use, understand, build and
  test). Detail sections in the README are a finding when they duplicate or
  contradict a doc in `docs/`, or when the README has grown past roughly
  100–150 lines of reference material.
- **One docs directory, named `docs/`:** a second one (`doc/`,
  `documentation/`, `wiki/`, docs scattered under `notes/`) is a finding
  when both hold prose docs, because readers and agents find one and miss
  the other, and new docs land in either. Merge into `docs/` and rewrite
  the links. Keep a differently named dir only when a tool requires that
  name (for example Go's `doc.go` files, which are not a directory, or a
  generator's fixed input path), and say why in the agent instructions.
- **One topic per file in `docs/`**, each linked from the README index.
- **Large docs disclose progressively:** a single doc of more than about
  600 lines is a finding when agents or readers are sent to it for one
  section, because loading it costs a large share of an agent's context
  and buries the part they need. Measure with
  `find docs -name '*.md' -exec wc -l {} + | sort -n | tail`, then for
  each large file the size of each section (headings outside code
  fences). The remedy keeps the file's path and turns it into an
  **index**: its intro, then a "Parts" list with one summary line per
  part and the sections that part holds, so an agent picks the part from
  the index alone. The sections move into a sibling folder named after
  the doc (`docs/testing.md` → `docs/testing/<part>.md`), one part per
  section or per group of small sections read together (not one file per
  15-line record). Each part opens with a "Part of" link back to its
  index. **Sub-folders by section:** a part still over the limit that
  has sub-sections becomes an index of its own the same way
  (`docs/testing/m4-acceptance.md` plus `docs/testing/m4-acceptance/`),
  recursively; a long section with no sub-headings gets headings at
  natural boundaries (step ranges, topic groups) before it is split,
  never a cut by line count. Keeping the old path as the index means
  every citation of the form `docs/x.md "Section"` or `docs/x.md #N`
  still resolves in one hop; for a numbered decision log, the index also
  lists every entry by number with the part that holds it. Script the
  split rather than doing it by hand, and verify: every original line
  lands in exactly one new file (only replaced tables of contents may
  drop), a part whose title is its old heading keeps its anchor, every
  `doc.md#anchor` link in the repo is rewritten to the part that now
  holds the anchor, links inside moved parts are rebased one directory
  deeper (keep trailing slashes), and the link check below passes with
  anchors, not only paths. Tests or tools that read a doc file (grep for
  `docs/` in test code) are consumers to update. Record the rule (the
  size limit, the index-plus-folder shape, where new content goes) in
  the agent instructions file so the next large doc is split the same
  way.
- **Finished plans retire:** a PLAN.md, roadmap or design doc whose work is
  done but which is still cited as the source of truth is a finding: split
  it into durable docs (decisions with their numbers kept, milestones with
  their headings kept so anchors survive, architecture, build, testing),
  rewrite every reference to it, and reword plan voice ("we will") into
  past-tense record.
- **A usage guide exists:** if users have to piece the workflow together
  from reference docs, file a task for a guide in `docs/guide/` with real
  commands and real output, plus example results (screenshots, sample
  output, an example rendered report) where the tool produces something
  visual.
- **Links resolve:** run the project's link checker, or
  `grep -o '](\([^)#]*\)' -r docs README.md` and test each path; after a
  doc split, also check each `#anchor` against the target's headings.

## 5. Keep it that way

The cheapest lever against clutter coming back is a written rule. When
the project has an agent instructions file (AGENTS.md, CLAUDE.md), check
that it states the layout: where outputs go, the lean-README rule, where
new docs go, the size limit past which a doc becomes an index plus parts, and that the layout decision is recorded where the project
records decisions. If clutter that an earlier tidy-up removed has come
back (`git log --diff-filter=D --name-only`, earlier `+codequality` tasks),
that is a repeat finding (pass C sub-step 4): the missing rule or check is
the remedy, for example a test that fails when the root gains an untracked
file, or a README line-count check.

## 6. Filing

Use the normal `+codequality` task format ([tasks.md](tasks.md)). Order
the declutter tasks so that each depends on the one before it:

1. Record the layout decision where the project keeps decisions, before
   any move (if the project has a decisions-first convention).
2. Move build-tool sources.
3. Move build outputs and state; update `.gitignore`, clean and every
   pinned consumer.
4. Delete stale artifacts.
5. Docs: retire finished plans, then slim the README, then split large
   docs into an index plus parts (sub-folders for oversized sections),
   then the guide (a guide written before the plan split and README cut
   has to be rewritten; one written before a doc split only needs its
   anchor links checked).
6. Add the "keep it that way" rule to the agent instructions file.

One task per move, not one per file. Each task names the consumers to
update and its verification: the inventory from §1 run again, the full
build/test gates, and the link check for docs tasks. The audit-closure
gate (§5 of SKILL.md) reruns the root inventory as part of its checks.
