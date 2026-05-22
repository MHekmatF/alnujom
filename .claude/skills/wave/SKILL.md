---
name: "wave"
description: "Kick off a multi-agent parallel implementation wave for a set of spec phases. Dispatches each phase as an isolated worktree agent, auto-routes models, merges sequentially, runs analyze + tests, optionally runs Opus review, and (with --auto) chains to the next wave."
argument-hint: "<phase-list> [--auto] [--cap N] [--review on|off]"
compatibility: "Requires spec-kit project structure with .specify/ directory, an active <NNN>-<name> branch with tasks.md, and docs/MULTI_AGENT_WORKFLOW.md as the canonical operating playbook."
metadata:
  author: "almaeda"
  source: "docs/MULTI_AGENT_WORKFLOW.md"
user-invocable: true
disable-model-invocation: false
---

## User Input

```text
$ARGUMENTS
```

You **MUST** parse `$ARGUMENTS` before doing anything else. If empty, report the syntax and stop — do not guess phases.

## Syntax

```
/wave <phase-list> [--auto] [--cap N] [--review on|off]
```

- **`<phase-list>`** (required): `+`-separated phase numbers from the active spec's `tasks.md`. Examples: `1+2+3`, `5+6+7+12`, `8+10`. Special keyword **`all`** = let the orchestrator auto-plan the first wave from `tasks.md` and continue from there (only meaningful with `--auto`).
- **`--auto`** (optional): autonomous mode — chain to the next wave without waiting for user review. Off by default.
- **`--cap N`** (optional): concurrency ceiling for this wave. Default `4`. Max `6` (with justification). `>6` rejected.
- **`--review on|off`** (optional): override the post-merge Opus audit pass. Default `on` for code waves, `off` for tests-only waves.

## Canonical playbook

This command is a thin orchestration layer over [`docs/MULTI_AGENT_WORKFLOW.md`](../../docs/MULTI_AGENT_WORKFLOW.md). Read that file once before each invocation — it is the source of truth for caps, model auto-routing, conflict resolution, and the merge cascade. This SKILL.md just enforces the command shape and sequencing.

## Outline

### 0. Parse arguments

- Split `$ARGUMENTS` on whitespace.
- First token = phase list. Accept either:
  - Numeric list matching `^\d+(\+\d+)*$` (e.g., `1+2+3`), OR
  - The literal keyword **`all`** — defer first-wave selection to §1.5.
- Reject anything else with the syntax line above.
- Parse flags: `--auto`, `--cap <N>`, `--review on|off`.
- Validate: `--cap` integer in `[1, 6]`. If `> 4`, log a one-line justification before proceeding (see §3). If `> 6`, reject.
- If phase list is `all` **without** `--auto`: warn — `all` only makes sense in autonomous mode (otherwise it's identical to typing the first wave by hand). Recommend either adding `--auto` or naming the explicit first-wave phases. Do **not** dispatch; wait for the user's revised invocation.

### 1. Locate the active spec

- Run `git rev-parse --abbrev-ref HEAD` — capture the current branch.
- Active spec dir = `specs/<branch-name>/`. Fail loudly if it does not exist.
- Read `specs/<branch>/tasks.md` and `specs/<branch>/plan.md` (Required); `spec.md` (for context).
- If phase list is a numeric list: confirm each requested phase number exists in `tasks.md` under a heading matching `## Phase N` (or equivalent project convention). Reject if any missing.
- If phase list is `all`: enumerate every phase heading in `tasks.md`; mark each as done (`[X]` everywhere) or pending. Proceed to §1.5.

### 1.5. Resolve `all` to a concrete first wave (only when phase list = `all`)

- From the *Phase Dependencies* section of `tasks.md`/`plan.md`, find every phase whose dependencies are **all merged** (or empty).
- Take the **largest set with no edges between them** as the candidate first wave.
- Apply the cap (`--cap` value or 4 default): if the candidate set is bigger than the cap, truncate to the cap, preferring foundational/setup phases first, then phases that gate the most downstream work.
- Treat this resolved set as the phase list for the rest of the outline. Emit it in the plan-out (§3) so the user sees what `all` resolved to before dispatch.

### 2. Verify wave is dispatchable

- Read the spec's *Phase Dependencies* section (in `tasks.md` or `plan.md`).
- For each requested phase, list its dependencies.
- For every dep: confirm it's already merged into the current branch (search `git log --oneline -50` for the phase's commit pattern, OR check that the phase is marked `[X]` in `tasks.md`).
- If any dep is unmet → **STOP** and report which phase blocks which. Do not dispatch a partial wave.

### 3. Plan the wave

Produce a plan-out block in chat and proceed. Format:

```
Wave plan (spec: <branch>, mode: <gated | --auto>):
  Phase A (Sonnet, <one-line task profile>)   → worktree-agent-A
  Phase B (Sonnet, <one-line task profile>)   → worktree-agent-B
  Phase C (Opus,   <one-line task profile>)   → worktree-agent-C
Cap: <N> (default 4 | justified raise to <5|6>: "<one-line reason>")
Review pass: <on | off>
Merge order (least-touch-fan first): C → A → B
```

- **Model auto-routing**: per the heuristic in `docs/MULTI_AGENT_WORKFLOW.md` § *Auto-routing heuristic*. Sonnet by default; Opus when the task touches atomic transactions / state machines / RLS / invariants. **Never ask the user.**
- **Merge order**: smallest touch-fan first; the agent that edits l10n + hub + exports last (minimizes back-pressure).
- **Cap justification** (required only when `--cap` ≥ 5): explain why the phases are truly disjoint in one line, e.g., "6 tests-only phases each in its own package; no shared file edits."

### 4. Dispatch the wave

Issue **all** Agent calls **in a single message** (parallel `Agent` tool blocks) with:

- `isolation: "worktree"`
- `run_in_background: true`
- `model`: routed per §3
- `subagent_type: "general-purpose"` (unless a more specific agent type exists for the task profile)
- `description`: `"Phase N — <short>"`
- `prompt`: a **self-contained brief** (see *Self-contained prompts* in `docs/MULTI_AGENT_WORKFLOW.md`):
  1. Repo root absolute path
  2. Files to read first (paths only)
  3. Exact task IDs from `tasks.md`, exact file paths to create
  4. Conventions to mirror (name template files from prior phases)
  5. Cross-agent API contracts (paste interface signatures if a wave-mate is building a dependency)
  6. Known gotchas (l10n regen wipes manual edits — use extensions; build_runner regen)
  7. Self-verification commands the agent must run before reporting back (`flutter analyze --fatal-infos` + `flutter test` — both must SUCCESS; fix failures, never suppress)
  8. Exact commit-message format
  9. **Do NOT push. Do NOT merge.** (orchestrator merges)
  10. Report format: branch name, commit SHA, test count, anticipated merge hazards, under 200 words

### 5. Wait for all agents to complete

You will receive task-completion notifications as each agent finishes. Do **not** poll. When the last wave-mate reports done, proceed.

### 6. Merge cascade (orchestrator)

Per `docs/MULTI_AGENT_WORKFLOW.md` § *Orchestrator merge cascade*:

1. Verify each agent's worktree branch is based on the current spec branch HEAD.
2. Merge in the planned order: `git merge --no-ff <agent-branch> -m "merge: Phase N (<short>) from worktree"`.
3. Resolve conflicts per the playbook (ARBs union, regen l10n via `flutter gen-l10n`, regen codegen via `dart run build_runner build --delete-conflicting-outputs`, hub-screen union, exports union, tasks.md `[X]` union).
4. Regenerate codegen **after** all conflicts resolved.
5. Stage and commit the merge-resolution.
6. Run `flutter analyze --fatal-infos` — must SUCCESS.
7. Run `flutter test` — must pass.
8. Push the spec branch.

If analyze or tests fail: investigate the root cause. If it's a merge artifact, fix in place. If it's an agent's logic bug, **either** fix in place **or** roll back the merge and re-dispatch on Opus.

### 7. Review pass (if `--review on`)

Per `docs/MULTI_AGENT_WORKFLOW.md` § *Review pass*: dispatch 1–3 parallel Opus audit agents on the freshly merged code. Apply real-bug fixes; defer cosmetic gaps to `docs/ui_completion_backlog.md`.

Skip when `--review off` OR the wave was tests-only / docs-only.

### 8. Report status

Always emit a wave-close summary:

```
Wave <N> complete (spec: <branch>):
  Merged: <list of phases with commit SHAs>
  Tests: <count> passing
  Analyze: clean
  Pushed: <branch> @ <sha>
  Review pass: <findings count, fixes applied count>
  Mode: <gated | --auto>
```

### 9. Next-wave decision

- **If `--auto`** AND there are remaining unimplemented phases whose deps are now met:
  - Plan the next wave (same algorithm as §3).
  - Loop back to §4.
- **If `--auto`** AND no more dispatchable phases (spec complete):
  - Open the single end-of-spec PR per [`docs/AI_AGENT_WORKFLOW.md`](../../docs/AI_AGENT_WORKFLOW.md). Squash-merge once CI green.
- **If gated** (no `--auto`):
  - Stop here. Wait for the user's next instruction.

### 10. Halt conditions (for `--auto`)

Per `docs/MULTI_AGENT_WORKFLOW.md` § *When `--auto` halts*. In any halt case, emit a clear report explaining where the chain stopped and why, then wait for human input. **Do not bypass, do not force-push, do not skip hooks.**

## Operating principles

- **Do not ask the user to pick a model** — auto-route per the heuristic.
- **Do not type out long natural-language prompts** — the user invoked `/wave` precisely to avoid that. Read the playbook, plan, dispatch.
- **Cap is a hard ceiling** — don't sneak past it; if 5+ feels necessary, write the justification first.
- **Never skip hooks**, never `--no-verify`, never open mid-spec PRs.
- **Auto-compaction is automatic** — the harness compacts the orchestrator's conversation as it approaches context limits. Sub-agent contexts are per-dispatch and don't share with the orchestrator. No manual compaction needed.
