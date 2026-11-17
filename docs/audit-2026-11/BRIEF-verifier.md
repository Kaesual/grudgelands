# Audit 2026-11: verifier brief

You are an independent verifier in a read-only audit of the Grudgelands game
code. A finder wrote raw findings for one package; you check each one
against the code in a fresh context. Project rule: **findings are
hypotheses**; "X is missing in Y" is wrong more often than "X is in Y".

## Paths

- Code and docs: `/home/jan/grudgelands` (branch `main`, commit `4cb49044e`).
- Input: `/home/jan/grudgelands/.claude/worktrees/audit-2026-11/docs/audit-2026-11/raw/<PKG>.md`
- **Write exactly one file:**
  `/home/jan/grudgelands/.claude/worktrees/audit-2026-11/docs/audit-2026-11/findings/<PKG>.md`.
  Change nothing else: no code, no other docs, no writing git command.

## Hard rules

- Static analysis only: no `luajit`, `lua`, engine, fixture, test or
  benchmark run. Allowed shell: `rg`, `wc`, `ls`, read-only `git`, `sed -n`.
- Engine behaviour is read in `reference_projects/luanti` and cited; if it
  is not checked out, say "engine behaviour not checked".
- Write early: create the output file after the first few verdicts and
  extend it; you may be stopped without warning.
- English. Never name an existing commercial game as a reference.

## What to do

Your launch prompt may name two or three packages; write one output file
per package. For **every** Critical, High and Medium finding (Low findings
keep the verdict UNVERIFIED unless one is checked in a single search):

1. Open the cited lines. Does the code say what the finding claims?
2. Try to **refute** it: look for the guard, the cache, the caller, the
   user, the throttle or the migration the finder may have missed (`rg` over
   all of `mods/`, not only the package). For "dead code", search for
   dynamic uses too (string-built names, `dofile` lists, registration
   tables, `tools/` fixtures). For "perf", check the real call frequency.
   For "docs", read the document's sentence and the code.
3. Check that the proposal would not change behaviour the project relies on
   (`AGENTS.md`, `docs/process/round-workflow.md` §5) and that the severity
   fits the definitions below; correct both where needed.

Verdicts:

- **CONFIRMED** — the claim holds as written.
- **CORRECTED** — a real problem, but the finder's description, location,
  severity or proposal was wrong; rewrite the finding to be right.
- **REFUTED** — the claim does not hold; say what refutes it (file:line).
- **UNVERIFIED** — you did not check it (Low findings only, or out of time).

Severity: **Critical** = data loss, crash loop, economy- or player-breaking
exploit; **High** = a real bug players hit, or a large server cost;
**Medium** = a clear improvement or a bug on a rarer path; **Low** = small
cleanup. Theoretical issues belong in "Backlog notes".

## Output format (exact; an index script parses the headings and verdicts)

Copy the raw file's structure and keep the finding ids. Change the first
line to `# <PKG> — <title> (verified)`, add `- Verifier model: <model id>`
under the finder line, and add one line to every finding, directly under
its heading:

```markdown
### <PKG>-03 | Medium | perf | <title>

- **Verdict:** CONFIRMED — <one or two sentences: what you checked>
- **Where:** ...
```

Keep the heading's severity and category current (after a correction the
heading shows the corrected values). Move REFUTED findings, with their
verdict line, to a final section `## Refuted`; keep their ids. You may add
a finding the finder missed that you met on the way (`<PKG>-V1`, verdict
`CONFIRMED — found by the verifier`), but do not start a second review.

## Your final reply

At most six lines: counts per verdict, the confirmed Critical and High ids
with titles, and anything you could not check.
