## 1. Groundwork

- [x] 1.1 Add `pkgs.gettext` to the devShell in `flake.nix`; verify `nix develop --command sh -c 'command -v xgettext msgfmt msgmerge msginit'` resolves all four inside the shell and not from the ambient environment
- [x] 1.2 Mark the fourteen strings in `magunetto@matteopacini.me/lib/curveInfo.js` with a locally defined `const N_ = s => s;`, leaving the file importing nothing; verify `node --test tests/curveInfo.test.js` still passes unchanged
- [x] 1.3 Wrap the nine strings in `magunetto@matteopacini.me/prefs.js` in `this.gettext(...)`, including the seven style names and seven descriptions read from `CURVES` at the point of display; verify the file still parses and that no title, subtitle, heading, body or dialog response is left holding a bare literal. `gnome-extensions prefs` cannot verify this — it opens the extension installed on the desktop, not the working tree — so the dialog itself is opened at 8.3

## 2. Extraction

- [x] 2.1 Create `po/` at the repository root — not inside the extension, which `packaging/install.sh` copies wholesale and `package.nix` takes as its source — with a `POTFILES` listing `prefs.js`, `lib/curveInfo.js` and the schema, and a `LINGUAS` naming the thirteen catalogues; verify both files list exactly the paths and locales the design names
- [x] 2.2 Add `po/update.sh`, running one `xgettext` pass with `--keyword=N_ --keyword=this.gettext` over all three sources — xgettext picks the reader per file, so the schema needs no separate pass, only `GETTEXTDATADIRS` pointing at glib's `share/gettext`, which the devShell now exports; verify the template holds 29 messages and that *"Sharper than GNOME's own, still gentle at the end."* survives its apostrophe intact
- [x] 2.3 Mark the stored values in the `snap-animation-curve` description as literal. `its:locNote` is not available: it survives `glib-compile-schemas --strict` but xgettext ignores it, because glib's `gschema.its` defines no `locNoteRule`. Quote the values in the source instead — `back` and `spring` are ordinary English words and are what a translator would render; verify the schema still compiles and the quotes reach the template

## 3. Translations

- [x] 3.1 Write the translator brief: each string with its placement (row title, row subtitle, dialog heading, dialog body, button, list item name, list item description), its length budget, the do-not-translate list, and a pointer to `$(dirname $(readlink -f $(command -v gnome-shell)))/../share/locale/<lang>/LC_MESSAGES/gnome-shell.mo` for established GNOME terminology; verify a catalogue exists there for all thirteen
- [x] 3.2 `en_US` — one entry, `travelling` to `traveling`; verify `msgfmt --check --statistics` reports it complete
- [x] 3.3 `de` — verify `msgfmt --check --statistics` reports it complete with no fuzzy entries
- [x] 3.4 `pt_BR` — verify as above
- [x] 3.5 `es` — verify as above
- [x] 3.6 `fr` — verify as above
- [x] 3.7 `ru` — verify as above
- [x] 3.8 `it` — verify as above
- [x] 3.9 `pl` — verify as above
- [x] 3.10 `nl` — verify as above
- [x] 3.11 `uk` — verify as above
- [x] 3.12 `ja` — verify as above, and that descriptions close with `。`
- [x] 3.13 `tr` — verify as above
- [x] 3.14 `zh_CN` — verify as above, and that descriptions close with `。`

## 4. Unit tests

- [x] 4.1 Add `tests/l10n.test.js` asserting the template regenerates identically from the sources; verify it fails when a string is added to `CURVES` without re-extracting
- [x] 4.2 Assert every `CURVES` label and description appears as a msgid in the template; verify it fails when a style is added with only its key
- [x] 4.3 Assert every catalogue in `LINGUAS` is `msgfmt --check` clean, translates every template string, and carries no fuzzy entry; verify it fails against a catalogue with one entry blanked and again with one marked fuzzy
- [x] 4.4 Assert the seven translated style names are distinct within each catalogue; verify it fails when two are made identical in one catalogue
- [x] 4.5 Assert each translated style description closes as a sentence in its language, accepting `.` and `。`; verify it fails when the closing punctuation is stripped from one entry
- [x] 4.6 Assert the curve keys appear unchanged in every catalogue's translation of the `snap-animation-curve` description; verify it fails when one key is translated
- [x] 4.7 Confirm `node --test tests/*.test.js` picks the new file up and the whole unit tier still runs in well under a second

## 5. Build and packaging

- [x] 5.1 Add `gettext` to `nativeBuildInputs` in `package.nix`, take `po/` as a second `builtins.path` so the derivation's source stays narrow, and compile into `locale/<lang>/LC_MESSAGES/magunetto@matteopacini.me.mo` during `buildPhase`; verify `nix build .#default` produces a `.mo` for all thirteen and leaves no `.po` or tooling in the installed tree
- [x] 5.2 Confirm the zip inherits them: `packaging/build.sh` builds it from the Nix output, so verify the archive holds thirteen `.mo` files
- [x] 5.3 Compile into the staged tree in `packaging/build.sh` *after* `packaging/install.sh` has copied it — install.sh reads from the working tree, so compiling before it would mean writing build output there — leaving `install.sh` a pure copier; verify the deb, rpm and pacman packages each list thirteen `.mo` files under `usr/share/gnome-shell/extensions/`
- [x] 5.4 Add `po/`, `tests/l10n.test.js` and `tests/locale-check.js` to git before any VM run; verify `git status --porcelain magunetto@matteopacini.me/` is clean and that `tests/run-all.sh --vm` no longer refuses on untracked files

## 6. VM test

- [x] 6.1 No locale needs building into the image. `LANGUAGE` selects a catalogue while requiring only that the *message* locale be real, and the NixOS default already builds `C.UTF-8` and `en_US.UTF-8`; setting `i18n.supportedLocales` to thirteen would rebuild `glibcLocales` for nothing. Verify the check still refuses when the message locale is `C`, which is when `LANGUAGE` is ignored
- [x] 6.2 Add `tests/locale-check.js` — one locale per invocation, because glibc resolves a domain's catalogue on first use and caches it, so a second `LANGUAGE` in the same process is silently ignored and every locale after the first reports the first one's answer. It binds the domain to the installed `locale/` directory and asserts the probe string differs from its source; verify it exits non-zero for an unknown locale, for a `C` message locale, and when a `.mo` is absent
- [x] 6.3 Wire it into `tests/nixos-test.nix`, reading the locale list from `po/LINGUAS` at evaluation time so it cannot fall behind; verify the existing gesture assertions are unaffected and the whole VM test still passes

## 7. Documentation

- [x] 7.1 Add a Translations section to `README.md` — the thirteen languages, British English as the source, and how to add or correct one; verify the layout tree in that file lists `po/` and `tests/l10n.test.js`
- [x] 7.2 Update the map in `AGENTS.md` with `po/` and `lib/curveInfo.js`'s marking role, and record why this change has no harness case; verify the loop section still describes every tier accurately
- [x] 7.3 Add the traps this change earns to `AGENTS.md`: a failed `setlocale` falls back to English and passes the assertion for the wrong reason, `i18n.supportedLocales` ships only `C.UTF-8` and `en_US.UTF-8` by default, and gettext strips a territory but never substitutes one

## 8. Verification

- [x] 8.1 Run `tests/run-all.sh` and confirm the unit and harness tiers pass with the harness case count unchanged
- [x] 8.2 Run `tests/run-all.sh --vm` and confirm the VM tier passes, including the new catalogue check
- [x] 8.3 Render the dialog in a translated locale and confirm the fallback. `watch.sh` is not the way — the outer compositor eats the shortcut and the dialog is a separate process anyway. Instead load the built extension's `prefs.js` into a plain `gjs` client against a headless shell under `dbus-run-session`, and walk the widget tree; verify every row reads in that language and that an unknown locale reads British English
