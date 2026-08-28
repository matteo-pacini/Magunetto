<p align="center">
  <img src="assets/icon.png" alt="Magunetto" width="160">
</p>

# Magunetto

Radial window snapping for GNOME Shell. Hold a shortcut, flick the pointer toward a direction, and
release: the focused window snaps to that region of the screen.

Named for how マグネット (*magunetto*, "magnet") sounds in Japanese. Inspired by
[Loop](https://github.com/MrKai77/Loop) on macOS, which has no Linux equivalent.

## How it works

![Snapping a window to every sector in turn](assets/demo.gif)

Hold **Alt** and tap **Z**. A radial menu appears where the pointer is. Keep Alt held and
move the mouse:

```
                  top
        top-left    |    top-right
                \   |   /
                 \  |  /
      left -------[ o ]------- right      o = centre: fill the work area
                 /  |  \                      inside it: no selection
                /   |   \
     bottom-left    |    bottom-right
                 bottom
```

Direction decides the sector, distance decides the band: stay near the centre and nothing is
selected, move a little for the centre action, move further for a direction. Release Alt to
snap, or press **Escape** to cancel.

Selection follows the *direction* you moved, not where the pointer landed, so you can flick well
past the menu and still hit the sector you aimed at.

## Requirements

GNOME Shell **50**, on Wayland. GNOME 50 has no X11 session — mutter dropped the X11 backend, and
`gnome-shell` no longer takes an `--x11` flag. Windows belonging to X11 applications run under
XWayland and are managed by mutter like any other, so they should snap the same way; that path is
not covered by the tests.

This extension targets one GNOME version deliberately. Each GNOME major release gets its own branch
and tag; the GNOME 50 tag keeps working on GNOME 50 after later branches exist. There are no
version guards in the code, which is what keeps it readable.

Window management on Wayland is only possible from inside the compositor, so this is a GNOME Shell
extension rather than an application. No external program can move another program's window.

## Install

With Nix flakes — add the input, then install the package:

```nix
{
  inputs.magunetto.url = "github:matteo-pacini/Magunetto";

  # in your NixOS or home-manager configuration:
  environment.systemPackages = [ inputs.magunetto.packages.${pkgs.system}.default ];
}
```

From a checkout, for development:

```sh
ln -sfn "$PWD/magunetto@matteopacini.me" \
        ~/.local/share/gnome-shell/extensions/magunetto@matteopacini.me
glib-compile-schemas magunetto@matteopacini.me/schemas/
```

Either way, log out and back in: the shell only scans for newly installed extensions at startup,
and Wayland has no way to restart it in place. Then enable it:

```sh
gnome-extensions enable magunetto@matteopacini.me
```

To iterate without logging out, use `tests/harness/watch.sh` (see below) — it loads the extension
into a nested shell that starts and stops in seconds.

## Changing the shortcut

Open the extension's preferences (`gnome-extensions prefs magunetto@matteopacini.me`) and click the
shortcut row.

The shortcut needs at least one modifier, because releasing that modifier is what commits the
selection. A shortcut without one still works, but can only be dismissed by a timeout.

The default is `<Alt>z`: one modifier, nothing else in GNOME claims it, and it is
reachable one-handed. `<Alt>space` would read more naturally but GNOME binds it to the
window menu, so it does nothing until that binding is cleared.

**Avoid Super.** Pressing Super puts the shell into overview mode, and shortcuts registered for
normal mode stop matching while it is held. Ctrl and Alt are reliable.

## Development

```sh
nix develop              # tools: gnome-shell, gjs, node, glib, gtk4

tests/run-all.sh         # unit tests + headless harness
tests/run-all.sh --vm    # also the NixOS virtual-machine test

node --test tests/*.test.js                # gesture maths only, milliseconds
dbus-run-session -- tests/harness/run.sh   # harness only
dbus-run-session -- tests/harness/run.sh gesture cancel   # named cases

tests/harness/watch.sh   # nested shell in a window, to drive the menu by hand
```

The harness boots a headless GNOME Shell with a virtual monitor, loads the extension, injects
synthetic input, and asserts on the extension's own state trace and the resulting window geometry.
Screenshots and logs from failing cases land in `.harness/`.

Each session runs under a throwaway home *and* forces `GSETTINGS_BACKEND=keyfile`. Both matter:
overriding `HOME` alone is not enough, because GSettings otherwise reaches the running dconf
service over the session bus and writes land in your real desktop configuration.

Assertions are on state, not pixels. The one exception is the overlay case, which compares
screenshots of different selections against each other to prove the menu actually redraws.

### Layout

```
magunetto@matteopacini.me/
  extension.js          keybinding, gesture lifecycle, state log
  prefs.js              shortcut preference
  stylesheet.css        menu colours, read off the theme node
  schemas/              GSettings schema; the shortcut lives here as a default
  lib/geometry.js       sector and rectangle maths - imports nothing
  lib/radialMenu.js     modal grab, release detection, Cairo drawing
  lib/snap.js           target eligibility and applying geometry
  lib/testInterface.js  test-only D-Bus surface, gated on MAGUNETTO_TEST
tests/
  geometry.test.js      unit tests for the maths
  run-all.sh            every tier in one command
  nixos-test.nix        virtual-machine test
  harness/run.sh        boots headless sessions, runs the cases
  harness/lib.sh        assertions and gesture helpers used by cases
  harness/cases/        one file per behaviour under test
  harness/testwindow.js a window with predictable size constraints
  harness/watch.sh      nested shell for driving the menu by hand
package.nix             the extension derivation
flake.nix               devShell, package, and the vm check
```

`lib/geometry.js` imports nothing on purpose: it is the only part testable without a compositor, so
it holds everything that can be tested that way.

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE).
