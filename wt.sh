# wt - git worktree manager
#
# Source this file in your .zshrc/.bashrc:
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
    rm)
      local feature="${2:?Usage: wt rm <feature>}"
      git worktree remove "${parent}/${project}-${feature}" && git branch -d "$feature" 2>/dev/null
      echo "Removed worktree and branch: $feature"
      ;;
    -h|--help|"")
      echo "wt - git worktree manager

Usage:
    wt <feature>       Create worktree, install deps, start dev server
    wt ls | list       List worktrees with ports
    wt rm <feature>    Remove worktree and branch
    wt -h, --help      Show this help"
      ;;
    *)
      local feature="$1"
      local worktree="${parent}/${project}-${feature}"
      local port=$(_wt_port "$feature")

      git worktree add "$worktree" -b "$feature" || return 1
      cd "$worktree" || return 1
      [[ -f package.json ]] && pnpm install

      printf '\n  Branch:  %s\n  Path:    %s\n  Server:  http://localhost:%s\n\n' \
        "$feature" "$worktree" "$port"

      PORT=$port pnpm dev
      ;;
  esac
}
