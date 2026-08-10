---
name: checkpoint-resume
description: Use when user types /checkpoint-resume or asks to pick up a task saved earlier with /checkpoint. Lists the current project's checkpoint org documents, reads the selected one, verifies its recorded world state against the repository as it is now (read-only), briefs the user, and stops for their direction. Resuming loads context — it never starts executing the task on its own.
argument-hint: "[topic|--all]  (default: list this project's documents)"
---

# /checkpoint-resume — reload a checkpointed task's context

This skill restores a task saved by `/checkpoint`: an org document under `$CLAUDE_CHECKPOINT_DIR` (default `~/org/checkpoints`) holding the task's context, conclusions, world state, and next steps. The document was written for a session with zero prior context — read it as the task's source of truth, but verify its recorded world state, because the world moves between sessions.

**Resuming loads context; it does not execute.** The outcome of this skill is a briefed user and a session ready to act — the acting itself starts only when the user says what to do next. Until then, take no action that modifies anything — the working tree, the repository, external services, trackers, or documents — no matter how obvious the first next step looks. (This rule is restated once more at the stop in step 5 — deliberately: a single mention tends to lose to the default bias toward acting.)

**Next steps are not standing authorization.** This holds even after the user directs work: a step's wording was written mid-session, where conversational gating was implicit, and replaying it cold does not carry that authority. Re-confirm outward-facing or hard-to-reverse actions — anything that publishes, sends, deletes, or otherwise changes state beyond the session — with the user in this session before executing them, however imperatively the step is phrased ("review and apply X" authorizes the review, not the apply).

**Announce when you start**: tell the user you're resuming; name the document once step 2 selects it.

## Where to invoke from

**The scripts scope themselves by the working directory**: they resolve the project via `git rev-parse --show-toplevel` of the CWD, falling back to the CWD itself outside a git repository. Make sure the working directory is inside the target project before invoking them — usually it already is; `cd` first only when it is not (for example when the shell sits in a nested or unrelated repository).

The scripts live next to this file, not in the project — `scripts/list.sh` below means `<this skill's directory>/scripts/list.sh`; invoke them by that absolute path from the project root.

## Procedure

1. **List documents**: run `scripts/list.sh` (add `--all` when the user asks for tasks across all projects). Output is TSV, one record per document: `<abs-path>`, `<state>` (root heading's TODO keyword), `<modified>` (`:MODIFIED:` property), `<title>`. When no documents exist it prints nothing on stdout and says so on stderr — a normal outcome, not an error.
2. **Select**:
   - The user passed a topic argument → match it case-insensitively as a substring of file name and title. One match: proceed. Several: show them and ask. None: show the full listing and ask.
   - No argument, exactly one `TODO` document → select it and say so — everything through the brief is read-only, so no confirmation is needed first.
   - No argument, several → present the listing (state, modified, title) and ask which to resume.
   - No documents at all → say so; suggest `--all` in case the task was saved under a different project, and `/checkpoint` for starting to record one.
3. **Read the selected document fully.**
4. **Verify world state — strictly read-only**:
   - `:COMMIT:` present → check ancestry first: `git merge-base --is-ancestor <commit> HEAD`. If it is an ancestor, `git log --oneline <commit>..HEAD | head -15` gauges the drift; if it is not (history diverged — HEAD may be a different branch now) or the commit is unknown (rebased away, different clone), say so — an empty log in those cases is not "no drift".
   - Check that files the document links still exist, and spot-check load-bearing claims (a function it names still present, a config value unchanged).
   - PRs or issues referenced → check current state with `gh` when available.
   - Follow the document's own **Resume notes** section — it lists exactly what its author considered fragile — but only its read-only checks.
   - Drift is reported, not repaired — verification changes nothing.
5. **Brief, then stop**: summarize to the user what the document records, the drift found, and the standing entries under `Open questions` — a conclusion contradicted by the current code is flagged, not silently re-planned. Present `Next steps` as the menu of pending work, recommend which step you'd take first, and **stop — the user chooses**. Not even an "obviously safe" first step starts without them: the user resumes the task; you restore its context.
6. **Keep the document current once work resumes**: after the user directs work and it progresses, update the document at milestones the way `/checkpoint` would — completed steps become `DONE`, new decisions land in Conclusions, `:COMMIT:` and `:MODIFIED:` are refreshed (run `scripts/where.sh`, which prints `<key><TAB><value>` lines — take the `commit` and `now` fields; the `commit` line is absent outside a git repository), and the root heading becomes `DONE` when the task finishes. The document outlives the session; leave it accurate. Preserve any user edits found in the file.

## Document format essentials

Everything is plain org — no custom markup. The root heading's TODO keyword is the task status (`TODO` active, `DONE` finished). Its property drawer holds `:CATEGORY:` (short project slug), `:PROJECT_ROOT:`, `:COMMIT:` (short local HEAD at last save — a drift anchor, not necessarily what the document's claims rest on), `:MODIFIED:` (inactive timestamp with time of the last save; the file-level `#+date:` is the creation date and never changes). Directly under the drawer sits a short status paragraph — where the task stands right now; read it first. Sections, each present only when it has content: Goal, Conclusions, Findings, Open questions, Work done (including dead ends), World state, Next steps (`*** TODO` subheadings), Resume notes. The full contract — format, prose, and update rules — lives in the sibling checkpoint skill: read `../checkpoint/SKILL.md`, resolved against this skill's directory, whenever these essentials aren't enough.
