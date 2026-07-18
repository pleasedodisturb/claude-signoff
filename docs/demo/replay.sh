#!/usr/bin/env bash
# Deterministic replay of a REAL `/signoff --dry-run` run, for the demo GIF.
# The output below is verbatim from an actual run on a throwaway 2-commit repo
# with one modified file + one new test (2026-07-18). Nothing here is fabricated;
# it is replayed (not re-executed) so the GIF renders fast and identically.
# Regenerate the GIF with:  vhs docs/demo/signoff-demo.tape

g()  { printf '\033[38;5;108m%s\033[0m\n' "$1"; }   # green  (prompts/ok)
d()  { printf '\033[38;5;245m%s\033[0m\n' "$1"; }   # dim    (comments)
y()  { printf '\033[38;5;214m%s\033[0m\n' "$1"; }   # yellow (warnings)
c()  { printf '\033[38;5;109m%s\033[0m\n' "$1"; }   # cyan   (headers)
p()  { sleep "${2:-0.35}"; printf '%s\n' "$1"; }

sleep 0.15   # small lead-in; the tape hides the `clear` before revealing

d "# a messy repo at the end of a work session"
g "\$ git status -s"
printf ' M src/parse.js\n?? src/parse.test.js\n'
sleep 0.8

g "\$ claude"
sleep 0.4
c "> /signoff --dry-run"
sleep 0.9

c "## Phase 1 — Commit outstanding work"
p "Would stage 2 files and commit." 0.25
y "⚠  You're on \`main\` — a real run would branch first (your rule forbids main)."
sleep 0.7
c "## Phase 3 — Issue-tracker sync"
p "No tracker detected → skipped. Won't invent a ticket." 0.25
sleep 0.5
c "## Phase 4 — Loose-ends audit"
y "1 found: parse.test.js is missing \`import { parse }\` — would ReferenceError."
sleep 0.7
c "## Phase 6 — Next-session handoff  →  docs/sessions/HANDOFF.md (local, public fail-safe)"
sleep 0.6
printf '\033[38;5;245m'
cat <<'EOF'
  # HANDOFF — signoff-demo-temp
  ## Status (Refreshed 2026-07-18)
  Uncommitted: parse() empty-input guard + a test. Nothing pushed (no remote).
  ## Next up, in order
  1. Add `import { parse } from "./parse.js"` to parse.test.js; run the test.
  2. Move work off main onto a branch; open PR if a remote is added.
EOF
printf '\033[0m'
sleep 1.0

g "── Session Sign-Off Complete (DRY RUN) ───────"
cat <<'EOF'
  Commits:    0 made — would stage 2 files, commit (⚠ on main; branch first)
  Worktrees:  none (only primary; nothing to prune)
  Tracker:    skipped — no ticket worked; would not invent one
  Loose ends: 1 found — parse.test.js missing `import parse` (act now)
  Summary:    docs/sessions/2026-07-18_parse-empty-guard.md (would write LOCAL)
  Handoff:    docs/sessions/HANDOFF.md (would write LOCAL — public/unknown repo)
  Mode:       dry-run (nothing written, committed, or closed)
EOF
g "──────────────────────────────────────────────"
sleep 2.0
