## 1. Prove the bug before fixing it

- [x] 1.1 Add `tests/harness/cases/cross-monitor.sh` with `CASE_MONITORS="1280x800,1280x800"`: open a
      window on monitor 0, warp the pointer onto monitor 1, run the gesture, and assert the window's
      frame lands inside monitor 1's work area. Read that work area by explicit index with
      `eval_value 'String(global.workspace_manager.get_active_workspace().get_work_area_for_monitor(1).x)'`
      — not via `work_area_field`, which derives from the target window's monitor and so holds both
      before and after the fix. Verify by running
      `dbus-run-session -- tests/harness/run.sh cross-monitor` and confirming it **fails** on the
      unfixed tree, with the window still on monitor 0.
- [x] 1.2 Add `tests/harness/cases/cross-monitor-latch.sh` with the same `CASE_MONITORS` so it shares
      the session: place window and pointer on monitor 1, begin the gesture, flick left far enough to
      carry the pointer across the seam onto monitor 0, and assert the window occupies monitor 1's
      left half. Verify it **passes** on the unfixed tree — it guards the fix, so it must not be
      satisfied by the bug.

## 2. Choose the monitor from the pointer

- [x] 2.1 In `magunetto@matteopacini.me/extension.js` `_onTrigger`, read the pointer once with
      `global.get_pointer()`, resolve it with `Main.layoutManager.findMonitorForPoint(x, y)`, and hold
      the resulting index on the gesture, falling back to `target.get_monitor()` when the lookup
      answers `null`. Pass it as the menu's `monitorIndex`. Verify `dbus-run-session --
      tests/harness/run.sh multi-monitor cross-monitor` shows the menu on the pointer's monitor and
      `cross-monitor` still fails only on its geometry assertion.
- [x] 2.2 In `magunetto@matteopacini.me/lib/snap.js`, change `workAreaFor` to take a monitor index
      instead of a window, and add the index as a parameter of `snap()`. Do not read
      `window.get_monitor()` anywhere in the snap path. Verify `node --test tests/*.test.js` still
      passes — `geometry.js` is untouched, so any failure there means the change leaked.
- [x] 2.3 Pass the held monitor index from `extension.js` `_onFinish` into `snap()`. Verify
      `dbus-run-session -- tests/harness/run.sh cross-monitor cross-monitor-latch` — both now pass.
- [x] 2.4 Confirm `lib/radialMenu.js`, `lib/geometry.js` and `lib/animate.js` are untouched by this
      change. Verify with `git diff --stat` naming only `extension.js` and `lib/snap.js` under
      `magunetto@matteopacini.me/`.

## 3. Bring the existing case into line

- [x] 3.1 Update the header comment of `tests/harness/cases/multi-monitor.sh` — its assertions stay
      valid because it places pointer and window on the same monitor, but "The menu follows the
      window's monitor" is now the wrong reason for them. State that pointer and window agree here,
      and that the cross-monitor cases cover the case where they do not. Verify
      `dbus-run-session -- tests/harness/run.sh multi-monitor` still passes unchanged.
- [x] 3.2 Add a case, or extend `cross-monitor.sh`, covering the maximised scenario in the
      `window-snap` delta: maximise a window on monitor 0, gesture from monitor 1, assert the window
      is no longer maximised and occupies the selected region of monitor 1. Verify by running that
      case.

## 4. Verify the whole tree

- [x] 4.1 Run `node --test tests/*.test.js` and confirm every unit test passes.
- [x] 4.2 Run `dbus-run-session -- tests/harness/run.sh` and confirm the full harness passes,
      including every pre-existing single-monitor case — none of them should have changed behaviour.
- [x] 4.3 `git add` the new case files, then run `tests/run-all.sh --vm` and confirm all three tiers
      pass. The `git add` is not optional: `nix build` takes the flake's source from the git tree, so
      an untracked case is absent from the derivation.

## 5. Record what cost time to find

- [x] 5.1 Add to `AGENTS.md` Traps, stated as standing constraints rather than as history: a modal
      grab receives motion for the whole stage regardless of the grab actor's allocation (the shell's
      own `dnd.js` grabs a 0×0 actor for a whole-desktop drag), and `event.get_coords()` is in stage
      coordinates spanning every monitor; the pointer passes straight through the seam between
      abutting monitors and pins only at the outer edge of their union, so a clamp written for a
      screen edge does not apply at a seam; and `work_area_field` reports the *target window's*
      monitor, so a multi-monitor assertion built on it can hold both before and after a fix. Verify
      by re-reading each entry against the code as it then stands.
