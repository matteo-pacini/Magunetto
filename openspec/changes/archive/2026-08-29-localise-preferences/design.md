## Context

See `proposal.md` — Why.

Every finding below was established against the installed GNOME Shell 50.4, by reading the shell's
own bundled JavaScript and by running the tools, not from documentation.

**Half the plumbing already exists and does nothing.** `metadata.json` declares
`"gettext-domain": "magunetto@matteopacini.me"` and the GSettings schema declares the same domain on
its `<schemalist>`. Nothing binds them to a catalogue, because there is none. From
`sharedInternals.js`, extracted from `libshell-18.so`:

```js
constructor(metadata) {
    ...
    this.initTranslations();          // runs from the base constructor
}

initTranslations(domain) {
    domain ||= this.metadata['gettext-domain'] ?? this.uuid;
    const localeDir = this.dir.get_child('locale');
    if (localeDir.query_exists(null))
        bindtextdomain(domain, localeDir.get_path());
    else
        bindtextdomain(domain, Config.LOCALEDIR);
}
```

`ExtensionPreferences extends ExtensionBase`, and `extensionPrefsDialog.js` constructs it as
`new prefsModule.default({...metadata, dir, path})`, so `dir` resolves. The domain is bound before
`fillPreferencesWindow` is ever called, in both processes, with no work on our part.

**The surface is 29 strings.** Nine in `prefs.js`, fourteen in `lib/curveInfo.js` — seven travel
style names and seven descriptions — and six in the schema. About 200 words in total.

**`metadata.json` is not translatable.** `extensionPrefsDialog.js:22` sets the window title from
`extension.metadata.name` verbatim, and nothing anywhere gettexts `metadata.description`. There is no
path for it, so there is no decision to make about it.

**The radial menu has no words.** 325 lines of Cairo, with no `St.Label`, no Pango, and no
`show_text`. This is not an oversight to be corrected; see the last requirement in the spec.

## Goals / Non-Goals

**Goals:**

- A user in any of the thirteen languages opens the preferences and sees their own.
- `lib/curveInfo.js` keeps importing nothing. That constraint is load-bearing and predates this
  change.
- The extension directory stays a pure source tree, because that is what lets one derivation feed
  the zip, the Nix package, and the three distro packages.
- Adding a travel style later cannot silently leave thirteen catalogues behind.

**Non-Goals:**

- Translating anything outside the preferences dialog and the schema. There is nothing else.
- Right-to-left support. None of the thirteen is right-to-left, and the one surface where mirroring
  would matter draws no text.
- A test that renders the dialog and reads pixels or accessibility text back. See the last decision.

## Decisions

### Translate through the preferences object, not through an import

`prefs.js` calls `this.gettext(...)`. The method is inherited, the domain is already bound, and no
import is added to a file that currently imports four things.

*Alternative — `import {gettext as _} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js'`.*
This works, and it is what most extensions do. Rejected because the module-level form resolves the
extension by walking `new Error().stack` for a path containing `/gnome-shell/extensions/`
(`GettextWrapper.#detectUrl`), which is a good deal of machinery to reach a method already on `this`.
It also has a different spelling in the shell process and the preferences process, which matters for
the next decision.

### `lib/curveInfo.js` marks, and does not translate

The file imports nothing on purpose: the preferences run in their own process and must not pull the
compositor's toolkit into it, and the table is unit-tested without a shell. It also holds fourteen of
the twenty-three dialog strings.

Both facts survive with the standard gettext marker — a local identity function, which is what `N_`
has always been:

```js
const N_ = s => s;

export const CURVES = {
    expo: {
        label: N_('Instant'),
        description: N_('Almost immediate, then a long drift into place.'),
```

The table still holds English source strings, so the existing unit tests are unaffected. `prefs.js`
translates at the point of display.

*Alternative — import a translation function into `curveInfo.js`.* Rejected outright: the two
processes that read this file bind gettext through different resource URIs, so there is no single
import that is correct in both.

*Alternative — pass a translation function into `infoFor()`.* Rejected as plumbing with one caller
and no second use.

*Alternative — move the prose out into `prefs.js`.* Rejected: it would split the table from its
descriptions and break the two unit tests that assert on them.

Extraction was verified against these exact shapes:

```sh
xgettext --language=JavaScript --from-code=UTF-8 \
         --keyword=N_ --keyword=gettext --keyword=this.gettext
```

It reads ESM, handles the apostrophe in *"Sharper than GNOME's own"*, and finds both call forms.

### British English is the source, American English is a catalogue

Exactly one displayed string carries it today — *"Show the window travelling to its new region"*.
`CENTRE` in `geometry.js` is an internal identifier and is never displayed.

`en_US.po` therefore carries one entry. That is not a waste: it is the largest single audience, and
`travelling` reads as a misspelling rather than as a dialect to them.

*Alternative — reword the source to a word both spell alike* (`moving`, `sliding`), making `en_US`
unnecessary. Rejected: it lets one word's orthography choose the project's vocabulary, and the next
such string would face the same trade with a worse alternative available.

*Alternative — American English as the source, British as a catalogue.* This is GNOME's own
convention and was the first instinct. Rejected because the repository is written in British English
throughout — `README.md`, `AGENTS.md`, the comments — and a source language that disagrees with the
prose around it will drift back on its own.

### Catalogues are named as GNOME names its own

The shell ships 93 catalogues at `share/locale/`. Its naming answers the question without argument:
`de`, `es`, `fr`, `it`, `ja`, `nl`, `pl`, `ru`, `tr` and `uk` are bare; `pt` and `pt_BR` both exist
because they differ; `zh_CN`, `zh_HK` and `zh_TW` are all qualified; and there is no `en_US`, because
that is the source.

This is also what gettext's lookup requires. It strips a territory but never substitutes one, so a
`de_AT` session searches `de_AT` then `de` and never looks at `de_DE`. Naming the catalogue `de_DE`
would serve Germany and nobody else.

Thirteen catalogues ship: `en_US`, `de`, `pt_BR`, `es`, `fr`, `ru`, `it`, `pl`, `nl`, `uk`, `ja`,
`tr`, `zh_CN`.

### Catalogues live inside the extension directory

`initTranslations()` binds to `<extension dir>/locale` when that directory exists, and to the
shell's own `LOCALEDIR` when it does not. Shipping `locale/` inside the extension takes the first
branch for every artefact this project publishes, including the distro packages —
`packaging/install.sh` copies the whole tree, so the directory is there.

*Alternative — install to `/usr/share/locale` for the distro packages only,* which is where a
distro would normally put them. Rejected: it makes the packaged layout differ from the zip and the
Nix package for no gain, against an install script whose entire reason to exist is that the layout
is stated once.

### Translations are committed as source; the binary form is built

`po/` sits at the repository root, not inside the extension. Inside it, the catalogue sources and the
tooling beside them would reach every installed tree: `packaging/install.sh` copies that directory
wholesale and `package.nix` takes it as its source. `package.nix` takes `po/` as a second
`builtins.path` instead, which keeps the derivation's source narrow — a change under `tests/` still
does not rebuild the package.

`po/*.po` is committed and reviewed like any other text. `msgfmt` runs in `package.nix` — feeding
both the Nix package and the zip, which is built from the Nix output — and in
`packaging/build.sh`, which compiles into the staged tree so `packaging/install.sh` stays a pure
copier.

```
   po/*.po  (committed, reviewed, diffable)
        |
        +--> package.nix [msgfmt] ------------------> Nix package, zip
        |
        +--> build.sh    [msgfmt] --> stage --> install.sh --> deb, rpm, pacman
```

*Alternative — commit the compiled catalogues.* Every build path keeps working untouched, which is
the appeal, and plenty of extensions do it. Rejected: thirteen binary blobs that no review can read
and that go stale in silence.

*Alternative — compile into the working tree and ignore the output in git.* Rejected, and this one
is a trap already recorded in `AGENTS.md`: `nix build` takes a flake's source from the git tree, so
an ignored file is simply absent from the derivation. The unit and harness tiers read the working
tree and pass; the VM installs an extension with no catalogues and says nothing.

### The schema strings are extracted too

`glib` ships `share/gettext/its/gschema.its`, so one additional `xgettext` run with
`GETTEXTDATADIRS` pointed at glib's share directory extracts the three summaries and three
descriptions. Six strings on a base of twenty-three.

They are worth taking because the schema already declares the domain, so today it makes a promise
the tree does not keep — and because `gsettings describe` and `dconf-editor` are where a user goes
when the dialog has not told them enough.

The `snap-animation-curve` description names its permitted values — *"One of expo, quint, md, cubic,
quad, spring, back"* — and those must survive untranslated. This is the requirement about stored
values in the spec, and it needs a translator comment in the template rather than trust.

### Each tier proves what only it can

**The unit tier** owns the catalogues. It regenerates the template and compares, so a travel style
added without re-extracting fails; it checks every catalogue for completeness and for entries marked
fuzzy; and it re-asserts, per catalogue, the two properties the English table is already tested for —
that the seven style names are distinct, and that each description closes as a sentence. A translator
who renders both *Instant* and *Snappy* as one word leaves a list with two identical rows, and only
this catches it.

**The VM tier** owns the binding, because it is the only tier that sees an installed tree. It runs
`tests/locale-check.js` once per locale:

```js
if (setlocale(LocaleCategory.MESSAGES, '') === null)
    throw new Error('the environment names no usable locale');
bindtextdomain(domain, localeDir);
if (dgettext(domain, source) === source) {
    printerr(`${locale}: did not resolve from ${localeDir}`);
    System.exit(1);
}
```

Two findings shape it, both established by running the thing rather than reasoning about it.

*One process per locale.* The obvious form is a loop over `LANGUAGE` inside a single process. It does
not work: glibc resolves a domain's catalogue on first use and caches it, so every locale after the
first reports the first one's answer. Probed with five locales, all five came back German.

*`LANGUAGE`, not a locale per catalogue.* Selecting each catalogue with `setlocale(_, 'de_DE.UTF-8')`
would mean building thirteen locales into the image — `i18n.supportedLocales` defaults to `C.UTF-8`
and `en_US.UTF-8` alone, so the node would have to name them and rebuild `glibcLocales`. `LANGUAGE`
needs only the *message* locale to be real, and the default image already has one.

That last point carries its own trap, which is why the `null` check stays: `LANGUAGE` is consulted
only when the message locale is not `C`. Under `LC_ALL=C` it is ignored and every catalogue looks
missing — verified, and the check refuses rather than reporting a false absence. The failure mode
this rules out is the same shape as the `grep -q false` trap already in `AGENTS.md`: a check that
passes because it never ran.

The probe string is *"Show the window travelling to its new region"* rather than a style name,
because it is the one string that differs from its source in **all thirteen** — including `en_US`,
where the whole catalogue is one spelling.

The gesture assertions in that test are unaffected: they grep for `ACTIVE`, and while `gnome-shell`'s
German catalogue does translate `State` to `Status`, it carries no entry for `ACTIVE` at all.

**The harness tier gains nothing**, and this is deliberate rather than an omission. The shell draws
no text, and the preferences run in a process the harness never starts. This is the first change
whose scenarios do not map onto harness cases, and `AGENTS.md` should say so.

*Alternative — render the dialog in a locale and read it back.* It is the only thing that would catch
a string wrapped but never marked, or a `this` that does not bind where the call site assumes.
Rejected as a committed tier: it is a whole new one, for a dialog with three rows, and the unit
tier's template comparison catches the same class of mistake at the source.

It is, however, entirely possible as a one-off, and was run once before this change landed — so the
next person weighing it has the recipe rather than the question. A headless shell under
`dbus-run-session` supplies the display; the extension's `prefs.js` is then imported by a plain `gjs`
client that registers `org.gnome.Shell.Extensions.src.gresource` and constructs the class the way
`extensionPrefsDialog.js` does, with `{...metadata, dir, path}`. Walking the resulting widget tree
prints every title and subtitle. Two typelibs are needed that the devShell does not carry:
libadwaita, and `Shew`, which is not a nixpkgs attribute at all — it lives inside gnome-shell, at
`lib/gnome-shell/girepository-1.0`.

That run confirmed all three rows, the list items and the selected style's description in `de`, `ja`
and `it`, and confirmed that an unknown locale falls back to British English rather than to blanks.

### Translations are produced per language, with the strings placed

Each language is translated in isolation, given the string, where it appears — row title, row
subtitle, dialog heading, dialog body, button, list item name, list item description — its length
budget, and the domain vocabulary. This is a window manager: *snap*, *region*, *work area*,
*modifier*, *shortcut* are terms, not prose.

The grounding that matters is that `gnome-shell` ships a catalogue for every one of the thirteen. A
translation should render *shortcut*, *animation* and *window* the way the user's own desktop
already renders them, and that rendering is on disk to be read rather than guessed.

## Risks / Trade-offs

**Thirteen catalogues written without a native reviewer for each** → They are text under review in
git rather than binaries, the unit tier enforces the structural properties that survive translation,
and `README.md` says where to send a correction. Quality here is bounded by the reviewer, and the
honest position is that a wrong word will ship and be fixed by whoever notices.

**Thirteen new files that must be tracked before the VM tier sees them** → the `git add` trap, at
thirteen times the surface. `tests/run-all.sh` already refuses `--vm` when anything under the
extension directory is untracked; the guard covers `po/` for free, and should be checked rather than
assumed.

**Adding a travel style now costs fourteen edits, not two** → intended. The alternative is silently
shipping an English name in twelve languages, which is the failure this change exists to prevent.
The template comparison makes the cost visible at the moment it is incurred rather than at release.

**A build dependency in a place that had none.** `packaging/install.sh` is a `set -eu` `/bin/sh`
script with no tools; keeping it that way is why `build.sh` compiles into the staged tree instead.
The dependency lands in `flake.nix` and `package.nix`, both of which already have several.
