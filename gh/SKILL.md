---
name: gh
description: "GitHub CLI (gh) and GitHub Actions workflows with git hygiene: secure CI YAML, least-privilege tokens, caching, concurrency, script-injection prevention, PR and issue automation, and operational commands. Use when authoring or reviewing .github/workflows, debugging Actions runs, using gh for repos/issues/PRs/runs/secrets/api, or when the user mentions GitHub Actions, GHA, workflow YAML, gh CLI, GITHUB_TOKEN, or GitHub automation."
---

# Git, GitHub CLI, and GitHub Actions

## Reference files

| Topic | File | When to read |
| :--- | :--- | :--- |
| GitHub Actions (workflows, security, performance) | [reference/github-actions.md](reference/github-actions.md) | Writing or reviewing workflow YAML, CI design, hardening |
| GitHub CLI (`gh`) | [reference/gh-cli.md](reference/gh-cli.md) | Commands for repos, issues, PRs, runs, secrets, API |

Read the relevant reference before suggesting version-specific action tags or `gh` flags; prefer verifying against current docs or `gh --help`.

## Git (repository hygiene)

- **Commits:** Small, coherent changes; messages that state intent and context (what changed and why, not only how).
- **Branches:** Use a consistent team convention for naming; keep feature branches short-lived and rebased or merged against the default branch as appropriate to the project policy.
- **Secrets:** Never commit tokens, keys, or `.env` with real credentials. Use secret managers, GitHub Secrets, or local git-ignored files.
- **History:** Avoid rewriting shared history without team agreement. Prefer `git revert` for public fixes on main when others depend on the graph.
- **Hooks and config:** Align with project `pre-commit` / CI checks; do not bypass hooks to land broken formatting or tests.

## GitHub CLI (`gh`)

- **Auth:** `gh auth login` for interactive use; `GH_TOKEN` (or `GITHUB_TOKEN` in Actions) for automation. Scope tokens to the minimum required.
- **Repo context:** `gh repo set-default owner/repo` in a clone reduces repeated `--repo` flags.
- **Automation-friendly output:** Prefer `--json` and `--jq` over scraping human tables in scripts.

Full command map, environment variables, and doc links: [reference/gh-cli.md](reference/gh-cli.md).

## GitHub Actions (high level)

- **Permissions:** Declare minimal `permissions:` at workflow or job level; default broad scopes are rarely needed for build/test.
- **Secrets and untrusted input:** Use `secrets.*` for sensitive values; avoid interpolating `github.event` fields directly into `run:` shells (see [reference/github-actions.md](reference/github-actions.md)).
- **Forks and `pull_request_target`:** Treat as high risk; never check out arbitrary fork refs in a context that can reach secrets without an explicit, reviewed pattern.
- **Performance:** Use path filters, concurrency groups, caching, and matrix design intentionally; skip redundant setup when the runner image already provides the tool (confirm via runner image docs in the reference).
- **Supply chain:** Pin third-party actions to a commit SHA when policy requires; keep actions updated (Dependabot or equivalent).

Structured checklist, official documentation links, and patterns for clean workflows: [reference/github-actions.md](reference/github-actions.md).

## When this skill is not enough

- **Enterprise or org policy:** Follow internal security and compliance rules over generic advice here.
- **Deep Git internals:** Use project docs or a dedicated Git reference for advanced history surgery.
