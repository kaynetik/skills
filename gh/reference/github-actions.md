# GitHub Actions reference (professional, performant, clean workflows)

Use this file when designing, reviewing, or debugging `.github/workflows/*.yml` (or `.yaml`).

## Official documentation (start here)

| Area | URL |
| :--- | :--- |
| Actions landing | https://docs.github.com/en/actions |
| Workflow syntax | https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions |
| Security hardening | https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions |
| Encrypted secrets | https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions |
| GITHUB_TOKEN permissions | https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication |
| Reusable workflows | https://docs.github.com/en/actions/sharing-automations/reusing-workflows |
| Composite actions | https://docs.github.com/en/actions/sharing-automations/creating-actions/creating-a-composite-action |
| OIDC with cloud providers | https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect |
| Events that trigger workflows | https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows |

## Security and correctness

- **Least privilege:** Set `permissions:` as tight as practical (often `contents: read` for CI builds). Add `pull-requests: write`, `id-token: write` (OIDC), `packages: write`, etc. only where required.
- **Secrets:** Reference via `${{ secrets.NAME }}`. Do not echo secrets into logs; mask or avoid printing environment blobs in debug steps.
- **Script injection:** Untrusted PR/issue/comment text must not flow into `run:` via `${{ }}` interpolation. Pass values through `env:` and expand as shell variables, per GitHub hardening guidance.
- **`pull_request_target`:** Runs in a context with access to secrets and base-repo credentials. Combining it with checkout of the PR head from a fork is a common footgun; read GitHub docs and security advisories before using it.
- **Third-party actions:** Prefer maintained actions; pin to full commit SHA for high-assurance pipelines; review action source and `action.yml` for unexpected `post` steps or network calls.
- **OIDC:** Prefer short-lived federation to cloud roles over long-lived cloud keys stored as repository secrets when your provider supports it.

## Performance and cost

- **Path filters:** Limit `push` / `pull_request` triggers with `paths` / `paths-ignore` when jobs do not need to run on every file change.
- **Concurrency:** Use `concurrency:` with `cancel-in-progress: true` for redundant runs on the same branch or PR when safe for your workflow.
- **Caching:** Use `actions/cache` (or ecosystem-specific setup actions that wrap cache) for dependency directories; key caches on lockfiles and OS/runner type.
- **Matrices:** Split independent work across jobs for parallelism; avoid N-times duplicate setup if a single job with a smarter script is cheaper.
- **Artifacts:** Upload only what downstream jobs or humans need; large binaries inflate storage and minutes.
- **Runner choice:** `ubuntu-latest` is the common default; use larger or private runners only when justified.

## Maintainability and clarity

- **One workflow, one purpose:** Prefer separate workflows (CI vs release vs scheduled hygiene) over one giant file with many unrelated jobs.
- **Names:** Clear `name:` on workflows and steps; consistent job ids for reuse and `needs:` graphs.
- **Defaults:** Use `defaults.run.working-directory` when most steps share a subfolder.
- **Environment promotion:** Gate deploy jobs with `if:` on branch/tag, environment protection rules, or manual approval as required by the team.

## Preinstalled tools on runners

Confirm what is available before adding redundant setup steps:

- Runner image inventories: https://github.com/actions/runner-images (see the README for each OS image, for example Ubuntu and macOS variants).

## Dependency and version hygiene

- Enable **Dependabot** for GitHub Actions (or another updater) so `uses:` references do not rot silently.
- When verifying a published action tag, the GitHub Releases page or `gh release view --repo owner/repo` can show current tags; align with org policy on tags versus SHAs.

## Related GitHub docs (deep cuts)

| Topic | URL |
| :--- | :--- |
| Workflow commands (summary, annotations) | https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions |
| Environments and protection rules | https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment |
| Storing workflow data (artifacts, caching) | https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/storing-and-sharing-data-from-a-workflow |
| Billing and limits (minutes, storage) | https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions |
