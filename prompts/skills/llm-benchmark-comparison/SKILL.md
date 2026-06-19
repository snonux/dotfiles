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

## Reference Files

Detailed reference documentation is in the `references/` subfolder:

- [Search & Sourcing](references/search-and-sourcing.md) — search endpoints (DuckDuckGo HTML, Brave), per-model queries, the source trust order (vendor blog → HF model card → Artificial Analysis → pricing pages → independent reviews), and the raw source endpoint URLs. Covers workflow steps 2–3.
- [Benchmarks Catalog](references/benchmarks-catalog.md) — the per-model fields-to-capture table (where to find each one) and the 2026 benchmark glossary (SWE-Bench Pro/Verified, Terminal-Bench, BrowseComp, HLE, τ²-Bench, MCP-Atlas, GPQA-Diamond, AIME, AA Intelligence Index, AA-Omniscience, GDPval-AA Elo).
- [Output & Analysis](references/output-and-analysis.md) — the copy-paste comparison table structure, the ordered analysis sections (quick reference, headline table, how-to-read, cost reality check, caveats, sources), the anti-patterns to avoid, the output-format rules, and the target output shape. Covers workflow steps 4–7.

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

Use the search endpoints and per-model queries in
[references/search-and-sourcing.md](references/search-and-sourcing.md).
Prefer the HTML DuckDuckGo endpoint; Brave is the fallback.

### 3. Pull authoritative sources

Follow the source trust order and capture the per-model fields. The trust
order and source endpoints are in
[references/search-and-sourcing.md](references/search-and-sourcing.md); the
fields-to-capture table and benchmark glossary are in
[references/benchmarks-catalog.md](references/benchmarks-catalog.md). If a
number is missing after two passes, mark it `n/a` — do not invent.

### 4. Build the comparison table

Use the copy-paste-ready table structure and formatting rules in
[references/output-and-analysis.md](references/output-and-analysis.md).

### 5. Write the analysis

Include the ordered analysis sections (quick reference, headline table,
how-to-read, cost reality check, caveats, sources) from
[references/output-and-analysis.md](references/output-and-analysis.md).

### 6. Avoid the anti-patterns

Don't average scores, don't quote vendor numbers without a harness caveat,
don't pick a "winner" unless asked, don't fabricate scores, don't bury the
cost, don't ignore the "what the numbers hide" angle. Full list with
rationale in
[references/output-and-analysis.md](references/output-and-analysis.md).

### 7. Match the output format

Plain markdown, tables first, sources at the bottom. The output-format rules
and the target output shape (two tables + 4–5 short sections) are in
[references/output-and-analysis.md](references/output-and-analysis.md).
