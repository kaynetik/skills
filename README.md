<h3 align="center">
 <br/>
 <img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/misc/transparent.png" height="30" width="0px"/>
</h3>

<p align="center">
 <a href="https://github.com/kaynetik/skills/releases/latest"><img src="https://img.shields.io/github/v/release/kaynetik/skills?colorA=363a4f&colorB=a6da95&style=for-the-badge&logo=github&logoColor=d8dee9" alt="Latest release"></a>
 <a href="https://github.com/kaynetik/skills/actions/workflows/agent-scan.yml"><img src="https://img.shields.io/github/actions/workflow/status/kaynetik/skills/agent-scan.yml?colorA=363a4f&style=for-the-badge&logo=github&logoColor=d8dee9&label=scan" alt="Scan status"></a>
 <a href="https://github.com/kaynetik/skills/commits"><img src="https://img.shields.io/github/last-commit/kaynetik/skills?colorA=363a4f&colorB=f5a97f&style=for-the-badge" alt="Last commit"></a>
 <a href="https://github.com/kaynetik/skills/blob/main/LICENSE"><img src="https://img.shields.io/github/license/kaynetik/skills?colorA=363a4f&colorB=b7bdf7&style=for-the-badge" alt="License"></a>
</p>


# kaynetik-skills

[Agent Skills](https://agentskills.io)-compatible packages for the [`skills` CLI](https://github.com/vercel-labs/skills) and [skills.sh](https://skills.sh/). Each top-level directory here is one installable skill (`SKILL.md` at its root).

## Table of contents

- [Skills](#skills)
- [Requirements](#requirements)
- [Install](#install)
- [Publish on GitHub](#publish-on-github)
- [Validate (optional)](#validate-optional)
- [Security scanning](#security-scanning)
- [References](#references)

## Skills _(with Snyk Validation)_

<table>
<tr>
<td rowspan="2" align="center"><b>1</b></td>
<td><a href="argocd/SKILL.md"><code>argocd</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/W007-warning-orange?style=for-the-badge&colorA=363a4f" height="28" alt="W007 warning"></td>
</tr>
<tr><td colspan="2">ArgoCD GitOps operations: Application/AppProject authoring, ApplicationSet generators, sync strategies, RBAC, SSO, health checks, CLI, and troubleshooting.</td></tr>
<tr>
<td rowspan="2" align="center"><b>2</b></td>
<td><a href="c-cpp-compilers/SKILL.md"><code>c-cpp-compilers</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f" height="28" alt="clean"></td>
</tr>
<tr><td colspan="2">C/C++ compiler toolchain: GCC, Clang/LLVM, build modes, warnings, sanitizers, static analysis, LTO, PGO, C++20/23/26, and debugging.</td></tr>
<tr>
<td rowspan="2" align="center"><b>3</b></td>
<td><a href="coding-guidelines/SKILL.md"><code>coding-guidelines</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f" height="28" alt="clean"></td>
</tr>
<tr><td colspan="2">Rust code style and best practices: naming, formatting, clippy, rustfmt, lint rules, and code review conventions.</td></tr>
<tr>
<td rowspan="2" align="center"><b>4</b></td>
<td><a href="devops-iac-engineer/SKILL.md"><code>devops-iac-engineer</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f" height="28" alt="clean"></td>
</tr>
<tr><td colspan="2">Infrastructure as code with Terraform, Kubernetes, and cloud platforms. CI/CD pipelines, observability, and security-first DevOps.</td></tr>
<tr>
<td rowspan="2" align="center"><b>5</b></td>
<td><a href="gh/SKILL.md"><code>gh</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/W011-warning-orange?style=for-the-badge&colorA=363a4f" height="28" alt="W011 warning"></td>
</tr>
<tr><td colspan="2">Git hygiene, GitHub CLI (<code>gh</code>), and GitHub Actions: workflows, security, performance, and operational commands.</td></tr>
<tr>
<td rowspan="2" align="center"><b>6</b></td>
<td><a href="helm/SKILL.md"><code>helm</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/W011-warning-orange?style=for-the-badge&colorA=363a4f" height="28" alt="W011 warning"></td>
</tr>
<tr><td colspan="2">Helm 3 chart development, scaffolding, templating, debugging, OCI registries, post-renderers, and production operations.</td></tr>
<tr>
<td rowspan="2" align="center"><b>7</b></td>
<td><a href="lua-projects/SKILL.md"><code>lua-projects</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f" height="28" alt="clean"></td>
</tr>
<tr><td colspan="2">Idiomatic Lua 5.4 for Neovim plugin/config ecosystems (LazyVim, lazy.nvim) and macOS bar tools (SketchyBar/SbarLua).</td></tr>
<tr>
<td rowspan="2" align="center"><b>8</b></td>
<td><a href="markdown-documentation/SKILL.md"><code>markdown-documentation</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f" height="28" alt="clean"></td>
</tr>
<tr><td colspan="2">Markdown formatting, GitHub Flavored Markdown, README files, and documentation best practices.</td></tr>
<tr>
<td rowspan="2" align="center"><b>9</b></td>
<td><a href="mermaid-diagrams/SKILL.md"><code>mermaid-diagrams</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f" height="28" alt="clean"></td>
</tr>
<tr><td colspan="2">Professional Mermaid diagrams from natural language or technical descriptions, with optional Excalidraw export.</td></tr>
<tr>
<td rowspan="2" align="center"><b>10</b></td>
<td><a href="meta-cognition-parallel/SKILL.md"><code>meta-cognition-parallel</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f" height="28" alt="clean"></td>
</tr>
<tr><td colspan="2">Three-layer parallel meta-cognition analysis (experimental).</td></tr>
<tr>
<td rowspan="2" align="center"><b>11</b></td>
<td><a href="podmaster/SKILL.md"><code>podmaster</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f" height="28" alt="clean"></td>
</tr>
<tr><td colspan="2">Container engineering: OCI images and runtimes, Docker and Compose, Podman, Dockerfile/Containerfile optimization, containerd and CRI, debugging and security.</td></tr>
<tr>
<td rowspan="2" align="center"><b>12</b></td>
<td><a href="practical-haskell/SKILL.md"><code>practical-haskell</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f" height="28" alt="clean"></td>
</tr>
<tr><td colspan="2">Efficient Haskell aligned with GHC practice: laziness/strictness, purity, fusion, newtypes, pragmas, Core reading, and space-leak avoidance.</td></tr>
<tr>
<td rowspan="2" align="center"><b>13</b></td>
<td><a href="solidity-security/SKILL.md"><code>solidity-security</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/W009-warning-orange?style=for-the-badge&colorA=363a4f" height="28" alt="W009 warning"></td>
</tr>
<tr><td colspan="2">Solidity smart contract security: vulnerability prevention, secure coding patterns, gas-safe optimizations, and audit preparation.</td></tr>
<tr>
<td rowspan="2" align="center"><b>14</b></td>
<td><a href="tdd-red-green-refactor/SKILL.md"><code>tdd-red-green-refactor</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f" height="28" alt="clean"></td>
</tr>
<tr><td colspan="2">Red-Green-Refactor TDD: failing test first, minimal pass, refactor; bug fixes, features, regression prevention.</td></tr>
<tr>
<td rowspan="2" align="center"><b>15</b></td>
<td><a href="tmux-mastery/SKILL.md"><code>tmux-mastery</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f" height="28" alt="clean"></td>
</tr>
<tr><td colspan="2">Comprehensive tmux: process management, session/window orchestration, and visual customization (ricing).</td></tr>
<tr>
<td rowspan="2" align="center"><b>16</b></td>
<td><a href="ultimate-db/SKILL.md"><code>ultimate-db</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f" height="28" alt="clean"></td>
</tr>
<tr><td colspan="2">Database engineering across PostgreSQL (primary), MySQL, MongoDB, and ClickHouse: schema design, indexing, query optimization, replication, MVCC, partitioning, and operations.</td></tr>
<tr>
<td rowspan="2" align="center"><b>17</b></td>
<td><a href="ultimate-nixos/SKILL.md"><code>ultimate-nixos</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/W013-warning-orange?style=for-the-badge&colorA=363a4f" height="28" alt="W013 warning"></td>
</tr>
<tr><td colspan="2">Nix ecosystem: NixOS system config, nixpkgs packaging and maintainer workflow, nix-darwin, Home Manager, flakes, derivations, modules, security hardening, and community processes.</td></tr>
<tr>
<td rowspan="2" align="center"><b>18</b></td>
<td><a href="ziglang/SKILL.md"><code>ziglang</code></a></td>
<td align="right"><img src="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f" height="28" alt="clean"></td>
</tr>
<tr><td colspan="2">Zig 0.15.x programming, build system config, and stdlib usage including breaking API changes from prior versions.</td></tr>
</table>

The `name` field in each `SKILL.md` must match the parent directory name (see [Agent Skills specification](https://agentskills.io/specification.md)).

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
for skill in argocd c-cpp-compilers coding-guidelines devops-iac-engineer gh helm lua-projects markdown-documentation mermaid-diagrams meta-cognition-parallel podmaster practical-haskell solidity-security tdd-red-green-refactor tmux-mastery ultimate-db ultimate-nixos ziglang; do
  npx skills add . --skill "kaynetik/skills/$skill" -g -a cursor -y
done
```

Use the path to your clone instead of `.` if you are not in the repo root.

## Validate (optional)

[skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref) can check frontmatter and naming:

```bash
for skill in argocd c-cpp-compilers coding-guidelines devops-iac-engineer gh helm lua-projects markdown-documentation mermaid-diagrams meta-cognition-parallel podmaster practical-haskell solidity-security tdd-red-green-refactor tmux-mastery ultimate-db ultimate-nixos ziglang; do
  skills-ref validate "./$skill"
done
```

## References

- [skills.sh documentation](https://skills.sh/docs)
- [vercel-labs/skills (CLI)](https://github.com/vercel-labs/skills)
- [Agent Skills specification](https://agentskills.io/specification.md)

## Security scanning

All skills in this repo are scanned by [Snyk Agent Scan](https://github.com/snyk/agent-scan) on every push and pull request that touches a `SKILL.md` file. The scan checks for:

- **Prompt injection** (E004) -- hidden or deceptive instructions inside skill content
- **Malicious code patterns** (E006) -- data exfiltration, backdoors, obfuscation
- **Hardcoded secrets** (W008) -- API keys or tokens embedded in skill text
- **Insecure credential handling** (W007) -- secrets passed verbatim through agent context
- **Untrusted third-party content** (W011) -- skills that expose the agent to arbitrary external input
- **Unverifiable external dependencies** (W012) -- skills that fetch instructions from remote URLs at runtime

See [docs/issue-codes.md](https://github.com/snyk/agent-scan/blob/main/docs/issue-codes.md) for the full issue reference.

### Run locally

Requires [uv](https://docs.astral.sh/uv/getting-started/installation/) and a valid `SNYK_TOKEN`.

```bash
# Rich output
SNYK_TOKEN=<token> ./scripts/agent-scan.sh

# JSON output saved to results.json
SNYK_TOKEN=<token> ./scripts/agent-scan.sh --out results

# Scan without failing the process on findings
SNYK_TOKEN=<token> ./scripts/agent-scan.sh --no-fail
```

Or run directly with `uvx` from the repo root:

```bash
export SNYK_TOKEN=<token>
uvx snyk-agent-scan@latest --skills .
```
