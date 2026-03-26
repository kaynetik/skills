# GitHub CLI (`gh`) reference

Use this file when operating GitHub from the terminal: repositories, issues, pull requests, Actions runs, secrets, and API access.

## Official documentation

| Resource | URL |
| :--- | :--- |
| Manual (all commands) | https://cli.github.com/manual/ |
| About GitHub CLI | https://docs.github.com/en/github-cli/github-cli |
| `gh` repository | https://github.com/cli/cli |

## Installation and version

- Install per platform instructions in the manual; verify with `gh --version`.
- Behavior and flags can change between releases; when in doubt, run `gh <command> --help`.

## Authentication

| Task | Command |
| :--- | :--- |
| Interactive login | `gh auth login` |
| Non-interactive / CI | `gh auth login --with-token` reading a token with minimal scopes |
| Git credential helper | `gh auth setup-git` |
| Show token (careful) | `gh auth token` |
| Hosts and users | `gh auth status` |

Environment variables commonly used in automation: `GH_TOKEN`, `GH_HOST`, `GH_REPO`. See `gh help environment` for the full list.

## Command map (where to look)

| Area | Command group | Typical use |
| :--- | :--- | :--- |
| Repository | `gh repo` | clone, create, fork, sync, view, set default |
| Issues | `gh issue` | list, view, create, close, comment |
| Pull requests | `gh pr` | list, view, checkout, diff, merge, checks, review |
| Workflow runs | `gh run` | list, view, watch, rerun, cancel, download logs |
| Workflow definitions | `gh workflow` | list, view, run, enable, disable |
| Caches | `gh cache` | list, delete |
| Secrets | `gh secret` | list, set, delete (repo, env, org) |
| Variables | `gh variable` | list, set, get, delete |
| Releases | `gh release` | create, list, download, upload assets |
| API | `gh api` | REST and GraphQL with auth and pagination |
| Search | `gh search` | code, issues, PRs, repos |

Run `gh <group> --help` for subcommands (for example `gh pr --help`).

## JSON output and scripting

- Prefer machine-readable output: `--json field1,field2` and optional `--jq 'expression'`.
- Use `--paginate` with `gh api` when listing large result sets.
- Set `GH_PROMPT_DISABLED=true` in scripts to avoid interactive prompts.

## Everyday patterns

| Goal | Example direction |
| :--- | :--- |
| Open current PR in browser | `gh pr view --web` |
| Wait for a workflow run | `gh run watch <run-id>` |
| Re-run failed jobs | `gh run rerun <run-id> --failed` |
| Create PR from branch | `gh pr create` with title/body flags or editor |
| Set default repo for cwd | `gh repo set-default owner/repo` |

## Security notes

- Treat `GH_TOKEN` like a password; never commit it or paste it into workflow logs.
- Use fine-grained or classic tokens with the smallest scope set that satisfies the automation.
- For Actions, prefer `GITHUB_TOKEN` with explicit `permissions:` over long-lived PATs unless a task truly requires it.
