# Benchmark Catalog & Per-Model Fields

What to capture for each model, and what each benchmark actually measures.

## Per-model fields to capture

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
