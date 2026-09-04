# Translating Magunetto

Thirty-nine strings, about three hundred words. The source language is **British
English**; American English is a catalogue like any other.

## What the extension does

Hold a keyboard shortcut, and a radial menu appears where the pointer is. Keep the shortcut's
modifier held and flick the pointer in a direction, then release: the focused window snaps to that
region of the screen. The window is seen to travel there rather than appearing, and how it travels
can be chosen.

The menu itself contains no text. Everything here is the preferences dialog, plus the settings
descriptions that `dconf-editor` and `gsettings describe` show.

## Where each string appears

```
  +--------------------------------------------------------------+
  |                                                              |
  |   Radial menu shortcut                          [ Alt+Z ]    |  <- row title
  |   Hold to raise the menu, release to snap                    |  <- row subtitle
  |                                                              |
  |   Snapping                                                   |  <- group heading
  |  +--------------------------------------------------------+  |
  |  | Preview                                        ( o__)  |  |  <- row title
  |  | Outline the region while the menu is up                |  |  <- row subtitle
  |  +--------------------------------------------------------+  |
  |  | Animate                                        ( o__)  |  |  <- row title
  |  | Show the window travelling to its new region           |  |  <- row subtitle
  |  +--------------------------------------------------------+  |
  |  | Style                                       Snappy  v  |  |  <- row title, list item
  |  | Most of the move happens at once, then it settles.     |  |  <- list item description
  |  +--------------------------------------------------------+  |
  |  | Outer gap                                    [  0 -+]  |  |  <- row title
  |  | Space between a window and the edge of the screen      |  |  <- row subtitle
  |  +--------------------------------------------------------+  |
  |  | Inner gap                                    [  0 -+]  |  |  <- row title
  |  | Space between two windows snapped side by side         |  |  <- row subtitle
  |  +--------------------------------------------------------+  |
  |                                                              |
  +--------------------------------------------------------------+

        clicking the shortcut row opens a dialog:

  +----------------------------------------+
  |   Press a shortcut                     |  <- dialog heading
  |   The shortcut must include a          |  <- dialog body
  |   modifier key.                        |
  |                             [ Cancel ] |  <- button
  +----------------------------------------+
```

### The dialog

| String | Role | Budget |
|---|---|---|
| `Radial menu shortcut` | row title | 2–4 words |
| `Hold to raise the menu, release to snap` | row subtitle | one clause, no full stop |
| `Snapping` | group heading | one word |
| `Preview` | switch row title | one word, a noun |
| `Outline the region while the menu is up` | row subtitle | one clause, no full stop |
| `Animate` | switch row title | one word, a verb |
| `Show the window travelling to its new region` | row subtitle | one clause, no full stop |
| `Style` | row title | one word |
| `Outer gap` | spin row title, and a settings summary | 2–3 words, distinct from *Inner gap* |
| `Space between a window and the edge of the screen` | row subtitle | one clause, no full stop |
| `Inner gap` | spin row title, and a settings summary | 2–3 words, distinct from *Outer gap* |
| `Space between two windows snapped side by side` | row subtitle | one clause, no full stop |
| `Press a shortcut` | dialog heading | 2–3 words, an instruction |
| `The shortcut must include a modifier key.` | dialog body | one sentence, with a full stop |
| `Cancel` | button | one word — use whatever your language's GNOME uses |

### The seven travel styles

Each is a name shown in a dropdown list, and a description shown beneath the list once selected.
The names must be **distinct from one another** in your language: they are all a user has to tell
the seven apart. Each description is **one sentence**, closed by whatever closes a sentence in your
language.

| Name | Description |
|---|---|
| `Instant` | `Almost immediate, then a long drift into place.` |
| `Snappy` | `Most of the move happens at once, then it settles.` |
| `Settle` | `Quick to move, unhurried to stop.` |
| `Soft` | `Sharper than GNOME's own, still gentle at the end.` |
| `Standard` | `The curve GNOME uses for its own window animations.` |
| `Spring` | `Overshoots as it slides, but never grows past its region.` |
| `Overshoot` | `Slides past the target and comes back, briefly exceeding its region.` |

These describe motion, not sound or speed of work. *Snappy* is about a movement that happens almost
all at once and then settles, not about a brisk or witty manner. *Settle* is the movement coming to
rest. *Spring* and *Overshoot* both go past the destination and come back; the difference is that
*Spring* only slides past, while *Overshoot* also grows briefly larger than the region.

### The settings descriptions

Seen only in `dconf-editor` and `gsettings describe`. Six summaries and six descriptions, in a
plainer register than the dialog — these are documentation, not interface. The two gap summaries
are the same strings as the two gap row titles, so they are translated once.

The two gap descriptions define the settings, and the definitions must survive translation: the
*inner* gap is the **total** distance between two windows, not a margin each one keeps; the *outer*
gap applies on all four sides; and filling the work area uses the outer gap alone. Where your
language's GNOME already has a word for the space between tiled windows — Tiling Assistant and Pop
Shell ship catalogues — use it.

## Rules

- **Never translate**: `GNOME`, `Alt`, `Super`, and the quoted values `"expo"`, `"quint"`, `"md"`,
  `"cubic"`, `"quad"`, `"spring"`, `"back"`. Those last are values the extension stores and reads;
  translating one would document a setting it cannot accept. Note that `"spring"` and `"back"` are
  also ordinary English words — inside the quotes they are not.
- **Row titles and subtitles carry no full stop.** Descriptions and dialog bodies do.
- **Match your desktop.** GNOME Shell ships a catalogue for your language. Read how it already
  renders *shortcut*, *animation*, *window*, *cancel*, and use the same words — a user should not
  meet two names for the same thing between the shell and this dialog.
- **Use your language's own punctuation and spacing** — `。` and `、` for Japanese and Chinese, the
  narrow no-break space before `?` `!` `;` `:` in French, and so on.
- **Leave no entry empty and none marked `fuzzy`.** A half-translated dialog reads as a bug rather
  than as an absent translation, so an incomplete catalogue does not ship.

## The loop

```sh
nix develop --command po/update.sh        # re-extract, and merge into every catalogue
msgfmt --check --statistics po/<lang>.po  # what is still missing
node --test tests/l10n.test.js            # the rules above, enforced
```

## Adding a language

Add its code to `po/LINGUAS` — bare, unless the territory genuinely changes the text, which is how
GNOME names its own — then run `po/update.sh` and fill in the file it creates.
