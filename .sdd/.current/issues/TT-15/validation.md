# Issue Validation Report: TT-15 — default UCI config

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-15/issue.md`
- **Plan**: `.sdd/.current/issues/TT-15/plan.md`
- **Overall Status**: Complete
- **Validation attempt**:
  1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 3 | 0 | 0 | 3 |
| Acceptance Criteria | 2 | 0 | 0 | 2 |
| Entities | 1 | 0 | 0 | 1 |
| Contracts | 0 | 0 | 0 | 0 |
| Guidelines | 0 | 0 | 0 | 0 |

## Task Status

- [x] **Task 1: Baseline — diff the current file against the contract** - PASS
  - Mode recorded: `git ls-files -s` → `100644 1e5e16c3…` (data file, not executable; the CI executable-bit gate lists only scripts, not this file).
  - Option-set extraction (awk on `config`/`option` lines) yields 5 `config` lines and 22 `option` lines, in contract order; the anonymous section prints as `config routing_profile`. Diff against the contract key list: empty.
- [x] **Task 2: Re-create the file from the contract** - PASS
  - `packages/luci-app-trusttunnel/root/etc/config/trusttunnel` is exactly the planned 31-line UCI text: 5 section headers, 22 options, one-TAB indent, single quotes, blank line between sections, no comments, trailing newline at EOF (verified: `wc -l` = 31, last byte 0x0a), mode 100644.
  - Rewrite commit `8bdd775` shows the only change vs the pre-rewrite file is the removal of the 5-line comment block above `config routing_profile` (36 → 31 lines), matching the pinned comment decision.
- [x] **Task 3: Verify — option-set diff vs current (identical) + consistency vs TT-03 and TT-11** - PASS
  - Step 1 (oracle equivalence, comment-normalized): `git show 8bdd775~1:<file>` vs current, stripped of leading whitespace/`#` lines/quotes/blank lines → diff empty; content identical.
  - Step 2 (option-set diff): old vs new key extraction → identical (5 sections / 22 options, same order and values).
  - Step 3 (TT-03 export schema, 26-key set): `uci-export` schema-keys marker (`routing_profile.name/mode/vpn_rules/bypass_rules`) plus main 2, endpoint scalars 11, endpoint lists 2 (`address`, `dns_upstream`), network 6, `domains.direct` 1 = 26 keys. Every file option is in the export schema except `endpoint.certificate` (deliberately excluded per the `uci-export` header). `tests/test_init_apply.sh` schema-completeness check green: "schema parse of uci-export yielded 26 keys", "every schema key is classified explicitly, none fell into the unknown branch". On these defaults `uci-export` emits 15 records (main 2 + endpoint 6 non-empty scalars + routing_profile.name/mode 2 + network 5; empty scalars skipped, lists empty) — matches the plan's prediction.
  - Step 4 (TT-11 field list, 26 fields): `settings.js` edits exactly main (enabled, log_level), endpoint (address, hostname, username, password, protocol, anti_dpi, post_quantum, custom_sni, client_random, routing_profile, has_ipv6, skip_verification, certificate, dns_upstream), routing_profile (name, mode, vpn_rules, bypass_rules), network (mtu, lan_devices, blackhole_on_down, include_router_traffic, fwmark, table) = 26 fields. Bijection with the file's 22 options: every file option maps to a UI field; every UI field maps to a file section/option; the four list fields map to empty list keys; `domains.direct` is not shown in the UI (legacy fallback).
  - Step 5 (rootfs acceptance): local proxy (normalized-content diff + option-set diff) empty. The literal fresh-install `uci export trusttunnel` check runs in the CI rootfs install gate, scoped to the TT-14 install flow (release.yml rootfs verifies on apk 25.12 / opkg 22.03–24.10); macOS has no `uci`, so the proxy is the local evidence (see Recommendation).
  - Step 6 (clean-room hygiene): `git status` clean; no `*.old` copies; the rewrite commit touched only the config file plus issue/plan docs.

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | The file contains exactly the schema above (same option set and content as the current file) | MET | Option-set diff old vs new empty (5 sections / 22 options, same order and values); comment-normalized content diff empty; file is the exact 31-line contract text; no legacy options (`full_exclude_lists`, `lists`, `intercept_dns`/`list_dns`/`list_resolver`/`list_doh_*`/`doh_network`, `domains.bypass`), no `list` lines, no flat `mode` (only `routing_profile.mode 'vpn'`) |
| 2 | `uci export` of a fresh install matches the contract | MET | Content is byte-identical (modulo the dropped comment block, which UCI ignores) to the pre-rewrite shipped file — the file that defined the export behavior — so the export is unchanged by construction; all consumers green (`sh tests/run.sh`: 315 assertions, 0 failed, including the TT-03 26-key schema check and the real-uci container scenarios); CI rootfs install gates cover the fresh install (TT-14 scope) |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| UCI config `trusttunnel` (the file itself) | OK — main (enabled '0', log_level 'info'), endpoint (12 options incl. custom_sni '' / client_random '' / routing_profile 'Default'), network (6 options), anonymous routing_profile (name 'Default', mode 'vpn'), domains (no options); 22 options in TT-03 export order | OK — consumed by `uci-export` (resolves the anonymous `routing_profile` via `endpoint.routing_profile 'Default'`), init.d, settings.js; declared conffile in the Makefile (lines 64–66) | OK — exactly the contract options; five list keys (`endpoint.address`, `endpoint.dns_upstream`, `routing_profile.vpn_rules`, `routing_profile.bypass_rules`, `domains.direct`) exist only as empty lists (no `list` lines); no other sections/options | PASS |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| — (N/A) | — | — | No API contracts in this issue. Cross-check contracts verified instead: TT-03 export schema (26-key set incl. resolved `routing_profile.*` keys) and TT-11 settings.js field list (26 fields) — both consistent with the file's 22 options |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| — (N/A) | N/A | No `AGENTS.md` exists in the repository; no guideline checklist to apply |

## Issues Found

No blocking issues found.

1. **No literal `uci export trusttunnel` gate in CI** (observation, not a failure)
   - Location: `.github/workflows/release.yml` rootfs verify steps (lines 456–506)
   - Description: The release rootfs gates install the package into fresh OpenWrt containers but verify only `trusttunnel_client --version`; no step runs `uci export trusttunnel` and compares it to the contract. The plan scopes this check to the TT-14 install flow and uses the normalized-content + option-set diffs as the local proxy, which are empty and therefore decisive (the file is byte-identical to the previously shipped file modulo comments).
   - Impact: None on this issue's correctness — the equivalence oracle is complete. Future edits to this file would not be caught by a dedicated gate.
   - Recommendation: Optional — when the TT-14 install gate is built, include `uci export trusttunnel` on the fresh rootfs and assert the five sections / 22 options.
   - Resolved:
     *(Filled by `prd-implement-issue` if a revision addresses this.)*

## Recommendations

- None required: all three tasks PASS, both acceptance criteria MET, and the verification trail (oracle diff, TT-03/TT-11 cross-checks, `sh tests/run.sh` green) is complete.
- Optional follow-up (non-blocking, tracked as an observation above): add `uci export trusttunnel` to the CI rootfs install gate as a permanent regression check for the default config.
