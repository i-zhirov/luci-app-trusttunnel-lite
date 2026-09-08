# Implementation Plan: TT-13 — Russian translation (.po) clean-room re-translation

- **Created**: 2026-09-08
- **Revised**: 2026-09-09
- **Status**: Draft
- **Issue**: `.sdd/.current/issues/TT-13/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM reimplementation: `packages/luci-app-trusttunnel/po/ru/trusttunnel.po` is inherited GPL-2.0 code — the Russian `msgstr` text must be RE-TRANSLATED (new Russian text, same meaning). The `msgid` set is the contract (pinned by TT-10/11/12). The header (UTF-8, `Plural-Forms: nplurals=3` Russian) stays. `msgfmt -c` must pass. msgids may be listed in the plan; no inherited `msgstr` text may be copied into the plan or the new file."

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (routing-profiles feature,
commit c43e20a). Re-measured on that tree:

- **34 new msgids** were added on main (profile fields/validation,
  custom_sni/client_random messages, profile-aware verdicts and Mode
  rows). The current `.po` has **217 msgid lines = 216 real msgids**
  (215 unique — `msgid "Mode"` is duplicated at lines 37 and 607).
- The current file **fails `msgfmt -c`** (fatal `duplicate message
  definition` for `Mode`, line 607 vs first definition at line 38) — the
  pre-rebase "exit 0" baseline is gone; the baseline gate in Task 1
  reflects the real red state and the skeleton (Task 2) is the first
  green state.
- **4 stale msgids** from the removed Exclusions tab remain in the
  inherited file ('Do not bypass these', 'Exclusions', 'Everything goes
  through the tunnel; …', 'Always sent out directly. Accepts a domain,
  …'). The issue contract requires the `msgid` set to exactly match the
  views' keys, so the re-authored catalog **drops them** (Task 1 filters
  them out; the skeleton never contains them).
- The re-translation task list gains a **fourth group** (Task 6) for the
  34 new profile/SNI/random strings (Routing profiles tab, validators,
  status verdicts).
- Task 1's cross-check runs against the REBASED views' key sets
  (re-measured: status.js 51, settings.js 79, diagnostics.js 89 unique
  `_()` keys; union 209; 10 keys shared by exactly two views).
- Everything else (header, plural forms, msgfmt gate, verbatim-copy
  check) unchanged.

## Summary

Rewrite `packages/luci-app-trusttunnel/po/ru/trusttunnel.po` as a clean-room
re-translation: keep the `msgid` set (deduplicated to one `Mode`, the 4 stale
Exclusions msgids dropped), keep the entry order and the minimal LuCI header
byte-identical to today, and author **new** Russian `msgstr` text for all
**211** entries: the 209 unique `_()` keys used by the rewritten views
`status.js`/`settings.js`/`diagnostics.js` + the 2 menu-only titles (`Status`,
`Settings`). The old `msgstr` text is never consulted while authoring: the only
authoring input is a skeleton generated from the pinned `msgid` list (212
lines incl. the header). Verification is mechanical (`msgfmt -c`,
`msgfmt --statistics` = 211 translated, msgid-set identity diff vs the
212-line baseline, placeholder-token check over the 11 `%s`/`%d` msgids,
old-vs-new verbatim-copy check) plus a manual LuCI Russian pass.

## Technical Context

- **File format**: Gettext `.po` as used by LuCI packages. UTF-8 (no BOM; the
  file contains em-dashes, ellipsis and «»-style punctuation). Entry layout
  follows the standard LuCI convention seen in this file today: header first,
  then one `msgid "…"` line + one `msgstr "…"` line per entry, blank line
  between entries, ASCII quoting with `\"` escapes for embedded double quotes.
  Escaping rules to preserve: `"` → `\"`, `\` → `\\`, `%` stays literal;
  apostrophes need no escape.
- **Header**: the minimal LuCI header is kept exactly as-is (boilerplate, not
  creative expression — the issue confirms): `msgid ""` whose `msgstr` carries
  `Content-Type: text/plain; charset=UTF-8` and the Russian plural rule
  `Plural-Forms: nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);`.
  `msgfmt -c` warns about the missing optional fields (`Project-Id-Version`,
  `PO-Revision-Date`, `Last-Translator`, `Language-Team`, `MIME-Version`,
  `Content-Transfer-Encoding`, `Language`) — expected and acceptable for the
  LuCI-minimal header; **do not** add those fields.
- **Plural forms**: no view calls `_n()`/`ngettext` (verified: zero `_n(`
  occurrences in the three views), so the catalog needs no `msgid_plural`
  entries; the `nplurals=3` header is retained as contract boilerplate only.
- **Placeholders**: exactly **11 msgids** carry `%s`/`%d` tokens (5 legacy +
  6 new profile strings; two of the new ones carry a double `%s` — see
  Contracts). Each new `msgstr` must keep the same tokens in the same order.
- **Key contract**: `msgid` strings are the interface between the views and
  the catalog. The set is pinned by TT-10/TT-11/TT-12 ("translation keys
  unchanged") and by the menu file `root/usr/share/luci/menu.d/luci-app-trusttunnel.json`
  (titles are translated at runtime through this app's `.po`). Re-measured on
  c43e20a the target set is **211 msgids** = 209 view keys + `Status` +
  `Settings` (menu-only). The current `.po` additionally carries 4 stale
  msgids (dropped) and a duplicate `Mode` (deduplicated).
- **Build/validation**: locally `msgfmt` is available
  (`/opt/homebrew/bin/msgfmt`, GNU gettext-tools). In the OpenWrt SDK build the
  package Makefile includes `$(TOPDIR)/feeds/luci/luci.mk`, which compiles
  `po/ru/trusttunnel.po` into the `luci-i18n-trusttunnel-ru` package (the
  `po2lmo` host tool turns the `.po` into a binary `.lmo`; ci.yml/release.yml
  reference the `luci-i18n-trusttunnel-*` artifacts). `msgfmt -c` is the
  stricter local gate from the issue contract: a file that passes `msgfmt -c`
  is well-formed for `po2lmo`.
- **Target platform**: OpenWrt (LuCI 22.03–25.12 / apk + opkg), Russian locale.

## Research

### msgfmt availability and current gate state

- `command -v msgfmt` → `/opt/homebrew/bin/msgfmt` (GNU gettext-tools 1.0).
  Docker fallback is **not** needed.
- Baseline gate on the current file (re-measured 2026-09-09 on c43e20a):
  `msgfmt -c -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po`
  → **exit 1** — fatal error:
  `trusttunnel.po:607: duplicate message definition...` / `trusttunnel.po:38:
  ...this is the location of the first definition` / `msgfmt: found 1 fatal
  error`. `msgfmt --statistics` fails with the same fatal error and prints no
  count. This red state is the baseline defect: the duplicate `msgid "Mode"`
  (first at line 37, second at line 607) makes the inherited file invalid.
  The first green `msgfmt -c` is the **skeleton** in Task 2 (after Task 1
  deduplicates `Mode` and drops the 4 stale msgids).
- The LuCI i18n build gate itself runs only inside the SDK build
  (`luci-i18n-trusttunnel-ru`). It cannot be run locally without the OpenWrt
  SDK + feeds; passing `msgfmt -c` is accepted as the local equivalent (the
  issue's contract). Optional stretch verification: build the package in the
  SDK (e.g. via a docker `openwrt/sdk` image) and confirm
  `luci-i18n-trusttunnel-ru` builds and installs.

### Key-set audit (re-measured on c43e20a, 2026-09-09)

Extracted from the current `.po` and the three views (scripts in Task 1):

| Set | Count |
| --- | --- |
| `.po` msgid lines total (incl. header) | 217 (= header + 216 msgids) |
| `.po` real msgids | 216 |
| `.po` unique real msgids | 215 (dedup of the duplicate `Mode`; 2nd occurrence at line 607) |
| View `_()` keys, unique (union of 3 views) | 209 |
| — `status.js` | 51 |
| — `settings.js` | 79 |
| — `diagnostics.js` | 89 |
| Keys shared by exactly two views | 10 |
| Menu-only titles present in `.po` (`menu.d` JSON) | 2: `Status`, `Settings` |
| Stale msgids (removed Exclusions tab) | 4: `Do not bypass these` (line 184), `Exclusions` (line 514), `Everything goes through the tunnel; these entries always go out directly. The client applies them by SNI, after the kernel has already marked the traffic.` (line 511), `Always sent out directly. Accepts a domain, *.domain, an IP address or a CIDR range.` (line 499) |
| View keys missing from the `.po` | **0** |
| `.po` msgids not used by views or menu | the 4 stale above (besides header); `Status`/`Settings` are the menu-only titles |
| Target msgid set (dedup + drop stale) | **211** = 209 view keys + `Status` + `Settings` |
| Target `.po` msgid lines incl. header | **212** |

So the pinned contract set = 209 view keys + 2 menu titles = **211 msgids**
(the current 216 − 1 duplicate `Mode` − 4 stale). The two quote-escaped view
keys (`Domains from the "do not bypass" list are sent out directly.` and
`Press Start to run it now, or turn on "Start on boot" in Settings.`) are
present in the `.po` as `\"`-escaped msgids — confirmed matched after
unescaping.

Note on the earlier 90/210 count: the re-measured unique `_()` key set of
`diagnostics.js` is 89 and the union is 209. A count of 90 arises only if a
non-catalog string is included — the `DIAG_TEXT` map key `/dev/net/tun
present` (diagnostics.js line 110) maps to `_('present')` and is itself
**not** a `_()` key: the catalog needs only `present`. Task 1's probes are
authoritative and must reproduce the table exactly.

Shared keys (one translation each; ownership assigned to a single task):

| msgid | Used by | Owned by |
| --- | --- | --- |
| `Checking…` | status, diagnostics | Task 3 |
| `Press Start and read the client log below.` | status, diagnostics | Task 3 |
| `TrustTunnel` | status, settings | Task 3 |
| `TrustTunnel client` | status, diagnostics | Task 3 |
| `not installed` | status, diagnostics | Task 3 |
| `Mode` | status, settings | Task 6 (the single deduplicated entry) |
| `Server` | status, settings | Task 4 |
| `Network` | settings, diagnostics | Task 4 |
| `Routing table` | settings, diagnostics | Task 4 |
| `TLS host name` | settings, diagnostics | Task 4 |

Per-task entry counts: Task 3 = 42, Task 4 = 53, Task 5 = 82, Task 6 = 34
→ **211** total. Placeholders per task: Task 3 = 4, Task 4 = 0, Task 5 = 1,
Task 6 = 6 → **11** total.

### LuCI i18n build mechanics (how the file is consumed)

- `luci.mk`'s i18n handling: every `po/<lang>/<name>.po` in the package builds
  into `luci-i18n-<name>-<lang>` (here `luci-i18n-trusttunnel-ru`), compiled to
  `.lmo` by `po2lmo`; runtime lookup is by exact `msgid` string. Therefore the
  `msgid` strings must be **byte-identical** to the `_('…')` literals in the
  views (incl. the two `"`-containing keys, escaped as `\"` in the `.po`), and
  the file must parse with standard .po syntax.
- The menu titles `TrustTunnel`/`Status`/`Settings`/`Diagnostics` from
  `root/usr/share/luci/menu.d/luci-app-trusttunnel.json` are rendered through
  the translation machinery at runtime — `Status` and `Settings` exist in the
  catalog only for the menu (the other two are also view keys).
- Backend strings surfaced by the UI (diagnostics `hint`/`detail` texts from
  `root/usr/share/rpcd/ucode/luci.trusttunnel`) are covered by the
  `DIAG_TEXT` map in `diagnostics.js`, whose values are `_()` lookups with the
  same English text — they are part of the 209 view keys; no extra catalog
  entries are needed for the backend (incl. the `/dev/net/tun present` map
  key, which resolves to `_('present')`).

### Clean-room protocol (binding)

1. The **only** authoring input is the skeleton produced in Task 2 (header +
   all 211 msgids, empty `msgstr`s). The author translates **from the English
   msgid** and the meaning notes in this plan.
2. The inherited file is copied to `/tmp/tt13_old.po` in Task 1 **exclusively**
   for automated verification (msgid-set diff, verbatim-copy check). The
   author must not open it, must not read its `msgstr` lines, and must not use
   git to view its history. It is never committed (`/tmp` only; PRD rule: no
   `*.old` files in the tree).
3. This plan lists `msgid`s (interface data, allowed by the issue) and the
   header boilerplate; it contains **no inherited `msgstr` text**.
4. An entry whose natural translation equals its own `msgid` (brand/token, e.g.
   `TrustTunnel`, `MTU`) is not "copied" — the verbatim check exempts
   `msgstr == msgid` entries.

## Entities

### `packages/luci-app-trusttunnel/po/ru/trusttunnel.po` (Gettext catalog)

- **Fields**:
  - `header`: `msgid ""` + `msgstr` with `Content-Type: text/plain; charset=UTF-8`
    and `Plural-Forms: nplurals=3; …` — byte-identical to today, first entry.
  - `msgid`: exact UI key string (may contain spaces, quotes, `%`, `–`, `…`,
    `tt://`, `host:port`, `*.domain`, `0x…`, `%s` etc.); immutable; 211
    entries in today's order (deduplicated `Mode` kept at its first position,
    line 37; the 4 stale Exclusions msgids absent).
  - `msgstr`: new Russian text, same meaning; may equal `msgid` only for
    brand/token entries.
- **Relationships**: each of the 209 msgids ↔ one `_('…')` literal in the
  views (`status.js` 51, `settings.js` 79, `diagnostics.js` 89; 10 shared);
  `Status`/`Settings` ↔ menu.d JSON titles; 11 msgids carry `%s`/`%d`
  placeholders that must survive verbatim in `msgstr`.
- **Validation**: `msgfmt -c` exit 0; `msgfmt --statistics` = 211 translated;
  msgid set identical to the 212-line baseline (211 msgids + header);
  placeholder tokens identical in count/order; zero verbatim old `msgstr`
  copies; no `_n()` → no `msgid_plural`; manual LuCI pass.
- **States**: baseline (inherited, 216 msgids, `msgfmt -c` RED — duplicate
  `Mode`) → skeleton (Task 2, 212 msgid lines, 0 translated, `msgfmt -c`
  green) → translated (Tasks 3–6, 211 translated) → verified (Task 7).

## Contracts

Reference: the issue's "Contract to reproduce" (`.sdd/.current/issues/TT-13/issue.md`)
and the baseline artifact `/tmp/tt13_msgids.txt` (211 msgids + header line in
today's order, deduplicated and stale-free, generated in Task 1).

- **Header contract** (kept byte-identical):
  ```
  msgid ""
  msgstr "Content-Type: text/plain; charset=UTF-8\nPlural-Forms: nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);\n"
  ```
- **Duplicate disposition**: the inherited file has `msgid "Mode"` twice
  (lines 37 and 607). The re-authored catalog keeps **one** `Mode` entry at
  the first position (line 37). Task 1's extraction deduplicates keeping the
  first occurrence; the skeleton therefore contains a single `Mode`. Without
  this, `msgfmt -c` can never pass (the inherited file fails with the fatal
  duplicate-message error — measured).
- **Stale-msgid disposition**: the 4 Exclusions-tab leftovers (`Do not bypass
  these`, `Exclusions`, `Everything goes through the tunnel; …`, `Always sent
  out directly. Accepts a domain, …`) are **dropped** from the re-authored
  catalog: Task 1 filters them from the baseline list, so they are absent from
  the skeleton and the final file. The issue contract requires the `msgid`
  set to exactly match the views' keys (plus the menu titles) — after the
  drop, `.po` msgids not used by views or menu = **0**.
- **Placeholder msgids** (11; the new `msgstr` must contain the same `%s`/`%d`
  tokens in the same order):
  1. `Connecting to %s`
  2. `All LAN traffic goes through %s`
  3. `%s is available`
  4. `the installed version is newer than the latest release (%s)`
  5. `checks passed: %d, remarks: %d, problems: %d, skipped: %d`
  6. `Tunnel works, profile %s — only the VPN rules go through %s` (double `%s`)
  7. `Tunnel works, profile %s — only the VPN rules go through the tunnel`
  8. `Tunnel works, profile %s — everything except the bypass rules goes through %s` (double `%s`)
  9. `Tunnel works, profile %s — everything except the bypass rules goes through the tunnel`
  10. `Profile %s — bypass, only the VPN rules are tunneled`
  11. `Profile %s — VPN, everything except the bypass rules is tunneled`
- **Key-set contract**: the 211 msgids listed per task in Tasks 3–6 (they are
  msgids — interface data; the plan intentionally contains no old `msgstr`).

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/po/ru/trusttunnel.po` | Modify | The only repo file touched: new Russian `msgstr`s for all 211 entries; header and msgid set unchanged except the `Mode` dedup and the 4 stale drops; entry order unchanged |
| `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/{status,settings,diagnostics}.js` | Read-only reference | Source of the `_()` key set (TT-10/11/12 rewrite them; keys pinned) |
| `packages/luci-app-trusttunnel/root/usr/share/luci/menu.d/luci-app-trusttunnel.json` | Read-only reference | Menu titles `Status`/`Settings` (the 2 non-view msgids) |
| `/tmp/tt13_old.po`, `/tmp/tt13_msgids.txt`, `/tmp/tt13_view_keys.txt` | Temp (outside repo, never committed) | Baseline copies + artifacts for the automated checks |
| `/tmp/tt13_check.py` | Temp (outside repo) | Verification helper (msgid identity, placeholders, verbatim-copy) |

No new repo files, no test framework files: verification is the `msgfmt` gates
+ the scripts below + the manual LuCI pass (per PRD testing decisions).

## Tasks

### [ ] Task 1: Baseline audit — pin the msgid set (dedup `Mode`, drop the 4 stale msgids)

**Files:**

- Read-only: `packages/luci-app-trusttunnel/po/ru/trusttunnel.po`
- Read-only: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js`, `settings.js`, `diagnostics.js`
- Read-only: `packages/luci-app-trusttunnel/root/usr/share/luci/menu.d/luci-app-trusttunnel.json`
- Create (temp): `/tmp/tt13_msgids.txt`, `/tmp/tt13_view_keys.txt`, `/tmp/tt13_old.po`

- [ ] **Step 1: Write the audit probes**

```sh
# 1a. msgids from the current .po, in file order, unescaped for comparison;
#     dedup keeping the first occurrence; drop the 4 stale Exclusions msgids
python3 - <<'EOF'
import re
po = open('packages/luci-app-trusttunnel/po/ru/trusttunnel.po', encoding='utf-8').read()
msgids = [m.group(1).replace('\\"', '"').replace('\\\\', '\\')
          for m in re.finditer(r'^msgid "((?:[^"\\]|\\.)*)"$', po, re.M)]
print('raw msgid lines incl. header:', len(msgids))
uniq = []
for m in msgids:
    if m not in uniq:
        uniq.append(m)          # drops the second "Mode"
print('unique msgids incl. header:', len(uniq))
stale = {
    'Do not bypass these',
    'Exclusions',
    'Everything goes through the tunnel; these entries always go out directly. The client applies them by SNI, after the kernel has already marked the traffic.',
    'Always sent out directly. Accepts a domain, *.domain, an IP address or a CIDR range.',
}
out = [m for m in uniq if m not in stale]
open('/tmp/tt13_msgids.txt', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('target msgid lines incl. header:', len(out))
EOF

# 1b. view _() keys (per view and union), unescaped
python3 - <<'EOF'
import re
total = set()
for f in ['status', 'settings', 'diagnostics']:
    src = open(f'packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/{f}.js', encoding='utf-8').read()
    ks = {k.replace("\\'", "'") for k in re.findall(r"_\(\s*'([^'\\]*(?:\\.[^'\\]*)*)'\s*\)", src)}
    print(f, '=', len(ks))
    total |= ks
print('union =', len(total))
open('/tmp/tt13_view_keys.txt', 'w', encoding='utf-8').write('\n'.join(sorted(total)) + '\n')
EOF
```

- [ ] **Step 2: Run the probes and record the baseline**

Run: `python3` (snippets above) and:

```sh
comm -23 <(sort /tmp/tt13_view_keys.txt) <(sort /tmp/tt13_msgids.txt)   # view keys missing from po
comm -13 <(sort /tmp/tt13_view_keys.txt) <(sort /tmp/tt13_msgids.txt)   # po msgids not in views
```

Expected: `raw msgid lines incl. header` = 217; `unique msgids incl. header`
= 216; `target msgid lines incl. header` = 212 (211 msgids + the empty header
line); `status = 51`, `settings = 79`, `diagnostics = 89`, `union = 209`.
"missing from po" output empty; "not in views" output is exactly the empty
header line, `Settings` and `Status` (the menu-only titles) — the 4 stale
msgids are already filtered by 1a. If TT-10/11/12 rewrites changed any `_()`
key, this step reports it — stop and reconcile with the view issues before
continuing.

- [ ] **Step 3: Gate the current file (baseline defect)**

Run:

```sh
msgfmt -c -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po
msgfmt --statistics -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po
```

Expected: **exit 1** — fatal `duplicate message definition` for `Mode`
(`trusttunnel.po:607` vs first definition at `trusttunnel.po:38`) and
`msgfmt: found 1 fatal error`; `--statistics` fails the same way and prints no
count. This red state is the recorded baseline defect, caused by the
duplicate `msgid "Mode"` (lines 37/607). It is resolved by the dedup in 1a:
the skeleton in Task 2 is the first state that passes `msgfmt -c`.

- [ ] **Step 4: Save the reference copy**

Run: `cp packages/luci-app-trusttunnel/po/ru/trusttunnel.po /tmp/tt13_old.po`

Expected: `/tmp/tt13_old.po` exists (used only by the automated checks in
Tasks 3–7; never opened while authoring, never committed).

**Verification**: the numbers above match the Research table exactly
(217/216/215-unique/212-target; 51/79/89; union 209; 0 missing; extras =
header + `Status` + `Settings`; 4 stale dropped; 1 `Mode` deduplicated);
artifacts `/tmp/tt13_msgids.txt` (212 lines), `/tmp/tt13_view_keys.txt`
(209 keys), `/tmp/tt13_old.po` exist.

### [ ] Task 2: Write the new .po skeleton (header + all 211 msgids, empty msgstrs)

**Files:**

- Modify: `packages/luci-app-trusttunnel/po/ru/trusttunnel.po` (skeleton only)
- Temp: `/tmp/tt13_msgids.txt` (from Task 1)

- [ ] **Step 1: Write the failing gate (target state)**

```sh
cat > /tmp/tt13_check.py <<'EOF'
import re, sys
po = open('packages/luci-app-trusttunnel/po/ru/trusttunnel.po', encoding='utf-8').read()
entries = list(re.finditer(r'^msgid "((?:[^"\\]|\\.)*)"\nmsgstr "((?:[^"\\]|\\.)*)"', po, re.M))
ids   = [m.group(1).replace('\\"', '"').replace('\\\\', '\\') for m in entries]
strs  = [m.group(2).replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\') for m in entries]
base  = open('/tmp/tt13_msgids.txt', encoding='utf-8').read().splitlines()
assert ids == base, 'msgid set/order mismatch vs baseline'
assert len(ids) == 212, 'entry count changed (211 msgids + header)'
ph = re.compile(r'%[sd]')
for i, s in zip(ids, strs):
    if '%' in i:
        assert ph.findall(i) == ph.findall(s), 'placeholder mismatch: %r' % i
print('CHECK PASS: msgid set identical to baseline, placeholders intact')
EOF
python3 /tmp/tt13_check.py
msgfmt --statistics -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po
```

Run against the inherited file first. Expected: **CHECK FAIL** (the inherited
file has 5 extra entries — the duplicate `Mode` + 4 stale msgids) and
`msgfmt --statistics` fails with the fatal duplicate-message error. The check
encodes the target identity; the skeleton in Step 2 is what must make it
pass, with its own failing state: `0 translated messages.`

- [ ] **Step 2: Generate the skeleton**

```sh
python3 - <<'EOF'
header = ('msgid ""\n'
          'msgstr "Content-Type: text/plain; charset=UTF-8\\n'
          'Plural-Forms: nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : '
          'n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);\\n"\n')
def esc(s): return s.replace('\\', '\\\\').replace('"', '\\"')
out = [header]
for m in open('/tmp/tt13_msgids.txt', encoding='utf-8').read().splitlines():
    if m == '':                      # header entry, already emitted
        continue
    out.append('msgid "%s"\nmsgstr ""\n' % esc(m))
open('packages/luci-app-trusttunnel/po/ru/trusttunnel.po', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('skeleton written')
EOF
```

Expected: the file contains only the header and 211 `msgid "…"`/`msgstr ""`
pairs in the baseline order; exactly one `Mode` entry; the 4 stale msgids
absent; the two quote-containing msgids appear as `\"`-escaped; UTF-8, no
BOM.

- [ ] **Step 3: Verify the skeleton**

Run:

```sh
python3 /tmp/tt13_check.py
msgfmt -c -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po
msgfmt --statistics -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po
head -2 packages/luci-app-trusttunnel/po/ru/trusttunnel.po
```

Expected: `CHECK PASS`; `msgfmt -c` **exit 0** (the first green state; 7
informational header warnings are fine); `0 translated messages.` (the
failing state that Tasks 3–6 must drive to 211); the first two lines are
byte-identical to the header in this plan's Contracts section.

**Verification**: msgid set + order identical to the 212-line baseline,
header unchanged, `msgfmt -c` green (the inherited file's duplicate-`Mode`
fatal error is gone). From this point the author works **only** from this
skeleton + this plan; `/tmp/tt13_old.po` is off-limits for authoring.

### [ ] Task 3: Re-translate page chrome + Status page legacy strings (42 entries)

**Files:**

- Modify: `packages/luci-app-trusttunnel/po/ru/trusttunnel.po`

- [ ] **Step 1: Confirm the failing state**

Run: `msgfmt --statistics -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po`
Expected: `0 translated messages.` (target by end of Task 6: 211).

- [ ] **Step 2: Author the 42 entries**

Translate the following msgids (skeleton entries) into new natural Russian
text with the same meaning. Sub-groups: (a) page chrome — modal, buttons,
notifications; (b) Status page verdicts and the "Now" facts table; (c) Versions
table + update-check states. The 5 shared keys below are owned here; the
other shared key in the status set (`Server`) is owned by Task 4 — leave it
empty here. The 9 new profile strings (`Mode`, the four `Tunnel works, profile
%s — …` heads, `Everything else stays direct.`, `The bypass rules are sent out
directly.`, the two `Profile %s — …` Mode-row strings) are owned by Task 6 —
leave them empty here.

```
%s is available
All LAN traffic goes through %s
All LAN traffic goes through the tunnel
Check now
Checking…
Client log
Command failed
Connecting to %s
Connecting to the server
Domains from the \"do not bypass\" list are sent out directly.
Done
Everything through VPN
GitHub unreachable, showing the last cached result
Now
Package
Please wait
Press Start and read the client log below.
Press Start to run it now, or turn on \"Start on boot\" in Settings.
Restart
run install.sh again to update
Run install.sh: the package does not ship the client binary.
Running…
Start
State
Stop
The client is running but the tunnel is not established yet. If this persists, the client log below says why.
The service did not start. The client log below says why.
The service is not running
The service is off
The TrustTunnel client is not installed
TrustTunnel
TrustTunnel client
unavailable — no network and no cached result
unknown
up to date
Update
Update check
Versions
working
not installed
the installed version is newer than the latest release (%s)
```

Plus the menu title `Status` (page name for the status page; rendered in the
LuCI menu).

Meaning notes for fidelity (all verdict states per TT-10, and the update-check
states per the status view): client binary missing; service not running (vs.
disabled); connecting to a host (the `%s` is the endpoint host or first
address); all LAN traffic through the tunnel with the `do not bypass`
exclusion list sent out directly; update states = unknown / not installed /
no network and no cached result / stale cache shown / a newer release
available / installed newer than latest / up to date.

- [ ] **Step 3: Verify the task scope**

Run:

```sh
msgfmt -c -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po
python3 /tmp/tt13_check.py
# verbatim-copy check for this task's keys (prints only msgids, never old text)
python3 - <<'EOF'
import re
def load(p):
    po = open(p, encoding='utf-8').read()
    d = {}
    for m in re.finditer(r'^msgid "((?:[^"\\]|\\.)*)"\nmsgstr "((?:[^"\\]|\\.)*)"', po, re.M):
        d[m.group(1).replace('\\"', '"').replace('\\\\', '\\')] = \
          m.group(2).replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')
    return d
old, new = load('/tmp/tt13_old.po'), load('packages/luci-app-trusttunnel/po/ru/trusttunnel.po')
same = [k for k in old if old[k] and old[k] != k and old[k] == new.get(k)]
assert not same, 'verbatim old msgstrs: %r' % same
print('NO-COPY PASS')
EOF
msgfmt --statistics -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po
```

Expected: `msgfmt -c` exit 0; `CHECK PASS`; `NO-COPY PASS`; `42 translated
messages.`; the 42 assigned entries (incl. `Status`) have non-empty msgstrs;
`Server` and the 9 Task-6 strings are still empty; the 4 `%s` placeholders in
this task's keys are preserved in order.

**Verification**: gate green, no verbatim old text, no placeholder drift.

### [ ] Task 4: Re-translate Settings page legacy strings (53 entries)

**Files:**

- Modify: `packages/luci-app-trusttunnel/po/ru/trusttunnel.po`

- [ ] **Step 1: Confirm the failing state**

Run: `msgfmt --statistics -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po`
Expected: `42 translated messages.`

- [ ] **Step 2: Author the 53 entries**

Translate the following msgids (the `Settings` menu title + all settings-view
legacy keys; includes the 4 shared keys owned here — `Server`, `Network`,
`Routing table`, `TLS host name`). The settings page is **one page with four
tabs** (`m.tabbed = true`, every section becomes a tab): **General / Server /
Routing profiles / Network** — there is no Exclusions tab anymore. The 26 new
settings strings (`Custom SNI`, `Client Random, hex prefix`, `Routing
profile`, `Routing profiles`, `Name`, `Mode`, the VPN/Bypass rules rows, the
profile descriptions and validator errors — full list in Task 6) are owned by
Task 6 — leave them empty here. `TrustTunnel` is owned by Task 3 — leave it
empty here.

```
Accepts any certificate, which removes the protection against a substituted server. Pin the certificate below instead whenever you can.
Accepts both forms a server hands out: the configuration file text and a tt:// link. Nothing is saved until you press Save & Apply.
Addresses
Adds a blackhole route so marked traffic is dropped instead of leaking to the provider.
Anti-DPI
Any table id except 0 and the reserved 253-255.
Applies to what the TrustTunnel client resolves on its own — for example the exclusion domains it pre-resolves. Empty means the client default, AdGuard DNS unfiltered.
By default only forwarded LAN traffic is routed. Enabling this also routes traffic originated by the router itself, including the update check.
Cancel
Countermeasures against traffic inspection. Worth enabling if the connection establishes but keeps dropping.
debug and trace write a lot; leave them on only while investigating something.
Decimal or 0x-prefixed hexadecimal. Change only on a conflict with mwan3, SQM or another package that marks packets.
DNS used by the client itself
Drop traffic when the tunnel is down
Enter a decimal number no greater than 4294967295
Enter a decimal number or 0x-prefixed hexadecimal
Enter a table id between 1 and 4294967294
Firewall mark
General
host:port or [ipv6]:port. With several addresses the client measures them and picks the fastest.
Import
Import endpoint configuration
Imported. Review the fields and press Save & Apply.
Import…
LAN interfaces
Leave empty to use the system trust store, which requires the ca-bundle package.
Log level
MTU
Network
Not a valid domain, IP address or CIDR range
Password
Paste the endpoint configuration generated by your server
Pinned certificate (PEM)
plain DNS
Post-quantum key exchange
QUIC is often faster, but some networks throttle or block UDP.
Route the router's own traffic too
Routing table
Server
Server carries IPv6
Server configuration
Settings
Skip certificate verification
Space-separated list whose forwarded traffic is considered. Empty means the device of the lan network.
Start on boot
Table ids 253, 254 and 255 are reserved by the system
The fast path: paste what your server generated and the fields below fill themselves in.
These rarely need changing. MTU is the exception: too high a value makes small pages load while TLS handshakes and large downloads stall.
TLS host name
Transport
Used for the TLS session, not for routing. Without it many servers refuse the connection.
User name
Whether the service starts when the router boots. The Start button on the Status page runs it right now.
```

Meaning notes: the four tabs (General / Server / Routing profiles / Network)
with their field labels, descriptions, validator errors, and the import modal
flow (paste config text or `tt://` link; nothing is saved until Save & Apply;
success notification). Preserve tokens: `tt://`, `host:port`, `[ipv6]:port`,
`*.domain`, `0x`, `253-255`, `1`, `4294967294`, `4294967295`, `ca-bundle`,
`AdGuard DNS`, `mwan3`, `SQM`, `QUIC`, `UDP`, `TLS`, `DPI`, `MTU`,
`PEM`, `CIDR`, `br-lan`, `lan`, `Save & Apply`.

- [ ] **Step 3: Verify the task scope**

Run: the same three commands as Task 3 Step 3 (`msgfmt -c`, `python3
/tmp/tt13_check.py`, the no-copy snippet) plus:

```sh
msgfmt --statistics -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po
```

Expected: `msgfmt -c` exit 0; `CHECK PASS`; `NO-COPY PASS`; `95 translated
messages.` (42 + 53); `TrustTunnel`, the 26 Task-6 settings strings and all 82
diagnostics entries are still empty.

**Verification**: gate green, no verbatim old text, no placeholder drift
(no `%`-placeholder msgids in this task, so the placeholder check is a no-op
here).

### [ ] Task 5: Re-translate Diagnostics page + backend strings (82 entries)

**Files:**

- Modify: `packages/luci-app-trusttunnel/po/ru/trusttunnel.po`

- [ ] **Step 1: Confirm the failing state**

Run: `msgfmt --statistics -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po`
Expected: `95 translated messages.`

- [ ] **Step 2: Author the 82 entries**

Translate the following msgids (all diagnostics-view keys incl. the `DIAG_TEXT`
backend-string lookups). The 7 shared keys used by diagnostics (`Checking…`,
`Press Start and read the client log below.`, `TrustTunnel client`, `not
installed` — owned by Task 3; `Network`, `Routing table`, `TLS host name` —
owned by Task 4) are already done or still empty — do not touch them.

```
A request bound to the device can fail even on a healthy tunnel, because the default route lives in the marked table. Judge by a LAN client instead.
absent
Both the user name and the password are required.
check
Check
Check a domain
Check again
Check the address, and that the router itself has internet access.
checks passed: %d, remarks: %d, problems: %d, skipped: %d
Checks the whole chain — configuration, prerequisites, service, kernel state and network — and says what to do about anything it finds.
Compare
Compare the external address
Configuration
Credentials
Diagnostics
direct
Directly
Enabled
Endpoint address
Endpoint reachable
everything checks out
Fill in the address on the Settings page, or import the server config.
Firewall zone
Hide
Host
Install kmod-tun.
installed
Kernel state
loaded in fw4
Loss
Loss and round-trip time for every configured address.
Marked traffic falls into the killswitch instead of the tunnel. Restart the service.
min / avg / max
missing
MTU matches settings
nftables table
no
no carrier
Normalized
not attached
not checked
not in the live ruleset
not set
ok
Ping
Ping the server
Pinging…
Prerequisites
present
problem
Restart the service so the client picks up the configured value.
Route attached to the device
Routing rule
Run /etc/init.d/firewall reload — traffic into the tunnel is dropped without the zone.
Run install.sh — the package does not ship the client binary.
Running
Running checks — this takes a few seconds…
Service
Show all checks
Show the checks that passed
Shows the address seen through the tunnel next to the one seen directly. The same address in both means traffic is not using the tunnel.
skipped
the client has not created one
The device belongs to the client, not to this package. Read the client log below.
The device exists but the client has not established the tunnel yet. This is the client side, not the routing — read the client log.
the router itself has no internet access
The tool to reach for when a particular site does not work: it says whether that domain goes through the tunnel, and why.
The tunnel is up but traffic is not using it.
there are problems
Through the tunnel
through the tunnel
Traffic goes through the tunnel
tun device
Tunnel carrier
Tunnel device
Turn on Enable on the Settings page, then press Start.
up
Verdict
Why
Without it the TLS session uses the bare address, which many servers reject.
works, with remarks
yes
```

Meaning notes: the five check groups (Configuration / Prerequisites / Service /
Kernel state / Network), verdict words and the counts banner (the single
`checks passed: %d, remarks: %d, problems: %d, skipped: %d` msgstr — keep all
four `%d` tokens in order), per-check status words (`ok`/`check`/`problem`/
`skipped`, `present`/`absent`, `not set`, `no carrier`, `loaded in fw4`, `not
attached`, `not in the live ruleset`, `up`), the three tools (Check a domain →
Normalized / Verdict / Why; Ping the server → Host / Loss / min / avg / max;
Compare the external address → Through the tunnel / Directly), and the
remediation hints (backend strings). Preserve tokens: `kmod-tun`, `install.sh`,
`fw4`, `/etc/init.d/firewall reload`, `tun`, `nftables`, `LAN`, `Settings`,
`Enable`, `Start`, `killswitch`, `%d`×4.

- [ ] **Step 3: Verify the task scope**

Run: the Task 3 Step 3 commands plus:

```sh
msgfmt --statistics -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po
```

Expected: `msgfmt -c` exit 0; `CHECK PASS`; `NO-COPY PASS`; `177 translated
messages.` (42 + 53 + 82).

**Verification**: gate green, no verbatim old text, all 82 assigned entries
translated, placeholder tokens preserved (the `checks passed: %d, …` entry is
this task's only placeholder).

### [ ] Task 6: Re-translate the 34 new profile/SNI/random strings (fourth group)

**Files:**

- Modify: `packages/luci-app-trusttunnel/po/ru/trusttunnel.po`

- [ ] **Step 1: Confirm the failing state**

Run: `msgfmt --statistics -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po`
Expected: `177 translated messages.`

- [ ] **Step 2: Author the 34 entries**

Translate the following msgids (the 34 msgids added by the routing-profiles
feature on main; the shared `Mode` is authored here as the single deduplicated
entry used by both the status page Mode row and the Routing profiles tab):

```
A profile decides what goes through the tunnel. VPN mode tunnels everything except the bypass rules; bypass mode tunnels only the VPN rules. Rules accept a domain, *.domain, an IP address, IP:port, or a CIDR range.
Always sent out directly: in VPN mode these are the only destinations that bypass the tunnel; in bypass mode the list has no effect.
Another profile already has this name
At most 64 characters
Bypass rules
Bypass — tunnel only the VPN rules
Client Random, hex prefix
Custom SNI
Enter hex digits only, e.g. 0a0b0c or 0a0b0c/0f0f0f
Everything else stays direct.
Mode
Name
Name is required
None — everything through the tunnel
Overrides the TLS Server Name. Needed when the server answers on an address that does not match its host name, e.g. behind a CDN or an IP-only setup.
Profile %s — VPN, everything except the bypass rules is tunneled
Profile %s — bypass, only the VPN rules are tunneled
Routing profile
Routing profiles
Sent through the tunnel: in bypass mode these are the only destinations that go through; in VPN mode the list has no effect.
TLS Client Random prefix and mask. Anti-scan servers accept only clients with the matching prefix. Format: abcdef or abcdef/0f0f0f.
The bypass rules are sent out directly.
The hex prefix must be a whole number of bytes
The mask must be hex digits, a whole number of bytes
The mask must be the same length as the prefix
The named profile that decides what goes through the tunnel. Profiles are managed on the Routing tab.
Tunnel works, profile %s — everything except the bypass rules goes through %s
Tunnel works, profile %s — everything except the bypass rules goes through the tunnel
Tunnel works, profile %s — only the VPN rules go through %s
Tunnel works, profile %s — only the VPN rules go through the tunnel
Unique name; the Server tab assigns a profile by it.
Use the format example.com
VPN rules
VPN — tunnel everything except the bypass rules
```

Meaning notes for fidelity (routing-profiles feature, TT-10):
- **Profile semantics**: a named routing profile decides what goes through the
  tunnel; VPN mode tunnels everything except the bypass rules, bypass mode
  tunnels only the VPN rules. Rules accept a domain, `*.domain`, an IP
  address, `IP:port` or a CIDR range.
- **Routing profile selector** (Server tab): the `Routing profile` ListValue
  with `None — everything through the tunnel` as the legacy fallback option;
  the help text says profiles are managed on the **Routing tab** (the Routing
  profiles tab).
- **Routing profiles tab**: `Routing profiles` section with `Name` (unique;
  the Server tab assigns a profile by it), `Mode` (`VPN — tunnel everything
  except the bypass rules` / `Bypass — tunnel only the VPN rules`), `VPN
  rules` and `Bypass rules` lists and their descriptions; validator errors:
  `Name is required`, `Another profile already has this name`.
- **Custom SNI / Client Random** (Server tab): `Custom SNI` overrides the TLS
  Server Name (`Use the format example.com`); `Client Random, hex prefix`
  with prefix/mask format `abcdef` or `abcdef/0f0f0f`; validator errors: `At
  most 64 characters`, `Enter hex digits only, e.g. 0a0b0c or 0a0b0c/0f0f0f`,
  `The hex prefix must be a whole number of bytes`, `The mask must be hex
  digits, a whole number of bytes`, `The mask must be the same length as the
  prefix`.
- **Profile-aware status verdicts** (Status page): working verdicts with the
  profile name in the first `%s` and the endpoint host in the second `%s`
  (when the host is known): bypass profile → `Tunnel works, profile %s — only
  the VPN rules go through %s` (or `…through the tunnel`) with detail
  `Everything else stays direct.`; VPN profile → `Tunnel works, profile %s —
  everything except the bypass rules goes through %s` (or `…through the
  tunnel`) with detail `The bypass rules are sent out directly.`. The Mode
  row shows `Profile %s — bypass, only the VPN rules are tunneled` /
  `Profile %s — VPN, everything except the bypass rules is tunneled` (the
  `%s` is the profile name) or `Everything through VPN` (authored in Task 3)
  when no profile is assigned.
- **Preserve tokens**: `%s` (one or two per msgid, in order), `*.domain`,
  `IP:port`, `CIDR`, `abcdef`, `0a0b0c`, `0f0f0f`, `example.com`, `CDN`,
  `SNI`, `TLS`, `VPN`, `hex`, `Routing tab`, `Server tab`.

- [ ] **Step 3: Verify the task scope**

Run: the Task 3 Step 3 commands plus:

```sh
msgfmt --statistics -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po
```

Expected: `msgfmt -c` exit 0; `CHECK PASS`; `NO-COPY PASS`; `211 translated
messages.` — the full catalog is translated; the 6 placeholder-bearing keys of
this task (two of them with a double `%s`) keep their tokens in order.

**Verification**: gate green, no verbatim old text, all 211 entries
translated, placeholder tokens preserved.

### [ ] Task 7: Final verification + manual LuCI Russian pass

**Files:**

- Verify: `packages/luci-app-trusttunnel/po/ru/trusttunnel.po`
- Temp: `/tmp/tt13_old.po`, `/tmp/tt13_msgids.txt` (from Task 1)

- [ ] **Step 1: Run the full mechanical gate**

Run:

```sh
msgfmt -c -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po
msgfmt --statistics -o /dev/null packages/luci-app-trusttunnel/po/ru/trusttunnel.po
python3 /tmp/tt13_check.py
python3 - <<'EOF'
import re
def load(p):
    po = open(p, encoding='utf-8').read()
    d = {}
    for m in re.finditer(r'^msgid "((?:[^"\\]|\\.)*)"\nmsgstr "((?:[^"\\]|\\.)*)"', po, re.M):
        d[m.group(1).replace('\\"', '"').replace('\\\\', '\\')] = \
          m.group(2).replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')
    return d
old, new = load('/tmp/tt13_old.po'), load('packages/luci-app-trusttunnel/po/ru/trusttunnel.po')
base = open('/tmp/tt13_msgids.txt', encoding='utf-8').read().splitlines()
assert list(new.keys()) == [m for m in base if m != ''], 'msgid set/order differs from target'
same = [k for k in old if old[k] and old[k] != k and old[k] == new.get(k)]
assert not same, 'verbatim old msgstrs: %r' % same
print('FINAL PASS: 211 msgids match the target set, 0 verbatim msgstrs')
EOF
```

Expected: `msgfmt -c` exit 0; `211 translated messages.`; `CHECK PASS`;
`FINAL PASS … 0 verbatim msgstrs`.

- [ ] **Step 2: Review the change as a diff**

Run:

```sh
git diff --stat packages/luci-app-trusttunnel/po/ru/trusttunnel.po
git diff packages/luci-app-trusttunnel/po/ru/trusttunnel.po | grep -E '^[-+](msgid|msgstr)' | sed -E 's/^(.)(msgid|msgstr).*/\1 \2/' | sort | uniq -c
git status --porcelain
```

Expected: `+ msgstr` = 211 and `- msgstr` = 216 (the 211 rewritten entries +
the 5 removed entries: 4 stale + the duplicate `Mode` block) — every retained
msgstr is rewritten;
`- msgid` = 5 and `+ msgid` = 0 — msgid lines change ONLY for the 5 removed
entries (4 stale + the duplicated `Mode`), every other `msgid` line is
unchanged (incl. the single retained `Mode`); `git status` shows exactly one
modified file, no `*.old`/backup files anywhere (PRD rule).

- [ ] **Step 3: Manual LuCI Russian pass**

On a device with the package installed (or the LuCI dev server), with
`/etc/config/luci` language set to Russian, check every page:

1. Status page: all verdict states (client missing / service off / service
   not running / connecting / working) — including the profile-aware working
   variants (bypass profile and VPN profile heads with the profile name and
   endpoint host, plus their detail lines; legacy no-profile variant with the
   `do not bypass` wording), the Mode row (Everything through VPN vs the two
   `Profile %s — …` states), Start/Stop/Restart buttons, client log box,
   Versions table + update states (unknown, not installed, unavailable — no
   network and no cached result, newer release available, installed newer
   than latest, up to date, stale cache), Check now button.
2. Settings page: four tabs (General / Server / Routing profiles / Network),
   every field label and hint; on the Server tab the Routing profile selector
   and the Custom SNI / Client Random fields with their validator errors; on
   the Routing profiles tab add/rename a profile and trigger the Name
   required / duplicate-name errors; the import modal (paste config text and
   a `tt://` link; success notification; Cancel); validator errors (bad
   domain/IP/CIDR, bad fwmark, bad table id); the DNS upstream presets.
3. Diagnostics page: five groups with fail/warn rows first, the show/hide
   toggle, the verdict banner with counts, Check a domain (Normalized /
   Verdict / Why), Ping the server table (Host / Loss / min / avg / max),
   Compare the external address (Through the tunnel / Directly), Check again.
4. Sidebar menu: TrustTunnel → Status / Settings / Diagnostics fully
   translated.
5. No raw `msgid` text visible anywhere; Russian reads naturally and matches
   the current UI's meaning, tone and terminology (issue anchors: "туннель",
   "обходить", "черный ход"/killswitch wording as in the current UI; the new
   profile strings keep the profile/VPN/bypass terminology consistent with
   the rest of the page).

Expected: every scenario fully translated, no raw keys, no meaning drift.

- [ ] **Step 4: Optional SDK gate (stretch)**

If an OpenWrt SDK (or the docker `openwrt/sdk` image) is available, build the
package and confirm `luci-i18n-trusttunnel-ru` is produced and installs.
Otherwise record that the SDK gate is deferred to CI (issue contract: the
local `msgfmt -c` gate already passes).

**Verification**: all gates green (msgfmt, 211-line identity, 11 placeholders,
no-copy, diff shape), manual pass checklist complete; the old file exists only
as `/tmp/tt13_old.po` and is not part of the commit.

## Notes

- Dependency warning: TT-10/TT-11/TT-12 define the `_()` key sets that Task 1
  audits against — if any key changes in their implementation, re-run Task 1
  before Task 2.
- Disposition summary (decision log): the duplicate `msgid "Mode"` (lines
  37/607) is deduplicated to the single first-position entry — the inherited
  file fails `msgfmt -c` with the fatal duplicate-message error, so the
  skeleton is the first gate-green state; the 4 stale Exclusions-tab msgids
  are dropped — the final catalog's 211 msgids exactly match the views' 209
  keys plus the 2 menu titles, satisfying the issue contract.
- The final commit for this issue must contain **only**
  `packages/luci-app-trusttunnel/po/ru/trusttunnel.po` (PRD: no old-vs-new
  diffs committed, no `*.old` files).
- The `.po` remains GPL-2.0-flagged in `Makefile` (`PKG_LICENSE`) until the
  license-flip issue (TT-16/PRD User Story 5) — out of scope here.
