# AI agent git workflow contract

Durable operating rule for AI agents (Claude Code, Codex, Cursor, Copilot, etc.) on this project. The agent owns git mechanics so the human can stay focused on feature work.

This file is **stack-agnostic** — drop it into any new project to get the same behavior. Adapt the CodeRabbit `path_filters` examples to your language/framework.

## How to use this in a new project

1. **Copy this file** to `docs/AI_AGENT_WORKFLOW.md` in the new project.
2. **Tell the agent**, in the very first message of the project's session:

   > Read `docs/AI_AGENT_WORKFLOW.md` and follow it as the durable operating rule for this project. I authorize auto-commit / push / PR / merge per the doc. Save it to memory so future sessions follow it automatically.

3. The agent will save the rule to per-project memory and operate on autopilot from there.

When done with the first feature, the agent will have set up: GitHub repo + branch protection + repo settings hardening + (optionally) CodeRabbit. After that, every push and PR happens without you being in the loop.

---

## Authorization

The agent MAY autonomously:
- `git commit` (write commits, sign as configured)
- `git push` to feature branches it created or has been working on
- Open pull requests
- Squash-merge **chore PRs** (tooling, config, lockfile updates) to the default branch
- Squash-merge **phase/feature PRs** when all checks are green and the user has previously acknowledged the phase as complete (e.g., "we've completed phase X")
- Merge dependency-update PRs from Dependabot once CI is green

The agent MUST NOT autonomously:
- Force-push or rebase a branch that has been pushed and another contributor (or another agent) has based work on
- Close or modify another agent's or contributor's PR
- Touch anything outside the current feature's scope
- Skip hooks or signature checks (`--no-verify`, `--no-gpg-sign`)
- Run destructive commands (`git clean -fdx`, `git reset --hard` on uncommitted work, `rm -rf` on the working tree) without confirming
- Merge a phase/feature PR if any check is failing — investigate first

## Commit cadence

Commit at every checkpoint, not at every line of code. If using Spec Kit, the `tasks.md` files have explicit checkpoint markers — use those.

| Granularity | When | Example commit message |
|---|---|---|
| Checkpoint within a phase | After each "**Checkpoint XXX**" or ⚠️ marker in `tasks.md` | `Phase 2 setup: workspace + analysis_options` |
| Phase end (1–6 inside a spec) | When all tasks for a phase are checked off | `Phase 2: foundational packages, app shells, l10n scaffolding` |
| Tooling / config fix | Immediately, on a chore branch | `chore(coderabbit): trim path filters under 150-file limit` |

**Push immediately after every commit.** The cost of an extra `git push` is zero; the cost of losing uncommitted work to a `git clean -fdx` accident is hours.

## Branch strategy

- **`main`** — protected; only mergeable via PR with linear history. No direct pushes.
- **`<NNN>-<spec-name>`** — one branch per Spec Kit spec, but **PRs are per-phase, not per-spec**. After each phase merges, the branch is auto-deleted on the remote and recreated from `main` for the next phase.
- **`chore/<topic>`** — short-lived branches for tooling/config fixes that need to land on `main` independently of feature work. Squash-merged to `main` and deleted.

When `main` advances (via chore PRs) while a feature branch is alive, **merge `main` into the feature branch** (don't rebase repeatedly). Avoids force-push overhead.

## PR strategy: one PR per phase

This is the cleanest pattern for solo-dev / heavy-AI-agent workflows:

1. **Per phase**: agent opens a PR when first push to the feature branch happens. PR accumulates commits across all checkpoints of that phase.
2. **At phase end**: agent marks PR ready-for-review, runs the test/lint suite one more time, squash-merges to `main`. Auto-delete deletes the remote branch.
3. **Next phase**: recreate the same branch name locally from `main`, push first commit, open new PR.
4. **Tag at spec milestones**: not at every phase merge. Only when a full spec is done (e.g., `v0.0.1-phase0` after the spec's final phase).

If you have CodeRabbit or human reviewers who do incremental review on long-running PRs, you can flip to "one long-running draft PR per spec" instead. But for solo-dev with paused/no review tooling, per-phase merging keeps each main commit small and revertible.

PR titles use Conventional Commits prefixes: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `build:`, `ci:`. Bodies follow this template:

```
## Summary
<1–3 bullets>

## Test plan
- [x] <ran locally>
- [ ] <CI must pass>
- [ ] <manual verification step if applicable>
```

## GitHub repo setup (one-time, per repo)

Run these once when creating a new repo. Use `gh` CLI.

```bash
# 1. Create the repo (private by default — adjust if open-source)
gh repo create <owner>/<name> --private --source=. --remote=origin \
  --description "<one-line project description>"

# 2. Push main first, then feature branches
git branch -M main
git push -u origin main
git push -u origin <feature-branch>

# 3. Branch protection on main
gh api -X PUT repos/<owner>/<name>/branches/main/protection --input - <<EOF
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
EOF

# 4. Repo hygiene: disable wiki, force squash/rebase only, auto-delete branches
gh api -X PATCH repos/<owner>/<name> \
  -f has_wiki=false \
  -F delete_branch_on_merge=true \
  -F allow_merge_commit=false \
  -F allow_squash_merge=true \
  -F allow_rebase_merge=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY

# 5. Free security: Dependabot alerts + automated security fixes
gh api -X PUT repos/<owner>/<name>/vulnerability-alerts
gh api -X PUT repos/<owner>/<name>/automated-security-fixes

# 6. Topics (replace with your stack — Flutter/Dart/Drift, Node/TS/Postgres, etc.)
gh api -X PUT repos/<owner>/<name>/topics \
  -f 'names[]=<lang>' \
  -f 'names[]=<framework>' \
  -f 'names[]=<domain>'
```

**`required_approving_review_count: 0` is critical** for solo devs / agents — it lets the workflow merge without requiring a human reviewer while still forcing every change through a PR.

## CodeRabbit (when to use, when to skip)

CodeRabbit is an independent AI reviewer. Worth using when there is **logic to review**. Not worth the setup time for scaffolding-heavy PRs (boilerplate package skeletons, identical smoke tests, framework-generated platform shells like `flutter create` outputs).

### Default policy: PAUSED, opt-in per phase

**`auto_review.enabled` is `false` by default on `main`.** CodeRabbit does NOT review every PR. The agent is responsible for deciding when a phase needs an external reviewer and flipping the switch *before* opening that phase's PR.

- **To enable** for a phase: open a `chore(coderabbit): enable for phase X` PR that flips `reviews.auto_review.enabled: true` in `.coderabbit.yaml`. Squash-merge to `main` BEFORE opening the phase's feature PR (CodeRabbit reads config from the default branch).
- **To disable** after the phase merges: open `chore(coderabbit): pause` PR that flips it back to `false`. Squash-merge.
- **To trigger a one-shot review** without flipping the global switch: comment `@coderabbitai review` on the open PR. Costs nothing if `auto_review.enabled` is already `false`.

The agent doesn't need to ask the user before flipping these — they're chore PRs by definition.

### When to enable

**Enable for phases that introduce at least one of:**
- Money / decimal / financial logic
- Database schema, migrations, or RLS policies
- Authentication / authorization / security boundaries (incl. Supabase Vault, signed URLs, Edge Function auth checks)
- Concurrency / sync / race conditions
- New business workflows (sales, payroll, posting, approval flows)
- New cross-feature contracts that future phases will depend on

For AlNujom specifically: enable from **Phase 4 (Supabase base schema + RLS)** onward by default. Phases 1–3 (Setup, Foundational, Design system + theme) and most localization/UI-polish phases don't need it. Push notifications (Phase 22) and Auth (Phase 5) and Vault-touching phases (Phase 5, 16, 19, 21, 22) all warrant enabling.

### When to skip

- PR is mostly framework scaffolding output (`flutter create`, `cargo new`, `next create-app`)
- PR is documentation only
- PR is a dependency bump (Dependabot handles those)
- The phase is purely visual/UX polish with no logic changes
- Iterating fast and rate limits would bite

### Config (`.coderabbit.yaml`) — lessons learned the hard way

```yaml
language: en

# IMPORTANT: tone_instructions has a 250-character hard limit.
# Validation fails silently and the entire config falls back to defaults
# (which means path filters, drafts: true, and per-path instructions are
# all ignored). Keep this short.
tone_instructions: >
  Pragmatic, terse, technical. Hard errors: <list project-specific
  invariants in <250 chars>.

reviews:
  auto_review:
    enabled: false             # default — flip to true on a chore PR
                               # before opening a phase that needs review
    drafts: true               # review long-running draft PRs too
    base_branches:
      - main

  # Per-path review guidance — no length limit here.
  path_instructions:
    - path: "<path>/**"
      instructions: >
        <Detailed project-specific rules for this area.>

  # Drop the diff under CodeRabbit's 150-file ceiling. Be aggressive —
  # `flutter create` alone produces 60+ generated files; framework
  # scaffolds in any language will too.
  path_filters:
    # Generated code (adapt for your stack)
    - "!**/*.g.dart"            # Dart codegen
    - "!**/*.freezed.dart"
    - "!**/lib/l10n/app_localizations*.dart"
    # - "!**/*.pb.go"           # Go protobuf
    # - "!**/dist/**"           # JS/TS build output
    # - "!**/__generated__/**"  # any "_generated" output

    # Lockfiles + tooling output
    - "!**/pubspec.lock"        # Dart
    - "!**/package-lock.json"   # Node
    - "!**/yarn.lock"
    - "!**/pnpm-lock.yaml"
    - "!**/Cargo.lock"          # Rust
    - "!**/.dart_tool/**"
    - "!**/node_modules/**"
    - "!**/build/**"
    - "!**/dist/**"

    # Native platform shells (Flutter, React Native, Tauri, etc.)
    - "!**/android/**"
    - "!**/ios/**"
    - "!**/windows/**"
    - "!**/macos/**"
    - "!**/linux/**"
    - "!**/.metadata"

    # Pure placeholders + identical-across-N-packages boilerplate
    - "!**/.gitkeep"
    - "!packages/*/README.md"
    - "!packages/*/analysis_options.yaml"

chat:
  auto_reply: true
```

**The config must live on the default branch (`main`) to be picked up.** Putting it only on the feature branch makes CodeRabbit fall back to defaults.

To pause without uninstalling: set `reviews.auto_review.enabled: false`. To resume: flip back to `true`.

### Common CodeRabbit gotchas

| Symptom | Cause | Fix |
|---|---|---|
| "Configuration used: defaults" in skip comment | YAML failed validation; check `tone_instructions` length (≤250) | Trim `tone_instructions`; per-path instructions go in `path_instructions` |
| "Too many files! 200 / 150" | Path filters too narrow | Aggressively exclude generated / native / platform / boilerplate paths |
| "Draft detected — skipped" | `drafts: false` (default) | Set `auto_review.drafts: true` |
| "Rate limit exceeded" | Free tier ~3-5 reviews/hour | Wait, or upgrade plan, or commit less granularly |
| Review never delivered after trigger | Config on feature branch, not main | Land config on main first via chore PR |

## Recovery story

**Commits are the primary backup. Pushed branches are the secondary backup.**

Don't rely on agent-tool snapshots (Codex sessions, OpenCode local snapshots, Cursor history) — they exist on the same disk that runs destructive commands.

If an agent suggests `git clean -fdx`, `git reset --hard` (against uncommitted work), or `rm -rf` on the working tree: **commit first, then evaluate**. The cost of an extra commit is zero; the cost of recovering from a wipe is hours.

A real incident on this project's predecessor: an agent's "undo my last edits" command became `git clean -fdx`, which deleted every uncommitted file in the workspace — including hours of unrelated work from other agents. Recovery took ~30 minutes via OpenCode's local snapshot, but only worked because that snapshot existed by accident. **The fix is committing more often, not relying on better snapshots.**

## End-of-turn summary contract

Every turn that touches git ends with a one-or-two-line summary:
- What was committed (SHA + one-line message)
- Whether it was pushed
- PR state if changed (opened / merged / draft → ready)

No long retrospectives. No "what's next" unless the user asked.

## Minimum prompt to give a fresh agent

If you don't want to copy this whole file, the absolute minimum prompt that captures the spirit of the workflow:

> Auto-commit and push at every checkpoint and at the end of every phase. Open a PR per phase, squash-merge when the phase is complete and tests pass, then start the next phase on the same branch name re-pushed from main. Use chore branches for tooling fixes that need to land on main independently. Never force-push, never `git clean -fdx` or `git reset --hard` on uncommitted work, never merge a PR with failing checks. End every turn with a one-line summary of git state. Save this rule to memory so future sessions follow it without me re-asking.
