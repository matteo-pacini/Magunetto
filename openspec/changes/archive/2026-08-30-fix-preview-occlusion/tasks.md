## 1. Prove it before fixing it

- [x] 1.1 Add `tests/harness/cases/preview-occlusion.sh`: snap a window to the right half, begin a
      second gesture and select the bottom-right quarter — a region wholly inside where the window
      now sits — then assert the preview's index in `global.window_group.get_children()` is above the
      target window actor's. Do not assert a rectangle; every existing preview case does that and all
      of them passed while the feature was invisible. Verify it **fails** on the unfixed tree.

## 2. Raise the outline

- [x] 2.1 In `magunetto@matteopacini.me/extension.js` `_onSelect`, call
      `global.window_group.set_child_above_sibling(this._preview, null)` immediately after each
      `open()`, with a comment saying why it is after each one rather than once: `open()` lowers the
      widget below the window actor every time it runs. Verify
      `dbus-run-session -- tests/harness/run.sh preview-occlusion` now passes.
- [x] 2.2 Verify the four existing preview cases still pass —
      `dbus-run-session -- tests/harness/run.sh preview preview-off preview-disabled preview-desktop-off`
      — and in particular that `preview-disabled.sh` still finds the widget gone after `disable()`,
      since raising changes the child order it counts.

## 3. Regenerate the demo

- [x] 3.1 Record with `dbus-run-session -- tests/harness/run.sh _demo`. Check the recording's last
      packet timestamp against the wall clock the case takes before encoding — a clip that claims
      half its real duration is the failure this repo has already had once.
- [x] 3.2 Encode with `tests/harness/demo-encode.sh`, then extract a frame from a gesture where the
      window is already filling a half and confirm the outline is visible over it. The first gesture
      of the tour is not evidence: the window is small and centred there, which is the one case that
      worked before this change.
- [x] 3.3 Confirm `assets/demo.gif` and `assets/demo.mp4` are the regenerated pair and that the gif
      is still a size the README can carry.

## 4. Verify the whole tree

- [x] 4.1 Run `node --test tests/*.test.js` and confirm every unit test passes.
- [x] 4.2 Run `dbus-run-session -- tests/harness/run.sh` and confirm the full harness passes.
- [x] 4.3 `git add` the new case file, then run `tests/run-all.sh --vm` and confirm all three tiers
      pass. The `git add` is not optional: `nix build` takes the flake's source from the git tree.
- [x] 4.4 Update the harness case count in `AGENTS.md`'s loop section from a fresh
      `ls tests/harness/cases/ | grep -vc '^_'` rather than adding to the number written there.

## 5. Record what cost time to find

- [x] 5.1 Add to `AGENTS.md` Traps, as a standing constraint: `TilePreview.open()` lowers itself
      below the window actor on every call, which suits the shell dragging a window elsewhere and
      hides the outline for a gesture that leaves the window where it is; anything reusing it for a
      stationary window has to raise it after each `open()`. Note alongside it that a rectangle
      assertion cannot see occlusion, so a widget's position in the stacking order needs asserting
      separately.
