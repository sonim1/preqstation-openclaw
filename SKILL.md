---
name: preqstation
description: Execute Claude Code, Codex CLI, or Gemini CLI from OpenClaw when input starts with "preqstation:" using a strict prompt template and completion-summary output.
metadata: {"openclaw":{"requires":{"anyBins":["claude","codex","gemini"]}}}
---

# preqstation

Use this skill only when the user message starts with:

`preqstation: <detail>`

## Trigger condition

- Trigger only if the input starts with `preqstation:`.
- If the prefix is missing, do not run this skill.

## Detail format

Inside `<detail>`, require flags:

`engine=<claude|codex|gemini> cwd=<absolute-path> prompt="..." [task=<TASK-ID>]`

Required keys:

- `engine`
- `cwd`
- `prompt`

Optional key:

- `task`

Full command form:

`preqstation: engine=<claude|codex|gemini> cwd=<absolute-path> prompt="..." [task=<TASK-ID>]`

## Prompt rendering (required template)

Do not pass user prompt directly. Render it into this template:

```text
Task ID: <task or N/A>
User Objective: <prompt>
Execution Requirements:
1) Work only inside <cwd>.
2) Complete the requested work.
3) After completion, return a short completion summary.
```

## Engine commands

### Claude Code

```bash
claude --dangerously-skip-permissions -p "<rendered_prompt>"
```

### Codex CLI

```bash
codex exec --dangerously-bypass-approvals-and-sandbox "<rendered_prompt>"
```

### Gemini CLI

```bash
GEMINI_SANDBOX=false gemini -p "<rendered_prompt>"
```

## Output policy

Return only a short completion summary.

Success format:

`completed: <task or N/A> via <engine> at <cwd>`

Failure format:

`failed: <task or N/A> via <engine> at <cwd> - <short reason>`

Never paste raw stdout/stderr unless explicitly requested by the user.

## Scope boundaries

- OpenClaw handles messenger routing, auth, and webhook/channel behavior.
- This skill only defines local CLI execution behavior.
