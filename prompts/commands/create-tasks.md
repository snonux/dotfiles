 # /create-tasks

 **Description:**  
 Generate a comprehensive, written execution plan for a goal, save that plan to disk, and then create Taskwarrior tasks for all the steps involved. Each task should be small but self-contained and should link back to the overall plan.

 ---

 ## Parameters / Usage

 Invoke `/create-tasks` followed by a concise description of the goal or project you want to execute.

 - **Input**: A natural language description of what you want to achieve (e.g., "Set up continuous deployment for this repo", "Write and publish a blog post about X").
 - **Assumptions**: If information is missing but reasonably inferable, make sensible assumptions rather than asking lots of questions. Only ask questions if a decision is truly blocking.

 Example invocations:

 - `/create-tasks Set up GitHub Actions CI for this repo`
 - `/create-tasks Refactor the authentication module and add tests`

 ---

## Prompt

Use the `taskwarrior-task-management` skill for this entire workflow.

You are an assistant that, when invoked via `/create-tasks`, turns a high-level goal into a concrete written plan and corresponding Taskwarrior tasks.

 Follow this process carefully:

 1. **Understand the goal**
    - Read the user’s request and infer:
      - The overall objective
      - The likely scope and constraints
      - Any obvious sub-areas of work (e.g., "planning", "implementation", "testing", "documentation")
    - If something is truly blocking (e.g., you must know the deployment provider), ask **one concise clarification question**. Otherwise, proceed with reasonable assumptions and clearly note them in the plan.

 2. **Create a comprehensive written plan**
    - Produce a clear, structured plan in markdown, including:
      - A short summary of the goal
      - Assumptions and constraints
      - High-level phases
      - A numbered list of concrete steps for each phase
    - Steps should be:
      - Small but self-contained (each step is actionable and can be done in a focused work session)
      - Ordered logically with explicit dependencies
    - Choose a reasonable file path for the plan within the current project or notes context. Prefer something like:
      - `plan.md`, `PLAN.md`, or `plans/<short-name>-plan.md`
    - Write the plan to disk at that path (creating directories as needed).
    - At the top of the plan file, include:
      - The project/goal title
      - The date
      - The filesystem path of this plan (for easy linking from tasks).

 3. **Derive Taskwarrior tasks from the plan**
    - Parse the numbered steps in the plan.
    - For each step that represents a distinct unit of work, create a Taskwarrior task.
    - Design tasks so that:
      - Each task is small but self-contained.
      - Tasks that logically depend on others come later and (if appropriate) mention their dependency in the description or annotation.
    - For each task:
      - Use a concise, verb-first description (e.g., "Configure GitHub Actions workflow for tests").
      - Add meaningful tags (e.g., project name, area like `dev`, `docs`, `infra`).
      - Set a `project` field in Taskwarrior that reflects the goal (e.g., `timr.ci`, `blog.post_x`).
      - Add an annotation that links back to the plan file path, for example:  
        `"See overall plan: <relative/or/absolute/path/to/plan.md>"`.
    - Use the appropriate tooling/commands to create the tasks (e.g., `task add ...`) in the user’s Taskwarrior setup.

 4. **Keep steps and tasks small but self-contained**
    - Prefer more, smaller tasks over fewer, very large tasks, as long as each:
      - Has a clear outcome
      - Can be completed in a focused sitting
    - Avoid microscopic tasks that don’t stand alone (e.g., "open editor").

 5. **Summarize to the user**
    - After writing the plan and creating the tasks:
      - Show the plan file path.
      - List the Taskwarrior tasks you just created, including:
        - Description
        - Project
        - Tags
        - The annotation containing the link to the plan
    - Keep the summary concise but clear enough that the user can immediately see what was created.

 Always prioritize actually writing the plan to disk and creating real Taskwarrior tasks, not just describing what you would do.
