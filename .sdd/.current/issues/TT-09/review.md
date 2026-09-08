# Plan Review Report: TT-09 — rpcd ucode backend

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-09/issue.md`
- **Plan**: `.sdd/.current/issues/TT-09/plan.md`
- **Verdict**: Revised
- **Review attempt**: 1

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | fail | 4 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | fail | 1 |
| Architecture | fail | 1 |
| Operational | pass | 0 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[high] correctness — Actualization not propagated into Task 3 (status keys)**
   - Target: Task 3 Step 2, R1/D9, Contracts table
   - Impact: The task body and Contracts table freeze the pre-rebase 11-key status set without routing_profile/routing_mode/vpn_mode; the implemented status cannot byte-match goldens from the current 14-key file.
   - Recommendation: Update Task 3, R1/D9 and the Contracts table to the 14-key set.
   - Status: Open
   - Resolved: Task 3 Step 2 now specifies the full actualized status key set — `enabled, running, device, device_up, rule, table, nft, endpoint_hostname, addresses[], client_installed, routing_profile, routing_mode, vpn_mode` — with `routing_profile`/`routing_mode` from the resolved records and `vpn_mode` = 'selective' iff mode 'bypass'; the Contracts table `status` row and R1/D9 carry the same set; Task 3 Step 4 runs status against base/bypass-profile/vpn-profile/service-stopped/no-records goldens.
2. **[high] correctness — Task 5 (check_domain) still pre-rebase**
   - Target: Task 5 Steps 2 and 4
   - Impact: No profile-aware list keys (routing_profile.vpn_rules/bypass_rules) or the four new reason strings; no profile scenarios.
   - Recommendation: Rewrite Task 5 per the actualized contract.
   - Status: Open
   - Resolved: Task 5 Step 2 rewritten with the profile-aware list-key selection (`routing_profile.vpn_rules` for a bypass-mode profile / `routing_profile.bypass_rules` for a vpn-mode profile / legacy `domains.direct`) and all six exact reason strings with their verdict mapping; Step 4's case list covers bypass-profile in/not-in vpn_rules, vpn-profile in/not-in bypass_rules, and the legacy base direct/suffix/non-direct cases plus empty and case-variant.
3. **[high] correctness — Task 6 (diagnose) still pre-rebase (17 vs 18 checks)**
   - Target: Task 6 Steps 2 and 4, R1/D2
   - Impact: No Routing profile check; base all-ok is 17 entries post-rebase, not 16; MTU-warn case is 18.
   - Recommendation: Update counts and the check list.
   - Status: Open
   - Resolved: Task 6 Step 2 now lists the "Routing profile" check (after "TLS host name", config group) with the exact detail/hint strings and the up-to-18-entry check list; Step 4 counts corrected to 17/18: base legacy healthy = 17 entries `{ok:16,warn:1,fail:0,skip:0}` verdict warn (the single warn is the Routing profile entry), healthy profile scenarios = 17 entries `{ok:17,warn:0,...}` verdict ok, diagnose-mtu-mismatch = 18 entries; R1/D2 refreshed to 18 possible entries incl. the Routing profile label.
4. **[high] correctness — Task 7 (import_config) still pre-rebase (5-field parser)**
   - Target: Task 7 Steps 2 and 4, Contracts table
   - Impact: No custom_sni/client_random/upstream_protocol→protocol/bools/dns_upstreams, no unquote/unlist/unbool shape parser, no every-field or malformed-value scenarios.
   - Recommendation: Rewrite Task 7 around the shape parser and extend the scenarios.
   - Status: Open
   - Resolved: Task 7 Step 2 rewritten around the shape parser (unquote/unlist/unbool; string fields incl. custom_sni/client_random taken non-empty; upstream_protocol http2/http3 → protocol; booleans → '1'/'0'; addresses + dns_upstreams arrays; initial `{addresses: [], dns_upstreams: []}`; recognisability test covers hostname/username/password/certificate/addresses only); Step 4 adds the every-field (12-key) and malformed-value scenarios (bad bool dropped, unquoted string skipped, unknown keys ignored, only custom_sni set → unrecognisable error); the Contracts table `import_config` row is the 12-key response and R1/D7/D9 were extended with the parser facts.
5. **[medium] architecture — Golden scenario matrix has no profile cases**
   - Target: Task 1 Step 4, File Structure scenarios
   - Impact: Only a legacy base scenario exists; the profile-aware branches of status/check_domain/diagnose have no golden fixtures, so equivalence for them cannot be proven.
   - Recommendation: Add bypass-profile, vpn-profile and legacy scenarios to the matrix.
   - Status: Open
   - Resolved: Task 1 Step 4 and the File Structure scenarios row now include `bypass-profile` (routing_profile.name/mode=bypass + vpn_rules) and `vpn-profile` (mode=vpn + bypass_rules) scenarios next to the legacy `base` (no profile); they differ from base only in the routing_profile.* TSV keys, so status/check_domain/diagnose all get profile-aware golden fixtures and the legacy branches stay covered by base.
6. **[medium] maintainability — R1/D2/D9 stale; two contradictory contract descriptions**
   - Target: plan.md R1 (D2, D9), Actualization
   - Impact: "Checked line-by-line… no contract violations" and the precision notes are pre-rebase; the plan carries two versions of the same contract with no authority statement.
   - Recommendation: Refresh R1 and state the actualization as authoritative.
   - Status: Open
   - Resolved: R1 re-verified against the actualized contract on the current file (c43e20a) with no violations; D2 now documents 18 possible diagnose entries incl. "Routing profile"; D9 status key order includes routing_profile/routing_mode/vpn_mode; the Actualization section now declares itself authoritative over any pre-rebase wording, and the Self-Review Notes record that every pre-rebase fragment was updated in place.
7. **[low] operational — docker ucode gate re-runs apt-get on every invocation**
   - Target: Task 1 Step 1
   - Impact: "Cached afterwards" is only partially true; every gate run pays the network+install cost.
   - Recommendation: Pre-build a reusable image or cache the apt layer.
   - Status: Open
   - Resolved: Task 1 Step 1 now builds a reusable `tt-ucode-gate` image from a new `tests/backend/Dockerfile` (apt deps + the pinned ucode v0.0.20250529 build); the apt layer is cached in the image, so the per-invocation gate path (`docker run tt-ucode-gate ... ucode -L ... -c <file>`) no longer re-runs apt-get; the stale `.ucode-build/` host cache and the `.gitignore` change were dropped.
8. **[low] operational — Rootfs stub injection mechanism unspecified**
   - Target: File Structure rootfs/, Task 1 Step 4
   - Impact: How /etc/init.d/trusttunnel, /usr/libexec/trusttunnel/routing and /opt/trusttunnel_client/* stubs get into the container is not described; the plan claims every step names commands.
   - Recommendation: Specify bind-mount or docker cp/exec steps.
   - Status: Open
   - Resolved: Task 1 Step 4 and the File Structure rootfs row now specify the injection mechanism: `tests/backend/rootfs/` is bind-mounted read-only at `/rootfs-stubs` and copied to the absolute targets (`/etc/init.d/trusttunnel`, `/usr/libexec/trusttunnel/routing`, `/opt/trusttunnel_client/trusttunnel_client`, `/opt/trusttunnel_client/setup_wizard`) via `install -d` + `install -m 0755` in the `-x` launch chain before ucode runs, with `docker cp` + `docker exec` documented as the fallback.

## Dismissed Findings

None.

## Notes

- The actualization itself is accurate against the code; the issue contract matches the code on every actualized point; security assertions (0600, unlink, no UCI) and the clean-room rule verified.
- On re-review, this report is updated in place.
