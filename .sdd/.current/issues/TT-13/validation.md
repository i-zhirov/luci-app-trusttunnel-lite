# Issue Validation Report: TT-13 — Russian translation (.po) clean-room re-translation

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-13/issue.md`
- **Plan**: `.sdd/.current/issues/TT-13/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 6 | 1 | 0 | 7 |
| Acceptance Criteria | 4 | 0 | 0 | 4 |
| Entities | 1 | 0 | 0 | 1 |
| Contracts | 3 | 1 | 0 | 4 |
| Guidelines | 2 | 0 | 0 | 2 |

## Task Status

- [x] **Task 1**: Baseline audit — pin the msgid set (dedup `Mode`, drop the 4 stale msgids) - PASS
  Reproduced the probes on the current tree: `.po` msgid lines = 217 (header + 216 msgids), unique = 216, target = 212; view keys status 51 / settings 79 / diagnostics 89, union 209; menu-only `Status`/`Settings` present. Baseline defect reproduced: the pre-rewrite file (`git show 737c7610:…trusttunnel.po`, byte-identical to the 44db74c version used in the plan) fails `msgfmt -c` with the fatal `duplicate message definition` for `Mode` (lines 38/607).
- [x] **Task 2**: Write the new .po skeleton (header + all 211 msgids, empty msgstrs) - PASS
  Final file has exactly 212 msgid lines (header + 211 msgids), exactly one `Mode` entry at the first position, the 4 stale Exclusions msgids absent, no BOM. The skeleton gate (`msgid` set/order identity, placeholders) is green against the final file.
- [x] **Task 3**: Re-translate page chrome + Status page legacy strings (42 entries) - PASS
  Final state confirms all 42 assigned msgids (incl. the `Status` menu title) have non-empty new Russian msgstrs; the 4 `%s` placeholders in this task's keys are preserved in order.
- [x] **Task 4**: Re-translate Settings page legacy strings (53 entries) - PASS
  All 53 assigned msgids (incl. `Settings`, `Server`, `Network`, `Routing table`, `TLS host name`) translated; no placeholder-bearing msgids in this task (no-op placeholder check).
- [x] **Task 5**: Re-translate Diagnostics page + backend strings (82 entries) - PASS
  All 82 assigned msgids translated; the `checks passed: %d, remarks: %d, problems: %d, skipped: %d` msgstr keeps all four `%d` tokens in order (verified by the full-catalog placeholder check).
- [x] **Task 6**: Re-translate the 34 new profile/SNI/random strings (fourth group) - PASS
  All 34 assigned msgids translated, incl. the single deduplicated `Mode`; the 6 placeholder-bearing keys (two with a double `%s`) keep their tokens in order.
- [ ] **Task 7**: Final verification + manual LuCI Russian pass - PARTIAL
  Step 1 mechanical gate fully green (`msgfmt -c` exit 0; `211 translated messages.`; msgid identity vs the 212-line target; 0 verbatim old msgstrs). Step 2 diff shape: `- msgid = 5`, `+ msgid = 0`, `- msgstr = 214`, `+ msgstr = 209` — differs from the plan's expected 216/211 by exactly the 2 exempted token entries (`TrustTunnel`, `MTU`, whose `msgstr == msgid` and are legitimately unchanged; plan's Task 7 expectation did not account for them). Step 3 manual LuCI Russian pass is **documented as deferred** ([ ] in plan; a catalog read-through was done instead; Russian sample reads naturally: «Режим работы», «Весь трафик — через VPN», «Идёт подключение к %s», «Домены из списка „не обходить" отправляются напрямую…»). Step 4 SDK gate documented as deferred to CI.

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Every `_()` key in the three views (and UI-shown backend strings) has a `msgid` entry | MET | Extracted key sets: status 51, settings 79, diagnostics 89, union 209; + `Status`/`Settings` menu titles = 211 msgids, all present in the `.po` (0 missing, 0 extra). 4 stale Exclusions msgids absent; `Mode` appears exactly once. |
| 2 | No `msgstr` line is copied verbatim from the inherited `.po` | MET | Full-catalog diff vs the pre-rewrite file (parent commit 737c7610, byte-identical to 44db74c): 0 verbatim old msgstrs. Byte-identical entries are only the header boilerplate, the brand `TrustTunnel`, and the token `MTU` (see Issues 1). |
| 3 | `msgfmt -c` passes | MET | `msgfmt -c -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po` → exit 0 (only the 7 expected informational header warnings); `msgfmt --statistics` → `211 translated messages.`, exit 0. |
| 4 | Russian text reads naturally and preserves meaning, tone, terminology | MET (read-through) | Catalog read-through done in lieu of the on-device pass (documented pending): sample msgstrs are natural Russian, keep terminology (туннель, VPN-правила, «не обходить») and all 11 `%s`/`%d` tokens in order. On-device pass remains a documented pending item (Task 7 Step 3). |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| `packages/luci-app-trusttunnel/po/ru/trusttunnel.po` | Header (msgid "" + UTF-8 + `nplurals=3` Russian Plural-Forms, byte-identical, no BOM) OK; 211 msgids in baseline order OK; 211 new Russian msgstrs (0 empty) OK | 209 msgids ↔ views' `_()` literals (51/79/89, 10 shared), `Status`/`Settings` ↔ menu.d JSON, 11 placeholder msgids ↔ `%s`/`%d` tokens preserved in order | `msgfmt -c` exit 0; statistics 211/211; msgid set == 212-line target; 0 verbatim copies; no `_n()`/`msgid_plural` | PASS |

## Contract Status

| Contract | Status | Notes |
| --- | --- | --- |
| Header (UTF-8, `Plural-Forms: nplurals=3; …`) byte-identical | PASS | Verified: first entry unchanged, no BOM. |
| Duplicate disposition (`Mode` once, first position) | PASS | `Mode` appears exactly once in the catalog. |
| Stale-msgid disposition (4 Exclusions msgids dropped) | PASS | All 4 absent; `.po` msgids not used by views/menu = 0. |
| Placeholder msgids (11, tokens same count/order) | PASS | 11 `%s`/`%d` msgids; token sequences in each msgstr match the msgid exactly. |
| Final commit contains only the `.po` | DEVIATION | Commit `f02abe1` also carries the TT-14 Makefile reimplementation and TT-14 doc updates (see Issues 3). No `*.old` files, working tree clean. |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| Clean-room: new `msgstr` text, never copy inherited expression | COMPLIANT | 0 verbatim old msgstrs; `msgstr == msgid` only for brand/token entries (`TrustTunnel`, `MTU`), per plan protocol §4. |
| No `*.old`/backup files committed; single-file change | COMPLIANT | `git status --porcelain` clean at branch tip ac8cd27; `/tmp/tt13_old.po` used for verification only. |

## Issues Found

1. **`MTU` msgstr is byte-identical to the inherited file**
   - Location: `packages/luci-app-trusttunnel/po/ru/trusttunnel.po` (entry `MTU` → `MTU`)
   - Description: The clean-room rule as stated for this validation allows identical old/new msgstrs only for the header boilerplate and the brand `TrustTunnel`. The `MTU` entry is the single additional byte-identical msgstr (`MTU` in both files). The plan's binding clean-room protocol §4 explicitly exempts token entries whose natural translation equals the msgid ("e.g. `TrustTunnel`, `MTU`"), and no creative expression is involved (a non-translatable acronym).
   - Impact: None on the clean-room goal — `MTU` carries no inherited creative expression.
   - Recommendation: Accept as a token entry per plan protocol §4, and (optionally) record the acceptance in the plan's notes so the strict rule and the protocol are reconciled. If the strict rule (header + `TrustTunnel` only) must be applied literally, this is the one item to adjudicate.
   - Resolved: (pending decision)

2. **Plan Task 7 Step 2 expected diff counts don't match the actual diff shape**
   - Location: `.sdd/.current/issues/TT-13/plan.md` Task 7 Step 2
   - Description: The plan expected `- msgstr = 216` / `+ msgstr = 211`; the actual diff vs the pre-rewrite file is `- msgstr = 214` / `+ msgstr = 209` (`- msgid = 5`, `+ msgid = 0` as expected). The 2-line delta is exactly the `TrustTunnel` and `MTU` entries, whose `msgstr == msgid` in both files and therefore produce no diff lines — consistent with the plan's own protocol §4.
   - Impact: None on the implementation; the expectation was computed without accounting for the two exempted token entries.
   - Recommendation: Update the plan's expected counts to 214/209 (or note the exemption) on the next plan revision.
   - Resolved: (pending)

3. **Commit `f02abe1` bundles TT-13's `.po` with TT-14's Makefile**
   - Location: `f02abe1 po+makefile: re-author the Russian translation and the package Makefile`
   - Description: The plan notes "The final commit for this issue must contain only `packages/luci-app-trusttunnel/po/ru/trusttunnel.po`". The commit also contains the TT-14 Makefile reimplementation (112 lines changed) and TT-14 doc updates.
   - Impact: None on the `.po` content or the acceptance criteria; a process deviation only.
   - Recommendation: Note the bundling in the plan/TT-14 docs; no action needed on the `.po`.
   - Resolved: (pending)

4. **Manual LuCI Russian pass and SDK gate remain pending (documented)**
   - Location: plan Task 7 Step 3 (deferred) and Step 4 (deferred to CI)
   - Description: The on-device LuCI Russian pass (all pages, verdict states, validator errors, import modal, menu) and the OpenWrt SDK build of `luci-i18n-trusttunnel-ru` cannot run in this environment; the plan documents both as deferred, with a catalog read-through as the substitute.
   - Impact: Acceptance criterion 4 rests on a read-through, not on a rendered-page check; no raw `msgid` visible / no meaning drift can only be fully confirmed on a device.
   - Recommendation: Perform the manual pass on a device with `/etc/config/luci` language = Russian when available, following the plan's Step 3 checklist; let CI cover the SDK gate.
   - Resolved: (pending)

## Recommendations

- Adjudicate issue 1 (accept `MTU` as a token per plan §4, or rephrase that one entry) and record the decision.
- Note the diff-count expectation correction (issue 2) and the commit bundling (issue 3) in the plan on its next revision.
- Run the deferred manual LuCI Russian pass (issue 4) in a device session to close the last verification item.
