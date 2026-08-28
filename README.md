<p align="center">
  <img src="assets/icon.png" alt="Magunetto" width="160">
</p>

# Magunetto

Radial window snapping for GNOME Shell. Hold a shortcut, flick the pointer toward a direction, and
release: the focused window snaps to that region of the screen.

Inspired by [Loop](https://github.com/MrKai77/Loop) on macOS.

## How it works

![Snapping a window to every sector in turn](assets/demo.gif)

Hold **Alt** and tap **Z**. A radial menu appears where the pointer is. Keep Alt held and move the
mouse:

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

Direction picks the sector, distance picks the band: near the centre nothing is selected, a little
further selects the centre action, further still selects a direction. Release Alt to snap, Escape to
cancel.

Selection follows the direction you moved, not where the pointer landed, so you can flick past the
menu and still hit the sector you aimed at.

## Requirements

GNOME Shell **50**, on Wayland. Later GNOME releases are supported on their own branches and tags.

## Install

Download `magunetto@matteopacini.me.shell-extension.zip` from the
[latest release](https://github.com/matteo-pacini/Magunetto/releases/latest):

```sh
gnome-extensions install --force magunetto@matteopacini.me.shell-extension.zip
```

Log out and back in, then:

```sh
gnome-extensions enable magunetto@matteopacini.me
```

### Nix

Add the flake input:

```nix
{
  inputs.magunetto.url = "github:matteo-pacini/Magunetto";
}
```

Then install the package on NixOS:

```nix
{
  environment.systemPackages = [ inputs.magunetto.packages.${pkgs.system}.default ];
  programs.dconf.enable = true;
}
```

### Home Manager

Install the package and enable it declaratively, so the extension and its shortcut are part of your
configuration:

```nix
{
  home.packages = [ inputs.magunetto.packages.${pkgs.system}.default ];

  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [ "magunetto@matteopacini.me" ];
    };

    "org/gnome/shell/extensions/magunetto" = {
      show-radial-menu = [ "<Alt>z" ];
    };
  };
}
```

Log out and back in after the first activation: the shell only scans for new extensions at startup.

## Changing the shortcut

Run `gnome-extensions prefs magunetto@matteopacini.me` and click the shortcut row, or set
`show-radial-menu` as shown above.

Two constraints:

- The shortcut needs at least one modifier. Releasing that modifier is what applies the selection;
  without one, the menu can only close on a timeout.
- Super cannot be used. Holding it puts the shell into overview mode, where the shortcut stops
  matching.

`<Alt>space` is bound to GNOME's window menu and does nothing until that binding is cleared.

## Development

```sh
nix develop

tests/run-all.sh         # unit tests and the headless harness
tests/run-all.sh --vm    # adds the NixOS virtual-machine test

node --test tests/*.test.js                # gesture maths, no shell required
dbus-run-session -- tests/harness/run.sh   # harness only
dbus-run-session -- tests/harness/run.sh gesture cancel   # named cases

tests/harness/watch.sh   # nested shell in a window, to drive the menu by hand
```

The harness boots a headless GNOME Shell with a virtual monitor, loads the extension, injects
synthetic input, and asserts on the extension's state trace and the resulting window geometry.
Screenshots and logs from failing cases land in `.harness/`.

Sessions run under a throwaway home with `GSETTINGS_BACKEND=keyfile`, which keeps every setting
written during a test inside that directory.

### Layout

```
magunetto@matteopacini.me/
  extension.js          keybinding, gesture lifecycle, state log
  prefs.js              shortcut preference
  stylesheet.css        menu colours
  schemas/              GSettings schema, including the default shortcut
  lib/geometry.js       sector and rectangle maths, no imports
  lib/radialMenu.js     modal grab, release detection, drawing
  lib/snap.js           target eligibility and applying geometry
  lib/testInterface.js  test-only D-Bus surface, gated on MAGUNETTO_TEST
tests/
  geometry.test.js      unit tests for the maths
  run-all.sh            every tier in one command
  nixos-test.nix        virtual-machine test
  harness/run.sh        boots headless sessions, runs the cases
  harness/lib.sh        assertions and gesture helpers
  harness/cases/        one file per behaviour under test
  harness/testwindow.js a window with predictable size constraints
  harness/watch.sh      nested shell for driving the menu by hand
package.nix             the extension derivation
flake.nix               devShell, package, and the vm check
```

## Contributing

Contributions are welcome — issues, bug reports, and pull requests alike.

Behaviour changes are spec-driven. The contract lives in `openspec/specs/`, and a change starts
there rather than in the code: propose it with OpenSpec, write the requirements and scenarios, then
implement. Each scenario should end up with a matching case in `tests/harness/cases/`.

Run `tests/run-all.sh` before opening a pull request, and include the result. Every tier must pass.

### AI-assisted contributions

Accepted, on the same terms as any other contribution:

- Follow [AGENTS.md](AGENTS.md) (symlinked as `CLAUDE.md`). It carries the project's constraints and
  the traps that are easy to fall into.
- Keep the spec-driven flow: specs before implementation.
- Run the tests and confirm they pass. Do not submit work that has not been run.

You are responsible for what you submit, whether or not a model wrote it.

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE).
