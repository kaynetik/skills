# Agent skills (skills.sh)

This directory holds [Agent Skills](https://agentskills.io)-compatible packages for use with the [`skills` CLI](https://github.com/vercel-labs/skills) and the [skills.sh](https://skills.sh/) ecosystem.

## Layout

Each skill is a folder with a `SKILL.md` at its root (plus optional files such as `examples.md`):

```text
skills/
  README.md                      # this file
  tdd-red-green-refactor/
    SKILL.md                     # required: YAML frontmatter + body
    references/                  # optional: on-demand docs (Agent Skills layout)
      examples.md
```

Discovery paths follow the CLI rules documented in [skills CLI - Creating Skills](https://github.com/vercel-labs/skills#creating-skills). This repo uses the `skills/<skill-name>/` layout.

## Requirements (checklist)

Each `SKILL.md` must include YAML frontmatter with:

- `name` -- lowercase identifier (e.g. `tdd-red-green-refactor`); **[must match the parent folder name](https://agentskills.io/specification.md)** (1 to 64 chars, `a-z`, digits, single hyphens; no leading or trailing hyphen, no `--` in the name)
- `description` -- 1 to 1024 chars; include **what** the skill does and **when** to use it (helps the agent pick it)

Optional frontmatter: `license`, `compatibility`, `metadata`, `allowed-tools` (experimental). See the [Agent Skills specification](https://agentskills.io/specification.md).

Optional frontmatter (see [CLI README](https://github.com/vercel-labs/skills)): `metadata.internal: true` to hide a WIP skill from default discovery when using `INSTALL_INTERNAL_SKILLS=1`.

## Try locally

From the **repository root** (parent of `skills/`):

```bash
npx skills add . --list
```

Install this skill into your agents (example: Cursor, global):

```bash
npx skills add . --skill tdd-red-green-refactor -g -a cursor -y
```

Replace `.` with a path to a clone of this repo if you are not inside it.

## After you push to GitHub

Others can install with `owner/repo` shorthand:

```bash
npx skills add YOUR_ORG/iac-candle --skill tdd-red-green-refactor
```

The [skills.sh leaderboard](https://skills.sh/) ranks skills using anonymous install telemetry from `npx skills add`; there is no separate upload step. Use a **public** repo if you want discovery via installs.

## Publishing hygiene

When making the repo public for the directory:

- Add a **LICENSE** at the repository root if you want clear redistribution terms.
- Keep each skill self-contained under `skills/<name>/`; keep file references **one level deep** from `SKILL.md` (see [spec: file references](https://agentskills.io/specification.md#file-references)).

## Validate against the spec (optional)

The [skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref) tool can validate frontmatter and naming:

```bash
skills-ref validate ./skills/tdd-red-green-refactor
```

## Skills in this bundle

| Skill | Summary |
|-------|---------|
| `tdd-red-green-refactor` | Red-Green-Refactor TDD, bug-first workflow, multi-language notes; see `tdd-red-green-refactor/SKILL.md`. |

## References

- [skills.sh documentation](https://skills.sh/docs)
- [vercel-labs/skills (CLI source and discovery rules)](https://github.com/vercel-labs/skills)
- [Agent Skills specification](https://agentskills.io/specification.md)
