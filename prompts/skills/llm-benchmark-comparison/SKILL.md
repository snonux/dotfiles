---
name: llm-benchmark-comparison
description: "Research and compare LLM model benchmarks (coding, agentic, reasoning, multimodal) across frontier and open-weight models. Produces a side-by-side comparison table with cost, context, modality, and per-benchmark scores; calls out ties, caveats, and 'what the numbers hide'. Use when asked to compare LLMs, benchmark models, rank models, or build a model-selection report. Triggers on: compare LLMs, LLM benchmark, model comparison, GPT vs Claude vs DeepSeek, which model is best, model leaderboard, SWE-Bench comparison, benchmark scores."
---

# LLM Benchmark Comparison

A repeatable workflow for turning "compare these LLMs" into a sourced,
side-by-side benchmark report. Output is a markdown table the user can paste
into a blog post, RFC, or procurement doc.

## When to Use

- The user names **two or more models** and wants them compared on
  benchmarks (e.g. "MiniMax M3 vs Kimi K2.6 vs GLM 5.1", "GPT-5.5 vs Claude
  Opus 4.7", "DeepSeek V4 vs Qwen3.7-Max").
- The user asks "which model is best at X" and you need to weigh multiple
  benchmarks.
- The user wants a model-selection report: benchmarks, pricing, context,
  license, modalities — in one table.

## Inputs

Resolve these before searching; if the user gave you a list of models, use
those. Otherwise ask which models to compare. Typical candidates from 2026:

- **Closed frontier:** Claude Opus 4.7, GPT-5.5, Gemini 3.1 Pro
- **Open-weight flagships (Chinese):** MiniMax M3, Kimi K2.6, GLM 5.1,
  DeepSeek V4, Qwen3.7-Max
- **Open-weight flagships (US):** Llama 4 Behemoth, Nemotron 3 Ultra

## Workflow

### 1. Identify the comparison set

Confirm the model names, including version suffixes. Many labs ship a new
point release every 1–3 months; `Kimi K2.6` is different from `Kimi K2.5` or
`Kimi K2 Thinking`. Get the exact release the user means.

### 2. Search the web for each model

Prefer the **HTML DuckDuckGo endpoint** (`https://html.duckduckgo.com/html/?q=…`)
because the JSON API and the JS site return empty in this environment. Brave
Search (`https://search.brave.com/search?q=…`) is a useful fallback. Bing
and Google both gate on CAPTCHA.

Useful per-model queries:

- `"<model>" benchmark scores`
- `"<model>" SWE-Bench Pro` (the de-facto coding test in 2026)
- `"<model>" pricing context window`
- `"<model>" site:huggingface.co` (model card)
- `"<model>" site:artificialanalysis.ai` (independent evals)
- `"<model>" review vs` (head-to-head pieces)

### 3. Pull authoritative sources

In this order of trust:

1. **Vendor blog / launch post** — gives headline numbers, but watch for
   cherry-picking and self-reported harnesses.
2. **Hugging Face model card** — usually has the most complete benchmark
   table; check the license, params, context.
3. **Artificial Analysis article** — independent evals (Intelligence
   Index, GDPval-AA Elo, AA-Omniscience hallucination rate).
4. **OpenRouter / LLM-Stats pricing pages** — current $/M token rates.
5. **Independent reviews** — Lushbinary, OfficeChai, Analytics India,
   Geeky Gadgets; useful for "what the numbers hide" and real-world
   anecdote.

For each model, capture:

| Field | Where to find it |
|---|---|
| Lab + release date | Vendor blog or HF model card |
| Architecture (dense/MoE, total/active params, attention type) | HF model card or technical report |
| Context window | Vendor page, often in the model card |
| Modalities | HF model card, README |
| License | HF model card (top of page) |
| **SWE-Bench Pro** | Almost always in launch blog |
| **SWE-Bench Verified** | Vendor blog, leaderboards |
| **Terminal-Bench 2.0 / 2.1** | Vendor blog, "agentic" tables |
| **BrowseComp** | Agentic browsing tests; check vendor and AA |
| **HLE (Humanity's Last Exam)** | With and without tools, often reported both |
| **GPQA-Diamond** | Reasoning benchmark; check leaderboards |
| **AIME 2026** | Math reasoning; check leaderboards |
| **τ²-Bench / τ²-Bench Telecom** | Tool-use / agentic |
| **MCP-Atlas** | Tool-use over MCP |
| **AA Intelligence Index** | artificialanalysis.ai |
| **AA-Omniscience hallucination** | artificialanalysis.ai |
| **Input $/M, Output $/M** | OpenRouter, vendor pricing page, LLM-Stats |

If a number is missing after two passes, mark it `n/a` — do not invent.

### 4. Build the comparison table

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

### 5. Write the analysis

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

### 6. Anti-patterns to avoid

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

### 7. Output format

- Plain markdown, ready to paste.
- Tables first, prose after.
- One section per analysis point, no walls of text.
- Sources at the bottom as a bulleted URL list, not inline links (easier
  to copy and verify).

## Quick benchmark glossary (2026)

- **SWE-Bench Pro** — Real GitHub issues, harder subset of SWE-Bench.
  Industry-standard coding test in 2026. Currently ~58% is the open-weight
  SOTA bar.
- **SWE-Bench Verified** — Human-verified easier subset. Top closed
  models hit 80%+.
- **Terminal-Bench 2.0 / 2.1** — Real command-line agent tasks.
- **BrowseComp** — Autonomous web browsing + information retrieval.
- **HLE (Humanity's Last Exam)** — Hardest reasoning benchmark; usually
  reported with and without tools.
- **τ²-Bench / τ²-Bench Telecom** — Tool-use in agentic loop, telecom
  domain.
- **MCP-Atlas** — Tool use over Model Context Protocol.
- **GPQA-Diamond** — Graduate-level science Q&A.
- **AIME** — Math competition problems.
- **AA Intelligence Index** — Composite index from Artificial Analysis
  combining many of the above; 54–57 is the current frontier band.
- **AA-Omniscience** — Hallucination + abstention metric; lower
  hallucination rate is better.
- **GDPval-AA Elo** — General agentic performance on knowledge-work
  tasks.

## Example output shape

A minimal good response is two tables + four short sections. A maximal
good response is two tables + five sections + sources. Anything longer
than that is padding.

## References

- `https://html.duckduckgo.com/html/?q=...` — primary search endpoint
- `https://search.brave.com/search?q=...` — fallback search
- `https://artificialanalysis.ai/articles/...` — independent evals
- `https://huggingface.co/<org>/<model>` — model cards
- `https://openrouter.ai/<provider>/<model>/benchmarks` — pricing +
  benchmarks in one place
- `https://llm-stats.com/home/models/<model>` — pricing + benchmark
  snapshot
