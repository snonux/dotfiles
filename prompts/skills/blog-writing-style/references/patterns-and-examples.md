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

## Concrete rewrite examples

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