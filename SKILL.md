---
name: preqstation-dispatch
description: "Dispatch PREQSTATION coding tasks from OpenClaw to Claude Code, Codex CLI, or Gemini CLI with PTY-safe execution (workdir + background + monitoring). Use when building, refactoring, or reviewing code in mapped workspaces. NOT for one-line edits or read-only inspection."
metadata: {"openclaw":{"requires":{"anyBins":["claude","codex","gemini"]}}}
---

# preqstation-dispatch

Execute PREQSTATION tasks with local CLI engines.

## Trigger / NOT for

Trigger when message contains: /skill preqstation-dispatch, !/skill preqstation-dispatch, preqstation, preq

Note: Telegram channels use ! prefix instead of / (e.g. !/skill preqstation-dispatch implement PROJ-1). Treat !/skill identically to /skill.

Do NOT use for: one-line edits, read-only inspection, launches inside ~/clawd/ or ~/.openclaw/.

## Hard rules

1. Always pty:true + background:true (foreground only if user explicitly asks).
2. Respect requested engine; default claude.
3. Never launch in ~/clawd/, ~/.openclaw/, or primary checkout paths.
4. Always create a git worktree before launching; scope execution to worktree only.
5. Worktree branch names must include the resolved project key.
6. Run preflight checks (command -v git, command -v <engine>) before launch.
7. Use dangerously-* / sandbox-disable flags only in resolved task worktrees.
8. Planning/read-only requests: do not launch engine commands.

## Input interpretation

Parse from user message:

1. engine — claude | codex | gemini (default: claude)
2. task — first token matching <KEY>-<number> (e.g. PRJ-284)
3. branch_name — parse from branch_name=<value> or branch=<value>; normalize lowercase, replace whitespace with -; if missing project_key prefix with preqstation/<project_key>/
4. project_cwd — absolute path from message, or resolve from OpenClaw agent memory by project key. Use `MEMORY.md` in this repo only as a sample format reference. If unresolved, ask the user for the absolute path and save the confirmed mapping to agent memory.
5. objective — user request as execution objective
6. cwd — worktree path: <worktree_root>/<project_key>/<branch_slug>
7. progress_mode — sparse (default) or live (if user says live/realtime/detailed)

## MEMORY.md

- Treat `MEMORY.md` in this repo as an example schema, not the user's live registry.
- Use OpenClaw agent memory for actual project key -> cwd mappings.
- Match project keys by exact match only (case-insensitive).
- Task prefix = candidate key (e.g. PROS-102 → pros).
- If a mapping is missing or unresolved: ask the user for the absolute path. Once confirmed, save it to agent memory, then continue.
- Sample format: | <key> | <absolute-path-or-TBD> | <note> |, one row per key, lowercase kebab-case.

## Worktree-first execution

1. Branch name: parsed branch_name → fallback preqstation/<project_key>. Reject unsafe names (.., leading /).
2. Worktree path: <worktree_root>/<project_key>/<branch_slug> (slug = branch with / → -).
3. Create: git -C <project_cwd> worktree add -b <branch_name> <cwd> HEAD (or without -b for existing branch).

## Prompt template

Do not forward raw user text. Render this template with <cwd> as the worktree path.

**Hard rule (prompt transport):** Always render the prompt into a file inside the worktree (e.g. `<cwd>/.preqstation-prompt.txt`) and pass it to the engine by reading the file contents. Do NOT pass multi-line prompts directly as shell argv, because CRLF / special characters / length can cause silent failures.

`text
Task ID: <task or N/A>
Project Key: <project key or N/A>
Branch Name: <branch_name or N/A>
Lifecycle Skill: preqstation (use preq_* MCP tools for task lifecycle)
User Objective: <objective>

Execution Requirements:
1) Work only inside <cwd>.
2) Use branch <branch_name> for commits/pushes when provided.
3) Use the preqstation lifecycle skill as the single source of truth for PREQ task rules, status transitions, deploy handling, and preq_* tool usage. Do not restate or override that workflow here.
4) Worktree cleanup after all work:
   git -C <project_cwd> worktree remove <cwd> --force
   git -C <project_cwd> worktree prune
5) When finished: openclaw system event --text "Done: <brief summary>" --mode now

## Engine commands

bash
# Claude Code
bash pty:true workdir:<cwd> background:true command:"claude --dangerously-skip-permissions '<rendered_prompt>'"

# Codex CLI
bash pty:true workdir:<cwd> background:true command:"codex exec --dangerously-bypass-approvals-and-sandbox '<rendered_prompt>'"

# Gemini CLI
bash pty:true workdir:<cwd> background:true command:"GEMINI_SANDBOX=false gemini -p '<rendered_prompt>'"
`

PR review: always in worktree, never primary checkout.

## Output

- Progress: update on state change only (start, milestone, error, completion). Live mode adds heartbeat.
- Success: `completed: <task or N/A> via <engine> at <cwd>`
- Failure: `failed: <task or N/A> via <engine> at <cwd or N/A> - <short reason>`
```
