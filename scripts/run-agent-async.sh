#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_root="$(cd "$script_dir/.." && pwd)"
index_dir="${OPENCLAW_INDEX_DIR:-$skill_root/.openclaw-artifacts}"
index_file="$index_dir/sessions.tsv"

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <engine> <cwd> <prompt>" >&2
  exit 2
fi

engine="$1"
cwd="$2"
prompt="$3"

sanitize_field() {
  local value
  value="${1//$'\t'/ }"
  value="${value//$'\n'/ }"
  printf '%s' "$value"
}

extract_prompt_field() {
  local key="$1"
  local value
  value="$(printf '%s\n' "$prompt" | sed -n "s/^${key}:[[:space:]]*//p" | head -n 1)"
  if [[ -z "$value" ]]; then
    printf 'N/A'
  else
    printf '%s' "$value"
  fi
}

if ! command -v tmux >/dev/null 2>&1; then
  echo "failed: tmux is not installed" >&2
  exit 1
fi

if [[ ! -d "$cwd" ]]; then
  echo "failed: cwd does not exist: $cwd" >&2
  exit 1
fi

escaped_cwd="$(printf '%q' "$cwd")"
escaped_prompt="$(printf '%q' "$prompt")"

case "$engine" in
  claude)
    engine_bin="claude"
    engine_cmd="claude --dangerously-skip-permissions -p $escaped_prompt"
    ;;
  codex)
    engine_bin="codex"
    engine_cmd="codex exec --dangerously-bypass-approvals-and-sandbox $escaped_prompt"
    ;;
  gemini)
    engine_bin="gemini"
    engine_cmd="GEMINI_SANDBOX=false gemini -p $escaped_prompt"
    ;;
  *)
    echo "failed: unsupported engine: $engine" >&2
    exit 1
    ;;
esac

if ! command -v "$engine_bin" >/dev/null 2>&1; then
  echo "failed: $engine_bin is not installed" >&2
  exit 1
fi

stamp="$(date +%Y%m%d-%H%M%S)"
session="openclaw-${engine}-${stamp}"
artifact_dir="${OPENCLAW_ARTIFACT_DIR:-$cwd/.openclaw-artifacts}"
mkdir -p "$artifact_dir" "$index_dir"
log_path="$artifact_dir/${session}.log"
escaped_log_path="$(printf '%q' "$log_path")"

session_cmd="cd $escaped_cwd && $engine_cmd >> $escaped_log_path 2>&1"

tmux new-session -d -s "$session" "$session_cmd"

if ! tmux has-session -t "$session" >/dev/null 2>&1; then
  echo "failed: could not create tmux session" >&2
  exit 1
fi

started_epoch="$(date +%s)"
task_id="$(extract_prompt_field "Task ID")"
project_key="$(extract_prompt_field "Project Key")"

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$started_epoch" \
  "$(sanitize_field "$session")" \
  "$(sanitize_field "$engine")" \
  "$(sanitize_field "$cwd")" \
  "$(sanitize_field "$log_path")" \
  "$(sanitize_field "$task_id")" \
  "$(sanitize_field "$project_key")" >> "$index_file"

echo "started: session=$session"
echo "attach: tmux -CC attach -t $session"
echo "log: $log_path"
echo "status: bash scripts/check-agent-status.sh --session $session"
