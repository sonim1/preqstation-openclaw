#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_root="$(cd "$script_dir/.." && pwd)"
index_dir="${OPENCLAW_INDEX_DIR:-$skill_root/.openclaw-artifacts}"
index_file="$index_dir/sessions.tsv"

session_filter=""
task_filter=""
tail_lines=20
limit=5
show_all=false

usage() {
  cat <<'EOF'
usage: scripts/check-agent-status.sh [options]

options:
  --session <name>   Filter by tmux session name
  --task <id>        Filter by task id (example: PRJ-284)
  --tail <n>         Log tail line count for preview (default: 20)
  --limit <n>        Max sessions to print (default: 5)
  --all              Include ended/unknown sessions (default: running only)
  --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session)
      session_filter="${2:-}"
      shift 2
      ;;
    --task)
      task_filter="${2:-}"
      shift 2
      ;;
    --tail)
      tail_lines="${2:-}"
      shift 2
      ;;
    --limit)
      limit="${2:-}"
      shift 2
      ;;
    --all)
      show_all=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "failed: unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ ! -f "$index_file" ]]; then
  echo "status: no running sessions"
  exit 0
fi

session_status() {
  local session="$1"
  local output

  if ! command -v tmux >/dev/null 2>&1; then
    printf 'unknown'
    return
  fi

  if tmux has-session -t "$session" >/dev/null 2>&1; then
    printf 'running'
    return
  fi

  output="$(tmux has-session -t "$session" 2>&1 || true)"
  if [[ "$output" == *"Operation not permitted"* ]]; then
    printf 'unknown'
  else
    printf 'ended'
  fi
}

printed=0

format_started_iso() {
  local epoch="$1"
  local iso

  iso="$(date -r "$epoch" +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || true)"
  if [[ -n "$iso" ]]; then
    printf '%s' "$iso"
    return
  fi

  iso="$(date -u -d "@$epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || true)"
  if [[ -n "$iso" ]]; then
    printf '%s' "$iso"
    return
  fi

  printf 'N/A'
}

reverse_index() {
  awk '{ lines[NR] = $0 } END { for (i = NR; i > 0; i--) print lines[i] }' "$index_file"
}

while IFS=$'\t' read -r started_epoch session engine cwd log_path task_id project_key; do
  [[ -n "$session" ]] || continue

  if [[ -n "$session_filter" && "$session" != "$session_filter" ]]; then
    continue
  fi

  if [[ -n "$task_filter" && "$task_id" != "$task_filter" ]]; then
    continue
  fi

  status="$(session_status "$session")"
  if [[ "$show_all" == false && "$status" != "running" ]]; then
    continue
  fi

  if (( printed >= limit )); then
    break
  fi

  started_iso="$(format_started_iso "$started_epoch")"
  last_log="(missing log file)"
  if [[ -f "$log_path" ]]; then
    last_log="$(tail -n "$tail_lines" "$log_path" | sed '/^[[:space:]]*$/d' | tail -n 1)"
    if [[ -z "$last_log" ]]; then
      last_log="(empty)"
    fi
  fi

  echo "session=$session status=$status engine=$engine task=$task_id project=$project_key started=$started_iso"
  echo "attach=tmux -CC attach -t $session"
  echo "log=$log_path"
  echo "last_log=$last_log"
  echo "---"

  printed=$((printed + 1))
done < <(reverse_index)

if (( printed == 0 )); then
  if [[ "$show_all" == true ]]; then
    echo "status: no matching sessions"
  else
    echo "status: no running sessions"
  fi
fi
