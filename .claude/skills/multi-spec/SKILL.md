---
name: "multi-spec"
description: "Orchestrate multiple independent specs in parallel, each running its own internal multi-agent wave via /wave. Dispatches one spec-orchestrator per spec in an isolated worktree, sequentially merges their end-of-spec PRs, and (with --auto) chains all of it without human review gates."
argument-hint: "<spec-list> [--auto] [--cap N] [--inner-cap N] [--review on|off]"
compatibility: "Requires spec-kit project structure with .specify/ directory, multiple <NNN>-<name> spec branches, docs/MULTI_SPEC_WORKFLOW.md as the canonical playbook, and the /wave skill installed."
metadata:
  author: "almaeda"
  source: "docs/MULTI_SPEC_WORKFLOW.md"
user-invocable: true
disable-model-invocation: false
---

## User Input

```text
$ARGUMENTS
```

You **MUST** parse `$ARGUMENTS` before doing anything else. If empty, report the syntax and stop — do not guess specs.

## Syntax

```
/multi-spec <spec-list> [--auto] [--cap N] [--inner-cap N] [--review on|off]
```

- **`<spec-list>`** (required): `+`-separated spec slugs (the `<NNN>-<name>` portion). Example: `011-listing-media+013-public-listing-details`.
- **`--auto`** (optional): autonomous across the full multi-spec run. Each spec orchestrator runs `--auto` internally; master orchestrator chains specs without waiting for human review.
- **`--cap N`** (optional): number of specs in parallel. Default `2`. Max `3` (with justification). `>3` rejected.
- **`--inner-cap N`** (optional): concurrency ceiling **inside each spec's wave**. Default `4`. Max `6`. Forwarded to internal `/wave` calls.
- **`--review on|off`** (optional): post-merge Opus audit pass per spec. Default `on`.

## Canonical playbook

This command is a thin orchestration layer over [`docs/MULTI_SPEC_WORKFLOW.md`](../../docs/MULTI_SPEC_WORKFLOW.md). Read that file once before each invocation — it is the source of truth for safety checks, topology caps, dispatch flow, and the sequential merge cascade. This SKILL.md just enforces the command shape and sequencing.

## Outline

### 0. Parse arguments

- Split `$ARGUMENTS` on whitespace.
- First token = spec list (`+`-separated slugs matching `^\d{3}[a-z]?-[a-z0-9-]+(\+\d{3}[a-z]?-[a-z0-9-]+)*$`). Reject otherwise.
- Parse flags: `--auto`, `--cap <N>`, `--inner-cap <N>`, `--review on|off`.
- Validate: `--cap` integer in `[1, 3]`; `--inner-cap` integer in `[1, 6]`. Reject out-of-range.

### 1. Pre-flight safety checks

Per [`docs/MULTI_SPEC_WORKFLOW.md`](../../docs/MULTI_SPEC_WORKFLOW.md) § *When is multi-spec safe?*. For every pair of specs in `<spec-list>`:

1. **No FR-level dependencies.** Skim each spec's `spec.md` for "depends on", "requires", "blocked by" pointing at another spec in the list.
2. **No shared migration files.** Confirm each spec's planned migrations are in disjoint date/sequence ranges.
3. **No shared core-domain type additions.** Skim `data-model.md` for each spec — flag overlapping entity names.
4. **No shared l10n keys.** Skim each spec's planned ARB additions if listed.
5. **Foundational baseline merged.** `git log main -10` should include the latest baseline commit; no pending baseline work in flight on `main`.

If **any** check fails → **STOP**. Report which specs collide on what, and recommend sequencing instead. Do not dispatch.

### 2. Master plan-out

Emit a plan block in chat:

```
Multi-spec plan (mode: <gated | --auto>):
  Spec A: <slug> → worktree branch <slug>, inner-cap <N>, --review <on|off>
  Spec B: <slug> → worktree branch <slug>, inner-cap <N>, --review <on|off>
  [Spec C: ...]
Cap: <N> specs (justified raise to 3: "<one-line reason>" if --cap 3)
Merge cascade order: <ordered list>
Master orchestrator: Opus (this session)
Spec orchestrators: Opus (each spawned via Agent + isolation: worktree)
```

### 3. Verify branches exist (or create them)

For each spec in `<spec-list>`:
- Check `git rev-parse --verify <spec> 2>/dev/null`.
- If missing, create from `main`: `git branch <spec> main`.
- Do **not** check out — the master orchestrator stays on `main`.

### 4. Dispatch spec orchestrators (single message, parallel)

Issue **all** spec-orchestrator `Agent` calls in **one message** with:

- `subagent_type: "general-purpose"`
- `isolation: "worktree"` — runtime creates a worktree on the spec branch
- `model: "opus"` — spec orchestrators always Opus (multi-step merge state)
- `run_in_background: true`
- `description: "Spec orchestrator — <slug>"`
- `prompt`: self-contained brief covering:
  1. Worktree absolute path; active spec slug.
  2. Files to read first: `specs/<slug>/{spec,plan,tasks}.md`, `docs/MULTI_AGENT_WORKFLOW.md`, `docs/MULTI_SPEC_WORKFLOW.md`, `docs/AI_AGENT_WORKFLOW.md`.
  3. Instruction: **invoke `/wave <phase-list>` repeatedly** to walk every phase. If master used `--auto`, pass `--auto` to each `/wave`. Pass `--cap <inner-cap>` if specified.
  4. Constraint: **do NOT push to `main`**. **Do NOT open a PR** — master orchestrator owns the PR step.
  5. Constraint: **do NOT touch `CLAUDE.md` active-feature pointer** — master orchestrator owns it.
  6. Halt conditions: blocked (failing tests after best-effort fix, schema decision needed) → stop and report. Do not bypass hooks, do not `--no-verify`.
  7. Final report: branch name, last commit SHA, total tests passing, list of waves completed, deferred backlog, anticipated cross-spec hazards, under 300 words.

### 5. Wait for all spec orchestrators

You will receive task-completion notifications as each spec orchestrator finishes. Do **not** poll. When the last spec reports done, proceed.

### 6. Sequential merge cascade

Per [`docs/MULTI_SPEC_WORKFLOW.md`](../../docs/MULTI_SPEC_WORKFLOW.md) § *Sequential merge cascade*:

For each spec in dependency order (or invocation order if disjoint):

1. `git checkout main && git pull origin main`.
2. Rebase/merge `main` into the spec branch on its worktree (or fetch + reset the worktree to spec HEAD then rebase).
3. Resolve any conflicts (rare; common files: `tasks.md` index, `CLAUDE.md` pointer, `pubspec.lock`).
4. On the spec branch: run `flutter analyze --fatal-infos` + `flutter test` — must pass.
5. Open the single end-of-spec PR per [`docs/AI_AGENT_WORKFLOW.md`](../../docs/AI_AGENT_WORKFLOW.md): `gh pr create ...`.
6. Wait for CI green.
7. Squash-merge: `gh pr merge <PR#> --squash --delete-branch`.
8. `git checkout main && git pull` to land the merge locally.

If a spec fails to merge (CI red after best-effort fix, unresolvable conflict): **stop the cascade**, leave remaining specs on their branches. Report.

### 7. Cross-spec review

Dispatch one Opus auditor across the combined diff (`git log main --since=<batch-start>`) looking for:

- Terminology drift between specs.
- Duplicate l10n keys that landed independently.
- Divergent UI patterns where one spec used pattern X and another used Y for the same UX.
- Cross-spec integration gaps (e.g., one spec reads from a table another spec added — is the read path correct?).

Apply real-bug fixes immediately; defer cosmetic gaps to `docs/ui_completion_backlog.md`.

### 8. Update memory + report

- Update `CLAUDE.md` active-feature pointer to the next planned spec OR to a "between specs" marker.
- Emit a final summary:

```
Multi-spec complete:
  Spec A: merged @ <sha>, <tests> tests, <waves> waves
  Spec B: merged @ <sha>, <tests> tests, <waves> waves
  [Spec C: ...]
Cross-spec review: <findings>, <fixes applied>
Main HEAD: <sha>
Mode: <gated | --auto>
```

### 9. Halt conditions (for `--auto`)

Per [`docs/MULTI_SPEC_WORKFLOW.md`](../../docs/MULTI_SPEC_WORKFLOW.md) § *Halt conditions*. Stop the chain on:

1. Pre-flight safety check fails → before dispatch.
2. Any spec orchestrator reports an unresolved blocker.
3. Sequential merge cascade fails on a spec → stop, leave subsequent specs on their branches.
4. Constitution / schema baseline decision required → stop, surface to user.

In every halt case, emit a clear report. Do not bypass, do not force-push, do not skip hooks.

## Operating principles

- **Specs must be truly independent** — when in doubt, sequence. Run `/wave` on one spec at a time instead.
- **Hard ceiling: 3 specs × 6 agents = 18 concurrent agents.** Never exceed.
- **Master orchestrator owns `main`, `CLAUDE.md`, and PR creation.** Spec orchestrators only commit to their own branch.
- **Spec orchestrators always Opus** — they manage internal multi-agent state.
- **Wave agents inside each spec follow `/wave`'s auto-routing** — Sonnet by default, Opus for irreducibly subtle work.
- **Auto-compaction is automatic** — the harness compacts when context approaches limits. Each spec orchestrator has independent context.
- **`--auto` does NOT grant** force-push, hook skipping, schema/constitution changes, or PRs against branches other than `main`.
