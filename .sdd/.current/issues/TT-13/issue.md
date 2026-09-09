# Issue TT-13: Russian translation (.po)

- **Status**: Implemented
- **PRD**: `../../prd.md`
- **Blocked by**: TT-10, TT-11, TT-12 (the `msgid` set must match the
  rewritten views)
- **Effort**: M
- **Files**: `packages/luci-app-trusttunnel/po/ru/trusttunnel.po`

## Context

The Russian translation file was inherited; the fork deleted the
list-related strings but the retained `msgstr` translation text is
inherited creative expression. A translation is a derivative work, so a
clean-room pass must **re-translate** the retained strings — new Russian
text, same meaning.

## Contract to reproduce

- File format: Gettext `.po` for LuCI (`luci-i18n-trusttunnel-ru`),
  charset UTF-8, header with the Russian plural forms:
  `Plural-Forms: nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 :
  n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);`
- The `msgid` set must exactly match the `_()` keys used by the rewritten
  views (status.js, settings.js, diagnostics.js) and any backend strings
  the UI shows. On main 2026-09-09 the set grew by 34 msgids (profile
  fields, custom_sni/client_random validation messages, profile-aware
  verdicts and Mode rows — the total is ~216 entries incl. the header).
- `msgstr` values: NEW Russian translations of the same meaning. Do not
  reuse the inherited `msgstr` text (re-translate each string). The
  strings are UI text: page titles, tab names, field labels, verdicts,
  notifications, diagnostics labels/hints, button labels, update-check
  states, and the new profile/SNI/random strings.
- The file must pass `msgfmt -c` (LuCI's i18n build gate).

## Acceptance criteria

- [ ] Every `_()` key in the three views (and UI-shown backend strings)
      has a `msgid` entry.
- [ ] No `msgstr` line is copied verbatim from the inherited `.po`
      (spot-check with a diff).
- [ ] `msgfmt -c` passes.
- [ ] The Russian text reads naturally and preserves meaning, tone and
      terminology (e.g. "туннель", "обходить", "черный ход"/killswitch
      wording as in the current UI).

## How to verify

1. Extract keys from the rewritten JS views and check coverage of the `.po`.
2. `msgfmt -c` the file.
3. Manual LuCI pass in Russian: pages render fully translated, no raw
   `msgid`s visible, no wrong meaning vs the current UI.

## Notes

- `msgid` keys are part of the code contract (the views' `_()` calls) —
  they stay as today; only `msgstr` is re-authored.
- The header block itself is format boilerplate, not creative expression;
  keep the standard LuCI header shape.
