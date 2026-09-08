# Plan Review Report: TT-06 — init.d service script

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-06/issue.md`
- **Plan**: `.sdd/.current/issues/TT-06/plan.md`
- **Verdict**: Revised
- **Review attempt**: 1

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | fail | 4 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | pass | 0 |
| Architecture | pass | 0 |
| Operational | pass | 0 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[medium] correctness — `setup_trust_store` is never assigned to any task**
   - Target: plan.md Task 4 (and Tasks 2-8 chunk assignments)
   - Impact: It is in the contract and called by start_service, but no task writes it; neither oracle test exercises it, so it could be silently omitted until the device smoke test.
   - Recommendation: Add it to Task 4 (start/stop chunk) including its contract log line.
   - Status: Open
   - Resolved: Task 4 (start/stop chunk) now has a dedicated Step 1 that writes `setup_trust_store()` from the contract — `-s` probe of /etc/ssl/cert.pem then /etc/ssl/certs/ca-certificates.crt, `SSL_CERT_DIR=/etc/ssl/certs` when the dir exists, early return on skip_verification=1 or a pinned certificate, and the contract log line `error: no CA bundle found; install ca-bundle, pin a certificate, or disable verification` (log line #3) on failure. The task title and verification now name it, and start_service's step consumes it as written in-chunk.
2. **[low] correctness — Stale oracle assertion counts (24+20 vs actual 29+21)**
   - Target: Summary, Task 1 Step 1, Task 7 Step 4, Task 8 Step 3
   - Impact: The oracle tests grew on main (profile assertions); the plan's quoted counts are pre-rebase. Gate itself unaffected.
   - Recommendation: Re-measure and update the counts.
   - Status: Open
   - Resolved: Counts re-measured from a real `sh tests/run.sh` run on c43e20a — test_init_apply.sh 29 assertions and test_init_reload.sh 21 assertions, 0 failed; updated in the Summary, Task 1 Step 1, Task 7 Step 4, and Task 8 Step 3 (full suite 180 assertions today, incl. the oracle).
3. **[low] correctness — Schema key counts do not match (26, not 25 or 19)**
   - Target: plan.md Research/actualization; issue.md
   - Impact: Parsing the real uci-export yields 26 keys; the plan/issue carry 25 and 19. Documentation-only (the ≥15 sanity threshold is what is enforced).
   - Recommendation: Pin 26 keys (and fix the issue contract).
   - Status: Open
   - Resolved: The plan pins 26 keys everywhere (actualization, Research §1 completeness check, Research §3 breakdown: 2 main + 13 endpoint incl. routing_profile and the two lists + 4 routing_profile.* + 6 network + 1 domains), confirmed by the oracle run ("schema parse of uci-export yielded 26 keys"). The actualization notes issue.md's "25-key schema threshold" as a typo for the caller; issue.md itself is out of scope for this revision (not edited).
4. **[low] correctness — `routing_profile.*` → restart branch missing from the plan body**
   - Target: Research 1 and Task 7 Step 1
   - Impact: Only the actualization carries the branch; an implementer reading Task 7 alone would produce a classifier failing the extended oracle.
   - Recommendation: Add the branch to the change_class spec table and Task 7.
   - Status: Open
   - Resolved: The `routing_profile.*` → restart branch (name, mode, vpn_rules, bypass_rules) and `endpoint.routing_profile` → restart are now in the Research §1 `change_class` spec table AND Task 7 Step 1; Research §1's reload section additionally names the profile-change scenario assertion (`routing_profile.mode` edit → `restart keep_routing=1`).
5. **[low] operational — Actualization's device-checklist item not carried into Task 9**
   - Target: plan.md actualization vs Task 9 Step 2
   - Impact: "editing the assigned profile reloads via restart-keep-routing" is missing from the checklist.
   - Recommendation: Add the item.
   - Status: Open
   - Resolved: Task 9 Step 2 now includes editing the assigned profile (`routing_profile.name`/`mode`/`vpn_rules`/`bypass_rules`) or switching it (`endpoint.routing_profile`) → client restart via restart-keep-routing, alongside the existing lan_devices/hostname/table items.

## Dismissed Findings

None.

## Notes

- The routing_profile.* branch exists in the current init.d; the extended oracle assertions, chunk ordering, log lines, procd params, and the 4 acceptance criteria all map to concrete tasks. Clean-room and PRD no-fix policy respected.
- On re-review, this report is updated in place.
