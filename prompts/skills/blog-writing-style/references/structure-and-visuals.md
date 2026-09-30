# Structure, Readability and Visuals

Rules from reviewing long technical posts (first applied to the 2026 "running
my own LLMs" draft). They go beyond de-LLMing: the reader has to be able to
follow the post from top to bottom.

## Order: every paragraph builds on the previous one

- Explain a concept before the first section that relies on it. Example: explain
  prefill, decode and the KV cache before the section that shows engine logs
  with "KV cache usage" and "prefix cache hit rate".
- Only a short glossary is allowed to name things ahead of time. It has to say
  where each term gets explained ("covered in X below").
- Group the post by the reader's mental model, not by the order things were
  written. For a client/server setup, a good order is: setup overview →
  glossary → how the server side works → server config/models → inspecting the
  server → client/harness side → measured numbers → costs → wrap-up.
- After moving sections, fix every "above", "below", "further down" and "more on
  that later". They go stale when sections move.
- Introduce a component before you use its name in passing (e.g. say what the
  harness is before "the harness sends ...").
- When the same explanation shows up in two places, keep it where it fits the
  flow best and point to it from the other place.

## Keep the intro short: ToC early

- Only a short hook goes before the table of contents: one or two paragraphs
  (what this is, what the post covers), the key back-link, and the hero image.
  Then `<< template::inline::toc`.
- Motivation, background, related reading and link blocks go after the ToC,
  under their own first `##` section (e.g. "Why rent instead of buy").

## Bullet lists: short items, details go into sub-sections

- A bullet is one or two short sentences. If it grows into a paragraph, cut it
  to its core and move the explanation into its own `###` sub-section right
  after the list (or into the later section that covers the topic).
- A glossary bullet names the term and what it means for the reader. The "how
  it works" part belongs in the body.
- Don't write label-colon essays ("X — long explanation with three clauses;
  another clause ..."). Split them.

## Explaining concepts to a human reader

- Define abbreviations and jargon on first use: FP8, AWQ, QAT, MoE, KV cache,
  system prompt, harness, MCP, etc. One sentence is enough.
- Name the two sides of a split explicitly when readers tend to mix them up
  (e.g. LLM vs harness, command vs skill). A short two-item list plus one
  paragraph on why the difference matters works well.
- Prefer real captured data over made-up examples. If a protocol example can
  be captured for real (e.g. an actual API request/response), use the real one
  and say so ("the real, trimmed response").
- Check the arithmetic in cost/performance sections (monthly totals, per-token
  math, percentages), and make sure conclusions in the wrap-up don't
  contradict the numbers earlier in the post.
- Flag claims you can't verify instead of silently rewriting them into
  something the author didn't measure.

## Diagrams: prefer real diagrams over ASCII boxes

- For explanatory diagrams (architecture, request timelines, caching, memory
  budgets, comparisons, benchmark tables), prefer a real SVG image over an
  ASCII box diagram or a text table. Store it in the post's asset folder and
  link it with `=> ./slug/name.svg Description`.
- Existing ASCII *art* (decorative pictures) stays as is.
- Charts: follow the `dataviz` skill (validated palette, one axis, direct
  labels, legend for ≥2 series). Add a `prefers-color-scheme: dark` block
  inside the SVG so it looks right in both themes.
- Render every SVG (e.g. headless Chrome `--screenshot`) and look at it before
  linking it: overlapping labels, grid lines drawn over bars, and cut-off
  bottoms are the usual bugs.
- Keep a number in the prose when the text refers to it; the chart is not a
  replacement for the sentence that makes the point.

## Screenshots vs text output

- Plain command output (`docker ps`, `ssh`, log lines, `curl` responses) stays
  as text in a code block. Readers can copy and search it.
- TUIs, colored dashboards and table-heavy full-screen apps get a real
  screenshot instead (coding agents, `watch`-style dashboards, `htop`-like
  tools). Don't duplicate the screenshot as a text block.
- Take real screenshots of real sessions. A way to do it headless on Linux:
  run the app in a detached tmux session, then screenshot a kitty window
  attached to it inside Xvfb:
  `xvfb-run -a -s "-screen 0 1800x1200x24" bash -c 'unset WAYLAND_DISPLAY; kitty -o linux_display_server=x11 tmux attach -r -t NAME & sleep 6; import -window root -trim out.png'`
  Turn off the tmux status bar (`tmux set -t NAME status off`) so it doesn't
  show unrelated info, and run the demo from a short path (e.g. `~/demo`), not
  a long temp path. Resize to ~1200px wide.
- A screenshot caption says what is on it and why it matters, not just the
  name of the tool.
- If a screenshot needs paid infrastructure to be running (e.g. a GPU VM), ask
  first, keep it short, and tear it down right after.
