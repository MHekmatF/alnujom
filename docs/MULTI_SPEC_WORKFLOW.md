# Multi-Spec Workflow

A playbook for running **multiple independent specs in parallel**, each with its own internal multi-agent wave. Layered on top of [`MULTI_AGENT_WORKFLOW.md`](MULTI_AGENT_WORKFLOW.md): that doc handles parallelism *inside* one spec; this one handles parallelism *across* specs.

**Read this when:** you have ≥2 specs that are truly independent (no FR-level dependencies, no shared migrations, no shared core-domain types beyond what's already merged). Greenfield specs after a foundational spec has merged are the canonical case.

**Skip this when:** specs are sequential by nature (e.g., 011-listing-media depends on 010-listing-creation's tables that aren't merged yet), or any spec touches the constitution / schema baseline.

---

## TL;DR

1. **Invoke with `/multi-spec <spec-list> [--auto] [--cap N] [--inner-cap N]`** — see [`Multi-spec command`](#multi-spec-command).
2. **Each spec runs on its own long-lived branch** (`<NNN>-<name>`), per the standing cadence in [`AI_AGENT_WORKFLOW.md`](AI_AGENT_WORKFLOW.md).
3. **Each spec's orchestrator runs in its own worktree** and internally dispatches its own multi-agent waves via [`MULTI_AGENT_WORKFLOW.md`](MULTI_AGENT_WORKFLOW.md).
4. **Topology cap**: max **3 specs in parallel** × max **4 agents inside each** = 12 concurrent agents. Hard ceiling: 18 (3 × 6). Don't exceed.
5. **Sequential merge to main** — each spec opens its single end-of-spec PR; the master orchestrator merges them one at a time, rebases the next spec on the latest main, and continues.
6. **`--auto`**: lights-out across all specs. Default: stop at each spec close for review.

---

## When is multi-spec safe?

Multi-spec is only safe when the candidate specs satisfy **all** of:

1. **No FR-level dependencies.** Spec A doesn't reference a feature delivered by Spec B.
2. **No shared migration files.** If both touch `supabase/migrations/`, they collide on row IDs, table names, or trigger names. Sequence them.
3. **No shared core-domain type additions.** Adding the same entity from two sides causes `dart run build_runner` to produce divergent generated files.
4. **No shared l10n keys.** Both specs may add ARB entries, but not the *same* key.
5. **Foundational baseline merged.** If the baseline (db schema, app shell, navigation) is itself in flight, specs must wait.

Examples that **work**:
- 011-listing-media + 013-public-listing-details — each owns its own feature directory, tables, and screens; they read from already-merged listings tables.
- 014-search-filters + 015-map-view — both are query/display layers over already-merged data.

Examples that **don't work**:
- Two specs that both add new Supabase migrations — they will collide on migration ordering. Sequence them.
- Two specs that both add routes to the same go_router shell — they collide on the router configuration file on every wave merge. Sequence them.

When unsure: **sequence**. The cost of running two specs sequentially is lower than the cost of recovering from a corrupted merge.

---

## Topology

```
master orchestrator (Opus, main worktree)
  ├── spec A orchestrator (Opus, worktree on 011-listing-media branch)
  │     ├── Wave 1 agent (Sonnet, isolated sub-worktree)
  │     ├── Wave 1 agent (Sonnet, isolated sub-worktree)
  │     └── Wave 1 agent (Opus,   isolated sub-worktree)
  ├── spec B orchestrator (Opus, worktree on 013-public-listing-details branch)
  │     ├── Wave 1 agent (Sonnet, isolated sub-worktree)
  │     └── Wave 1 agent (Sonnet, isolated sub-worktree)
  └── spec C orchestrator (Opus, worktree on 014-search-filters branch)
        ├── Wave 1 agent (Sonnet, isolated sub-worktree)
        ├── Wave 1 agent (Sonnet, isolated sub-worktree)
        └── Wave 1 agent (Opus,   isolated sub-worktree)
```

- **Master orchestrator** = the user's main Claude Code session. It dispatches spec orchestrators.
- **Spec orchestrator** = an `Agent` invocation with `isolation: "worktree"` and a brief instructing it to run `/wave` waves on its assigned spec branch.
- **Wave agents** = standard sub-agents within the spec orchestrator's worktree (per `MULTI_AGENT_WORKFLOW.md`).

### Cap rules

| Level | Default | Max with justification | Hard ceiling |
|---|---|---|---|
| Specs in parallel | 2 | 3 | 3 |
| Agents per spec wave | 4 | 6 | 6 |
| Total concurrent agents | 8 | 12 | 18 |

**Never** exceed the hard ceiling. The orchestrator becomes the bottleneck and merge complexity grows non-linearly.

---

## Multi-spec command

The `/multi-spec` slash command is the canonical way to invoke this workflow.

### Syntax

```
/multi-spec <spec-list> [--auto] [--cap N] [--inner-cap N] [--review on|off]
```

- **`<spec-list>`** — `+`-separated spec slugs (the `<NNN>-<name>` portion). Examples: `011-listing-media+013-public-listing-details`, `014-search-filters+015-map-view`.
- **`--auto`** — autonomous across the full multi-spec run. Each spec runs `/wave ... --auto` internally; master orchestrator chains specs without waiting for human review at spec close.
- **`--cap N`** — number of specs in parallel. Default `2`. Max `3` (with justification).
- **`--inner-cap N`** — concurrency ceiling **inside each spec's wave**. Default `4`. Max `6`. Forwarded to `/wave` calls.
- **`--review on|off`** — override the Opus review pass after each spec close. Default `on`.

### Examples

```
/multi-spec 011-listing-media+013-public-listing-details
```
Run two specs in parallel; gated mode (stop at each spec close for user review).

```
/multi-spec 014-search-filters+015-map-view+016-saved-listings --auto
```
Lights-out across three specs. Each spec autopilots through its waves, opens its end-of-spec PR, master orchestrator merges sequentially, then starts review/wrap-up.

```
/multi-spec 014-search-filters+015-map-view --cap 2 --inner-cap 6
```
Two specs, each allowed up to 6 agents per wave (justified because both are display-only with disjoint files).

---

## Dispatch flow

### 1. Pre-flight (master orchestrator)

- Confirm each requested spec has a `specs/<spec>/` directory with `spec.md`, `plan.md`, `tasks.md`.
- Confirm each spec branch exists locally OR can be created from `main` via `git branch <spec> main`.
- Run the **safety checks** in [`When is multi-spec safe?`](#when-is-multi-spec-safe). If any fails, **stop** and report — propose sequencing instead.
- Confirm `main` is clean and at the expected baseline SHA.

### 2. Per-spec worktree creation

For each spec in `<spec-list>`:

- Create a worktree: `git worktree add ../<spec> <spec>` (or use `isolation: "worktree"` semantics on the Agent call so the runtime manages it).
- The spec orchestrator's working directory = its worktree.

### 3. Dispatch spec orchestrators

Issue **all** spec-orchestrator `Agent` calls in a **single message** (parallel):

```
Agent({
  description: "Spec orchestrator — <spec>",
  subagent_type: "general-purpose",
  isolation: "worktree",
  model: "opus",                              // orchestrators always Opus
  run_in_background: true,
  prompt: <self-contained spec-orchestrator brief — see below>,
})
```

### 4. Spec-orchestrator brief

Each spec orchestrator gets a self-contained brief:

1. Repo root absolute path (its worktree path).
2. Active spec slug.
3. Files to read first: `specs/<spec>/spec.md`, `specs/<spec>/plan.md`, `specs/<spec>/tasks.md`, `docs/MULTI_AGENT_WORKFLOW.md`, `docs/AI_AGENT_WORKFLOW.md`.
4. Instruction: **invoke `/wave` repeatedly** to walk through every phase in `tasks.md`. Use `--auto` if the master invocation included `--auto`; pass `--cap <inner-cap>` if specified.
5. Constraint: do **NOT** push to `main`. Do **NOT** open a PR yet — the master orchestrator opens the PR after all specs in the batch are done, OR per-spec at spec close (your choice; pick one and report).
6. Halt conditions: if the spec gets blocked (failing tests after best-effort fix, schema decision needed), stop and report — do not bypass.
7. Final report: branch name, last commit SHA, total tests passing, list of waves completed, any deferred backlog items.

### 5. Sequential merge cascade (master orchestrator)

Once all spec orchestrators report done:

1. Order specs by dependency (if any). If truly disjoint, alphabetical or invocation order.
2. For each spec, in order:
   a. Check out `main`.
   b. Pull latest (in case anything landed in parallel).
   c. Rebase the spec branch onto `main` if needed (or merge `main` into the spec branch).
   d. Resolve any conflicts (rare if the safety checks held; common files: `tasks.md` index, `CLAUDE.md` active-feature pointer, `pubspec.lock`).
   e. Run `flutter analyze --fatal-infos` + `flutter test` **on the spec branch** — must pass.
   f. Open the single end-of-spec PR per [`AI_AGENT_WORKFLOW.md`](AI_AGENT_WORKFLOW.md).
   g. Wait for CI green; squash-merge.
   h. Pull merged `main` locally.
3. Update `CLAUDE.md` active-feature pointer to the next planned spec (or to `none — between specs` if done).

If a spec fails to merge (CI red, conflict that can't be auto-resolved): **stop the cascade**. Report. Specs further down the list stay on their branches; nothing is lost.

### 6. Cross-spec review

After all specs merged: dispatch one Opus auditor across the combined diff for cross-spec drift (terminology drift between specs, l10n key duplication, divergent UI patterns between specs that landed in parallel).

---

## Autonomous mode (`--auto`)

`/multi-spec --auto` is the most permissive autonomy gate the workflow allows. It grants the master orchestrator standing authorization to:

- Dispatch all N spec orchestrators (each with its own `--auto`).
- Wait for completion notifications (no polling).
- Run the sequential merge cascade.
- Squash-merge each spec's PR once CI is green.
- Update memory / active-feature pointers.

It does **NOT** grant:

- Force-push, `--no-verify`, hook skipping, destructive git ops.
- Schema / constitution changes — any spec that requires one halts and reports.
- Opening PRs against branches other than `main`.
- Touching specs not in `<spec-list>`.

### Halt conditions

1. Pre-flight safety check fails → stop before dispatch.
2. Any spec orchestrator halts (blocked, failing CI) → stop the chain after merging whatever's already merge-ready.
3. Sequential merge cascade fails on a spec (CI red after best-effort fix, unresolvable conflict) → stop, leave subsequent specs on their branches.
4. All specs merged → master orchestrator reports done and waits.

---

## Failure modes & recovery

### Two specs both edit the same shared file

This should have been caught in pre-flight. If it slipped through:

- The later merge in the cascade hits a conflict.
- Resolve by hand: pick the union if both edits are additive; sequence and re-run if one is destructive.
- Add the file to the pre-flight safety check for next time.

### One spec's CI is red after merge

- Don't merge the next spec yet.
- Investigate: is it the spec's own bug, or did a conflict-resolution miss a regen?
- Fix on the spec branch, push, wait for CI green, then merge.
- Resume the cascade.

### Master orchestrator runs out of context

- Auto-compaction handles this — the harness compresses the master orchestrator's conversation when context approaches limits.
- Spec orchestrators each have independent contexts; their state is preserved on their worktree branches (commits) and reported back via final summaries.
- If the master orchestrator session dies entirely: each spec's work is durable on its branch. Resume by reading the spec branches' `tasks.md` (checkboxes) to see what's done.

### Two spec orchestrators want to update `CLAUDE.md` active-feature pointer

- They both should be told **not to** in their briefs. The master orchestrator owns that file.
- If they did anyway: the conflict surfaces at merge cascade time. Pick the "no active feature" state and move on.

---

## When not to use multi-spec

- **Just starting on this codebase.** Run one spec sequentially first, learn the conventions, then layer in multi-spec on greenfield work.
- **Constitution change in flight.** All specs depend on the constitution; serialize.
- **Schema baseline still moving.** Wait until db schema is stable.
- **CI is flaky.** Multi-spec amplifies CI noise; fix CI first.
- **Reviewer human-in-the-loop is unavailable** AND specs touch RLS or critical DB migrations. The Opus review pass catches a lot, but for schema-touching work, human review at spec close is cheap insurance.

---

## Portability notes

To adopt `/multi-spec` on another project:

1. Have a stable `<NNN>-<name>` branch + spec-kit `specs/<branch>/` layout.
2. Have `docs/MULTI_AGENT_WORKFLOW.md` and the `/wave` skill in place — multi-spec layers on top of them.
3. Pre-flight checks are project-specific (your shared files differ); update the safety-check list in step 1 to match what *your* specs touch.
4. Time-to-adopt: ~1 hour once the single-spec multi-agent flow is proven on this project.
