---
name: checkpoint
description: Use when user types /checkpoint or asks to save the current task's state — design conclusions, research findings, open questions, work already done, a PR queue, an improvement backlog — into a resumable document. Creates or updates a per-project org file outside the repository, using only plain org-mode conventions (TODO keywords, property drawers, timestamps, links). The companion /checkpoint-resume skill reads these documents back in a later session.
argument-hint: "[topic]  (default: derive from the discussion)"
allowed-tools: [Bash, Read, Write, Edit]
---

# /checkpoint — save the task's state as a resumable org document

This skill distills the current task's state into an org document that a future session — with zero conversation context — can read to resume the task. Task state is more than conclusions; the document captures four things: **where the task is going** (the goal), **what is known** (conclusions, findings, open questions), **what has been done** (work applied, dead ends, next steps), and **how to pick it up** (current status, world state, what to re-verify). Documents live **outside any project repository**, under `$CLAUDE_CHECKPOINT_DIR` (default `~/org/checkpoints`), one directory per project, one file per topic; the per-project directory is named by the project's absolute path flattened into one token (`/home/user/projects/my-app` → `-home-user-projects-my-app`), so equally-named projects in different locations never collide. They belong to the user: they are plain org files the user reads, edits, and syncs with their normal org tooling, and user edits are always preserved.

**Announce when you start**: tell the user you're checkpointing; name the target document once the procedure resolves it — an existing file found in step 2, or the slug composed in step 3.

## When to use

When the user invokes `/checkpoint`, or asks to save the discussion state to a document. Suggesting a checkpoint at a natural milestone is welcome; writing one unasked is not. Never write these documents into the project repository.

## Where to invoke from

**The scripts scope themselves by the working directory**: they resolve the project via `git rev-parse --show-toplevel` of the CWD, falling back to the CWD itself outside a git repository. Make sure the working directory is inside the target project before invoking them — usually it already is; `cd` first only when it is not (for example when the shell sits in a nested or unrelated repository).

The scripts live next to this file, not in the project — `scripts/where.sh` below means `<this skill's directory>/scripts/where.sh`; invoke them by that absolute path from the project root.

## Procedure

1. **Resolve locations**: run `scripts/where.sh`. It prints `base`, `project` (short human-readable slug — the `:CATEGORY:` value), `tag` (org-tag-safe slug), `root` (absolute project root), `dir` (this project's document directory, named by the flattened `root`), `today` (the current date as a ready-made inactive org timestamp), `now` (the same with time), and `commit` (short HEAD — the line is absent outside a git repository or before the first commit) as TSV.
2. **Check for an existing document**: run `scripts/list.sh`. It prints one TSV record per document — `<abs-path>`, `<state>` (the root heading's TODO keyword), `<modified>` (the `:MODIFIED:` property), `<title>` — and when no documents exist yet it prints nothing on stdout and says so on stderr: a normal outcome, not an error. Compare the topic — the argument the user passed, or the one you derive from the discussion when none was given — against the listed file names and titles. If an existing document covers the topic, **update it — never create a near-duplicate**. When in doubt whether two topics are the same, ask.
3. **Compose the topic**: a short human-readable title (this becomes `#+title:` and the root heading) and its kebab-case slug (this becomes the file name, e.g. `modeline-redesign.org`). The slug is stable across updates — never rename on update.
4. **Gather world state**: `:PROJECT_ROOT:` and `:COMMIT:` come straight from `where.sh`'s `root` and `commit` fields (no `commit` line → omit the `:COMMIT:` property), plus whatever facts the document's claims rest on — branch names, PR numbers, key file paths.
5. **Write the document** (`mkdir -p` the project directory first) following the format below. For updates, Read the existing file fully first and follow the update rules.
6. **Report**: give the user the absolute path, whether it was created or updated, and a one-line summary of what it now records. End with the exact command that reloads the task's context in a future session — `/checkpoint-resume <topic-slug>` with the actual slug substituted, ready to paste (the companion skill ships in this same plugin).

## Document format

Everything in the document is expressed with plain org-mode conventions — file keywords, headings with TODO keywords, property drawers, inactive timestamps, org links, and prose. **Never invent metadata syntax on top of org**: no YAML front matter, no HTML/markdown, no custom `key: value` lines outside a property drawer.

```org
#+title: Cache layer redesign
#+filetags: :checkpoint:my_app:
#+date: [2026-08-09 Sun]

* TODO Cache layer redesign
:PROPERTIES:
:CATEGORY: my-app
:PROJECT_ROOT: /home/user/projects/my-app
:COMMIT: 1a2b3c4
:MODIFIED: [2026-08-09 Sun 14:05]
:END:

Where the task stands right now, in two or three sentences — the first thing
a resuming session reads. Refreshed on every save.

** Goal
The problem, why it matters, and what finished looks like — including
explicit non-goals when scope was deliberately cut.

** Conclusions
Decisions reached, each with its rationale — including rejected alternatives
and why they lost, since "why not X" is what evaporates first.

** Findings
Evidence gathered that isn't itself a decision: measurements, benchmark
numbers, documentation excerpts as #+begin_quote blocks with a source link,
API facts.

** Open questions
Undecided items, each with what the decision waits on — user input, an
experiment, an upstream release.

** Work done
Changes already applied: commits as short-sha plus subject, PRs opened, files
touched. Include dead ends — approaches tried and abandoned, and why — so no
future session re-treads them.

** World state
Facts observed at save time that the rest of the document rests on: branch
names, PR state ([[https://github.com/user/repo/pull/42][PR #42]]), key files
as org links ([[file:/home/user/projects/my-app/src/cache.c::42][cache.c:42]]),
plus the task's own working state — checked-out branch, uncommitted or
stashed changes, environment setup needed to continue.

** Next steps
*** TODO First actionable step
*** TODO Second step

** Resume notes
What to re-verify before trusting this document: did PR #42 merge, does the
function it mentions still exist, has the file moved.
```

**The sections are a vocabulary, not a form.** Always present: the status paragraph under the root heading, `Goal`, and `Next steps`. Every other section appears only when it has content, and different task shapes lean on different sections:

| Task shape | Sections that carry the weight |
| --- | --- |
| Design discussion | Conclusions (rejected alternatives included), Open questions |
| Research | Findings (with source links), Open questions |
| Implementation in flight | Work done (dead ends included), World state (branch, WIP) |
| Review or triage queue (e.g. a PR queue) | Next steps as the ordered queue, one TODO per item with why it is there |
| Improvement backlog | Next steps, plus Conclusions for the prioritization rationale |

Keep the canonical section names verbatim so a resuming session can navigate them; add subheadings freely inside any section where the material calls for it.

Format rules:

- **File keywords**: `#+title:` (the human-readable topic), `#+filetags: :checkpoint:<tag>:` (`<tag>` from `where.sh`), `#+date:` (creation date as an inactive org timestamp — never changed on update).
- **Status is the root heading's TODO keyword**: `TODO` while the task is active, `DONE` when finished. Only these two standard keywords — no custom keyword sets. Mark the document `DONE` (and its remaining next steps) when the task completes; never delete a finished document.
- **Metadata lives in the root heading's property drawer**: `:CATEGORY:` (the `project` value from `where.sh` — org-agenda uses it for grouping; the org-tag-safe `tag` value appears only in `#+filetags:`), `:PROJECT_ROOT:` (the `root` value), `:COMMIT:` (the `commit` value — local HEAD at last save), `:MODIFIED:` (the `now` value at last save — with time, so same-day saves stay distinguishable).
- **`:COMMIT:` is a drift anchor, not provenance**: it lets `/checkpoint-resume` gauge how far the repository moved since the save. When the document's claims rest on something else — a remote branch tip, a deployed version, no code at all — record that fact in World state or Findings; the property itself always just holds local HEAD.
- **Timestamps** are inactive org timestamps. The two metadata ones are copied ready-made from `where.sh` — `today` (`[YYYY-MM-DD Day]`) into `#+date:`, `now` (`[YYYY-MM-DD Day HH:MM]`) into `:MODIFIED:` — never hand-derived. In free content (prose, tables, findings) write timestamps yourself; the day name is optional there — `[2026-08-07]` is valid org — so omit it rather than guess it. Free content uses absolute dates only — never "yesterday" or "last week".
- **Links** use org syntax: `[[file:/abs/path/file.el::123]]` for code, `[[https://...][PR #42]]` for the web.
- **Next steps** are `*** TODO` subheadings, ordered and actionable; completed ones become `DONE` rather than being deleted. Because they are real org TODO headings, the user can surface them in org-agenda by adding the file to `org-agenda-files`.
- **Phrase authorization gates explicitly in Next steps.** Imperative shorthand written mid-session ("review and apply X") reads as pre-authorization when replayed cold in a later session. A step ending in an outward-facing or hard-to-reverse action should carry its condition — "apply after the user confirms", "send once approved". (`/checkpoint-resume` re-confirms such actions regardless, but the document should not invite the mistake.)

Prose rules:

- Write for a reader with **zero session context**: no conversation shorthand, no codenames invented mid-discussion, abbreviations spelled out on first use.
- Distill — conclusions and reasoning, never transcript. If the discussion reversed itself, record the final position and, when instructive, the reversal's why.
- State decisions impersonally ("Chosen: X over Y because …"), with no reference to the assistant or the session that produced them.

## Update rules

- The file on disk is the source of truth for everything this session did not touch. The user may have edited it between sessions — **preserve their edits**; merge around them.
- Rewrite conclusions the session overturned; append new ones. Refresh `:COMMIT:` and `:MODIFIED:`; leave `#+date:` alone.
- Prefer `Edit` for targeted changes over rewriting the whole file, so unrelated user content cannot be lost.

## Failure modes

- **Not in a git repository**: fine — the slug and `root` fall back to the CWD, and `where.sh` omits the `commit` line, so the document simply carries no `:COMMIT:`. Say so in the report.
- **Base directory missing or unwritable**: `mkdir -p` handles missing; on permission errors report the path and stop — do not fall back to writing inside the repository.
