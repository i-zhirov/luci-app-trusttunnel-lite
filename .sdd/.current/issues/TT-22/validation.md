# Issue Validation Report: License flip (TT-22)

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-22/issue.md`
- **Plan**: `.sdd/.current/issues/TT-22/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 7 | 0 | 0 | 7 |
| Acceptance Criteria | 4 | 1 | 0 | 5 |
| Entities | 0 | 0 | 0 | 0 |
| Contracts | 0 | 0 | 0 | 0 |
| Guidelines | 0 | 0 | 0 | 0 |

The flip to Apache-2.0 is implemented and verified: `LICENSE` is the
byte-identical canonical Apache-2.0 text (202 lines, fetched from
apache.org), both package Makefiles carry Apache-2.0 SPDX/`PKG_LICENSE`,
the README states independence and the new license with zero "fork"
mentions, the gpl/NooBiToo/капаров grep gates are clean over `packages/`
and hit only intentional mentions elsewhere, and `sh tests/run.sh` is fully
green. Two non-blocking deviations from the plan's letter are recorded
below (flip commit scope of 6 files vs 3; a post-flip functional Makefile
commit), plus a dirty working tree caused by in-flight work on other
issues.

## Task Status

- [x] **Task 1: Pre-flip gate — confirm the tree is clean of inherited expression** - PASS
  Post-flip state confirms the gate's expectation: `git grep -i -e "gpl" -e
  "NooBiToo" -e "капаров"` over the tracked tree hits only README (history
  note, Acknowledgements, License section) and the spec/planning docs
  (`.sdd/`, `docs/` — tracked, so visible to `git grep`; the plan's
  "untracked" assumption was stale but the whitelist itself covered them
  "if already committed"). The pre-flip whitelist itself (Makefile lines,
  README) is no longer present post-flip, exactly as intended.
- [x] **Task 2: Confirm the license choice with the owner (go/no-go gate)** - PASS
  The flip commit a5c376b opens with "Owner decision (Apache-2.0)" and
  records the choice per Task 2 Step 2. The owner additionally decided to
  correct the `trusttunnel-client/Makefile` stale GPL-2.0-only SPDX header
  (the plan's default was "stays untouched"); the commit message documents
  this explicitly ("the GPL-2.0-only header was a leftover").
- [x] **Task 3: Replace `LICENSE` with the chosen license's text** - PASS
  `LICENSE` is 202 lines / 11358 bytes and `diff` against a fresh fetch of
  https://www.apache.org/licenses/LICENSE-2.0.txt reports
  BYTE-IDENTICAL. Title "Apache License / Version 2.0, January 2004". The
  old GPL-2.0 text (338 lines) is gone from the working tree — it survives
  only in git history.
- [x] **Task 4: Update the app Makefile — SPDX header, `PKG_LICENSE`, de-fork comment** - PASS
  `packages/luci-app-trusttunnel/Makefile`: line 1
  `# SPDX-License-Identifier: Apache-2.0`, line 24 `PKG_LICENSE:=Apache-2.0`,
  lines 3–5 comment rewritten to the independence statement ("Independent
  reimplementation (Apache-2.0); the upstream package was only the starting
  point of the design…"); `PKG_MAINTAINER` kept. `git grep -i gpl -- packages`
  → 0 hits.
- [x] **Task 5: Update the README — independence statement, de-fork the body, License section** - PASS
  Intro rewritten to the independence statement (lines 3–9), all
  present-tense fork phrasing removed (comparison table header "This
  package", "this package touches / does NOT touch", "the package is built
  around"), Acknowledgements kept as the history note (lines 292–299),
  `## License` section added (lines 301–306) pointing at `LICENSE` and
  noting the GPL-2.0 text survives only in git history. `grep -c "fork"`
  README.md = 0. The only "fork" left in `packages/` is the plain verb in
  a ucode comment ("procd forks the client asynchronously") — not an
  upstream-lineage reference.
- [x] **Task 6: Verification gate — old-license text, tests, diff scope, package metadata** - PASS
  Step 1 gate: `git grep -i -e "gpl" -e "NooBiToo" -e "капаров" -- packages`
  → exit 1, zero hits; whole-tree hits limited to README (intentional) and
  `.sdd/`/`docs/` (spec docs). Step 2: `sh tests/run.sh` → all suites green
  (26+57+5+29+29+21+31+51+66 assertions, 0 failed, "== all tests passed",
  exit 0). Step 3 diff scope: the flip commit contains exactly the four
  content files + the two `.sdd` status lines (see Issues 1). Step 4 (SDK
  metadata): not run locally — no SDK available; relies on CI and the
  TT-14 golden-ipk evidence which already records `License: GPL-2.0-only →
  Apache-2.0 (the TT-22 flip)`.
- [x] **Task 7: Single reviewable commit, then push/CI** - PASS
  One commit a5c376b with a documented message (owner decision, per-file
  changes, gate results, the client-wrapper note); staged files are exactly
  the flip's. Deviations: the commit also carries the two `.sdd` status
  flips (repo convention — issue/plan Status Approved → Implemented) and
  the client Makefile SPDX fix (owner-sanctioned). The flip is not the
  last commit touching the flip files (see Issue 2). Push/CI execution
  cannot be verified from the local worktree (branch not pushed).

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | `LICENSE` contains the chosen license text | MET | 202 lines, byte-identical to apache.org LICENSE-2.0.txt (diff clean, 11358 bytes) |
| 2 | `PKG_LICENSE` and SPDX headers state the chosen license | MET | luci-app Makefile line 1 `SPDX-License-Identifier: Apache-2.0`, line 24 `PKG_LICENSE:=Apache-2.0`; trusttunnel-client Makefile line 1 `Apache-2.0`, line 26 `PKG_LICENSE:=Apache-2.0`; only SPDX lines in the tree are these two |
| 3 | README states independence and the new license | MET | Intro (lines 3–9), `## License` (301–306), `grep -c "fork"` = 0 |
| 4 | Grep for upstream-derived text finds nothing except git history | MET | `git grep -i -e "gpl" -e "NooBiToo" -e "капаров"`: 0 hits in `packages/`; remaining hits only README history note/Acknowledgements + `.sdd/`/`docs/` spec docs (intentional) |
| 5 | All CI gates still pass (nothing but licensing metadata changed) | PARTIAL | `sh tests/run.sh` fully green locally (the repo's regression net); CI `tests` job (shellcheck, syntax, rootfs installs) not observed — requires a push, which the branch has not had |

## Entity Status

N/A — no data entities (licensing metadata only, per plan "Entities").

## Contract Status

N/A — no API contracts. The de-facto contract was the plan's option table;
the owner's choice (Apache-2.0, recorded in the flip commit message) selects
its column, and Tasks 3–5 applied exactly that column's values.

## Guidelines Compliance

N/A — no `AGENTS.md` in the repository.

## Issues Found

1. **Flip commit scope: 6 files, not the planned 3 (4 content + 2 spec-status)**
   - Location: commit a5c376b
   - Description: The plan (Task 7, File Structure) expected exactly
     `LICENSE` + `packages/luci-app-trusttunnel/Makefile` + `README.md`,
     with `packages/trusttunnel-client/Makefile` explicitly "NOT touched"
     and `.sdd/` "untracked". The commit actually contains 6 files: the
     planned three, plus `packages/trusttunnel-client/Makefile` (SPDX
     header GPL-2.0-only → Apache-2.0) and
     `.sdd/.current/issues/TT-22/{issue,plan}.md` (Status Approved →
     Implemented). The plan's "untracked .sdd/" premise was stale — the
     issue/plan files had been committed earlier (fa45849, bf6be19) — so
     the status flips followed the repo's established convention of
     flipping statuses in the issue's own commit.
   - Impact: None on the license outcome. The client Makefile header is
     now consistent with its `PKG_LICENSE:=Apache-2.0` (the pre-existing
     inconsistency the plan flagged is gone). The flip remains one
     reviewable commit.
   - Recommendation: Accept as-is; both extras are documented in the
     commit message and consistent with the owner's decision (the
     validation brief itself expects the client-Makefile SPDX fix).
   - Resolved:
     (Omitted — validation in progress.)

2. **The flip is not the last commit touching the flip files (post-flip `2740ad2`)**
   - Location: `packages/luci-app-trusttunnel/Makefile`, commit 2740ad2
     ("makefile: restore the BuildPackage scan marker", 2026-09-10)
   - Description: `git log --oneline -1 -- LICENSE
     packages/luci-app-trusttunnel/Makefile packages/trusttunnel-client/Makefile`
     returns 2740ad2, not a5c376b. The post-flip commit appended
     `# call BuildPackage - OpenWrt buildroot signature` as the Makefile's
     final line — a functional OpenWrt feed-scan discovery marker (the
     clean-room rewrite had dropped it, silently removing the package from
     SDK feed scans). It touches no license text (gates stay clean).
   - Impact: None on the license flip's content; the issue's note
     tolerates later changes ("any later change to an inherited file would
     have been fine"), but the flip's "cleanest when final" review-scope
     preference is not met.
   - Recommendation: Accept — the commit is a legitimate functional fix
     with its own documented evidence (local SDK builds 22.03 + 25.12);
     optionally note in the flip review that 2740ad2 supersedes the "flip
     is final" ordering.
   - Resolved:
     (Omitted — validation in progress.)

3. **Working tree not pristine (unrelated in-flight work)**
   - Location: `.github/workflows/ci.yml` (uncommitted `M`), plus untracked
     `.sdd/.current/issues/TT-15..TT-20/validation.md`
   - Description: The working tree carries an uncommitted ci.yml edit that
     moves the `rm -f uc.out` cleanup after the negative-control ucode
     compile (a fix from the in-flight CI/backend validation work, not
     TT-22), and uncommitted validation reports for TT-15..TT-20.
   - Impact: None on TT-22 — the flip commit itself is clean and
     self-contained; the dirty entries predate/postdate it as separate
     activity.
   - Recommendation: No action for TT-22; push the flip branch with a clean
     checkout (commit or stash the ci.yml edit together with its own issue
     when that validation completes).
   - Resolved:
     (Omitted — validation in progress.)

4. **SDK package-metadata check not executed in this validation**
   - Location: issue "How to verify" step 3 (release build shows the new
     `PKG_LICENSE`)
   - Description: No OpenWrt SDK is available in this environment, so
     `apk info -a` / `opkg info` evidence for the Apache-2.0 metadata was
     not produced here. The plan itself downgraded this to "rely on CI"
     when no SDK is at hand; TT-14's validation already recorded the
     golden ipk metadata line `License: GPL-2.0-only → Apache-2.0 (the
     TT-22 flip)`.
   - Impact: None — metadata source of truth (`PKG_LICENSE:=Apache-2.0`)
     verified directly in the Makefiles.
   - Recommendation: Confirm once on the next CI run / SDK build; not a
     blocker.
   - Resolved:
     (Omitted — validation in progress.)

## Recommendations

- Run/push the branch so the `ci.yml` `tests` job executes on the flip
  commit (completes AC-5 and the "How to verify" step 3 metadata check).
- Optional follow-ups (both out of scope, per issue Notes): fresh history
  (orphan branch/new repo) so the repo itself contains no GPL text; extend
  the independence wording to shell-script comments if the owner wants
  (the review note's non-blocking flag — no "fork" lineage references
  remain in `packages/` today).
