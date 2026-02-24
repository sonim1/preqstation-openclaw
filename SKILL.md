---
name: preqstation
description: "Delegate PREQSTATION coding tasks to Claude Code, Codex CLI, or Gemini CLI with PTY-safe execution (workdir + background + monitoring). Use when building, refactoring, or reviewing code in mapped workspaces. NOT for one-line edits or read-only inspection."
metadata: {"openclaw":{"requires":{"anyBins":["claude","codex","gemini"]}}}
---

# preqstation

Use this skill for natural-language requests to execute PREQSTATION-related work with local CLI engines.

## Trigger / NOT for

Trigger when the user asks to:

- start, continue, or complete a PREQSTATION task
- run coding work in a project workspace
- use `claude`, `codex`, or `gemini` for implementation
- mention `preq` or `preqstation` anywhere in the message (case-insensitive)

Do NOT use this skill for:

- simple one-line manual edits that can be handled directly
- read-only file inspection or explanation without execution
- any coding-agent launch inside `~/clawd/` or `~/.openclaw/`

For Codex routing reliability, start prompts with `$preqstation`.

## Codex Skill Routing (Important)

When using Codex, start the prompt with `$preqstation` to force this skill to activate.

Examples:

- `$preqstation preq: implement PROJ-1`
- `$preqstation /skill preqstation: implement the PROJ-27`

## Quick trigger examples

- `/skill preqstation: implement the PROJ-1`
- `preq: implement PROJ-1`

## Hard rules

1. Always run coding agents with `pty:true`.
2. Respect the engine the user requested. If unspecified, default to `claude`.
3. Do not kill sessions only because they are slow; poll/log first.
4. Never launch coding agents in `~/clawd/` or `~/.openclaw/`.
5. Never perform branch checkout or PR review inside live OpenClaw project paths (for example `~/Projects/openclaw/`).
6. PR review must run in a temp clone or git worktree, never in a live primary checkout.
7. Keep execution scoped to resolved `<cwd>` only.
8. Worktree branch names must include the resolved project key.

## Input interpretation

Parse from user message:

1. `engine`
- if explicitly provided: `claude`, `codex`, or `gemini`
- default: `claude`

2. `task`
- first token matching `<KEY>-<number>` (example: `PRJ-284`)
- optional

3. `cwd` (required to execute)
- if absolute path is explicitly provided, use it
- else resolve by `project` key from `MEMORY.md`
- else if task prefix key matches a `MEMORY.md` project key, use that path
- if unresolved, return a short failure asking for project key or absolute path

4. `objective`
- use the user request as the execution objective

## MEMORY.md resolution

- Read `MEMORY.md` from this repository root.
- Use the `Projects` table (`key | cwd | note`).
- Match project keys case-insensitively.
- If user asks to add/update project path mapping, update `MEMORY.md` first, then confirm.

## MEMORY.md update rules

- Keep mappings in the `Projects` table only.
- Add or update using this row format: `| <key> | <absolute-path> | <note> |`.
- Use one row per key. If a key already exists, replace that row.
- Always store absolute paths (no relative paths).

## Branch naming convention (project key based)

Use this format for worktree branches:

`codex/<project_key>/<task_or_purpose>`

Rules:

- `<project_key>` must be the resolved project key from `MEMORY.md`.
- Normalize `<project_key>` to lowercase and kebab-case.
- If task id exists, prefer task id for suffix (lowercased):
  - example: `codex/preq/prj-284`
- If no task id, use a short purpose slug:
  - example: `codex/preq/issue-101`

## Prompt rendering (required template)

Do not forward raw user text directly. Render this template:

```text
Task ID: <task or N/A>
Project Key: <project key or N/A>
User Objective: <objective>
Execution Requirements:
1) Work only inside <cwd>.
2) Complete the requested work.
3) After completion, return a short completion summary.
```

## Engine commands (current policy retained)

All engine commands must be launched via bash with PTY and explicit workdir.

### Claude Code

```bash
bash pty:true workdir:<cwd> command:"claude --dangerously-skip-permissions '<rendered_prompt>'"
```

### Codex CLI

```bash
bash pty:true workdir:<cwd> command:"codex exec --dangerously-bypass-approvals-and-sandbox '<rendered_prompt>'"
```

### Gemini CLI

```bash
bash pty:true workdir:<cwd> command:"GEMINI_SANDBOX=false gemini -p '<rendered_prompt>'"
```

## Bash execution interface (required)

Use bash with PTY and optional background mode.

### Bash parameters

| Parameter    | Type    | Required | Purpose |
| ------------ | ------- | -------- | ------- |
| `command`    | string  | yes      | Engine command to run |
| `pty`        | boolean | yes      | Must be `true` for coding-agent CLIs |
| `workdir`    | string  | yes      | Resolved `<cwd>` |
| `background` | boolean | no       | Run asynchronously and return session id |
| `timeout`    | number  | no       | Hard timeout in seconds |
| `elevated`   | boolean | no       | Host execution if policy allows |

### Process actions for background sessions

Use these actions as standard controls:

- `list`: list sessions
- `poll`: check running/done status
- `log`: read incremental output
- `write`: send raw stdin
- `submit`: send stdin + newline
- `kill`: terminate a session only when required

## Execution patterns (workdir + background + pty)

### One-shot example

```bash
bash pty:true workdir:<cwd> command:"codex exec --dangerously-bypass-approvals-and-sandbox '<rendered_prompt>'"
```

### Background example

```bash
bash pty:true workdir:<cwd> background:true command:"claude --dangerously-skip-permissions '<rendered_prompt>'"

process action:poll sessionId:<id>
process action:log sessionId:<id>
```

### If user input is required mid-run

```bash
process action:write sessionId:<id> data:"y"
process action:submit sessionId:<id> data:"yes"
```

## PR review safety pattern (temp dir/worktree only)

Never run PR review in live OpenClaw folders.

```bash
# temp clone review
REVIEW_DIR=$(mktemp -d)
git clone <repo> "$REVIEW_DIR"
cd "$REVIEW_DIR" && gh pr checkout <pr_number>
bash pty:true workdir:"$REVIEW_DIR" command:"codex review --base origin/main"

# or git worktree (project-key based branch naming)
git worktree add -b codex/<project_key>/pr-<pr_number>-review /tmp/<project_key>-pr-<pr_number>-review <base_branch>
bash pty:true workdir:/tmp/<project_key>-pr-<pr_number>-review command:"codex review --base <base_branch>"
```

## Parallel issue pattern (worktrees)

```bash
git worktree add -b codex/<project_key>/issue-101 /tmp/<project_key>-issue-101 main
git worktree add -b codex/<project_key>/issue-102 /tmp/<project_key>-issue-102 main

bash pty:true workdir:/tmp/<project_key>-issue-101 background:true command:"codex exec --dangerously-bypass-approvals-and-sandbox 'Fix issue #101. Commit after validation.'"
bash pty:true workdir:/tmp/<project_key>-issue-102 background:true command:"codex exec --dangerously-bypass-approvals-and-sandbox 'Fix issue #102. Commit after validation.'"

process action:list
process action:log sessionId:<id>
```

## Progress update policy

For background runs:

- Send one short start update (what is running, engine, and cwd).
- Send updates only when there is a meaningful state change:
  - milestone complete
  - engine asks for input
  - blocked/error requiring action
  - final completion summary
- If a session is terminated, immediately report that it was killed and why.

## Auto-notify on completion

For long-running jobs, append a completion trigger to the rendered prompt:

```text
When completely finished, run this command:
openclaw system event --text "Done: <brief summary>" --mode now
```

Example:

```bash
bash pty:true workdir:<cwd> background:true command:"codex exec --dangerously-bypass-approvals-and-sandbox '<rendered_prompt>

When completely finished, run:
openclaw system event --text \"Done: implemented requested PREQSTATION task\" --mode now'"
```

## Reload verification checklist

After editing this skill:

1. Trigger a message like `preqstation run PRJ-284`.
2. Confirm `preqstation` is selected and task parsing works.
3. Confirm PTY/background guidance is present in loaded behavior.
4. Confirm branch naming follows `codex/<project_key>/<...>`.
5. If changes do not appear, reload OpenClaw config/process and retry.

## Output policy

Return only a short completion summary.

Success format:

`completed: <task or N/A> via <engine> at <cwd>`

Failure format:

`failed: <task or N/A> via <engine> at <cwd or N/A> - <short reason>`

Do not dump raw stdout/stderr unless user explicitly asks.

## Scope boundaries

- OpenClaw handles messenger routing, auth, and channel/webhook behavior.
- This skill only defines local CLI execution behavior and MEMORY mapping usage.
