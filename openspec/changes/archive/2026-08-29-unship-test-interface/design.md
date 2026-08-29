## Context

See `proposal.md` — Why.

Everything below was established against GNOME Shell 50.4 by probe, not from documentation.

The harness cannot drive the gesture from outside the compositor: it must hold a modifier down while
moving the pointer, and no external tool can do that on Wayland. Something inside the shell has to
synthesise the input. The question is only where that something lives and how it gets there.

## Goals / Non-Goals

**Goals:**

- The shipped extension contains no surface that can inject input.
- The harness keeps its bus name, object path, method names and semantics, so the 31 existing cases
  do not change.
- Nothing a user can observe changes.

**Non-Goals:**

- Changing how tests are written. Cases stay bash with the same helpers.
- Rewriting the harness onto `gnome-shell-test-tool` (see Open Questions).
- Any new gate on the extension. After this there is nothing left to gate.

## Decisions

### Inject the hook rather than gate it harder

The hook moves to `tests/harness/shellhook.js` and is loaded into the running shell by the harness:

```
Eval("import('file:///…/shellhook.js').then(m => m.init())")
```

`init()` finds the extension through `Main.extensionManager.lookup(uuid).stateObj` and constructs the
interface around it, so the extension neither knows nor cooperates.

Verified end to end with the gate shut and nothing test-related shipped: the object path is absent
before injection, present after, and a full gesture drives through it — correct state log, frame
`640 32 640 768` against work area `0 32 1280 768`, no leftover snapshots, zero shell errors.

*Alternative — harden the gate in place.* Rejected because it cannot work where it matters. Property
getters under `wrapJSObject` never see the invocation, so `Log` cannot be sender-checked; the shell's
`DBusSenderChecker` short-circuits under unsafe mode, which every tier sets; and polkit authenticates
the user, not the program, while gnome-shell is itself the polkit agent. The strongest gate available
— `global.backend.is_headless()`, which has no setter and is fixed at startup — would still be three
gates guarding something that need not exist.

*Alternative — replace the interface with Eval calls against a `global.mg` object.* This also works,
and was proven. Rejected only because it rewrites every `mg_*` helper and the VM tier's wrappers for
no additional security: both approaches ship nothing, and both depend on Eval.

*Alternative — a peer-to-peer `Gio.DBusServer` socket in `XDG_RUNTIME_DIR` at 0600.* The only option
that is a real boundary against a sandboxed same-user caller. Rejected here because it protects a
surface this change removes, and because `gdbus` cannot address a peer-to-peer connection at all —
it always sends the bus `Hello` first — so every client call in the harness would become a bespoke
gjs script.

### The hook carries its own constants

An injected module resolves relative imports against its own directory, so `shellhook.js` cannot
`import './animate.js'`. `SNAPSHOT_NAME` is duplicated into the hook rather than imported.

This is a real duplication and it can drift: rename the snapshot actor and the ghost count silently
reads zero, which would make `animate-*` cases pass while asserting nothing. A case asserts a
non-zero ghost count during a travel so the duplication cannot rot unnoticed.

The alternative, importing from the extension by absolute `file://` URL, was rejected: it would make
the hook depend on where the extension is installed, which differs between the harness symlink and
the VM's system path.

### Injection happens once per session, not per case

`start_session` injects after the readiness wait, alongside the existing overview-hiding step. Cases
see the interface already present, exactly as they do today.

The VM tier injects through the same wrapper-script mechanism it already uses for quoting, after the
extension reports ACTIVE — not merely after the shell is ready. `init()` resolves the extension
through the extension manager, so an injection that beat the extension's own load would find nothing
to hook and fail the session.

The wrappers are baked with their JavaScript already inside, and both `evalScript` and `runAs` wrap
what they are given in single quotes, so the injected code uses only double quotes.

## Risks / Trade-offs

- **The extension's accessors become an undeclared interface.** `log`, `clearLog`, `targetWindow`,
  `isOverlayUp`, `isGrabHeld` exist only for the hook, and nothing in the extension enforces their
  shape any more. → They are already exercised by every case through the hook, so a change that
  breaks them fails the suite immediately.
- **`extensionManager.lookup().stateObj` is a shell internal.** → It is what ddterm uses for the same
  purpose, and the harness already depends on comparable internals.
- **A stale hook could be injected against a mismatched extension.** → `init()` throws if the lookup
  returns nothing, which fails the session rather than the case.
- **Injection adds a step that can fail silently.** A promise fired into Eval reports nothing: the
  first attempt at this failed with an unresolved import and looked like success. → The harness waits
  for the object path to answer and fails the session if it does not appear.

## Open Questions

`gnome-shell-test-tool` gained `--extension` in GNOME 50.alpha. It runs an automation script
in-process, needing neither Eval nor unsafe mode, and sets up a throwaway `XDG_*_HOME` with
`GSETTINGS_BACKEND=keyfile` on its own — two of this project's documented traps, solved upstream.

It is the better long-term shape and it is deliberately not adopted here: it would mean rewriting the
harness from bash and D-Bus into in-process JavaScript, which is a much larger change than removing a
file from the shipped artefact. Recording it so the next person does not have to rediscover it.
