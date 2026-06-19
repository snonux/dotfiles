# Search & Sourcing

How to find the numbers and which sources to trust, for steps 2–3 of the
workflow.

## Search the web for each model

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

## Pull authoritative sources

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

See [benchmarks-catalog.md](benchmarks-catalog.md) for the full list of
fields to capture from these sources.

## Source endpoints

- `https://html.duckduckgo.com/html/?q=...` — primary search endpoint
- `https://search.brave.com/search?q=...` — fallback search
- `https://artificialanalysis.ai/articles/...` — independent evals
- `https://huggingface.co/<org>/<model>` — model cards
- `https://openrouter.ai/<provider>/<model>/benchmarks` — pricing +
  benchmarks in one place
- `https://llm-stats.com/home/models/<model>` — pricing + benchmark
  snapshot
