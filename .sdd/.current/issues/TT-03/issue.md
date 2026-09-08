# Issue TT-03: uci-export

- **Status**: Planned
- **PRD**: `../../prd.md`
- **Blocked by**: TT-02
- **Effort**: S
- **Files**: `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export`

## Context

`uci-export` was inherited from upstream (comments translated, list-related
options removed in place; the `scalar`/`listopt` structure is inherited
expression). It is the canonical source of the records schema: the init
script's change-classifier completeness test parses this file's source to
learn the key set, so the emitted keys are themselves a contract.

## Contract to reproduce

- Executable shell script; reads the `trusttunnel` UCI config via
  `/lib/functions.sh` (`config_load trusttunnel`) and prints records TSV on
  stdout: `section.option<TAB>value`, one line per value, repeated keys for
  lists.
- Exact emitted schema (order matters for the golden diff):
  - `main.enabled`, `main.log_level`
  - `endpoint.hostname`, `endpoint.username`, `endpoint.password`,
    `endpoint.protocol`, `endpoint.anti_dpi`, `endpoint.post_quantum`,
    `endpoint.skip_verification`, `endpoint.has_ipv6`,
    `endpoint.custom_sni`, `endpoint.client_random`,
    `endpoint.routing_profile`
  - `endpoint.address` (one line per list value), `endpoint.dns_upstream`
    (one line per list value)
  - The ASSIGNED routing profile, resolved by name from
    `endpoint.routing_profile` via `config_foreach` over the
    `routing_profile` sections: `routing_profile.name` (when non-empty),
    `routing_profile.mode`, `routing_profile.vpn_rules` (one line per
    list value), `routing_profile.bypass_rules` (one line per list
    value). Nothing is exported when `endpoint.routing_profile` is empty
    or names no existing section. The resolution source text MUST carry
    the marker comment `# schema-keys: routing_profile.name
    routing_profile.mode routing_profile.vpn_rules
    routing_profile.bypass_rules` (the completeness test parses it) —
    keep it in sync with the emitted options. Total schema: 26 keys.
  - `network.mtu`, `network.table`, `network.fwmark`,
    `network.blackhole_on_down`, `network.include_router_traffic`,
    `network.lan_devices`
  - `domains.direct` (one line per list value) — the legacy fallback
    list; still exported for the no-profile case.
- `endpoint.certificate` is deliberately NOT exported (multi-line PEM
  cannot be a record value); the init script writes it to `endpoint.pem`.
- No other keys, ever (foreign edits to the UCI config must not leak into
  records).
- MUST NOT use `set -u`: `/lib/functions.sh` reads uninitialized variables
  (`IPKG_INSTROOT`, `CONFIG_LIST_STATE`), and under `set -u` the script
  dies before printing anything — verified on a live router; this is a
  behavioral requirement, not a style choice.
- Executable bit `100755` in the git index (CI enforces it).

## Acceptance criteria

- [ ] Against the default `/etc/config/trusttunnel` values the output
      contains exactly the schema above, in order.
- [ ] Golden byte-diff: old vs new implementation produce identical output
      for the same UCI input (use `tests/fixtures/records/*.tsv` as the
      expected shape reference).
- [ ] The schema-completeness test in `tests/test_init_apply.sh` still
      passes (it parses this file's key list).
- [ ] No `set -u`, executable bit set.

## How to verify

1. `sh tests/run.sh` — `test_init_apply.sh` green (schema check).
2. Manual: `uci export trusttunnel` into a scratch config dir and compare
   old vs new script output byte-for-byte.
3. `shellcheck -s sh` clean (with the existing SC1091 disable comment).

## Notes

- `tests/test_records.sh` semantics apply to the output format; this file
  has no dedicated test script of its own (schema is tested via
  `test_init_apply.sh` and the golden diff).
- **Source-shape coupling (critical)**: `schema_keys()` in
  `tests/test_init_apply.sh` awk-parses this file's SOURCE TEXT with
  literal token patterns — the loop variable must literally be `o`, the
  `scalar` keyword must be followed by the section name, `listopt
  <section> <option>` must sit at line start, and multi-line continuations
  need the two-TAB indentation. The new file must keep this structural
  shape or the schema-completeness gate silently drops keys.
- Golden capture needs a working `/lib/functions.sh` (macOS lacks it):
  use a scratch stub with the documented config_load semantics, or a live
  router / docker-alpine container.
