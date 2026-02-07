# wt - git worktree manager
#
# Source this file in your .profile/.bashrc/.zshrc:
#   source /path/to/wt.sh

wt() {
  local main_wt=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
  local project=$(basename "$main_wt")
  local parent=$(dirname "$main_wt")

  # Deterministic port: hash feature name → 3001-3999
  _wt_port() { echo $(( ($(printf '%s' "$1" | cksum | cut -d' ' -f1) % 997) + 3001 )); }

  case "${1:-}" in
    ls|list)
      git worktree list --porcelain | while read -r line; do
        case "$line" in
          worktree\ *)
            local wt_path="${line#worktree }"
            ;;
          branch\ *)
            local branch="${line#branch refs/heads/}"
            local port=$(_wt_port "$branch")
            printf "  %-20s %-50s :%s\n" "$branch" "$wt_path" "$port"
            ;;
          HEAD\ *)
            # detached HEAD worktree, no branch
            printf "  %-20s %s\n" "(detached)" "$wt_path"
            ;;
        esac
      done
      ;;
    add)
      shift
      wt "$@"
      ;;
    proxy)
      node ~/wt/proxy.js
      ;;
    rm)
      local current_wt=$(git rev-parse --show-toplevel 2>/dev/null)
      if [[ "$current_wt" != "$main_wt" ]]; then
        echo "error: run 'wt rm' from the main worktree ($main_wt)" >&2
        return 1
      fi

      local feature="${2:-}"
      if [[ -z "$feature" ]]; then
        echo "Worktrees:"
        wt ls
        echo
        printf "Feature to remove: "
        read -r feature
        [[ -z "$feature" ]] && echo "Aborted." && return 1
      fi

      printf "Remove worktree '%s'? [y/N] " "$feature"
      read -r confirm
      [[ "$confirm" != [yY] ]] && echo "Aborted." && return 0

      git worktree remove "${parent}/${project}-${feature}" && git branch -d "$feature" 2>/dev/null
      echo "Removed worktree and branch: $feature"
      ;;
    -h|--help|"")
      echo "wt - git worktree manager

Usage:
    wt <feature>              Create worktree, install deps, start dev server
    wt <feature> -c [args]    Create worktree, install deps, start Claude
    wt <feature> -cdsp [args] Same but with --dangerously-skip-permissions
    wt ls | list              List all worktrees with ports
    wt rm [feature]           Remove worktree and delete branch (interactive if no arg)
    wt proxy                  Start reverse proxy on :3000 (<feature>.localhost routing)
    wt -h, --help             Show this help"
      ;;
    *)
      local feature="$1"
      shift
      local worktree="${parent}/${project}-${feature}"
      local port=$(_wt_port "$feature")

      # Parse flags
      local mode="dev"
      local claude_args=()
      if [[ "${1:-}" == "-cdsp" ]]; then
        mode="claude-dsp"
        shift
        claude_args=("$@")
      elif [[ "${1:-}" == "-c" ]]; then
        mode="claude"
        shift
        claude_args=("$@")
      fi

      git worktree add "$worktree" -b "$feature" || return 1
      cd "$worktree" || return 1
      [[ -f package.json ]] && pnpm install

      printf '\n  Branch:  %s\n  Path:    %s\n  Server:  http://localhost:%s\n\n' \
        "$feature" "$worktree" "$port"

      case "$mode" in
        claude-dsp) claude --dangerously-skip-permissions "${claude_args[@]}" ;;
        claude)     claude "${claude_args[@]}" ;;
        dev)        PORT=$port pnpm dev ;;
      esac
      ;;
  esac
}
