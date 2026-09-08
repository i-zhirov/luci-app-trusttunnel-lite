# Plan Review Report: TT-14 — package Makefile

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-14/issue.md`
- **Plan**: `.sdd/.current/issues/TT-14/plan.md`
- **Verdict**: Revised
- **Review attempt**: 1

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | fail | 1 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | fail | 1 |
| Architecture | fail | 1 |
| Operational | fail | 1 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[critical] correctness — Task 2's embedded Makefile text still emits the OLD depends list**
   - Target: Entities + Task 2 Step 1 + Task 3 Step 2
   - Impact: The embedded text has `LUCI_DEPENDS:=+trusttunnel-client +luci-base +kmod-tun +ip-full +curl +ca-bundle +ucode-mod-math` (no +nftables, wrong split). Implementing it verbatim fails tests/test_deps.sh (non-repetition rule + nftables assert) and AC4; Task 3's grep-only gate blesses the wrong value.
    - Recommendation: Replace the embedded depends with the actualized `+trusttunnel-client +luci-base +ip-full +nftables +curl +ucode-mod-math`.
    - Status: Open
    - Resolved: The Entity table and Task 2's embedded Makefile text now carry the actualized `LUCI_DEPENDS:=+trusttunnel-client +luci-base +ip-full +nftables +curl +ucode-mod-math`; the split's other half — `trusttunnel-client`'s own `DEPENDS:=+kmod-tun +ca-bundle` — is noted in the Actualization, the Entity table, Task 2's requirements, and the embedded comment. Task 3 Step 2 no longer grep-blesses any value: it requires the EXACT full-line match plus negative greps proving the app's LUCI_DEPENDS contains no kmod-tun/ca-bundle, and the new Task 3 Step 4 runs `sh tests/run.sh`, whose test_deps.sh fails on repetition — the gate that would catch the old list.
2. **[critical] architecture — Golden-oracle mismatch: v1.0.13 release assets predate the rebase**
   - Target: Task 1 + Task 4 Step 2
   - Impact: The official v1.0.13 assets were built from the pre-rebase HEAD with the OLD depends; the rebased tree builds with the NEW depends, so Task 4's "all diffs empty" is unsatisfiable. The actualization's "golden is the rebased tree's" is not implemented anywhere.
    - Recommendation: Derive the golden from a REBASED-tree build (local SDK build first, then compare), not from the old release assets.
    - Status: Open
    - Resolved: Research §4 is rewritten: the v1.0.13 release assets are documented as pre-rebase (built at `1fdf82c` from the OLD Makefile with the old depends) and unusable as the metadata golden. The golden is now derived from a REBASED-tree SDK build — Task 1 Step 2 builds the current (pre-rewrite) tree at HEAD `c43e20a` via the gh-action-sdk docker recipe (workflow_dispatch alternative provided) and Task 1 Step 3 extracts the transcripts into `.build-out/golden-22.03/` / `.build-out/golden-25.12/`; Task 4 Step 2 diffs the post-rewrite build against that golden, so "all diffs empty" is satisfiable and means exactly "the rewrite changed no metadata".
3. **[critical] operational — Task 1's baseline precondition un-runnable on the rebased worktree**
   - Target: Task 1 Step 1
   - Impact: `git log -1 v1.0.13` == HEAD `1fdf82c` can no longer hold; HEAD is c43e20a and both Makefiles changed.
    - Recommendation: Replace the precondition with the rebased-tree state and a local golden build.
    - Status: Open
    - Resolved: Task 1 Step 1's precondition is rewritten for the rebased worktree: HEAD is `c43e20a` (not `1fdf82c`), `git log -1 v1.0.13` == `1fdf82c` is documented as the PRE-rebase HEAD, `git describe --tags --abbrev=0` → `v1.0.15` (nearest reachable tag), and the step records that BOTH Makefiles changed (the LUCI_DEPENDS split, the client's DEPENDS). The step's conclusion is now: the v1.0.13 assets cannot be the golden — the golden is built from this tree in Step 2, before any rewrite.
4. **[medium] correctness/operational — tests/test_deps.sh never run by any task**
   - Target: Tasks 3-5
   - Impact: It is the only guard for the non-repetition rule, real invocations, and install.sh parity — and the only test that would catch finding 1.
    - Recommendation: Add `sh tests/run.sh` (or at least test_deps.sh) as an explicit gate.
    - Status: Open
    - Resolved: `sh tests/run.sh` is now an explicit verification gate in the task list — new Task 3 Step 4 runs the fork's full test suite (test_deps.sh asserts the app's declaration of trusttunnel-client/luci-base/ip-full/nftables/curl/ucode-mod-math, the client's kmod-tun/ca-bundle, the non-repetition rule, the real nft/ip/curl/math invocations, and install.sh's apk/opkg parity; baseline verified green at plan time: 40 assertions, 0 failed), and Task 5's gate summary records its output as acceptance evidence.
5. **[low] maintainability — Stale "89 lines" claim (actual: 98)**
   - Target: Summary
   - Impact: Cosmetic; same staleness class as findings 1-3.
    - Recommendation: Update the line count.
    - Status: Open
    - Resolved: The Summary's "89 lines" is updated to "98 lines" (verified at plan time: `packages/luci-app-trusttunnel/Makefile` is 98 lines at HEAD `c43e20a`).

## Dismissed Findings

None.

## Notes

- Everything else in the embedded Makefile matches the current file byte-for-byte (version derivation, conffiles ordering, Build/Compile after include, SPDX header). AC1-AC3 coverage holds; the failure is AC4 and the golden architecture.
- On re-review, this report is updated in place.
