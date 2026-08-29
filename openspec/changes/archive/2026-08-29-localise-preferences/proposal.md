## Why

Every word Magunetto shows a user is English, and the preferences dialog is the only place it shows
words at all. The plumbing to fix that is already half-declared and entirely unused: `metadata.json`
names a `gettext-domain`, the GSettings schema declares one on its `<schemalist>`, and
`ExtensionBase` calls `initTranslations()` from its constructor. Nothing is marked for extraction, so
those declarations are a promise the tree does not keep.

The surface is small enough to finish rather than start: 29 strings, about 200 words. It will only
grow, and every travel style added later is two more strings in thirteen catalogues.

## What Changes

- The preferences dialog is translated: its own 9 strings, and the 14 label-and-description strings
  the travel styles carry in `lib/curveInfo.js`.
- The GSettings schema's 3 summaries and 3 descriptions are translated. These are seen only in
  `dconf-editor` and `gsettings describe`, but the schema already declares the domain.
- **en_GB is the source language.** One string carries it today — *"Show the window travelling to its
  new region"* — and `en_US` becomes a catalogue with a single entry rather than the base.
- Thirteen catalogues ship: `en_US`, `de`, `pt_BR`, `es`, `fr`, `ru`, `it`, `pl`, `nl`, `uk`, `ja`,
  `tr`, `zh_CN`. Named as GNOME names its own 93, which is also what gettext's fallback requires: a
  `de_AT` user finds `de` and never `de_DE`.
- Translations are committed as `.po` and compiled to `.mo` at build time. The extension tree stays a
  pure source tree, which is what lets the zip, the Nix package, and the three distro packages all be
  built from it.
- `metadata.json` is **not** translated. `extensionPrefsDialog.js` uses `metadata.name` verbatim and
  nothing gettexts `metadata.description`; there is no path for it.
- The radial menu is **not** translated, because it contains no text. It is 325 lines of Cairo with
  no `St.Label`, no Pango, and no `show_text`. None of the thirteen languages is right-to-left, so
  there is no mirroring question either.

## Capabilities

### New Capabilities

- `localisation`: which surfaces carry translatable text, what the source language is, how a
  catalogue is selected and resolved at runtime, and what a catalogue must satisfy to ship.

### Modified Capabilities

None. No existing requirement in `radial-menu` or `window-snap` changes: the gesture, the geometry,
and the travel are all unaffected. What a preference is *called* is new ground, not a change of
behaviour.

## Impact

**Code**

- `magunetto@matteopacini.me/prefs.js` — strings wrapped in `this.gettext(...)`, which needs no
  import: `ExtensionPreferences extends ExtensionBase`, whose constructor binds the domain.
- `magunetto@matteopacini.me/lib/curveInfo.js` — strings marked with a locally defined `N_`. The file
  imports nothing and must keep importing nothing, so it marks for extraction without translating;
  `prefs.js` translates at the point of display.
- `po/` — new, at the repository root rather than inside the extension: the template, thirteen
  catalogues, `LINGUAS`, `POTFILES`, the extraction script, and the translator brief. Inside the
  extension they would ship in every artefact — `packaging/install.sh` copies that tree wholesale.

**Build and packaging**

- `flake.nix` — `gettext` in the devShell. It is currently only ambient on the author's machine.
- `package.nix` — `msgfmt` in `nativeBuildInputs`; compiles `po/` into `locale/`. Feeds both the Nix
  package and the zip.
- `packaging/build.sh` — compiles into the staged tree, so `packaging/install.sh` stays a pure
  copier and the layout is still stated once.

**Tests**

- `tests/l10n.test.js` — new unit-tier catalogue tests.
- `tests/nixos-test.nix` — asserts every catalogue resolves from the *installed* tree, which is the
  only tier that sees it. Needs `i18n.supportedLocales` set: the NixOS default is `C.UTF-8` and
  `en_US.UTF-8` only.
- The harness gains nothing. The shell draws no text and never starts the preferences process.

**Docs**

- `README.md` — a Translations section, and how to add a language.
- `AGENTS.md` — the map, and the traps this change earns.
