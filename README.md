# wt

A thin wrapper around `git worktree` that adds deterministic dev server ports and a simple CLI.

## Why

Git worktrees let you work on multiple branches simultaneously without stashing or switching. `wt` adds two things on top:

1. **Convention-based paths** - worktrees are created as sibling directories: `project-feature/` next to `project/`
2. **Deterministic ports** - each branch name hashes to a fixed port (3001-3999), so you never get port conflicts between worktrees

## Install

```bash
git clone https://github.com/JWPapi/wt.git ~/wt
echo 'source ~/wt/wt.sh' >> ~/.profile
```

## Usage

```
wt <feature>              Create worktree, install deps, start dev server
wt <feature> -c [args]    Create worktree, install deps, start Claude
wt <feature> -cdsp [args] Same but with --dangerously-skip-permissions
wt ls | list              List all worktrees with ports
wt rm [feature]           Remove worktree and delete branch (interactive if no arg)
wt proxy                  Start reverse proxy on :3000 (<feature>.localhost routing)
wt -h                     Show help
```

### Create a worktree

```bash
wt auth-refactor
```

This will:
- Create a new branch `auth-refactor`
- Create a worktree at `../project-auth-refactor/`
- Run `pnpm install` if `package.json` exists
- Start `pnpm dev` on a deterministic port

```
  Branch:  auth-refactor
  Path:    /home/user/project-auth-refactor
  Server:  http://localhost:3847
```

### Create a worktree with Claude

```bash
# Start Claude interactively
wt auth-refactor -c

# Start Claude with a prompt
wt auth-refactor -c -p "refactor the auth module"

# Start Claude with --dangerously-skip-permissions
wt auth-refactor -cdsp

# Same, with extra args
wt auth-refactor -cdsp -r -p "fix the login bug"
```

All arguments after `-c` or `-cdsp` are forwarded to `claude`.

### List worktrees

```bash
wt ls
```

```
  master               /home/user/project                                  :3042
  auth-refactor        /home/user/project-auth-refactor                    :3847
  fix-nav              /home/user/project-fix-nav                          :3219
```

### Remove a worktree

```bash
# With argument — asks for confirmation
wt rm auth-refactor

# Without argument — shows worktrees, prompts for name, then confirms
wt rm
```

Must be run from the main worktree. Removes the worktree directory and deletes the local branch.

### Reverse proxy

```bash
wt proxy
```

Starts a reverse proxy on `:3000` that routes `<feature>.localhost:3000` to the worktree's deterministic port. This lets you access any worktree dev server at a friendly URL:

```
auth-refactor.localhost:3000  →  localhost:3847
fix-nav.localhost:3000        →  localhost:3219
```

WebSocket upgrades (HMR) are proxied automatically.

> **Browser note:** Chrome and Firefox resolve `*.localhost` to `127.0.0.1` by default. Safari does not — add entries to `/etc/hosts` or use Chrome/Firefox.

## How ports work

The branch name is hashed with `cksum` and mapped to a port in the 3001-3999 range. The same branch name always gets the same port, so you can bookmark `localhost:3847` and it stays stable for that feature branch.

```
port = (cksum(branch_name) % 997) + 3001
```

## Requirements

- git
- zsh or bash
- Node.js (for `wt proxy`)
- pnpm (for auto-install and dev server)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (optional, for `-c` / `-cdsp` flags)
