---
name: blog-writing-style
description: De-LLM blog posts to sound authentically human. Rewrite text in .gmi.tpl and .gmi files to match the casual, personal style of older posts. Remove corporate/formal language, hedging, and over-explanation. Triggers on: de-llm, humanize text, fix writing style, blog style.
---

# Blog Writing Style (De-LLM)

Rewrite blog content to sound authentically human by removing LLM-generated patterns and matching the established voice from older posts (9+ months old). This skill humanizes text in `.gmi.tpl` template files and `.gmi` files that don't have a `.tpl` counterpart.

## When to Use

- Use when blog text sounds too formal, corporate, or LLM-generated
- Use when asked to "de-llm" or "humanize" blog content
- Use when reviewing writing style of foo.zone posts
- Use after composing or updating blog posts (reference from `compose-blog-post` and `update-blog-post` skills)
- **DRAFT files**: Apply more thoroughly - they typically have more LLM patterns than published posts

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

Rewrite text that contains these patterns:

**Opening structures:**
- "This [noun] [verb]..." → Start with action or personal observation
- "As a [role], you..." → Use direct "You" or "I" statements
- "In today's world..." → Cut entirely or rephrase

**Corporate/marketing language:**
- "robust", "vital", "ensuring", "leveraging", "enabling", "facilitating"
- "comprehensive", "seamless", "powerful", "efficient"
- Replace with simpler words or remove

**Hedging language:**
- "often", "typically", "can help", "may", "might"
- "tends to", "generally", "usually"
- Replace with definitive statements or personal experience

**Over-explanation:**
- Sentences explaining *why* something is useful after stating it
- Redundant clarifications
- Paragraphs that summarize what was just said
- Remove these entirely

**Formal transitions:**
- "Furthermore", "Additionally", "Moreover", "In conclusion"
- "It's worth noting that", "It's important to understand"
- Replace with conversational transitions or just cut

**Passive constructions:**
- "This can be achieved by..." → "You can do this by..."
- "It is recommended to..." → "I'd recommend..." or just state it directly

**Third-person distance:**
- "The author suggests..." → "Larson suggests..." or "The book says..."
- "One should consider..." → "You might consider..." or "I'd..."

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

### 5. Concrete Rewrite Examples

**Before (LLM):**
> "This blog post describes my hackathon efforts adding observability to X-RAG..."

**After (Human):**
> "This post describes my hackathon efforts adding observability to X-RAG..."

---

**Before (LLM):**
> "This thesis aims to make it easier for users to view distributed systems from a different perspective. Here, the viewpoint of an end user is not adopted; instead, the functional methods of protocols and their processes in distributed systems should be made comprehensible, while simultaneously making all relevant events of a distributed system transparent."

**After (Human):**
> "This thesis aims to make distributed systems easier to understand from a different angle. Instead of the end-user perspective, it focuses on the functional methods of protocols and their processes, making all relevant events of a distributed system transparent."

---

**Before (LLM):**
> "In the previous posts, I deployed applications to the k3s cluster using Helm charts and Justfiles—running `just install` or `just upgrade` to imperatively push changes to the cluster. While this approach works, it has several drawbacks:"

**After (Human):**
> "In previous posts, I deployed applications to the k3s cluster using Helm charts and Justfiles—running `just install` or `just upgrade` to imperatively push changes to the cluster. Works fine, but has some drawbacks:"

---

**Before (LLM):**
> "I especially made time available over the weekend to join his 3-day hackathon..."

**After (Human):**
> "I made time over the weekend to join his 3-day hackathon..."

---

**Before (LLM):**
> "It is insane how times have changed."

**After (Human):**
> "Times have changed."

---

**Before (LLM):**
> "Larson breaks down the role of a Staff Engineer into four main archetypes, which can help frame how you approach the role:"

**After (Human):**
> "Larson defines four archetypes. You'll probably recognize yourself in one (or a mix):"

---

**Before (LLM):**
> "As a Staff Engineer, influence is often more important than formal authority. You'll rarely have direct control over teams or projects but will need to drive outcomes by influencing peers, other teams, and leadership. It's about understanding how to persuade, align, and mentor others to achieve technical outcomes."

**After (Human):**
> "You won't have direct authority over most people or teams you work with. Influence is the actual tool here. You have to persuade, align, sometimes just nudge people in the right direction. No one reports to you, but you still need to drive outcomes."

---

**Before (LLM):**
> "Robust monitoring is vital to any infrastructure, especially one as distributed as mine. I've thought about a setup that ensures I'll always be aware of what's happening in my environment."

**After (Human):**
> "I want to know when stuff breaks (ideally before it breaks), so monitoring is a big part of the plan."

---

**Before (LLM):**
> "The Beelink S12 Pro with Intel N100 CPUs checks all the boxes for a k3s project: Compact, efficient, expandable, and affordable. Its compatibility with both Linux and FreeBSD makes it versatile for other use cases, whether as part of your cluster or as a standalone system."

**After (Human):**
> "Honestly, the Beelink S12 Pro with the N100 is kind of perfect for this — tiny, cheap, sips power, and runs both Linux and FreeBSD without drama. I'm pretty happy with it."

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
