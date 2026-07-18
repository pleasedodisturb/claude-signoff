---
name: signoff
description: >-
  End-of-session sign-off for Claude Code. Commits your work, prunes finished
  worktrees, syncs your issue tracker, audits loose ends, writes a session
  summary, and — the part nothing else does — commits a cold-start handoff so
  the NEXT session (on any machine, in the cloud, or a fresh terminal) resumes
  with full intent. Local-only, zero dependencies, it's just git. Use it when
  you're done working, before /clear, or when you say "wrap up" / "sign off".
disable-model-invocation: true
user-invocable: true
argument-hint: "[--dry-run] [--no-tracker] [--no-push] [--summary-dir <path>]"
allowed-tools: "Read Write Edit Bash(git *) Bash(gh *) Grep Glob AskUserQuestion"
effort: high
---

# Session Sign-Off

Run the full end-of-session sign-off. Work through every phase in order — skip a
phase only when its **detection step** says it doesn't apply, and say so in the
final report. Be thorough in action, concise in output.

## Options (parse from `$ARGUMENTS`)

- `--dry-run` — **report what each phase WOULD do; write nothing, commit nothing,
  close nothing.** Honour this in every phase. First run on a new project should
  usually be a dry-run so the user can see the plan before trusting it.
- `--no-tracker` — skip issue-tracker sync (Phase 3) even if one is detected.
- `--no-push` — commit locally but never `git push` / open a PR.
- `--summary-dir <path>` — where session summaries + the handoff live
  (default: `docs/sessions/`).

State the resolved options in one line before Phase 0 so the user knows the mode.

## Pre-flight context

> Every probe is guarded so launching from a non-repo directory never aborts the
> sign-off. If you see `NOT-A-GIT-REPO`, start at **Phase 0**.

Current git state:
```!
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git status --short
  git log --oneline -5
else
  echo "NOT-A-GIT-REPO: $(pwd) is not inside a git repository."
fi
```

Current branch / date / project:
```!
git branch --show-current 2>/dev/null || echo "NOT-A-GIT-REPO"
date +%Y-%m-%d
git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null || pwd | xargs basename
```

Detected issue tracker (first match wins; `none` is fine):
```!
if command -v gh >/dev/null 2>&1 && gh repo view >/dev/null 2>&1; then
  echo "tracker=github-issues"
elif command -v linear >/dev/null 2>&1 || command -v linearis >/dev/null 2>&1; then
  echo "tracker=linear-cli"
elif command -v jira >/dev/null 2>&1; then
  echo "tracker=jira-cli"
else
  echo "tracker=none"
fi
```

Repo visibility (drives the public-vs-private summary rule). **Fail safe: only a
definitive `false` counts as private-and-pushable; `unknown` (no `gh`, or a
non-GitHub remote) is treated as PUBLIC so nothing is pushed by accident:**
```!
gh repo view --json isPrivate -q '.isPrivate' 2>/dev/null || echo "unknown"
```

Default branch (used by the worktree gates and push logic — don't assume `main`):
```!
git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' \
  || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main"
```

## Phase 0: Repo allocation (only if `NOT-A-GIT-REPO`)

If pre-flight shows `NOT-A-GIT-REPO`, the session was launched from a non-repo
directory (e.g. a projects parent folder). Do **not** abort and do **not** run
any git/`gh` phase against this directory. Instead:

1. **Offer candidates and ask** (`AskUserQuestion`). Build the list from, in order:
   - Repos **touched this session** (infer from the conversation — branches, PRs,
     paths, tickets discussed).
   - Git repos one or two levels below the cwd:
     `for d in */ */*/; do git -C "$d" rev-parse --show-toplevel 2>/dev/null; done | sort -u`.
   Always include a free-text "other path" escape hatch.
2. **Confirm the choice**, then treat `<chosen-repo>` as the working root for every
   later phase — run all git/`gh` as `git -C <chosen-repo> …` with absolute paths,
   and re-derive branch / status / tracker / visibility from it.
3. If the user declines to pick a repo, run only the repo-independent phases
   (3 tracker, 4 loose ends) and say so in the final report.

If pre-flight showed a normal branch/status, skip Phase 0.

## Phase 1: Commit outstanding work

1. `git status` and `git diff` to see uncommitted changes.
2. **If the repo is not definitively private** (`isPrivate` is `false` or `unknown`)
   and the changes include generated/local files (session notes, scratch output),
   ask once:
   - **Commit** normally, or
   - **Keep local** — add to `.gitignore` instead of committing.
   Skip the prompt if the user already specified via arguments.
3. If there are changes:
   - Stage the relevant files — **never** stage secrets, `.env`, or build artifacts.
   - Commit with a clear title + a body explaining what changed and why. If an
     issue tracker is present, reference the issue in the title; if not, don't
     invent one.
   - Push if on a branch other than the default branch (detected in pre-flight) —
     **unless** `--no-push`.
4. If clean: confirm no uncommitted work.

`--dry-run`: list what you *would* stage/commit/push; write nothing.

## Phase 2: Worktree cleanup

Prune redundant git worktrees created for work that's now finished.

1. List them: `git worktree list`.
2. For each worktree **created or worked in during THIS session**, check all four
   safety gates:
   - **Work complete** — its issue is closed/done (or, with no tracker, the work
     is clearly finished).
   - **Merged** — its PR is merged, or the branch is merged into the **default
     branch** detected in pre-flight (`git branch --merged <default>` /
     `gh pr view <branch> --json state`). Don't assume `main`.
   - **Clean** — `git -C <path> status --porcelain` is empty.
   - **Pushed** — the branch has an upstream **and** no unpushed commits. Check the
     upstream first (`git -C <path> rev-parse --abbrev-ref @{u}`); if there is **no
     upstream**, treat it as **not pushed** (fail safe — keep it). Only when an
     upstream exists and `git -C <path> log @{u}..` is empty does this gate pass.
3. If **all four** hold → remove it: `git worktree remove <path>`, then
   `git branch -d <branch>` if fully merged.
4. **Never remove** a worktree with uncommitted changes, unpushed commits, or an
   **open** PR — and **never touch another session's in-flight worktree**. When any
   gate is unmet or unverifiable, keep it and report why.
5. Report each touched worktree: `removed <path>` or `kept <path> (reason)`.

Conservative by design — a wrongly-removed worktree with unpushed work is
unrecoverable. Default to keeping. `--dry-run`: report the verdict per worktree,
remove nothing.

## Phase 3: Issue-tracker sync

Skip entirely if `tracker=none` or `--no-tracker` (note it in the final report,
and make sure any unfinished work is captured in the Phase 5 summary + Phase 6
handoff instead).

Otherwise, review the conversation for issues that were **worked on**,
**completed**, **discovered**, or **blocked**, and sync them using the detected
tool:

- `tracker=github-issues` → `gh issue comment` / `gh issue close` / `gh issue create`.
- `tracker=linear-cli` → your Linear CLI (whichever `linear`-style command you have).
- `tracker=jira-cli` → the `jira` CLI.

**Close with a resolution comment, not just a status flip** — one line on the
outcome + the PR/commit that delivered it. A closed issue with no trail is opaque
a month later. `--dry-run`: list the intended updates; make no API calls.

## Phase 4: Loose-ends audit

Scan the conversation for:
- Things discussed but never implemented
- Decisions made but not acted on
- TODOs mentioned but never tracked
- Questions raised but never answered
- "I'll do X later" promises that weren't kept

List each with a recommendation: **act now** (small enough to finish),
**create issue** (needs future work), **note in handoff** (context, not a task),
or **drop** (superseded). Ask before acting on anything with side effects.
`--dry-run`: list the loose ends and recommendations only; take no "act now" action.

## Phase 5: Session summary

Write a summary to `<summary-dir>/YYYY-MM-DD_<short-slug>.md` (default
`docs/sessions/`; add `-2`, `-3` … for multiple sessions the same day). Create
the directory if missing.

```markdown
# Session: <short title>
**Date:** YYYY-MM-DD
**Branch:** <branch or "main">
**Issues:** <ids, or "none">

## What was done
- <completed work>

## Decisions made
- <key decisions + rationale>

## Lessons / gotchas
- <anything that went wrong or surprised you, and how to avoid it — omit if none>

## Open items
- <deferred / left for next session>

## Commits
- <commits this session, short descriptions>
```

Keep it factual and scannable — 20–40 lines, no filler.

**Public-repo rule (fail safe):** a summary can leak private context, so it is
committed **only when the repo is definitively private** (`isPrivate == true`).
If `isPrivate` is `false` **or `unknown`**, ensure `<summary-dir>/` is in
`.gitignore`, write the file **locally**, and skip the branch/PR steps entirely.

When committing (private repo, not `--no-push`): create branch
`docs/session-summary-YYYY-MM-DD`, push `-u`, and **open a PR** — this is the
default. Do **not** auto-merge into the default branch unless the user asked for
it or the project clearly permits it (solo repo, no required review); many team
repos forbid it. If auto-merge is wanted: `gh pr merge --squash --auto`.
`--dry-run`: print the summary to chat; write no file.

## Phase 6: Next-session handoff  ← the reason this skill exists

**Write or refresh `<summary-dir>/HANDOFF.md` on every sign-off.** This is a
message-in-a-bottle to the next session: a self-contained prompt a **cold** Claude
Code session (fresh terminal, teammate's clone, or a cloud/container run that sees
only a `git clone`) can paste as its first message and resume with full intent —
something opaque local memory stores and Pro/Max session-memory can't reach.

Bootstrap it if it doesn't exist yet — writing 40 lines once beats every future
session re-deriving "where were we?" from `git log` + issue archaeology.

Required sections (keep the names; refresh the content):

1. **Status** — date-stamp ("Refreshed YYYY-MM-DD"), one paragraph: what landed
   since the last refresh, whether the ticket list changed.
2. **Mission** — one paragraph: the active focus for the next session.
3. **Gotchas** — environment/workflow traps the next agent will hit. Carry
   forward the still-true ones, prune the stale, add new.
4. **Next up, in order** — the top of the backlog. Number each; include scope and
   (if known) a verification command.
5. **Working agreements** — branch-per-issue, tests required, review before merge —
   whatever this project actually follows.
6. **Context links** — path to the latest session summary; key files to read first.

**Repo visibility rule** (same fail-safe as Phase 5): definitively private
(`isPrivate == true`) → commit + bundle in the same branch/PR as the summary.
`false` **or `unknown`** → write locally, ensure `<summary-dir>/` is gitignored,
skip the PR. Never skip *writing* the file — it's for the next agent regardless of
whether it ships to the remote. `--dry-run`: print it; write nothing.

## Phase 7: Final report

```
── Session Sign-Off Complete ─────────────────
  Commits:    <N made / already clean>
  Worktrees:  <N removed / N kept (reason) / none>
  Tracker:    <N updated / N closed / N created / none / skipped>
  Loose ends: <N resolved / N ticketed / all clear>
  Summary:    <summary-dir>/<filename>
  Handoff:    <summary-dir>/HANDOFF.md <created / refreshed / local (public repo)>
  Mode:       <normal / dry-run>
──────────────────────────────────────────────
```

If anything couldn't be completed, flag it clearly so the user knows what's left.
