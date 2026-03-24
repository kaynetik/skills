# kaynetik-skills

[Agent Skills](https://agentskills.io)-compatible packages for the [`skills` CLI](https://github.com/vercel-labs/skills) and [skills.sh](https://skills.sh/). Each top-level directory here is one installable skill (`SKILL.md` at its root).

## Table of contents

- [Skills in this repo](#skills-in-this-repo)
- [Repository layout](#repository-layout)
- [Requirements](#requirements)
- [Install](#install)
- [Publish on GitHub](#publish-on-github)
- [Validate (optional)](#validate-optional)
- [References](#references)

## Skills in this repo

| Directory | `name` (frontmatter) | Summary |
| :--- | :--- | :--- |
| [`argocd`](argocd/SKILL.md) | `argocd` | ArgoCD GitOps operations: Application/AppProject authoring, ApplicationSet generators, sync strategies, RBAC, SSO, health checks, CLI, and troubleshooting. |
| [`c-cpp-compilers`](c-cpp-compilers/SKILL.md) | `c-cpp-compilers` | C/C++ compiler toolchain: GCC, Clang/LLVM, build modes, warnings, sanitizers, static analysis, LTO, PGO, C++20/23/26, and debugging. |
| [`coding-guidelines`](coding-guidelines/SKILL.md) | `coding-guidelines` | Rust code style and best practices: naming, formatting, clippy, rustfmt, lint rules, and code review conventions. |
| [`devops-iac-engineer`](devops-iac-engineer/SKILL.md) | `devops-iac-engineer` | Infrastructure as code with Terraform, Kubernetes, and cloud platforms. CI/CD pipelines, observability, and security-first DevOps. |
| [`helm`](helm/SKILL.md) | `helm` | Helm 3 chart development, scaffolding, templating, debugging, OCI registries, post-renderers, and production operations. |
| [`lua-projects`](lua-projects/SKILL.md) | `lua-projects` | Idiomatic Lua 5.4 for Neovim plugin/config ecosystems (LazyVim, lazy.nvim) and macOS bar tools (SketchyBar/SbarLua). |
| [`markdown-documentation`](markdown-documentation/SKILL.md) | `markdown-documentation` | Markdown formatting, GitHub Flavored Markdown, README files, and documentation best practices. |
| [`mermaid-diagrams`](mermaid-diagrams/SKILL.md) | `mermaid-diagrams` | Professional Mermaid diagrams from natural language or technical descriptions, with optional Excalidraw export. |
| [`meta-cognition-parallel`](meta-cognition-parallel/SKILL.md) | `meta-cognition-parallel` | Three-layer parallel meta-cognition analysis (experimental). |
| [`practical-haskell`](practical-haskell/SKILL.md) | `practical-haskell` | Efficient Haskell aligned with GHC practice: laziness/strictness, purity, fusion, newtypes, pragmas, Core reading, and space-leak avoidance. |
| [`solidity-security`](solidity-security/SKILL.md) | `solidity-security` | Solidity smart contract security: vulnerability prevention, secure coding patterns, gas-safe optimizations, and audit preparation. |
| [`tdd-red-green-refactor`](tdd-red-green-refactor/SKILL.md) | `tdd-red-green-refactor` | Red-Green-Refactor TDD: failing test first, minimal pass, refactor; bug fixes, features, regression prevention. |
| [`tmux-mastery`](tmux-mastery/SKILL.md) | `tmux-mastery` | Comprehensive tmux: process management, session/window orchestration, and visual customization (ricing). |
| [`ultimate-nixos`](ultimate-nixos/SKILL.md) | `ultimate-nixos` | Nixpkgs maintainer/committer workflow: PRs, OfBorg, `nixpkgs-review`, merge bot, r-ryantm, staging, and backports. |
| [`zig-programming`](zig-programming/SKILL.md) | `zig-programming` | Zig 0.15.x programming, build system config, and stdlib usage including breaking API changes from prior versions. |

The `name` field in each `SKILL.md` must match the parent directory name (see [Agent Skills specification](https://agentskills.io/specification.md)).

## Repository layout

```text
kaynetik/skills/
  README.md
  LICENSE
  argocd/
    SKILL.md
  c-cpp-compilers/
    SKILL.md
    reference/
      clang.md
      gcc.md
      modern-cpp.md
      sanitizers.md
      static-analysis.md
  coding-guidelines/
    SKILL.md
    index/
      rules-index.md
  devops-iac-engineer/
    SKILL.md
    reference/
      cicd.md
      cloud_platforms.md
      gcp.md
      kubernetes.md
      observability.md
      security.md
      templates.md
      terraform.md
  helm/
    SKILL.md
  lua-projects/
    SKILL.md
  markdown-documentation/
    SKILL.md
    reference.md
    templates.md
  mermaid-diagrams/
    SKILL.md
    reference.md
  meta-cognition-parallel/
    SKILL.md
  practical-haskell/
    SKILL.md
    reference.md
  solidity-security/
    SKILL.md
  tdd-red-green-refactor/
    SKILL.md
    references/
      examples.md
  tmux-mastery/
    SKILL.md
  ultimate-nixos/
    SKILL.md
    reference.md
  zig-programming/
    SKILL.md
    references/
      build-system.md
      migration-patterns.md
      stdlib-api-reference.md
```

Discovery follows the layout rules in [Creating Skills](https://github.com/vercel-labs/skills#creating-skills) for the `skills` CLI.

## Requirements

Each `SKILL.md` needs YAML frontmatter with:

- **`name`**: Lowercase identifier, 1 to 64 characters, `a-z`, digits, single hyphens only; no leading or trailing hyphen, no `--` in the name. Must match the directory name.
- **`description`**: 1 to 1024 characters. State what the skill does and when the agent should use it (discovery depends on this).

Optional frontmatter: `license`, `compatibility`, `metadata`, `allowed-tools` (experimental). See the [spec](https://agentskills.io/specification.md).

Optional: `metadata.internal: true` hides a WIP skill from default discovery when using `INSTALL_INTERNAL_SKILLS=1` (see [CLI README](https://github.com/vercel-labs/skills)).

Keep file references from `SKILL.md` one level deep where possible ([file references](https://agentskills.io/specification.md#file-references)).

## Install

From a clone of this repository (repository root, where this `README.md` lives):

```bash
npx skills add . --list
```

Install one skill into Cursor globally:

```bash
npx skills add . --skill <skill-name> -g -a cursor -y
```

Install all skills at once:

```bash
for skill in argocd c-cpp-compilers coding-guidelines devops-iac-engineer helm lua-projects markdown-documentation mermaid-diagrams meta-cognition-parallel practical-haskell solidity-security tdd-red-green-refactor tmux-mastery ultimate-nixos zig-programming; do
  npx skills add . --skill "$skill" -g -a cursor -y
done
```

Use the path to your clone instead of `.` if you are not in the repo root.

## Publish on GitHub

Others can install with `owner/repo` shorthand:

```bash
npx skills add kaynetik/skills --skill <skill-name>
```

The [skills.sh](https://skills.sh/) directory ranks skills from anonymous install telemetry from `npx skills add`; there is no separate upload step. Use a **public** repo if you want discovery through installs.

For directory hygiene: include a root `LICENSE` if you want clear redistribution terms.

## Validate (optional)

[skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref) can check frontmatter and naming:

```bash
for skill in argocd c-cpp-compilers coding-guidelines devops-iac-engineer helm lua-projects markdown-documentation mermaid-diagrams meta-cognition-parallel practical-haskell solidity-security tdd-red-green-refactor tmux-mastery ultimate-nixos zig-programming; do
  skills-ref validate "./$skill"
done
```

## References

- [skills.sh documentation](https://skills.sh/docs)
- [vercel-labs/skills (CLI)](https://github.com/vercel-labs/skills)
- [Agent Skills specification](https://agentskills.io/specification.md)
