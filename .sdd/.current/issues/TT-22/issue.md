# Issue TT-22: License flip

- **Status**: Implemented
- **PRD**: `../../prd.md`
- **Blocked by**: TT-01..TT-21 (the tree must be clean of inherited
  expression first)
- **Effort**: S
- **Files**: `LICENSE`, `packages/luci-app-trusttunnel/Makefile`
  (`PKG_LICENSE` + SPDX header), `README.md` (independence + license
  statement), any SPDX headers in reimplemented files

## Context

The final step. Once every inherited file has been re-expressed (TT-01..
TT-21), the tree contains no upstream-derived expression and the project
may choose its license freely. This issue performs the flip as ONE
reviewable commit.

## Contract to reproduce

- The license choice is the owner's decision (Open Questions in the PRD);
  this issue defines the process, not the choice. Recommended candidates
  (from the consideration doc): stay GPL-2.0 (by choice now, not
  obligation), GPL-2.0-or-later, GPL-3.0, or a permissive license
  (MIT/Apache-2.0) — noting the official OpenWrt feed's AGPL preference
  for LuCI apps if upstream submission is ever considered.
- Steps:
  1. Replace `LICENSE` with the chosen license's full text.
  2. Update `PKG_LICENSE` in the package Makefile and the SPDX header
     line.
  3. Add SPDX headers to the reimplemented files that carry them (only
     where the project's convention has headers — the package Makefile
     today; do not blanket-add headers to every file).
  4. Update `README.md`: independence statement (no longer a fork bound
     to GPL-2.0; clean-room reimplementation history note), license
     section pointing at the new `LICENSE`.
  5. Single commit; message documents the flip and references the
     reimplementation docs.

## Acceptance criteria

- [ ] `LICENSE` contains the chosen license text.
- [ ] `PKG_LICENSE` and SPDX headers state the chosen license.
- [ ] README states independence and the new license.
- [ ] Grep for upstream-derived text (the old GPL notice, upstream
      copyright lines) finds nothing in the current tree except the git
      history.
- [ ] All CI gates still pass (nothing but licensing metadata changed).

## How to verify

1. `git grep -i -e "gpl" -e "NooBiToo" -e "капаров"` (case-insensitive)
   over the working tree: only hits are in the git history, `LICENSE` if
   staying GPL, and intentional mentions (e.g. the README's history
   note).
2. `sh tests/run.sh` green.
3. Release build: package metadata shows the new `PKG_LICENSE`.

## Notes

- Optional follow-up (NOT part of this issue): fresh history (orphan
  branch or new repo) so the repository itself contains no GPL text.
- The flip must be the LAST reimplementation commit: any later change to
  an inherited file would have been fine (they are all rewritten), but
  the flip's review scope is cleanest when it is final.
