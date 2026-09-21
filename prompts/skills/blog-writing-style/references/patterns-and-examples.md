# LLM Patterns to Remove (foo.zone working set)

The foo.zone-focused catalog of LLM tells to hunt for. For the exhaustive
29-pattern catalog with voice calibration and the full worked example, see
[signs-of-ai-writing.md](signs-of-ai-writing.md).

## Opening structures
- "This [noun] [verb]..." → Start with action or personal observation
- "As a [role], you..." → Use direct "You" or "I" statements
- "In today's world..." → Cut entirely or rephrase

## Corporate/marketing language
- "robust", "vital", "ensuring", "leveraging", "enabling", "facilitating"
- "comprehensive", "seamless", "powerful", "efficient"
- Replace with simpler words or remove

## Hedging language
- "often", "typically", "can help", "may", "might"
- "tends to", "generally", "usually"
- Replace with definitive statements or personal experience

## Over-explanation
- Sentences explaining *why* something is useful after stating it
- Redundant clarifications
- Paragraphs that summarize what was just said
- Remove these entirely

## Formal transitions
- "Furthermore", "Additionally", "Moreover", "In conclusion"
- "It's worth noting that", "It's important to understand"
- Replace with conversational transitions or just cut

## Passive constructions
- "This can be achieved by..." → "You can do this by..."
- "It is recommended to..." → "I'd recommend..." or just state it directly

## Third-person distance
- "The author suggests..." → "Larson suggests..." or "The book says..."
- "One should consider..." → "You might consider..." or "I'd..."

## Tells found in the 2026 retrospective audit

A full pass over all posts (Fable reviewers, 2026-09) turned up more patterns than the list above. Most were in posts from 2023 onwards.

### Series-opener puffery
Openers of multi-part series and "casual" LLM drafts: "ever-evolving universe", "Let's dive in", "Navigating the Nexus", "guiding light through tricky waters", "ongoing journey", "where the magic begins", "Trust me on this one", "your ticket to...". Cut the opener and start with what you did or what you think.

### Fake-casual register
"First off", "Plus,", "super important", "gonna" layered over the classic tells (rule-of-four lists, em-dash asides, "it's not just about X"). This is the LLM imitating a casual voice. The real casual voice has a concrete detail somewhere; if a paragraph has no anecdote, no number, and no name, it is suspect.

### Em dashes, "actually" and fragment punchlines
- Em-dash density: more than one or two per screen is a tell. Use a comma, parentheses, or a new sentence. (The blog uses ASCII text otherwise, so curly quotes and apostrophes in one paragraph are a giveaway for pasted LLM output.)
- "actually" repeated many times in one post.
- Fragment punchlines: "Would I recommend it? No. Is it charming? Absolutely." and stacked rhetorical questions.
- A conclusion stated three or four times in different words. Say it once.

### Label-colon bullet lists and Markdown leftovers
- Bullets shaped as "Label: description", especially "Benefits of X", "Key features", "Key principles". Turn them into a sentence or two.
- `**bold**`, `_italic_`, and Markdown tables never render in gemtext. Remove them (they are also a sign of LLM output that was pasted in unchanged).

### Report skeletons
LLM-generated sections named: Introduction / Architecture Overview / Key Features / Benefits Realized / Challenges and Solutions / Lessons Learned / Future Explorations / Summary. Real posts use plain headings that name the actual thing ("Request flow", "Why WireGuard").

### Agent completion reports
Text that reads like the summary an agent prints after a task: subjectless "Created X. Applied Y. Updated Z.", a 50-line inventory of dashboard panels, "Key Metrics to Monitor". Say what you did in the first person and mention only the two or three items a reader cares about.

### Explainer paragraphs under links
In list-of-links posts (Random Weird Things, project lists) the author writes a terse joke or one-line teaser per link. Encyclopedia paragraphs added under each link ("showcases Perl's flexibility, thus confirming its Turing completeness") and product blurbs ("powerful", "seamless") are LLM-generated. Shorten to one line or delete.

### Justification tails on release notes
Release-note bullets that each end in "Useful because..." or "Useful when...". State what changed. The reader can decide whether it is useful.

### Vendor-pitch paragraphs
Whole paragraphs that read like documentation marketing: the WireGuard pitch, "Benefits of dual-stack", step-by-step tap-the-toggle walkthroughs for a phone. If it could be copy-pasted from the project's landing page, cut it or link to it.

### Book notes
Highlights and quotes are verbatim, do not rewrite them. But watch for a polished self-help preamble at the top of each section that the raw notes below then repeat, and for prose paragraphs that read like an LLM chapter condensation ("crucial", "vital", "invaluable", "fosters", "a new era"). Delete the duplicates; keep the author's raw notes.

### Consistency errors LLM edits leave behind
When cleaning a post, also look for these. They were all found in the audit:
- Fabricated details: a made-up sign-off email address; check it against the address the other posts use.
- Leaked tooling artifacts: "(line 215)", "From notes: ...", a stray `&lt;nil&gt;`.
- A cross-reference to the wrong part number in a series ("Part 5" where the storage post is Part 6).
- A post that contradicts itself (which component was the bottleneck) after several edit rounds.
- Corrupted source lines (a word split by 68 spaces) and stray `*` characters.

### Old posts with new insertions
Posts before Dec 2022 predate ChatGPT and are human by definition. Their clumsy English and German-isms are the author's voice, not tells. But old posts can get LLM-written paragraphs added later (a GarminOS paragraph appeared in a 2022 post in 2026 commits). For an old post, check `git log -p` for recent prose edits, and only flag those.

## Concrete rewrite examples

**Before (LLM):**
> "First off, a healthy on-call rotation is about more than just handling incidents. It's about creating a supportive ecosystem. This means cutting down on pain points, offering mentorship, quickly iterating on processes, and making sure engineers have the right tools. But there's a catch—engineers need to be willing to learn."

**After (Human):**
> "A healthy on-call rotation is more than handling incidents. It needs mentorship, fewer pain points, processes that get fixed quickly, and the right tools. But engineers also need to be willing to learn."

---

**Before (LLM):**
> "Deploying a simple IPv6/IPv4 connectivity test application to the f3s Kubernetes cluster. It displays visitors' IP addresses and tells them whether they're connecting via IPv6 or IPv4—useful for testing dual-stack connectivity."

**After (Human):**
> "I deployed a small IPv6/IPv4 test page to the f3s cluster. It shows you your IP address and whether you came in over IPv6 or IPv4, which is handy for checking dual-stack connectivity."

---

**Before (LLM):**
> "Getting new team members ready for on-call duties is super important for keeping systems reliable and efficient. This means giving them the knowledge, tools, and support they need to handle incidents with confidence."

**After (Human):**
> "New team members need proper onboarding before they go on-call. Shadowing an experienced on-call engineer for a while helps a lot."

---

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