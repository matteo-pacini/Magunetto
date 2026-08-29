## 1. Move the surface out of the extension

- [x] 1.1 Create `tests/harness/shellhook.js` from `lib/testInterface.js`: same bus name, object path,
      methods and properties, with `SNAPSHOT_NAME` inlined rather than imported, and verify
      `node --check` parses it
- [x] 1.2 Add an `init()` that resolves the extension through
      `Main.extensionManager.lookup('magunetto@matteopacini.me').stateObj` and throws if it is
      absent, and verify the throw by injecting into a session with the extension disabled
- [x] 1.3 Delete `magunetto@matteopacini.me/lib/testInterface.js`
- [x] 1.4 Remove the `MAGUNETTO_TEST` branch, the `TestInterface` import, `this._test` in `disable()`
      and the then-unused `GLib` import from `extension.js`, and verify the extension still reaches
      ACTIVE in a headless session with nothing exported at the test object path

## 2. Inject it from the harness

- [x] 2.1 Add `install_hook` to `tests/harness/lib.sh`: one Eval that imports the hook by absolute
      path and calls `init()`, then waits for the object path to answer, failing the session if it
      never does. Verify by asserting the path is absent before the call and present after
- [x] 2.2 Call `install_hook` from `start_session` after the readiness wait, drop
      `export MAGUNETTO_TEST=1` from `run.sh`, and verify a named case still passes
- [x] 2.3 Verify the promise-swallows-errors failure mode is caught: point `install_hook` at a
      missing file and confirm the session fails with a clear message rather than every case failing
      individually

## 3. The virtual-machine tier

- [x] 3.1 Add a wrapper that injects the hook, drop `MAGUNETTO_TEST=1` from the shell service
      environment in `tests/nixos-test.nix`, and inject after `mg-ready`
- [x] 3.2 Run `git add` on every new file, then `tests/run-all.sh --vm`, and confirm the VM tier
      still snaps to the right half. The flake source is the git tree, so an untracked hook is
      absent from the VM

## 4. Guard the duplication

- [x] 4.1 Add a harness case asserting a non-zero ghost count during a travel, so that renaming the
      snapshot actor fails the suite instead of silently making every ghost assertion vacuous, and
      verify it fails when `SNAPSHOT_NAME` is deliberately mismatched

## 5. Documentation

- [x] 5.1 Update the layout tables in `README.md` and `AGENTS.md`: `lib/testInterface.js` is gone,
      `harness/shellhook.js` is new, and verify no path named in either file is missing
- [x] 5.2 Add to the Traps section of `AGENTS.md`: an injected module resolves relative imports
      against its own directory, so a hook cannot import from the extension
- [x] 5.3 Add to the Traps section of `AGENTS.md`: `gdbus` parses an Eval argument as GVariant text
      first, so an expression that both starts and ends with a double quote loses its quotes before
      reaching JavaScript
- [x] 5.4 Add to the Traps section of `AGENTS.md`: `Meta.is_wayland_compositor` was removed in GNOME
      50, alongside the existing removals
- [x] 5.5 Record in `AGENTS.md` that `gnome-shell-test-tool --extension` exists since GNOME 50.alpha
      and handles the throwaway home and keyfile backend itself, as the direction this harness should
      eventually take

## 6. Finishing

- [x] 6.1 Run `tests/run-all.sh --vm` and confirm all three tiers pass
- [x] 6.2 Confirm the built artefacts carry no test surface: build with `packaging/build.sh` and
      verify no package contains `testInterface.js` and that the extension exports nothing at
      `/dev/matteopacini/Magunetto/Test` in a session where the harness has not injected the hook
