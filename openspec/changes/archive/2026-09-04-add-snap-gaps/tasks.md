## 1. The maths

- [x] 1.1 Give `rectFor()` in `magunetto@matteopacini.me/lib/geometry.js` a third argument
      `gaps = {outer: 0, inner: 0}`. Take `2 * outer + inner` out of each span before the
      floor/remainder split, offset the near region by `outer` and the far region by `near + inner`,
      and inset the centre action by `outer` alone. The module must still import nothing. Verify
      `node --test tests/geometry.test.js` passes unchanged before any test is added — the default
      argument must reproduce today's rectangles.
- [x] 1.2 Add unit tests to `tests/geometry.test.js`, over the existing `AREAS` and a set of gap
      pairs including `{0,0}`, an odd inner, and `{100,100}`: the near edge of a half is `outer`
      from the area edge; the far edge of the opposite half is `outer` from the far area edge; the
      two halves are exactly `inner` apart; halves differ by at most one pixel; quarters compose
      both axes and the four quarters leave one seam per axis; the centre action ignores `inner`;
      no rectangle has a non-positive size at the bound; and `{0,0}` deep-equals the two-argument
      call. Verify each fails when the corresponding term is removed from `rectFor`.

## 2. The preferences

- [x] 2.1 Add `snap-outer-gap` and `snap-inner-gap` to
      `magunetto@matteopacini.me/schemas/org.gnome.shell.extensions.magunetto.gschema.xml`, type
      `i`, `<range min="0" max="100"/>`, default 0, each with a summary and a description in the
      register of the keys already there. The inner description must say the value is the total
      distance between two windows. Verify `glib-compile-schemas --strict` succeeds and that a value
      of 101 is refused by `gsettings set` in a harness session.
- [x] 2.2 Read both keys in `_onTrigger` in `extension.js`, beside the preview flag, and hold them on
      the instance for the gesture. Pass them to `rectFor` in `_onSelect` and to `snap()` at commit;
      `snap()` in `lib/snap.js` gains the argument and passes it through. Clear them in `disable()`.
      Verify by hand with `nix develop --command tests/harness/watch.sh` after setting the keys with
      `gsettings` in the nested session: the outline and the landing agree.
- [x] 2.3 Add two `Adw.SpinRow`s to the Snapping group in `prefs.js`, after Style, titled and
      subtitled through `this.gettext(...)`, with an adjustment of 0 to 100 step 1 and bound with
      `Gio.SettingsBindFlags.DEFAULT`. Verify the rows render and clamp by loading the working tree's
      `prefs.js` into a `gjs` client as the localisation change did at its task 8.3, or by reading
      the construction against the rows beside it if that path is not restored.

## 3. Make it testable

- [x] 3.1 Add `CASE_OUTER_GAP` and `CASE_INNER_GAP` to `tests/harness/run.sh`: defaults of 0, written
      into the session keyfile, part of the session profile and of `ensure_session`'s comparison.
      Add both names, and the missing `PREVIEW`, to the profile grep that groups cases so that cases
      sharing a profile share a boot. Verify the full harness still passes and that the number of
      shell boots in a run does not rise for the existing cases.
- [x] 3.2 Add `tests/harness/cases/gap-halves.sh` with `CASE_OUTER_GAP=8` and `CASE_INNER_GAP=12`:
      snap one window left, read its frame; open a second, snap it right, read its frame. Assert the
      left window's x is `outer` from the work area's left, its y `outer` from the top, its height
      `height - 2 * outer`; the right window's far edge `outer` from the work area's right; and the
      gap between them exactly `inner`. Verify the case fails against the current `rectFor`.
- [x] 3.3 Add `tests/harness/cases/gap-quarter.sh` with the same profile: top-left and bottom-right
      quarters on two windows, asserting the outer inset on the outer sides and the inner gap on
      both axes between the two. Verify it fails without task 1.1.
- [x] 3.4 Add `tests/harness/cases/gap-centre.sh` with the same profile: the centre action places
      the window `outer` from all four edges, and its size is the work area less `2 * outer` on each
      axis, unaffected by `inner`. Verify it fails without task 1.1.
- [x] 3.5 Add `tests/harness/cases/gap-preview.sh` with the same profile: select a half, settle, and
      assert the outline's rectangle equals the gapped rectangle the window then lands on. Verify it
      fails when `_onSelect` is given zero gaps.
- [x] 3.6 Add `tests/harness/cases/gap-cross-monitor.sh` with the same gap profile and the existing
      two-monitor `CASE_MONITORS`: gesture on the second monitor, and the window lands inset from
      that monitor's work area read with `monitor_work_area_field`. Verify it fails when the gesture
      monitor is replaced with the window's.
- [x] 3.7 Add `tests/harness/cases/gap-repeat.sh` with the same profile: the same sector twice, the
      geometry identical both times. Verify it passes and that it fails if the second snap is made
      to a different sector.
- [x] 3.8 Add `tests/harness/cases/gap-live.sh` with the same profile: set `snap-inner-gap` to
      another value through the extension's settings object as `_curves.sh` does, gesture, assert
      the seam uses the new value, and restore the profile's value before the case ends. Verify the
      cases that share the profile still pass when run after it.

## 4. Thirteen languages

- [x] 4.1 Run `nix develop --command po/update.sh` and confirm `po/magunetto.pot` grows from 33
      messages to 39: two titles that double as the schema summaries, two subtitles, two
      descriptions. Verify by reading
      the new entries.
- [x] 4.2 Update `po/TRANSLATING.md`: the string count, the dialog sketch with the two new rows, the
      table with the six strings and their budgets, and a note that "gap" should follow whatever
      the language's GNOME shell or Tiling Assistant catalogue already uses where one exists. Verify
      every new msgid appears in the brief.
- [x] 4.3 Translate the six strings into all thirteen catalogues — `en_US`, `de`, `pt_BR`, `es`,
      `fr`, `ru`, `it`, `pl`, `nl`, `uk`, `ja`, `tr`, `zh_CN` — keeping the two row titles distinct
      from each other in each language, and closing descriptions as sentences and subtitles without
      a full stop. Verify `nix develop --command po/update.sh --check` and `msgfmt --check
      --statistics` on each catalogue report complete with no fuzzy entry.
- [x] 4.4 Run `nix develop --command node --test tests/*.test.js` and confirm the l10n tier is green.

## 5. Documentation

- [x] 5.1 Add the two gaps to the Snapping section of `README.md`, stating that inner is the total
      distance between two windows and outer applies on all four sides, and add both keys to the
      Home Manager example. Verify the section still reads in the order the dialog does.
- [x] 5.2 Update `AGENTS.md`: the `prefs.js` map entry no longer says two settings, the harness case
      count in the loop section is the verified number from `ls tests/harness/cases/ | grep -vc '^_'`,
      and the `CASE_*` list names the two new knobs. Verify each line against the tree.

## 6. Verify the whole tree

- [x] 6.1 Run `nix develop --command node --test tests/*.test.js` and confirm every unit test passes.
- [x] 6.2 Run `dbus-run-session -- tests/harness/run.sh` and confirm the full harness passes, every
      pre-existing case included — with the defaults at 0 none of them may change.
- [x] 6.3 `git add` the new case files, then run `tests/run-all.sh --vm` and confirm all three tiers
      pass. `nix build` takes the flake's source from the git tree, so an untracked case is absent
      from the derivation.
