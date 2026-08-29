## 1. Show the region

- [x] 1.1 Add an `onSelect(sector)` callback to `RadialMenu`, invoked in `vfunc_motion_event` where
      the menu already notices the selection changed, beside the existing `record('select:...')`.
      Verify `dbus-run-session -- tests/harness/run.sh gesture deadzone` still passes — the callback
      must change nothing on its own.
- [x] 1.2 In `extension.js`, import `TilePreview` from
      `resource:///org/gnome/shell/ui/windowManager.js` and `Mtk` from `gi://Mtk`. Construct one
      instance lazily on first use, open it with the sector's rectangle converted to an
      `Mtk.Rectangle`, and close it when `rectFor` answers `null`. Verify by hand with
      `nix develop --command tests/harness/watch.sh`: hold Alt, tap X, and confirm the outline
      follows the selection and disappears in the dead zone. Change sector at least **twice** — a
      missing `Mtk.Rectangle` conversion fails only on the second change, where `_rect` is no longer
      null.
- [x] 1.3 Close the preview when the gesture finishes, both on commit and on cancel. Verify
      `dbus-run-session -- tests/harness/run.sh cancel exit-paths` passes and that nothing is drawn
      after either path.
- [x] 1.4 Destroy the preview in `disable()` and null the field, beside the existing `cancelAll()`.
      Verify with the case added in 3.4.

## 2. The preference

- [x] 2.1 Add the `snap-preview` boolean key, default `true`, to
      `magunetto@matteopacini.me/schemas/org.gnome.shell.extensions.magunetto.gschema.xml`, with a
      summary and description in the style of the two keys already there. Verify
      `glib-compile-schemas --strict schemas` succeeds.
- [x] 2.2 Read the key when the menu opens, not at `enable()`, so a change applies to the next
      gesture. Skip creating or opening the preview when it is off. Verify by the case added in 3.5.
- [x] 2.3 Add a row to the existing Snapping group in `prefs.js`, above Animate, with its title and
      subtitle wrapped in `this.gettext(...)`. Verify the dialog renders with
      `nix develop --command gnome-extensions prefs magunetto@matteopacini.me` — or, if that reaches
      the installed copy rather than the working tree, by reading the group construction against the
      two rows already there.

## 3. Make it testable

- [x] 3.1 Add a `PreviewRect() -> (iiii)` method to `tests/harness/shellhook.js`, reporting the
      preview widget's live allocation and `[-1, -1, -1, -1]` when there is none. Report the
      allocation rather than a stored target, so the assertion fails if the widget never moves.
      Verify it answers over D-Bus during a gesture.
- [x] 3.2 Add `preview_rect` to `tests/harness/lib.sh` beside `mg_rect`'s other users, with a
      `preview_field` helper matching `frame_field`. Verify by reading a rect in a scratch case.
- [x] 3.3 Add `tests/harness/cases/preview.sh`: the preview takes the selected sector's rectangle
      and matches what `rectFor` would give for that work area; it moves when the selection moves;
      it is absent in the dead zone; it is gone after the gesture. Settle before sampling — the
      widget eases towards its region, so an immediate read catches it mid-flight. Verify the case
      **fails** before task 1.2 is implemented.
- [x] 3.4 Add `tests/harness/cases/preview-disabled.sh`: disable the extension while the menu is up
      with a sector selected, and assert no preview widget is left in `global.window_group`. Mirror
      `animate-disabled.sh`, which found the equivalent problem for the travel, and re-enable at the
      end since the session is shared. Verify it fails without task 1.4.
- [x] 3.5 Add `tests/harness/cases/preview-off.sh` with `CASE_PREVIEW=false`: no region is outlined,
      the menu still indicates the selection, and committing places the window exactly where it
      would otherwise. This needs a new `CASE_PREVIEW` knob in `run.sh` alongside `CASE_ANIMATION`,
      written into the session keyfile. Verify the case passes and that `run.sh` still shares
      sessions correctly for cases that do not set it.
- [x] 3.6 Add a desktop-animations-off assertion, either as a case or by extending the existing
      `animate-desktop-off.sh` session profile: with `CASE_DESKTOP_ANIMATIONS=false` the region is
      still outlined. Verify it fails if the preview is suppressed along with the travel.

## 4. Thirteen languages

- [x] 4.1 Run `nix develop --command po/update.sh` and confirm `po/magunetto.pot` grows from 29
      messages to 33, carrying the two schema strings and the two preferences strings. Verify with
      `msgfmt --statistics` and by reading the new entries.
- [x] 4.2 Translate the four new strings into all thirteen catalogues — `en_US`, `de`, `pt_BR`,
      `es`, `fr`, `ru`, `it`, `pl`, `nl`, `uk`, `ja`, `tr`, `zh_CN` — giving each translator the
      context of where the string appears, as `po/TRANSLATING.md` describes. Verify no catalogue
      carries a fuzzy or untranslated entry with
      `nix develop --command po/update.sh --check`.
- [x] 4.3 Run `nix develop --command node --test tests/*.test.js` and confirm the l10n tier is green
      — it re-extracts and compares, so it stays red until 4.1 and 4.2 are both complete.

## 5. Verify the whole tree

- [x] 5.1 Run `nix develop --command node --test tests/*.test.js` and confirm every unit test passes.
- [x] 5.2 Run `dbus-run-session -- tests/harness/run.sh` and confirm the full harness passes,
      including every pre-existing case — the preview must not have changed any of them.
- [x] 5.3 `git add` the new case files, then run `tests/run-all.sh --vm` and confirm all three tiers
      pass. The `git add` is not optional: `nix build` takes the flake's source from the git tree, so
      an untracked case is absent from the derivation.
- [x] 5.4 Update the harness case count in `AGENTS.md`'s loop section to the verified number from
      `ls tests/harness/cases/ | grep -vc '^_'`, rather than adding to the figure already written
      there.

## 6. Record what cost time to find

- [x] 6.1 Add to `AGENTS.md` Traps, as standing constraints rather than history: `TilePreview` is
      exported from `ui/windowManager.js` and reusable, but `_updateStyle()` overwrites
      `style_class` on every update so a reused instance cannot be restyled; and it wants an
      `Mtk.Rectangle`, whose absence fails on the second selection change rather than the first
      because the `equal()` guard is skipped while `_rect` is null. Verify each entry against the
      code as it then stands.

## 7. Cover the cross-monitor scenario

- [x] 7.1 Add `tests/harness/cases/preview-cross-monitor.sh` with the existing two-monitor session
      profile: window on the first monitor, gesture made on the second, and the outline falls in the
      second monitor's work area. The spec scenario had no case, and the preview follows the
      gesture's monitor by construction rather than by looking one up. Verified it fails when
      `_onSelect` is pointed at the window's monitor instead — the outline lands at 640 rather than
      1920.
