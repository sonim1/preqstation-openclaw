# preqstation-openclaw

OpenClaw skill package for running `claude`, `codex`, or `gemini` CLI with a fixed execution template.

This repository is skill-only. It does not ship HTTP servers, webhook handlers, or messenger integration code.

## OpenClaw skill usage

Input format (flags):

`engine=<claude|codex|gemini> cwd=<absolute-path> prompt="..." [task=<TASK-ID>]`

Examples:

1. `engine=claude cwd=/Users/me/projects/app task=PRJ-284 prompt="implement API pagination and update tests"`
2. `engine=codex cwd=/Users/me/projects/app prompt="fix failing lint and commit minimal patch"`
3. `engine=gemini cwd=/Users/me/projects/docs task=DOC-12 prompt="rewrite README intro in concise technical tone"`
4. `engine=claude cwd=/Users/me/projects/mobile prompt="triage crash and add regression test"`
5. `engine=codex cwd=/Users/me/projects/platform task=OPS-7 prompt="add healthcheck and verify deployment config"`

## Expected output

Success:

`completed: <task or N/A> via <engine> at <cwd>`

Failure:

`failed: <task or N/A> via <engine> at <cwd> - <short reason>`

## ClawHub import

Use GitHub import with this repository URL:

`https://github.com/sonim1/preqstation-openclaw`

ClawHub should detect `SKILL.md` from repository root.

## Responsibility boundary

- OpenClaw: messenger routing, permissions, webhook/channel integration
- This repo: CLI execution instructions and prompt template only
