# Multi-Agent Workflow

A portable playbook for parallelizing spec implementation across multiple Claude Code sub-agents. Conventions evolved across spec 006-purchasing; reusable from **Phase 1 onwards** for any spec with weakly-coupled phases.

**Read this when:** you're about to start a spec with ≥3 phases that have weak inter-dependencies. **Skip this when:** the work is a single bugfix, a one-file refactor, or sequential by nature.

This file is companion to [`AI_AGENT_WORKFLOW.md`](AI_AGENT_WORKFLOW.md) — that one covers the git workflow (single end-of-spec PR, no mid-spec PRs, etc.); this one covers the **execution topology** (how many agents, which model, in what order). For running **multiple specs in parallel**, see [`MULTI_SPEC_WORKFLOW.md`](MULTI_SPEC_WORKFLOW.md).

---

## TL;DR

1. **Invoke with `/wave <phase-list> [--auto]`** — see [`Wave command`](#wave-command) below. Example: `/wave 1+2+3` dispatches Phases 1, 2, 3 in parallel. `--auto` chains review gates without waiting.
2. **Plan the wave** by reading the spec's `tasks.md` § *Phase Dependencies* — find the largest set of phases with no edges between them.
3. **Dispatch each phase as its own sub-agent** with `isolation: "worktree"` so they don't step on each other.
4. **Auto-route the model per agent**: Sonnet by default; Opus when the task profile requires it (see [`Model selection`](#model-selection)). The orchestrator picks per-agent — user does not specify.
5. **Orchestrator stays on Opus** — merges worktree branches sequentially, resolves predictable conflicts (l10n, hub screen, exports, tasks.md), regenerates codegen, runs `flutter analyze --fatal-infos` + tests, pushes once green.
6. **Review pass** on Opus after the merge — 1-3 parallel audit agents surface real bugs. Skipped for tests-only waves.
7. **Auto-compaction** of the orchestrator's conversation happens automatically when context approaches limits — no manual action needed. Sub-agent contexts are independent and reset per dispatch.

---

## When to fan out vs. stay sequential

### Fan out (parallel) when:
- Phases touch **disjoint code paths** (different services, different feature directories).
- The spec's *Phase Dependencies* section lists ≥2 phases that can run independently.
- Phases are mostly **verification + documentation** (those are cheap to parallelize because they don't fight over shared files).
- A wave will save ≥30 minutes of wall-clock time after accounting for merge conflicts.

### Stay sequential when:
- A phase depends on another phase's public surface (the dependent agent doesn't see the in-flight surface).
- The phase touches **central files** (e.g., a registry, a switch in a router) that every concurrent agent would also touch — every concurrent edit becomes a merge conflict.
- The work is a **single integration task** rather than a parallelizable decomposition.

### Cost model (rough):
- 4 agents in parallel → ~40–50% wall-clock savings vs. sequential, **after** subtracting ~15–30 min of orchestrator merge-conflict resolution.
- 2 agents in parallel → ~30% savings.
- 6+ agents in parallel → diminishing returns; merge complexity grows superlinearly. Stop at 4 unless the phases are truly disjoint (tests-only verifications).

---

## Phase decomposition

Read the spec's `tasks.md` for the dependency graph. **Multi-agent fan-out works from Phase 1** onwards — there is nothing special about starting mid-spec. If the spec's first three phases are independent (e.g., scaffolding + l10n + DB migration with no cross-edges), dispatch them as Wave 1 from a cold start.

Generic shape:

```
Phase A → no deps
Phase B → no deps                  ← Wave 1 (A, B, C in parallel)
Phase C → no deps
Phase D → depends on A             ← Wave 2 starts after A merges
Phase E → depends on A + B
Phase F → depends on C + E         ← Wave 3 after E merges
```

Concrete example (006-purchasing, mid-spec):

```
Phase 6 → depends on Phase 5
Phase 7 → depends on Phase 4 only
Phase 9 → depends on Phase 4 + 5 + 12  ← BLOCKED until 12 done
Phase 12 → depends on Phase 4
```

**Group into waves** — a wave is a set of phases that can run concurrently. Pick the largest independent set first, defer trivial verification phases to a later wave (they parallelize cheaply against larger phases).

### Cap rules

- **Default ceiling: 4** concurrent agents per wave. Beyond 4, orchestrator merge-conflict overhead exceeds parallelism gain.
- **Maximum: 6** — only when phases are *clearly* disjoint (e.g., 6 tests-only phases each in its own package). Requires explicit orchestrator decision in the wave's plan-out, with one-line justification in the dispatch comment.
- **Never uncap.** Beyond 6, the orchestrator becomes the bottleneck and merge complexity dominates.

The `/wave` command enforces these caps: passing `--cap 7+` rejects; `--cap 5` or `--cap 6` requires the orchestrator to log a justification line before dispatching.

---

## Model selection

| Task profile | Model | Reasoning |
|---|---|---|
| Mechanical test-writing against a known service contract | **Sonnet** | Pattern-matching task; cheap; usually one-shot correct |
| L10n key additions (ARB files + gen-l10n) | **Sonnet** | Mechanical; the only risk is typos |
| ADR documents | **Sonnet** | Prose; the structure is templated |
| Verification-only phases (e.g., "prove the invariant holds") | **Sonnet** | Reading code + writing tests; rarely needs deep reasoning |
| New CRUD UI screens following an established pattern | **Sonnet** | Mirror existing screens; bloc/state pattern is templated |
| **Atomic db.transaction services** with rollback semantics | **Opus** | Subtle invariants; one missed branch silently corrupts data |
| **Novel state machines** with error-routing across multiple variants | **Opus** | The branch matrix is non-obvious; Sonnet tends to miss edge cases |
| **Cross-agent integration / merge-conflict resolution** | **Opus** | Multi-file reasoning; the orchestrator's job |
| **Deep review of a freshly merged phase** | **Opus** | Catches semantic bugs Sonnet's pattern-match misses (e.g., precision loss in SQL aggregations, missing per-line audit rows) |
| **Performance / invariant audits** | **Opus** | Requires holding the whole data model in head |

**Default rule:** implementation → Sonnet; review → Opus. **The orchestrator auto-routes** based on the task profile above — user does **not** need to specify a model when invoking `/wave`. The orchestrator inspects each phase's task list and picks Sonnet vs. Opus per agent, then logs the routing decision in the dispatch comment.

**Cost rough order-of-magnitude:** Opus ≈ 3-5× Sonnet per token. So routing the 60-70% of work that's mechanical to Sonnet is a real cost win.

### Auto-routing heuristic the orchestrator applies

For each phase the orchestrator is about to dispatch:

1. Read the phase's tasks in `tasks.md`.
2. Check for any of these signals → escalate to **Opus**:
   - Phrases: "atomic transaction", "rollback", "invariant", "state machine", "cross-currency", "concurrent", "ordering guarantee".
   - Files: anything under a `services/`, `posting/`, `ledger/`, or `gl/` path; anything touching FX, balance-sheet, period-close logic.
   - Tests with `_invariant_`, `_atomic_`, `_immutability_`, `_rls_` in the filename.
3. Otherwise → **Sonnet**.
4. Mid-wave promotion: if a Sonnet agent reports "I had to assume X" or its output needs >1 round of orchestrator-side correction, re-dispatch the same phase on Opus before merging. Log the promotion.

### Auto-routing for the orchestrator itself

The orchestrator runs on whatever model the human user invoked Claude Code with. For autonomous waves (`--auto`), recommend Opus — it must hold the multi-agent merge state in mind without a human in the loop.

---

## Wave command

The `/wave` slash command is the canonical way to invoke this workflow. It replaces typing out a long natural-language prompt like *"/speckit-implement Phases 5+6+7, I must review when done, I will let you know when to proceed"*.

### Syntax

```
/wave <phase-list> [--auto] [--cap N] [--review on|off]
```

- **`<phase-list>`** — `+`-separated phase numbers from the active spec's `tasks.md`. Examples: `1+2+3`, `5+6+7+12`, `8+10` (later wave). Special keyword **`all`** = orchestrator picks the first wave from `tasks.md` automatically; only meaningful with `--auto`.
- **`--auto`** — autonomous mode (see below). Default: off (orchestrator stops after each wave for user review).
- **`--cap N`** — concurrency ceiling. Default 4; max 6 with justification; values >6 rejected.
- **`--review on|off`** — run the Opus audit pass after merge. Default `on` for code-bearing waves, `off` for tests-only waves. Override when needed.

### Examples

```
/wave 1+2+3
```
Dispatch Phases 1, 2, 3 in parallel from a cold start. Orchestrator stops after merge for user review before next wave.

```
/wave 5+6+7+12 --auto
```
Dispatch four phases, merge sequentially, run review pass, then immediately plan + dispatch the next wave without waiting. Good for overnight runs.

```
/wave 8+10 --review off
```
Tests-only wave; skip the Opus audit pass.

```
/wave 4+5+6+7+8+9 --cap 6
```
Six phases truly disjoint (e.g., one per package); orchestrator must log justification before dispatching.

```
/wave all --auto
```
Full autopilot from a cold start. Orchestrator reads `tasks.md`, picks the first dispatchable wave (largest set of phases with no unmet deps, capped at 4 by default), dispatches it, and chains every subsequent wave until the spec is done and the end-of-spec PR is squash-merged.

### What the command does

1. Loads `tasks.md` from the active spec branch; verifies every requested phase exists and its dependencies are merged.
2. Plans the wave: assigns each phase a worktree branch name and a model (Sonnet vs. Opus per the auto-routing heuristic).
3. Dispatches all wave-mate agents in a single message (parallel `Agent` tool calls with `isolation: "worktree"`, `run_in_background: true`).
4. As agents complete, orchestrator merges them in order of least-touch-fan first.
5. Resolves conflicts (per the playbook below), regenerates codegen, runs `flutter analyze --fatal-infos` + tests.
6. Pushes the spec branch.
7. If `--review on`: dispatches the Opus audit pass.
8. If `--auto`: plans the next wave and repeats. Otherwise: reports status and stops.

---

## Autonomous mode (`--auto`)

By default, `/wave` stops after each merged wave and waits for user review. This is the gated mode — useful when the human wants to inspect each phase before the next dispatches.

`--auto` flips the gate **off**. The orchestrator chains waves automatically: as soon as Wave N is merged + pushed + reviewed, it plans Wave N+1 and dispatches without asking. Use this for **lights-out / overnight builds**.

### What standing authorization `--auto` grants

For the duration of the command:

- Plan and dispatch subsequent waves without re-asking
- Run the Opus audit pass and apply trivial fixes (typos, missing test cases) without confirmation
- Continue through the spec until either: (a) all phases complete, (b) a wave fails analyze/tests after the orchestrator's best repair attempt, (c) a phase reports it cannot proceed without human input

It does **NOT** grant:

- Skipping CI failures, hooks, or `--no-verify` — still investigate and fix
- Opening mid-spec PRs — still single end-of-spec PR per [`AI_AGENT_WORKFLOW.md`](AI_AGENT_WORKFLOW.md)
- Force-push or any destructive git op
- Schema / constitution / spec edits — those still require human input

### When `--auto` halts

The orchestrator stops the chain and reports if:

1. Analyze or tests fail after a merge **and** the orchestrator's repair attempt also fails.
2. A sub-agent reports an unresolved blocker (e.g., "the spec says X but the code requires Y; need clarification").
3. The next wave would require a constitution / schema decision the orchestrator can't make alone.
4. The spec is fully implemented — orchestrator opens the single end-of-spec PR and stops.

In every halt case, the user finds a clear report explaining where it stopped and why.

### Gated vs. autonomous: when to pick which

| Situation | Mode | Why |
|---|---|---|
| First time using `/wave` on a new spec | gated | Verify the wave plan is right before committing to the autopilot |
| Mid-spec, you're staying online | gated | Cheap to review each wave; catches drift early |
| Overnight / weekend / "I'm going to sleep" | `--auto` | Maximize wall-clock progress |
| Spec is mostly tests + ADRs + verification | `--auto` | Low risk of subtle bugs; review pass catches what matters |
| Spec touches GL / balance sheet / RLS / migrations | gated | These are the irreducibly subtle parts; human review is cheap insurance |

---

## Dispatch pattern

Use `Agent` tool with `isolation: "worktree"` for every parallel agent. The runtime creates a separate git worktree on a fresh branch (`worktree-agent-<id>`) so the agent works in its own copy of the repo.

```
Agent({
  description: "Phase N — <short>",
  subagent_type: "general-purpose",
  isolation: "worktree",
  model: <auto-routed per auto-routing heuristic>,  // "sonnet" or "opus"
  prompt: "<self-contained prompt — see below>",
  run_in_background: true,        // dispatch all wave-mates at once
})
```

The orchestrator picks `model` per agent — never asks the user. It logs the routing decision in the dispatch summary: `"Wave 1: Phase 1 (Sonnet, scaffolding) | Phase 2 (Sonnet, l10n) | Phase 3 (Opus, atomic posting service)"`.

### Self-contained prompts

Each agent starts with **zero context** from the orchestrator's conversation. Briefing it like a smart colleague who just walked in:

1. **Repo root** (absolute path).
2. **Files to read FIRST** (don't dump them into prompt; just list paths — agents will read what they need).
3. **Scope** — exact task IDs from `tasks.md`, exact file paths to create.
4. **Conventions to mirror** — name one or two existing files from prior phases as templates ("read `listing_form_bloc.dart` first to internalize the BLoC pattern").
5. **Cross-agent API contracts** the agent should code against — if Wave-mate B is building a widget you depend on, paste the interface (constructor signature, exported types) directly in the prompt so the agent doesn't have to guess.
6. **Known gotchas** — e.g., l10n regen wipes manual edits; put extensions in a separate file.
7. **Self-verification before reporting back** — `flutter analyze --fatal-infos` + `flutter test` must both be SUCCESS. State: "If a test fails, FIX it (don't suppress)."
8. **Final commit** — exact commit-message format. "Do NOT push. Do NOT merge." (orchestrator merges)
9. **Report format** — branch name, commit SHA, test count, anticipated merge hazards, under N words.

**Anti-pattern:** terse command-style prompts ("implement Phase 7"). Sonnet wastes tool calls exploring; Opus stays vague. Always front-load the context.

---

## Worktree isolation rules

Each agent gets its own worktree. Inside its worktree, it can:
- Read any file
- Modify any file (including shared files like ARBs, hub screens, exports — these become merge conflicts the orchestrator resolves)
- Run `flutter test`, `flutter analyze`, `dart run build_runner`, `flutter gen-l10n`
- Commit to its worktree branch

It must NOT:
- `git push` (orchestrator pushes)
- `git merge` to the main branch (orchestrator merges)
- `git rebase` (could rewrite shared history)
- Edit files outside the repo (no global config touches)

If two agents would BOTH touch a file that's load-bearing for both (e.g., a shared BLoC event file with two new event types), warn them up front — they can both add their types, and the orchestrator unions on merge.

---

## Orchestrator merge cascade

After all wave-mate agents complete (each on its own worktree branch with one commit), the orchestrator:

1. **Verify each agent's branch is based on the current `main-spec-branch` HEAD** (not on `main` or some stale point). Worktrees are sometimes created on the wrong base — check `git log --oneline <branch> -3` and confirm the spec's last commit is in its ancestry.
2. **Order the merges from least to most touch-fan.** Smallest agent first; largest (the one that touches l10n + hub + exports) last — minimizes back-pressure.
3. **For each branch**: `git merge --no-ff <branch> -m "merge: Phase N (...) from worktree"`. Take the conflict prompts as they come.
4. **Resolve conflicts** (playbook below).
5. **Regenerate codegen** AFTER all conflicts resolved (`dart run build_runner build --delete-conflicting-outputs`, `flutter gen-l10n`). Stage the regenerated files.
6. **Run** `flutter analyze --fatal-infos` — must SUCCESS.
7. **Run** `flutter test` — must pass.
8. **`git push`** to the spec branch.

If analyze or tests fail after a merge, **diagnose and fix** — don't bypass. If the failure is in an agent's logic (not a merge artifact), surface it and either fix in place or roll back the merge and re-dispatch that agent.

---

## Conflict resolution playbook

These conflicts recur for every UI-bearing phase. Resolve as follows:

| File | Conflict pattern | Resolution |
|---|---|---|
| `app_en.arb` + `app_ar.arb` | Both sides add new key blocks | **Union** — keep both blocks; remove `<<<<<<<` / `=======` / `>>>>>>>` markers |
| `app_localizations*.dart` (generated) | All three files diverge | **Don't hand-merge.** Just resolve the ARBs, then `flutter gen-l10n` overwrites cleanly |
| `*.freezed.dart` (generated) | Diverged | Not applicable — this project has no `freezed` dependency. If encountered unexpectedly, resolve the source `.dart` file then `dart run build_runner build --delete-conflicting-outputs` |
| Hub/nav screen (e.g., `publisher_dashboard_page.dart`) | Both sides add a tile or route | **Union** — keep both tiles/entries; both factory methods below |
| Export barrel files (`*.dart` export lists) | Both sides add exports | **Union** — alphabetical order; drop conflict markers |
| `tasks.md` | Both sides mark off different task IDs | Usually auto-merges. If not, take both sets of `[X]` marks |

After every merge step, run `git status` to verify no markers remain. Run `grep -rn "<<<<<<<\|=======\|>>>>>>>" .` if in doubt.

---

## Review pass

After the merge cascade lands, optionally dispatch **1-3 parallel Opus audit agents** for a deep review. Skip if the merged wave was tests-only (Phase 8, 10).

**Pattern:**
- One audit agent reads the new service code looking for subtle bugs (precision loss, missed audit rows, off-by-one validation order).
- One reads the new UI looking for unwired callbacks, missing form fields, error-routing gaps (the `feedback_proactive_gap_audit` rule from memory).
- One reads the new tests looking for coverage gaps vs. the spec's acceptance scenarios.

Each audit agent reports:
- **Real bugs** — orchestrator fixes immediately.
- **Anticipated false positives** — orchestrator pushes back and documents why.
- **Coverage gaps** — orchestrator adds one or two tests if cheap; defers the rest to `docs/ui_completion_backlog.md` (or equivalent).

**Don't review everything.** Audit the load-bearing slices — atomic-transaction services, invariant tests, anything that touches the DB schema or RLS policies.

---

## Commit cadence

Per [`AI_AGENT_WORKFLOW.md`](AI_AGENT_WORKFLOW.md):
- **One commit per agent worktree** (the agent itself commits).
- **One orchestrator commit per merge** (the `--no-ff` merge commit captures the integration).
- **One push per wave** — push the spec branch after the wave's merge cascade is green.
- **No PRs mid-spec.** Single end-of-spec PR per the standing authorization. Squash-merge once CI green.

Each phase's commit message:

```
feat(<spec>): Phase N — <USX short title> (T<first>-T<last>)

<2-4 bullet summary of deliverables>

Verification: flutter analyze clean; <N> new tests pass.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

Merge commits:

```
merge: Phase N (USX — <short>) from W<wave>-<letter> worktree
```

---

## Lessons learned (spec 006-purchasing, source project)

> These lessons are from the source project (almaeda-system-project) where this workflow was developed. The structural lessons (test harness ordering, SQL precision, gen-l10n extension pattern) transfer directly; the specific file names and service patterns do not.

- **Test harnesses may need special seeding order.** If a migration only applies a flag when a prerequisite row exists, and your test inserts that prerequisite AFTER migrations run, the flag won't be set in-memory. Mirror the correct seeding order in every new harness.
- **SQL aggregation precision**: `SELECT SUM(numeric_col) AS total` cast to Dart `double` silently loses precision on totals > 10^7. Use `printf('%.4f', COALESCE(SUM(col), 0)) AS total` SQL-side + `Decimal.parse(result.read<String>('total'))` Dart-side.
- **gen-l10n wipes manual edits.** Any helper on the generated `AppLocalizations` class must live in an `extension` in a separate file, never hand-edited into `app_localizations*.dart` (the file is regenerated on every `flutter gen-l10n`).
- **Cross-agent import collisions on common names**: if two packages both export a type with the same name (e.g., `Currency`, `Listing`), any file importing both needs explicit `hide` clauses on one side.

---

## Portability notes (using this workflow on another project)

To adopt this workflow on a new project:

1. Ensure the spec has a `tasks.md` with an explicit **Phase Dependencies** section. Without it, decomposing into waves is guesswork.
2. Establish conventions early: a clear template for BLoC/screen files, a clear repository/datasource split. Agents copy templates; if there's no template, every agent invents a slightly different one and merges are painful.
3. Pick one l10n approach (this project uses `flutter_localizations` + ARB + `flutter gen-l10n`) and one codegen approach (`injectable_generator` for DI). Document them in `CLAUDE.md` so agents pick them up automatically.
4. Maintain a memory file (this project's `memory/MEMORY.md`) capturing project-specific gotchas. Agents read it via the host's auto-memory system.

Time-to-adopt on a fresh project: ~1-2 hours to set up the conventions; ~30 min per wave once running. Worth it once you've crossed 3 spec-sized features.
