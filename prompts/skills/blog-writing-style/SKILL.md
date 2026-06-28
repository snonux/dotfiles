---
name: blog-writing-style
description: "De-LLM blog posts to sound authentically human. Rewrite text in .gmi.tpl and .gmi files to match the casual, personal style of older posts. Remove corporate/formal language, hedging, and over-explanation. Triggers on: de-llm, humanize text, fix writing style, blog style."
---

# Blog Writing Style (De-LLM)

Rewrite blog content to sound authentically human by removing LLM-generated patterns and matching the established voice from older posts (9+ months old). This skill humanizes text in `.gmi.tpl` template files and `.gmi` files that don't have a `.tpl` counterpart.

## When to Use

- Use when blog text sounds too formal, corporate, or LLM-generated
- Use when asked to "de-llm" or "humanize" blog content
- Use when reviewing writing style of foo.zone posts
- Use after composing or updating blog posts (reference from `compose-blog-post` and `update-blog-post` skills)
- **DRAFT files**: Apply more thoroughly - they typically have more LLM patterns than published posts

## Reference Files

Detailed reference documentation is in the `references/` subfolder:

- [Signs of AI Writing](references/signs-of-ai-writing.md) — the deep, general-purpose reference based on Wikipedia's "Signs of AI writing" page (WikiProject AI Cleanup). Voice calibration, personality/soul injection, the 29 numbered AI patterns (content, language, style, communication, filler/hedging) with before/after examples, the full worked example, and the standard process/output format. Use this when you need the exhaustive pattern catalog.
- [Patterns & Rewrite Examples](references/patterns-and-examples.md) — the foo.zone-focused working set: the LLM tells to hunt for (opening structures, corporate/marketing language, hedging, over-explanation, formal transitions, passive constructions, third-person distance) and concrete before/after rewrite pairs.
- [Gemtext Authoring Conventions](references/gemtext-conventions.md) — shared foo.zone gemtext rules (file rules, format constraints, post structure, TOC, links, images/diagrams, multi-part series). Used by this skill, `compose-blog-post`, and `update-blog-post`.

## Target Files

- All `*.gmi.tpl` files in `~/git/foo.zone-content/gemtext/gemfeed/`
- All `*.gmi` files that don't have a corresponding `.gmi.tpl` file
- Never modify `.gmi` files that have a `.gmi.tpl` counterpart (those are generated)
- **Note**: Standalone `.gmi` files are often older posts outside the target window and usually don't need changes

## Instructions

### 1. Read Reference Posts First

Read 2-3 posts from 9+ months ago to absorb the authentic voice. Look at files dated before the current month minus 9. Examples of good reference posts:

- `2021-09-12-keep-it-simple-and-stupid.gmi.tpl`
- `2022-09-30-after-a-bad-nights-sleep.gmi.tpl`
- `2022-12-24-ultrarelearning-java-my-takeaways.gmi.tpl`

### 2. Don't Over-Edit

**Important**: Many published posts already have a natural human voice. Before making changes:

- Read the post first to assess its current state
- If it already sounds conversational and personal, leave it alone
- Focus on posts with obvious LLM patterns (formal openings, hedging, over-explanation)
- Technical posts with code examples are often already well-written

### 3. Identify LLM Patterns to Remove

Rewrite text that contains the LLM tells cataloged in
[references/patterns-and-examples.md](references/patterns-and-examples.md)
(opening structures, corporate/marketing language, hedging, over-explanation,
formal transitions, passive constructions, third-person distance). For the
exhaustive 29-pattern catalog with before/after examples, see
[references/signs-of-ai-writing.md](references/signs-of-ai-writing.md).

### 4. Apply Human Writing Patterns

**Voice:**
- Use "I" for personal experience and opinion
- Use "you" when addressing the reader directly
- Use contractions: don't, it's, I'm, you'll, they're
- State opinions directly: "I think", "Honestly", "Kind of", "Pretty much"

**Sentence structure:**
- Break long sentences into shorter ones
- Use dashes (—) for emphasis and asides
- Parenthetical asides for casual comments
- Mix sentence lengths for rhythm

**Tone:**
- Conversational but not juvenile
- Personal anecdotes and experience
- Occasional humor where appropriate
- Direct statements without hedging
- "Anyway," "So," "By the way," for natural flow

**Practical examples:**
- Draw from personal experience
- Use specific details over generalizations
- Show, don't tell

Concrete before/after rewrite pairs are in
[references/patterns-and-examples.md](references/patterns-and-examples.md).

### 5. Gemtext Format Constraints

Gemtext has no Markdown bold/italic and a fixed post structure. Follow the
shared foo.zone conventions in
[references/gemtext-conventions.md](references/gemtext-conventions.md) (file
rules, format constraints, TOC, links, images/diagrams).

### 6. Preserve What Works

Do NOT change:
- Technical accuracy
- Code blocks and commands
- Links and URLs
- ASCII art
- The core information being conveyed
- Personal anecdotes that already sound human
- Direct quotes from sources (only rewrite your own commentary)

### 7. Process Each File

1. Read the target `.gmi.tpl` or standalone `.gmi` file
2. Identify sections that sound LLM-generated
3. Rewrite using human patterns
4. Preserve all technical content, links, code blocks
5. Show a diff before writing
6. Write the updated file

### 8. Related Skills

When using `compose-blog-post` or `update-blog-post`, apply this writing style proactively to ensure new content sounds human from the start. Reference this skill when writing or editing any blog content.

For the full Wikipedia-based pattern catalog (voice calibration, personality/soul, the 29 numbered AI patterns, and the complete worked example), see [references/signs-of-ai-writing.md](references/signs-of-ai-writing.md).