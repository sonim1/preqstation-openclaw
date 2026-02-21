---
name: preqstation
description: Run Claude Code, Codex CLI, or Gemini CLI from natural-language OpenClaw requests for PREQSTATION work.
metadata: {"openclaw":{"requires":{"anyBins":["claude","codex","gemini"]}}}
---

# preqstation

Use this skill for natural-language requests to execute PREQSTATION-related work with local CLI engines.

## Trigger condition

Trigger this skill when the user asks to:

- start, continue, or complete a PREQSTATION task
- run coding work in a project workspace
- use `claude`, `codex`, or `gemini` for implementation
- check progress/status of running engine sessions
- mentions `preq` or `preqstation` anywhere in the message (case-insensitive)

No fixed prefix is required.

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

5. `intent`
- if user asks "status", "progress", "what is running", or similar: run status query
- otherwise: run new async execution

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

## Prompt rendering (required template)

Do not forward raw user text directly. Render this template:

```text
Task ID: <task or N/A>
Project Key: <project key or N/A>
User Objective: <objective>
Execution Requirements:
1) Work only inside <cwd>.
2) Complete the requested work.
3) Start execution asynchronously in tmux.
4) Return a short start summary with tmux session info.
```

## Engine commands

### Claude Code

```bash
scripts/run-agent-async.sh claude "<cwd>" "<rendered_prompt>"
```

### Codex CLI

```bash
scripts/run-agent-async.sh codex "<cwd>" "<rendered_prompt>"
```

### Gemini CLI

```bash
scripts/run-agent-async.sh gemini "<cwd>" "<rendered_prompt>"
```

All engine executions must be asynchronous.

- do not wait for CLI completion in OpenClaw
- start work in a detached `tmux` session via `scripts/run-agent-async.sh`
- include `tmux -CC attach -t <session>` in the summary so the user can jump in immediately
- include log path from script output so users can inspect background execution

## Status query commands

For status/progress requests, use:

```bash
bash scripts/check-agent-status.sh
```

Optional filters:

```bash
bash scripts/check-agent-status.sh --session "<session>"
bash scripts/check-agent-status.sh --task "<KEY-123>"
bash scripts/check-agent-status.sh --all
```

## Output policy

Return only a short start summary.

Success format:

`started: <task or N/A> via <engine> at <cwd> (session: <session>, attach: tmux -CC attach -t <session>, log: <log_path>)`

Failure format:

`failed: <task or N/A> via <engine> at <cwd or N/A> - <short reason>`

Do not dump raw stdout/stderr unless user explicitly asks.

`scripts/run-agent-async.sh` log directory:

- default: `<cwd>/.openclaw-artifacts`
- override: `OPENCLAW_ARTIFACT_DIR`

Session index for status queries:

- default: `<skill-root>/.openclaw-artifacts/sessions.tsv`
- override: `OPENCLAW_INDEX_DIR`

## Scope boundaries

- OpenClaw handles messenger routing, auth, and channel/webhook behavior.
- This skill only defines local CLI execution behavior and MEMORY mapping usage.
