# Issue Validation Report: TT-05 — routing (nft/ip management)

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-05/issue.md`
- **Plan**: `.sdd/.current/issues/TT-05/plan.md`
- **Overall Status**: Complete
- **Validation attempt**:
  1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 4 | 0 | 0 | 4 |
| Acceptance Criteria | 3 | 0 | 0 | 3 |
| Entities | 2 | 0 | 0 | 2 |
| Contracts | 1 | 0 | 0 | 1 |
| Guidelines | 0 | 0 | 0 | 0 |

## Task Status

- [x] **Task 1**: Snapshot the oracle and capture `routing dump` goldens - PASS
      The oracle material is intact under `/tmp/tt05/` (`routing.old`,
      `test_routing.old.sh`, `up.tsv`, `router.tsv`, `up.golden`,
      `router.golden`, `smoke.sh`). Re-verified the golden byte shape and the
      fixture difference set: `up.golden` has `iifname != { "br-lan",
      "br-guest" }` and no output chain; `router.golden` has
      `iifname != { "br-lan" }` plus the output-chain block — exactly the
      difference set the plan's verification describes.
- [x] **Task 2**: Rewrite `tests/test_routing.sh` from the contract - PASS
      The rewritten test runs 51 assertions, 0 failed against the NEW
      implementation (`sh tests/test_routing.sh`), and the same 51/0 against
      the oracle snapshot (`TT_ROUTING=/tmp/tt05/routing.old sh
      tests/test_routing.sh`) — the oracle-validation step holds. The
      stubbed `ip`/`nft` argv-logging technique with `$TT_ROUTING` override,
      `$TT_NFT_STDIN` capture for `-f -` only, and literal fixture endpoints
      (no real nslookup) matches the plan.
- [x] **Task 3**: Implement the new `routing` script from the contract - PASS
      `sh -n` clean; pinned shellcheck `koalaman/shellcheck:v0.11.0 -s sh`
      clean (exit 0, no findings) on the script and the test; rewritten test
      green; both golden diffs byte-identical (`diff` and `cmp` empty on
      `up.tsv`/`up.golden` and `router.tsv`/`router.golden`); the exact
      literals `TT_IP="${TT_IP:-ip}"` and `TT_NFT="${TT_NFT:-nft}"` present
      (`grep -Fq` both exit 0); mode `100755` (`git ls-files -s` and
      `stat`).
- [x] **Task 4**: End-to-end verification and smoke checklist - PASS
      Full suite green: `sh tests/run.sh` → `== all tests passed` (10 test
      files; `test_deps.sh` 26/0 including the byte-for-byte literal
      assertions; `test_routing.sh` 51/0). Final `cmp` byte-identical on
      both fixtures; shellcheck clean on both files; mode 100755; `git
      status --short` clean with exactly the two intended tracked files
      (committed in `0d95892`, tip `ad2b309`) and no stray `??` entries.
      Device/rootfs smoke re-run by the validator on
      `openwrt/rootfs:x86-64-25.12.0` and `x86-64-22.03.7` with
      `--cap-add=NET_ADMIN`: 25.12 passes every item; 22.03 passes every
      item except the v6-blackhole check, which is a busybox-22.03
      limitation reproduced identically by the OLD implementation (see
      Issues Found #2).

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | `tests/test_routing.sh` rewritten from the contract and green (dump content: sets, prerouting mangle, iifname set, endpoint returns, private ranges, mark line, no output chain by default, output chain + `oifname "tun*"` when router traffic on, no tt_bypass, no dstnat; line-break hygiene; `up` blackhole + rules via stubbed `ip`, single `nft -f -` transaction, no tuntap/link set; `attach`/`detach`/`down` route replace/del + device file; no-blackhole variant; unknown subcommand exit 1) | MET | `tests/test_routing.sh` — 51 assertions, 0 failed, both against the new script and against the oracle (`/tmp/tt05/routing.old`); inside `sh tests/run.sh` green |
| 2 | Golden byte-diff: old vs new `routing dump` identical on both record fixtures | MET | `diff` and `cmp` empty for `up.tsv` vs `up.golden` and `router.tsv` vs `router.golden` (re-run at validation time) |
| 3 | `shellcheck -s sh` clean | MET | `koalaman/shellcheck:v0.11.0 -s sh` exits 0 with no findings on `routing` and `tests/test_routing.sh` |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| Kernel routing state | OK — nft table `inet trusttunnel` with `tt_endpoint4/6` interval sets, prerouting (filter/mangle) + optional output (route/mangle) chains, `meta mark set 0x9527`, fwmark rule `0x9527/880/30820`, blackhole metric 1000, attached route metric 1, `$OUT_DIR/device` file | OK — up→attach→detach→down verified live on 25.12 rootfs; reattach idempotent; detach leaves blackhole+nft; down removes rule/table/nft/device file but never the client device | OK — constants pinned by goldens and tests; device validated live via `ip link show dev`; ruleset bytes byte-identical to oracle | PASS |
| Records TSV (read-only input) | OK — `network.table` 880, `network.fwmark` 0x9527, `include_router_traffic` 0, `blackhole_on_down` 1, `network.mtu` 1350 (coerced, vestigial read kept), `network.lan_devices` with the dump-mode-uci-skip fallback chain, `endpoint.address` list | OK — consumed via `records.sh` (`tt_get`/`tt_bool`/`tt_list`, TT-02 interface); booleans via `tt_bool`; MTU coercion junk → 1350 present | OK — exercised by the suite fixtures and the validator's behavioral checks (dump skips `uci`, non-dump consults it, empty → `br-lan`) | PASS |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| `routing dump\|up\|attach\|reattach\|detach\|down\|status <records> [out-dir] [device]` | CLI | PASS | All 7 subcommands present; env overrides `TT_IP`/`TT_NFT`/`TT_LIBDIR`; unknown subcommand → `routing: unknown subcommand '<cmd>'` on stderr, exit 1; missing records → `routing: missing records file`, exit 1; mode 100755 |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| (no AGENTS.md in the repository) | N/A | No project guidelines file exists; nothing to check |

## Issues Found

1. **[Low — throwaway oracle harness, not in the committed tree] `smoke.sh` item 4 false positive: `grep -q 'metric 1'` matches the blackhole's `metric 1000`**
   - Location: `/tmp/tt05/smoke.sh` (line 61, the "detach leaves only the blackhole" check); never committed
   - Description: After detach, table 880 contains only `blackhole default metric 1000`; the check `! ip route show table 880 | grep -q 'metric 1'` fails because "metric 1000" contains the substring "metric 1". The implementation behavior is correct — verified directly: up → attach → detach leaves exactly the blackhole and no metric-1 route.
   - Impact: The smoke checklist as written reports a FAIL for a correct state on both 25.12 and 22.03. Does not affect the committed implementation or the test suite.
   - Recommendation: Anchor the pattern in the throwaway script, e.g. `grep -Eq 'metric 1([^0-9]|$)'`. With the anchor, all smoke items pass on 25.12 (verified).
   - Resolved: *(to be filled on re-validation if the harness is corrected)*

2. **[Informational — environment limitation, not a regression] v6 blackhole is not installed by busybox `ip` on 22.03**
   - Location: rootfs smoke item 1 on `openwrt/rootfs:x86-64-22.03.7`; busybox 22.03 `ip` (v1.35) behavior
   - Description: `ip -6 route replace blackhole default table 880 metric 1000` exits 0 but installs nothing (`ip -6 route show table 880` is empty) on the 22.03 busybox. Verified side-by-side: the OLD implementation (`/tmp/tt05/routing.old`) leaves the identical state — v4 blackhole present, v6 table empty, fwmark rule present. The reimplementation is functionally identical to the oracle on this platform.
   - Impact: None for this issue — the contract is behavioral equivalence with the inherited implementation, which holds byte-for-byte. On 25.12 (busybox v1.37 / iproute2) the v6 blackhole installs and the check passes.
   - Recommendation: None for the implementation; if the smoke checklist is re-run on 22.03, expect this single environmental FAIL and treat it as such.

## Recommendations

- No implementation changes required: all tasks PASS, all acceptance criteria MET, suite and goldens green, smoke passed on 25.12 and passed on 22.03 modulo the busybox-22.03 `ip -6` limitation shared with the old implementation.
- If the throwaway smoke checklist is reused (e.g. for later issues), fix the item-4 grep anchor (`metric 1([^0-9]|$)` instead of `metric 1`) so the check reports the true state.
- Optional: commit the TT-05 implementation record already landed (`0d95892` + `a7c5c5b`); the working tree contains exactly the two intended tracked changes and no oracle material.
