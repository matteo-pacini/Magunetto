## Why

The shipped extension carries `lib/testInterface.js`: a session-bus D-Bus interface that synthesises
keystrokes and pointer motion inside the compositor. It is closed in a normal session — the gate is
an environment variable read from gnome-shell's own process, which nothing short of ptrace can
change — but it does not need to be in the shipped artefact at all.

Three things settle it:

- **It cannot be hardened where it is exposed.** `Gio.DBusExportedObject.wrapJSObject` passes the
  invocation only to `*Async` methods; property getters receive `(info, impl, propertyName)` and
  there is no async property form. `Log`, the whole assertion surface, therefore cannot be
  sender-checked at all. The shell's own `DBusSenderChecker` would be worse than useless: it returns
  early under unsafe mode, which every test tier already sets.
- **Nobody else ships one.** A code search for `create_virtual_device` alongside `DBusExportedObject`
  in JavaScript returns five repositories; this is one of them, and the other four use virtual
  devices as a product feature. ddterm, which has the largest end-to-end suite in the ecosystem,
  injects its hook at test time and ships none of it.
- **The mechanism is not the problem.** GNOME Shell's own tests synthesise input with the same
  `seat.create_virtual_device()` call. Shipping it is the anomaly.

## What Changes

- The test surface moves out of the extension and into the harness, and is injected into the running
  shell when a test session starts rather than being built by the extension.
- The extension stops reading `MAGUNETTO_TEST` and stops constructing anything for tests. Its state
  accessors stay: they are inert properties, and they are what the injected hook reads.
- Nothing a user can observe changes. The gesture, the placement, the animation and the preferences
  are untouched, and the extension's behaviour in a normal session is identical — it exported
  nothing there before and exports nothing now.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. `skip_specs: true`.

The specs describe what a user can observe: the menu, the placement, the travel. None of that
changes. The test surface was never part of the contract — no requirement mentions it — and adding
one now to describe where test code lives would be inventing a requirement to satisfy validation
rather than to describe behaviour.

## Impact

- `magunetto@matteopacini.me/lib/testInterface.js` — deleted.
- `magunetto@matteopacini.me/extension.js` — the `MAGUNETTO_TEST` branch, the `TestInterface` import,
  `this._test`, and the then-unused `GLib` import all go.
- `tests/harness/shellhook.js` — new. The same interface, plus an `init()` that finds the extension
  instead of being constructed by it.
- `tests/harness/lib.sh` — an injection helper; the `mg` client helpers are unchanged.
- `tests/harness/run.sh`, `tests/nixos-test.nix` — inject after the session is ready, drop the
  `MAGUNETTO_TEST` environment.
- `README.md`, `AGENTS.md` — the layout tables name the moved file, and the traps this uncovered.

The harness keeps talking to the same bus name, object path and methods, so the 31 existing cases
are untouched.

No new dependencies. The injection uses `org.gnome.Shell.Eval`, which every tier already requires.
