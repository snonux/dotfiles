# Blocked tasks and handoffs

Read this when a task cannot continue, when you are about to ask the user a
question, or when you stop before a task is finished.

## Decide, park, or stop

1. **Decide it yourself** when the choice is reversible and inside the task's
   scope (a name, a default, a library already used in the project). Record
   it: `ask annotate <id> "Decision: <choice> because <reason>"`. If your
   instructions tell you to consult a reviewer or advisor sub-agent for such
   questions, an orchestrator or solo agent does that instead of asking the
   user. A launched worker never spawns agents: it decides, or parks.
2. **Park the task** when only a human can answer: an approval for a
   destructive or outward-facing action, a missing credential or device, or a
   requirement with two readings that lead to different products.

   ```bash
   ask park <id> "Which port should the service use: 8080 or the next free one?"
   ```

   `park` stops the task, hides it from `ask ready`, and records
   `Needs human: <question>`. Write the question so it can be answered in one
   line, and name the options. Then **continue with the next task**.
3. **Stop the run** only when every remaining task is parked or depends on a
   parked one, or when the user's stated limit is reached. Do not stop at the
   first parked task, and do not ask the user to pick a task.

When the user answers, record the answer and release the task:

```bash
ask annotate <id> "Answer: use 8080"
ask unpark <id>
```

`ask parked` lists every open question. Put that list in the final report.

A task that needs a change to a vendored or upstream dependency is a parked
task too: park it with the question "may I change <dependency>, or should
this become its own task?" Do not patch the dependency.

## Handoff when stopping unfinished

Agents are interrupted, run out of budget, or are replaced by another agent.
Whenever you stop before `ask done`, leave the state in one annotation:

```bash
ask stop <id> "Handoff: parser test is red (TestEmptyHeader); next: handle the empty-header case in parse.go; uncommitted: parse.go, parse_test.go"
```

The three parts are fixed: **state** (what works, what is red), **next**
(the one next step), **uncommitted** (files with changes not committed, or
"none"). Commit what is coherent first. The agent that resumes reads this
annotation with `ask info <id> last:3` and follows
[6-recover-stalled-task.md](6-recover-stalled-task.md) for the working tree.

If the budget is nearly used up, stop early enough to write the handoff. An
unfinished task with a handoff is cheap to resume; one without it has to be
re-investigated from the start.
