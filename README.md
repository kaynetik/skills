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
| [`tdd-red-green-refactor`](tdd-red-green-refactor/SKILL.md) | `tdd-red-green-refactor` | Red-Green-Refactor TDD: failing test first, minimal pass, refactor; bug fixes, features, regression prevention. |
| [`ultimate-nixos`](ultimate-nixos/SKILL.md) | `ultimate-nixos` | Nixpkgs maintainer and committer workflow: PRs, OfBorg, `nixpkgs-review`, merge bot, r-ryantm, staging and backports, plus how nix-darwin and Home Manager relate to nixpkgs. Optional detail in [`ultimate-nixos/reference.md`](ultimate-nixos/reference.md). |

The `name` field in each `SKILL.md` must match the parent directory name (see [Agent Skills specification](https://agentskills.io/specification.md)).

## Repository layout

```text
kaynetik-skills/
  README.md
  LICENSE
  tdd-red-green-refactor/
    SKILL.md
    references/
      examples.md
  ultimate-nixos/
    SKILL.md
    reference.md
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
npx skills add . --skill tdd-red-green-refactor -g -a cursor -y
npx skills add . --skill ultimate-nixos -g -a cursor -y
```

Use the path to your clone instead of `.` if you are not in the repo root.

## Publish on GitHub

Others can install with `owner/repo` shorthand:

```bash
npx skills add YOUR_GITHUB_USER/kaynetik-skills --skill tdd-red-green-refactor
npx skills add YOUR_GITHUB_USER/kaynetik-skills --skill ultimate-nixos
```

The [skills.sh](https://skills.sh/) directory ranks skills from anonymous install telemetry from `npx skills add`; there is no separate upload step. Use a **public** repo if you want discovery through installs.

For directory hygiene: include a root `LICENSE` if you want clear redistribution terms.

## Validate (optional)

[skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref) can check frontmatter and naming:

```bash
skills-ref validate ./tdd-red-green-refactor
skills-ref validate ./ultimate-nixos
```

## References

- [skills.sh documentation](https://skills.sh/docs)
- [vercel-labs/skills (CLI)](https://github.com/vercel-labs/skills)
- [Agent Skills specification](https://agentskills.io/specification.md)
