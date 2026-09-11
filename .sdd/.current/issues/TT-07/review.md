# Plan Review Report: TT-07 — uci-defaults (first-boot firewall setup)

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-07/issue.md`
- **Plan**: `.sdd/.current/issues/TT-07/plan.md`
- **Verdict**: Approved
- **Review attempt**: 2

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | pass | 5 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | pass | 0 |
| Architecture | pass | 0 |
| Operational | pass | 0 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[high] correctness — The upgrade/profile-seed scenario was never added to the task list**
   - Target: plan.md Tasks 1-6 vs Actualization
   - Impact: The actualization promises a 4th "upgrade" scenario and the seed-block implementation, but Tasks 2-5 cover only dedup/creation/migration/finalize and no task asserts the profile seed (name/mode/bypass_rules migration, endpoint.routing_profile). An implementer would silently drop the seed — a functional regression against the current tree and install.sh's immediate-run step.
   - Recommendation: Add the upgrade scenario to Task 1 and a seed-block task (name/mode/migration/commit/log assertions).
   - Status: Resolved
   - Resolved: Task 1 Step 1 now lists the FOURTH scenario `upgrade` (no routing_profile section + populated domains.direct → a Default profile with the migrated bypass_rules and endpoint.routing_profile='Default'; re-run → no-op), and the seed block gets its own task body — Task 5 "Routing profile seed block" — which implements and asserts it in a red/green cycle (config_load trusttunnel, config_foreach count, name='Default'/mode='vpn', domains.direct → bypass_rules via the `uci -q get | while read` pipeline, endpoint.routing_profile, uci commit trusttunnel, exact log string), with regression checks on the previous chunks.
2. **[high] correctness — Side-effects scenario asserts "log empty" but the seed block fires on every run**
   - Target: Task 1 Step 1 scenario 4, Step 3
   - Impact: The stock rootfs image has no /etc/config/trusttunnel, so the seed block writes the "created the default routing profile..." log line on every scenario; the baseline "all five scenarios green" is unachievable as written.
   - Recommendation: Provide a trusttunnel config in the side-effects fixture or assert the expected log line.
   - Status: Resolved
   - Resolved: every scenario fixture now ships a scratch /etc/config/trusttunnel in the shipped-config shape (a Default routing_profile section), copied into the container by the runner, so the seed block is a no-op in the baseline scenarios and the side-effects "log empty" assertion holds on the stock rootfs image; the seed's firing is exercised only in the `upgrade` and `idempotent` scenarios, which assert the "created the default routing profile..." log line explicitly.
3. **[medium] correctness — Duplicated scenario's ZONE_COUNT=1 is wrong with an unrelated zone present**
   - Target: Task 1 Step 1 scenario 2
   - Impact: ZONE_COUNT counts all zones; the fixture also contains `lanzone` which is asserted to survive, so after dedup the count is 2, not 1.
   - Recommendation: Scope the count to trusttunnel zones or expect 2.
   - Status: Resolved
   - Resolved: zone-count assertions are now scoped to trusttunnel zones (`grep -c "name='trusttunnel'"`); the duplicated scenario additionally asserts the total `@zone[` count is 2, proving the unrelated `lanzone` survives dedup while exactly one trusttunnel zone remains.
4. **[medium] correctness — Legacy scenario's FWD_COUNT=1 is wrong (no forwarding in the fixture)**
   - Target: Task 1 Step 1 scenario 3
   - Impact: The fixture has no forwarding and creation is suppressed, so FWD_COUNT must be 0 (or the fixture needs the forwarding a real upgraded router has).
   - Recommendation: Fix the assertion or the fixture.
   - Status: Resolved
   - Resolved: the legacy scenario now asserts FWD_COUNT=0 — the fixture has no forwarding, creation does not fire (the zone exists), and the migration phase never creates forwarding, matching the contract.
5. **[low] correctness — Actualization's "idempotence covers the seed block" is overstated**
   - Target: plan.md Actualization line 27; Task 6 Step 1
   - Impact: Task 6 diffs only `uci show firewall` and log lines; the seed block's UCI state (trusttunnel config) is never asserted.
   - Recommendation: Add a trusttunnel-config dump to the idempotence check.
   - Status: Resolved
   - Resolved: the idempotence check (now Task 7, renumbered after the seed task was inserted) uses an upgrade-shaped fixture (no profile + populated domains.direct) and dumps BOTH `uci show firewall` and `uci show trusttunnel` after each run; it asserts both dumps identical and no new log lines after run 2, so the seed block's no-op on the second run is actually asserted.

## Dismissed Findings

None.

## Notes

- Re-review (attempt 2): all 5 prior findings verified Resolved (upgrade scenario + seed-block task, side-effects fixture, trusttunnel-scoped zone counts, FWD_COUNT=0, idempotence dumps trusttunnel state).
- New on re-review (informational): the double-run runner variant writes per-run dumps to container files (/tmp/fw1, /tmp/fw2, /tmp/tt1, /tmp/tt2, RELOADS) but the plan never states these are emitted into the captured out stream — the host-side assertions have no stated access path; make the cat of the per-run dumps explicit in Task 1 Step 1.
- On re-review, this report is updated in place.
