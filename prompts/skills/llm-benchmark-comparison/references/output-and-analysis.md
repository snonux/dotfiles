# Output & Analysis Format

How to build the comparison table, write the analysis, and avoid the common
traps — steps 4–7 of the workflow plus anti-patterns and the target output
shape.

## Build the comparison table

Use this structure (markdown, copy-paste-ready):

```markdown
| | **Model A** | **Model B** | **Model C** |
|---|---|---|---|
| Lab | ... | ... | ... |
| Released | YYYY-MM-DD | ... | ... |
| Architecture | ... | ... | ... |
| Context | ... | ... | ... |
| Modalities | ... | ... | ... |
| License | ... | ... | ... |
| Input $/M (promo/std) | ... | ... | ... |
| Output $/M | ... | ... | ... |

| Benchmark | Model A | Model B | Model C | Notes |
|---|---:|---:|---:|---|
| SWE-Bench Pro | ... | ... | ... | ... |
| SWE-Bench Verified | ... | ... | ... | ... |
| Terminal-Bench 2.x | ... | ... | ... | ... |
| BrowseComp | ... | ... | ... | ... |
| HLE (w/ tools) | ... | ... | ... | ... |
| GPQA-Diamond | ... | ... | ... | ... |
| AIME 2026 | ... | ... | ... | ... |
| τ²-Bench Telecom | ... | ... | ... | ... |
| MCP-Atlas | ... | ... | ... | ... |
| AA Intelligence Index | ... | ... | ... | ... |
```

Right-align numeric columns (`---:`) so the digits line up. Round benchmark
percentages to one decimal. Keep the Notes column short — one phrase, not
a sentence.

## Write the analysis

After the table, include these sections in order:

1. **Quick reference** — a one-row-per-model summary table covering the
   "what is it" fields (lab, release, arch, context, modalities, license,
   price). Optional but useful when the user has 3+ models.
2. **Headline benchmark table** — the long table above.
3. **How to read this** — 4–8 bullets, each one a claim grounded in the
   numbers:
   - "Coding is effectively a tie at 58–59% on SWE-Bench Pro"
   - "K2.6 is the most battle-tested for long-horizon work (13-hour
     exchange-core rewrite, 5-day autonomous ops agent)"
   - "M3's pitch is cheap 1M context, GLM 5.1's is breadth, K2.6's is
     tool-use + reasoning"
4. **Cost reality check** — a per-task worked example. Standard
   workload: 500K input tokens + 100K output tokens. Compute
   `(0.5 × input_$/M) + (0.1 × output_$/M)` per model. Reference Claude
   Opus-class price as a baseline.
5. **Caveats** — required. Cover at least:
   - Vendor-published numbers (most are)
   - Harness / scaffold differences (Claude Code, Terminus, OpenHands,
     Mini-SWE-Agent) — same model scores differently across harnesses
   - Token usage differences (K2.6 uses ~2× K2.5 tokens; M3's 1M context
     costs more tokens per turn)
   - Open-weights claim status (M3 weights + technical report promised
     ~10 days post-launch, not day-one in June 2026)
   - Independent verification status
6. **Sources** — list the URLs you actually pulled from, not the
   search-results page.

## Anti-patterns to avoid

- **Don't average across benchmarks** ("average score 73%") — hides the
  shape. SWE-Bench Pro 58% and AIME 95% are not commensurable.
- **Don't quote vendor numbers without a harness caveat.** A 59% on
  SWE-Bench Pro run with Claude Code scaffolding is not the same as 59%
  with OpenHands.
- **Don't pick a "winner" unless the user asks.** The whole point of the
  comparison is that the right model depends on the workload: long
  context vs. low cost vs. best tool use vs. strongest reasoning.
- **Don't fabricate a score** to fill a cell. `n/a` is honest; "60%"
  invented is not.
- **Don't bury the cost.** Pricing is often the deciding factor for
  agentic workloads and usually changes the ranking entirely.
- **Don't ignore the "what the numbers hide" angle.** A Medium-style
  "I tested both on 15 real tasks" piece usually finds that the
  benchmark gap is much smaller than the practical gap (or vice versa).
  Worth citing at least one such piece per comparison.

## Output format

- Plain markdown, ready to paste.
- Tables first, prose after.
- One section per analysis point, no walls of text.
- Sources at the bottom as a bulleted URL list, not inline links (easier
  to copy and verify).

## Example output shape

A minimal good response is two tables + four short sections. A maximal
good response is two tables + five sections + sources. Anything longer
than that is padding.
