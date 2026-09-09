# Implementation Plan: License flip (TT-22)

- **Created**: 2026-09-09
- **Status**: Approved
- **Issue**: `.sdd/.current/issues/TT-22/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "Write an implementation plan for issue TT-22; the license CHOICE is a separate decision — define the process, enumerate the concrete edit points for GPL-2.0-or-later / GPL-3.0 / MIT / Apache-2.0, resolve the actual choice at implementation time with the owner; a default candidate with an explicit go/no-go gate is acceptable"

## Summary

Final step of the reimplementation. Once TT-01..TT-21 have replaced every
inherited file with independent expression, the tree contains no
upstream-derived text and the project may choose its license freely. This
issue performs the flip as ONE reviewable commit: replace `LICENSE`, update
`PKG_LICENSE` + the SPDX header in `packages/luci-app-trusttunnel/Makefile`,
rewrite the README's independence/license prose, and prove via the
gpl/NooBiToo/капаров grep gates + `sh tests/run.sh` that no old-license text
remains in the tracked tree.

The license CHOICE is the owner's decision (PRD Open Questions); the plan
defines the process, enumerates the concrete edit points for every candidate
(GPL-2.0-only, GPL-2.0-or-later, GPL-3.0, MIT, Apache-2.0), and names a
default candidate (Apache-2.0) that the implementer must confirm with the
owner (explicit go/no-go gate, Task 2) before committing. No file is touched
before that confirmation.

Metadata/documentation only — no behavior change, therefore no unit tests.
Verification is gate-based: each grep assertion is defined BEFORE the edit
(failing), then re-run after the edit (passing).

## Technical Context

- **Language/Version**: POSIX sh (gates) + Makefile metadata; no code changes.
- **Primary Dependencies**: none — no new dependencies; only licensing
  metadata consumed by the OpenWrt build (apk/opkg `PKG_LICENSE`).
- **Storage**: n/a.
- **Testing**: gate-based verification — `git grep`/`grep` assertions defined
  before each edit; `sh tests/run.sh` as the regression net; CI (`ci.yml`
  `tests` job) runs after the flip commit is pushed (Task 7 Step 4).
- **Target Platform**: OpenWrt package repo (`luci-app-trusttunnel` apk/opkg
  metadata surfaces `PKG_LICENSE` to package managers).

## Research

### Gate design (revised after review)

- **Working gates (kept):** `git grep -i -e "gpl" -e "NooBiToo" -e "капаров"`
  over the tracked tree, plus the targeted per-file greps in Tasks 3–5.
  These cover upstream-derived expression (the old GPL notice, upstream
  author markers) and satisfy AC-4 together with the `LICENSE` replacement.
- **Copyright gate (dropped):** no `git grep -i "opyright"` gate exists in
  this plan. It can never pass: the tracked `LICENSE` alone contains 16
  `Copyright` hits, and every candidate license text (Apache-2.0, GPL-3.0,
  MIT) contains the word — including after the flip. Upstream copyright
  lines are removed by the `LICENSE` replacement (Task 3) and are not
  present elsewhere in the tracked tree; nothing more is gained by a
  Copyright grep.
- **BSD grep portability:** all gate greps run on macOS BSD grep — only
  single-pattern `grep PATTERN` or multi-pattern `grep -e P1 -e P2` /
  `grep -E` forms are used; no BRE `\|` alternation anywhere.
- **Untracked dirs:** `.sdd/` and `docs/` are untracked (`?? .sdd/`,
  `?? docs/`) and stay that way — they are not part of the flip commit. The
  clean-tree gates whitelist them explicitly (Tasks 1, 6).

### Edit-point inventory (verified in the current tree, 2026-09-09)

| # | File | Line(s) | Current content | Flip action |
|---|---|---|---|---|
| 1 | `LICENSE` | 1–338 | GPL-2.0 text (338 lines, title "GNU GENERAL PUBLIC LICENSE / Version 2, June 1991") | Replace with the chosen license's canonical text (keep unchanged for GPL-2.0 choices) |
| 2 | `packages/luci-app-trusttunnel/Makefile` | 1 | `# SPDX-License-Identifier: GPL-2.0-only` | Replace with the chosen SPDX identifier |
| 3 | `packages/luci-app-trusttunnel/Makefile` | 23 | `PKG_LICENSE:=GPL-2.0-only` | Replace with the chosen SPDX identifier |
| 4 | `packages/luci-app-trusttunnel/Makefile` | 4–6 (NooBiToo text on line 5) | comment: "Lightweight fork of the original luci-app-trusttunnel (NooBiToo/TrustTunnelOpenWrt): full-tunnel only, no domain lists, no dnsmasq/nftset machinery." | Drop the fork/upstream lineage phrasing (it fails the `NooBiToo` gate); keep the neutral feature description |
| 5 | `packages/luci-app-trusttunnel/Makefile` | 24 | `PKG_MAINTAINER:=TrustTunnelOpenWrt contributors` | Keep — attribution, intentional mention, matches no gate pattern |
| 6 | `README.md` | 3–5 | intro: "A lightweight fork of the original luci-app-trusttunnel … (GPL-2.0) for OpenWrt 25.12+ (apk)." | Rewrite into the independence statement + history note (post TT-21 line numbers may shift; locate by content) |
| 7 | `README.md` | 289–296 (NooBiToo bullet at 291–292) | "## Acknowledgements … NooBiToo/TrustTunnelOpenWrt — the original package this fork is derived from (GPL-2.0)" | Keep as attribution/history (intentional mention per the issue's gate); reword "fork" to "clean-room reimplementation" phrasing |
| 8 | `README.md` | — | no License section exists | Add `## License` section pointing at the root `LICENSE` |
| 9 | `packages/trusttunnel-client/Makefile` | 1 | `# SPDX-License-Identifier: GPL-2.0-only` | **NOT touched** — out of scope (PRD "Out of Scope"); pre-existing inconsistency: header says GPL-2.0-only while line 26 says `PKG_LICENSE:=Apache-2.0`; whitelisted in the gates, flagged to the owner at Task 2 |
| 10 | `packages/trusttunnel-client/Makefile` | 26 | `PKG_LICENSE:=Apache-2.0` | **NOT touched** — vendor binary wrapper |
| 11 | `packages/luci-app-trusttunnel/po/ru/trusttunnel.po` | — | no license/copyright in the header | Nothing (verified clean) |
| 12 | `repo-site/*` | — | no license/copyright mentions | Nothing (verified clean; also out of scope) |
| 13 | `.github/workflows/ci.yml`, `release.yml` | — | no license mentions | Nothing (verified clean) |
| 14 | All other tracked files (42 tracked total) | — | no `gpl` / `NooBiToo` / `капаров` / `SPDX` hits | Nothing — verified: `git grep` returns only the lines listed above |

Note: `LICENSE` does NOT appear in the gpl-gate whitelist — the GPL-2.0 text
contains no `gpl` substring (verified: 0 case-insensitive hits), so it never
matches the gpl/NooBiToo/капаров gate pre-flip; its old text is removed by
Task 3's replacement instead.

Note on `.sdd/` and `docs/`: currently untracked; they discuss the GPL-2.0
history extensively (spec documents). They are intentional mentions and are
invisible to `git grep` until committed; the clean-tree gates whitelist
their `??` entries (Tasks 1 Step 2 and 6 Step 3). They are NOT committed by
this issue — the flip stays a three-file commit.

### License-choice options and consequences

| Choice | SPDX value (line 1 + `PKG_LICENSE`) | `LICENSE` action | Consequences |
|---|---|---|---|
| Stay GPL-2.0 (by choice, not obligation) | `GPL-2.0-only` | Keep the existing 338-line GPL-2.0 text (zero diff) | Copyleft stays; fully compatible with the OpenWrt feed; the flip commit then touches only the Makefile + README |
| GPL-2.0-or-later | `GPL-2.0-or-later` | Keep the existing text (same GPL-2.0 document; its section 9 covers later versions) | Copyleft with upgrade freedom for recipients; minimal diff |
| GPL-3.0 | `GPL-3.0-only` or `GPL-3.0-or-later` (owner sub-choice at the gate) | Replace with the canonical text from https://www.gnu.org/licenses/gpl-3.0.txt | Modern copyleft; no GPL-2.0 code remains in the tree, so no 2.0/3.0 combination concern; accepted in the official feed |
| MIT | `MIT` | Replace with the canonical MIT text + copyright line `Copyright (c) 2026 i-zhirov` | Permissive, simplest; no copyleft; conflicts with the official OpenWrt feed's AGPL-3.0 preference for LuCI apps — relevant only if upstream submission is ever considered (out of scope today) |
| **Apache-2.0 (default candidate)** | `Apache-2.0` | Replace with the canonical text from https://www.apache.org/licenses/LICENSE-2.0.txt | Permissive + explicit patent grant; consistent with the already-Apache-2.0 client chain (`trusttunnel-client`); same feed-policy caveat as MIT |

**Default candidate: Apache-2.0** — it aligns the whole dependency chain
(the vendored client and its wrapper are already Apache-2.0) and maximizes
the independence the reimplementation was for. This is a DEFAULT for the
go/no-go gate, not a decision: Task 2 requires the owner's explicit
confirmation or a different pick; the option table's column then determines
the concrete values for Tasks 3–5.

**Clean-room rule for the flip**: the old GPL-2.0 text is replaced, never
edited into the new license; the new text is fetched from the canonical
source of the chosen license, not reproduced from memory or from the current
`LICENSE`. This plan deliberately does not quote the old license text.

## Entities

N/A — no data entities. The flip changes five licensing-metadata fields:

- `LICENSE` (root file): the full license text.
- `PKG_LICENSE` (luci-app Makefile line 23): SPDX expression surfaced in
  apk/opkg metadata.
- SPDX header (luci-app Makefile line 1): source-file license marker. The
  project convention is Makefile-only (verified: the only SPDX lines in the
  tree are the two Makefiles) — do NOT blanket-add headers to other files.
- README intro + new License section: user-facing license statement.
- (read-only) `packages/trusttunnel-client/Makefile`: vendor wrapper, out of
  scope; its SPDX line 1 is a pre-existing metadata inconsistency.

## Contracts

N/A — no API endpoints. The de-facto contract is the option table above:
the owner's choice at Task 2 selects one column, and Tasks 3–5 apply exactly
that column's values.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `LICENSE` | Replace | Chosen license's canonical text (unchanged for GPL-2.0 choices) |
| `packages/luci-app-trusttunnel/Makefile` | Modify | Line 1 SPDX, line 23 `PKG_LICENSE`, lines 4–6 comment de-forked (NooBiToo text on line 5) |
| `README.md` | Modify | Independence statement (intro), de-forked body references, new License section; Acknowledgements kept |
| `packages/trusttunnel-client/Makefile` | Untouched | Out of scope (vendor wrapper; pre-existing SPDX inconsistency, whitelisted) |
| `tests/run.sh` | Untouched | Regression gate only |

## Tasks

### [ ] Task 1: Pre-flip gate — confirm the tree is clean of inherited expression

**Files:** none (read-only gate)

- [ ] **Step 1: Define the gate.** The gate is the issue's verification
      command over the tracked tree:
      `git grep -i -e "gpl" -e "NooBiToo" -e "капаров"`
      Expected whitelist BEFORE the flip:
      - `packages/luci-app-trusttunnel/Makefile` (lines 1, 23, 4–6)
      - `packages/trusttunnel-client/Makefile` (line 1)
      - `README.md` (intro and Acknowledgements)
      - `.sdd/` and `docs/` only if already committed (spec docs, intentional)
      `LICENSE` needs NO whitelist entry: its GPL-2.0 text contains no
      `gpl` substring (verified: 0 hits), so the gate never matches it.

- [ ] **Step 2: Run the gate, expect it to show exactly the whitelist.**
      Run: `git grep -i -e "gpl" -e "NooBiToo" -e "капаров"`
      Expected: only the whitelisted lines. There is deliberately NO
      `Copyright` grep: it can never pass (LICENSE alone has 16
      `Copyright` hits and every candidate license text contains the
      word) — upstream expression is covered by the three patterns
      above plus the Task 3 replacement. Also verify prerequisites:
      `git status --porcelain` shows nothing except the allowed
      untracked dirs (`?? .sdd/`, `?? docs/`), `git log -1` is the last
      reimplementation commit (TT-21), and the TT-01..TT-21 acceptance
      criteria are all landed in the branch history.

- [ ] **Step 3: Act on failure.** Any hit OUTSIDE the whitelist means the
      tree still carries inherited expression — STOP, do not flip, report
      the offending file to the owner.

**Verification**: gate output equals the whitelist exactly; `git status`
clean except the two allowed untracked dirs.

### [ ] Task 2: Confirm the license choice with the owner (go/no-go gate)

**Files:** none (decision only — no edits before confirmation)

- [ ] **Step 1: Present the options.** Show the owner (i-zhirov) the
      Research option table with the default candidate Apache-2.0. Ask:
      (a) which license; (b) if GPL-3.0, `-only` or `-or-later`;
      (c) confirm `packages/trusttunnel-client/Makefile` stays untouched
      despite its pre-existing SPDX `GPL-2.0-only` header on an Apache-2.0
      wrapper (out of scope, whitelisted in the gates).

- [ ] **Step 2: Record the choice.** Write the confirmed license into the
      flip commit message (Task 7) and, if the owner wants, update the
      status line of `docs/reimplementation-consideration.md` §5.

- [ ] **Step 3: Stop unless confirmed.** If the owner does not confirm a
      choice, do not edit any file; the flip waits.

**Verification**: choice recorded and acknowledged; it selects one column of
the option table, which Tasks 3–5 apply verbatim.

### [ ] Task 3: Replace `LICENSE` with the chosen license's text

**Files:**

- Modify: `LICENSE`

- [ ] **Step 1: Record the before-state.** `wc -l LICENSE` = 338;
      `head -3 LICENSE` shows the GPL-2.0 title.

- [ ] **Step 2: Run the gate, expect it to fail (old text present).**
      Run: `git grep -n "General Public License" -- LICENSE`
      Expected: hit (the old text is there — this is the failing test).

- [ ] **Step 3: Apply the replacement**, per the owner's choice:
      - Apache-2.0: fetch https://www.apache.org/licenses/LICENSE-2.0.txt
        and overwrite `LICENSE` with it (verify: byte-compare against a
        second fetch).
      - MIT: fetch the canonical MIT text from https://opensource.org/license/mit
        and write it with the copyright line `Copyright (c) 2026 i-zhirov`
        prepended.
      - GPL-3.0: fetch https://www.gnu.org/licenses/gpl-3.0.txt and
        overwrite `LICENSE`.
      - GPL-2.0-only / GPL-2.0-or-later: leave `LICENSE` untouched (zero
        diff); the flip then changes metadata only.
      Clean-room rule: the new text is the canonical text of the chosen
      license from its official source; the old GPL-2.0 text is deleted in
      the same operation and never quoted into any other file.

- [ ] **Step 4: Run the gate, expect it to pass.**
      Run: `git diff --stat LICENSE` (full replacement, or no diff for
      GPL-2.0) and `head -3 LICENSE`
      Expected: the new license's title (e.g. "Apache License",
      "GNU GENERAL PUBLIC LICENSE Version 3", "MIT License"); the
      `General Public License` grep hits only if the choice is GPL-family.

**Verification**: `LICENSE` = canonical text of the chosen license; old
GPL-2.0 text absent from the working tree.

### [ ] Task 4: Update the app Makefile — SPDX header, `PKG_LICENSE`, de-fork comment

**Files:**

- Modify: `packages/luci-app-trusttunnel/Makefile`

- [ ] **Step 1: Define the target values** from the option table column
      chosen at Task 2:
      - line 1 → `# SPDX-License-Identifier: <chosen SPDX>`
      - line 23 → `PKG_LICENSE:=<chosen SPDX>`
      - lines 4–6 (NooBiToo text on line 5) → drop the "fork of the
        original luci-app-trusttunnel (NooBiToo/TrustTunnelOpenWrt):"
        phrasing, keep only the neutral feature description, e.g.:
        `# Full-tunnel-only LuCI app for the TrustTunnel client: no domain lists, no`
        `# dnsmasq/nftset machinery.`

- [ ] **Step 2: Run the gate, expect it to fail (old values present).**
      Run: `grep -n -e 'GPL-2.0-only' -e 'NooBiToo' packages/luci-app-trusttunnel/Makefile`
      (separate `-e` patterns — BSD grep has no BRE `\|`; `grep -E` would
      also work)
      Expected: hits on lines 1, 23 and 4–5.

- [ ] **Step 3: Apply the three edits.** Line 1 SPDX, line 23
      `PKG_LICENSE`, lines 4–6 comment. Leave line 24
      `PKG_MAINTAINER:=TrustTunnelOpenWrt contributors` unchanged
      (attribution, matches no gate pattern).

- [ ] **Step 4: Run the gate, expect it to pass.**
      Run: `grep -n -e 'SPDX' -e 'PKG_LICENSE' packages/luci-app-trusttunnel/Makefile`
      and `git grep -n NooBiToo`
      Expected: the new SPDX/`PKG_LICENSE` values; `NooBiToo` no longer
      matches this file; `grep -n 'GPL' packages/luci-app-trusttunnel/Makefile`
      returns nothing unless the chosen license is GPL-family (then exactly
      the intended lines).

**Verification**: Makefile metadata matches the option table; no upstream
markers remain in the file.

### [ ] Task 5: Update the README — independence statement, de-fork the body, License section

**Files:**

- Modify: `README.md`

- [ ] **Step 1: Locate the edit points by content** (line numbers verified
      2026-09-09; they may shift after TT-21 — locate by content). Full
      inventory of present-tense "fork" references (8 grep hits at lines 3,
      9, 23, 34, 67, 146, 243, 292):
      - intro (lines 3–5): "A lightweight fork of [the original
        luci-app-trusttunnel] … (GPL-2.0) for OpenWrt 25.12+ (apk)."
      - line 9: "This fork removes the entire list machinery — …"
      - line 23: "Everything on the router that the fork touches:"
      - line 34: "What the fork does **not** touch: …"
      - line 67: "…the fork does not need nftset in…"
      - line 146: "**DNS:** the fork does not intercept or redirect DNS. …"
      - lines 243–244: "## Differences from the original package" table —
        header row "| | original | this fork |"
      - Acknowledgements (lines 289–296; NooBiToo bullet at 291–292):
        "— the original package this fork is derived from (GPL-2.0)"
      - no License section exists.

- [ ] **Step 2: Run the gate, expect it to fail (fork wording present).**
      Run: `grep -n 'fork' README.md`
      Expected: hits at lines 3, 9, 23, 34, 67, 146, 243, 292 (8 hits),
      including the intro.

- [ ] **Step 3: Apply the edits**, treating every hit above:
      - Intro (3–5): replace the "fork … (GPL-2.0)" sentence with an
        independence statement: the project is an independent, clean-room
        reimplementation of the luci-app-trusttunnel concept — originally a
        fork of NooBiToo/TrustTunnelOpenWrt (GPL-2.0), fully re-expressed
        in 2026 — licensed under the chosen license. Keep the OpenWrt
        version/package-manager compatibility statement. This is the ONE
        kept "fork" mention, past-tense, as the history note the issue's
        gate allows.
      - Line 9: "This fork removes" → "This package removes" (and any other
        "the fork" phrase in the sentence).
      - Line 23: "that the fork touches" → "that this package touches".
      - Line 34: "What the fork does **not** touch" → "What this package
        does **not** touch".
      - Line 67: "the fork does not need nftset" → "the package does not
        need nftset".
      - Line 146: "the fork does not intercept" → "the package does not
        intercept".
      - Lines 243–244: table header cell "this fork" → "this package"
        (keep the "Differences from the original package" comparison as
        context).
      - Acknowledgements (291–292): keep the NooBiToo/TrustTunnelOpenWrt
        attribution as history; reword "the original package this fork is
        derived from (GPL-2.0)" → "the original package this project is a
        clean-room reimplementation of (GPL-2.0)".
      - Add a `## License` section directly before `## Acknowledgements`
        (line 289): state the chosen license, point at the root `LICENSE`
        file, note that the vendored client and its wrapper package remain
        Apache-2.0, and reference `docs/reimplementation-consideration.md`
        and `docs/reimplementation-file-review.md` as the reimplementation
        record.

- [ ] **Step 4: Re-run the 'fork' gate, expect it to pass.**
      Run: `grep -n 'fork' README.md`
      Expected: NO hits except the intro history note's single past-tense
      "fork" mention (intentional per the issue's gate); zero present-tense
      "the fork …" constructions anywhere in the file.

- [ ] **Step 5: Run the license gate + read-through.**
      Run: `grep -ni 'license' README.md` and a read-through
      Expected: the new License section is present; the independence
      statement reads correctly; no sentence claims the project is currently
      GPL-bound except the historical note.

**Verification**: README states independence and the chosen license; no
present-tense fork phrasing remains; attribution preserved; owner
read-through.

### [ ] Task 6: Verification gate — old-license text, tests, diff scope, package metadata

**Files:** none (gate — runs on the working tree BEFORE the commit)

- [ ] **Step 1: Grep gate.**
      Run: `git grep -i -e "gpl" -e "NooBiToo" -e "капаров"`
      Expected AFTER the flip — exactly:
      - `packages/trusttunnel-client/Makefile:1` (out-of-scope pre-existing
        SPDX line, whitelisted)
      - `README.md` history note + Acknowledgements (intentional)
      - `.sdd/` and `docs/` if committed (spec docs)
      - if the choice is GPL-family: `LICENSE` (if its text matches) and
        the app Makefile's SPDX/`PKG_LICENSE` lines
      - nothing else. (No `Copyright` grep — it can never pass; see
        Research "Gate design".)

- [ ] **Step 2: Tests.**
      Run: `sh tests/run.sh`
      Expected: all assertions green (nothing but metadata changed).

- [ ] **Step 3: Diff scope.**
      Run: `git status --porcelain`
      Expected: ONLY `LICENSE` (if replaced),
      `packages/luci-app-trusttunnel/Makefile`, `README.md` — plus the
      allowed untracked dirs `?? .sdd/` and `?? docs/` (spec docs, not flip
      changes). Any other modified or untracked entry → STOP and
      investigate; the flip must not smuggle unrelated changes.

- [ ] **Step 4: Package metadata (recommended).** If an SDK build is
      available, build and verify the package metadata shows the new
      license (`apk info -a` / `opkg info`); otherwise rely on CI.

**Verification**: all four checks pass.

### [ ] Task 7: Single reviewable commit, then push/CI

**Files:** `LICENSE`, `packages/luci-app-trusttunnel/Makefile`, `README.md`

- [ ] **Step 1: Stage only the flip files.**
      Run: `git add LICENSE packages/luci-app-trusttunnel/Makefile README.md`
      (never `git add -A` here — `.sdd/` and `docs/` stay untracked).

- [ ] **Step 2: Commit with a documented message** that records the choice
      and references the reimplementation docs. Example (default candidate
      Apache-2.0):

      ```
      license: relicense under Apache-2.0 after the clean-room reimplementation

      The tree no longer contains inherited GPL-2.0 expression: every file
      that descended from NooBiToo/TrustTunnelOpenWrt has been re-expressed
      from the behavioral contract (TT-01..TT-21), recorded in
      docs/reimplementation-consideration.md and
      docs/reimplementation-file-review.md. The license is now the owner's
      free choice (PRD Open Questions, issue TT-22).

      - LICENSE: GPL-2.0 text replaced by the canonical Apache-2.0 text.
      - packages/luci-app-trusttunnel/Makefile: PKG_LICENSE:=Apache-2.0,
        SPDX-License-Identifier: Apache-2.0, header comment no longer
        claims fork lineage.
      - README.md: independence statement, de-forked body references, and
        new License section; the acknowledgement of the original project is
        kept as history.

      The trusttunnel-client vendor wrapper (Apache-2.0) is intentionally
      untouched.
      ```

- [ ] **Step 3: Verify the commit.**
      Run: `git show --stat HEAD` and `git log -1`
      Expected: exactly the three files (only two when the chosen license
      leaves `LICENSE` unchanged — e.g. the GPL-2.0-only / GPL-2.0-or-later
      choices keep the current text, so the commit then touches only the
      app Makefile and README); the message documents the choice and the
      process; this is the LAST reimplementation commit (per the issue's
      note, no later file changes).

- [ ] **Step 4: Push / CI (post-commit).** The flip commit now exists, so
      push the branch / open the PR and run the `ci.yml` `tests` job.
      Expected: green.

**Verification**: one commit, three files, documented message, CI green on
the pushed flip commit.
