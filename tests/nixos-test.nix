# Merge-gate test: a real GNOME session in a virtual machine, rather than the
# bare headless shell the development loop uses.
#
# The driver's own key-sending primitive presses and releases a key atomically,
# so it cannot hold a modifier while moving the pointer. The gesture is therefore
# driven from inside the shell even here, through the harness's control surface —
# which the shell is asked to import, and which the extension does not ship.
{ pkgs, magunetto }:
let
  uuid = magunetto.passthru.extensionUuid;

  # A user bus only accepts connections from its own user, so every call has to
  # run as alice. These wrappers keep that to a single level of quoting in the
  # test script: arguments below may contain double quotes, never single ones.
  session = ''
    export XDG_RUNTIME_DIR=/run/user/1000
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
    export WAYLAND_DISPLAY=wayland-0
    export GDK_BACKEND=wayland
  '';

  # Each query gets its own wrapper with the JavaScript baked in, so the test
  # script never has to pass parentheses or quotes through "su -c".
  evalScript =
    name: js:
    pkgs.writeShellScriptBin name ''
      ${session}
      exec gdbus call --session -d org.gnome.Shell -o /org/gnome/Shell \
          -m org.gnome.Shell.Eval '${js}'
    '';

  # Eval answers "(true, '<json>')" on success and "(false, '')" when it is
  # refused, so a check must match the quoted value. Matching a bare word would
  # accept a refusal that happens to contain the same letters.
  evalExpect =
    name: js: expected:
    pkgs.writeShellScriptBin name ''
      ${session}
      gdbus call --session -d org.gnome.Shell -o /org/gnome/Shell -m org.gnome.Shell.Eval '${js}' | grep -q '"${expected}"'
    '';

  mgReady = evalExpect "mg-ready" "String(Main.layoutManager._startingUp)" "false";
  mgHasFocus = evalExpect "mg-hasfocus" "String(!!global.display.get_focus_window())" "true";
  mgNormalMode = evalExpect "mg-normalmode" "String(Main.actionMode)" "1";
  mgHasWindow = evalExpect "mg-haswindow" "String(global.get_window_actors().length>0)" "true";
  mgHideOverview = evalScript "mg-hideoverview" "Main.overview.hide();String(1)";
  mgWindowCount = evalScript "mg-windowcount" "String(global.get_window_actors().length)";
  # Synthetic input counts as user activity, so a window mapping afterwards can
  # lose the focus-stealing race and open unfocused.
  mgActivate = evalScript "mg-activate" "global.get_window_actors().at(-1).meta_window.activate(global.get_current_time());String(1)";

  # The control surface is not part of the extension; the shell imports it from
  # the store when the test asks. Single quotes would end the shell quoting that
  # evalScript and runAs both apply, so the injected code uses only double ones.
  hookFile = ./harness/shellhook.js;

  mgInstallHook = evalScript "mg-installhook" ''
    globalThis.magunettoHookResult = "pending";
    import("file://${hookFile}")
        .then(m => { globalThis.magunettoHookResult = String(m.init()); })
        .catch(e => { globalThis.magunettoHookResult = "failed: " + e; });
    String(1)
  '';

  # An import failure resolves the promise rather than throwing, so the request
  # answers successfully either way. Only this tells the two apart.
  mgHookReady = evalExpect "mg-hookready" "String(globalThis.magunettoHookResult)" "hooked";

  mgHook = pkgs.writeShellScriptBin "mg-hook" ''
    ${session}
    method=$1; shift
    exec gdbus call --session -d org.gnome.Shell \
        -o /dev/matteopacini/Magunetto/Test \
        -m "dev.matteopacini.Magunetto.Test.$method" -- "$@"
  '';

  mgShell = pkgs.writeShellScriptBin "mg-shell" ''
    ${session}
    exec "$@"
  '';

  runAs = command: "su alice --shell=/bin/sh -c '${command}'";
  hook = method: args: runAs "mg-hook ${method} ${args}";
in
pkgs.testers.nixosTest {
  name = "magunetto";

  nodes.machine =
    { ... }:
    {
      imports = [ (pkgs.path + "/nixos/tests/common/user-account.nix") ];

      services.xserver.enable = true;
      services.displayManager.gdm.enable = true;
      services.displayManager.autoLogin = {
        enable = true;
        user = "alice";
      };
      services.desktopManager.gnome.enable = true;

      environment.systemPackages = [
        magunetto
        pkgs.glib
        pkgs.gnome-calculator
        mgHook
        mgShell
        mgReady
        mgHasFocus
        mgNormalMode
        mgHasWindow
        mgHideOverview
        mgWindowCount
        mgActivate
        mgInstallHook
        mgHookReady
      ];

      # Eval is how the test reads shell state and how it loads the control
      # surface, and it is refused unless the shell was started in unsafe mode.
      # The template unit is what gets instantiated; overriding the instance name
      # produces a unit file that is never used.
      systemd.user.services."org.gnome.Shell@".serviceConfig = {
        ExecStart = [
          ""
          "${pkgs.gnome-shell}/bin/gnome-shell --unsafe-mode"
        ];
      };

      virtualisation.memorySize = 2048;
      virtualisation.cores = 2;
    };

  testScript = ''
    import re

    def numbers(text):
        return [int(n) for n in re.findall(r"-?\d+", text)]

    machine.wait_for_unit("display-manager.service")
    machine.wait_for_file("/run/user/1000/wayland-0")
    machine.wait_for_unit("default.target", "alice")
    machine.wait_until_succeeds("${runAs "mg-ready"}")

    machine.succeed("${runAs "mg-shell gnome-extensions enable ${uuid}"}")
    machine.wait_until_succeeds(
        "${runAs "mg-shell gnome-extensions info ${uuid}"} | grep -q ACTIVE"
    )

    # init() resolves the extension through the extension manager, so this can
    # only run once the extension is loaded.
    machine.succeed("${runAs "mg-installhook"}")
    machine.wait_until_succeeds("${runAs "mg-hookready"}")

    machine.execute("${runAs "nohup mg-shell gnome-calculator >/tmp/calc.log 2>&1 &"}")
    machine.sleep(15)
    print("calculator output:", machine.execute("cat /tmp/calc.log")[1])
    print("window count:", machine.execute("${runAs "mg-windowcount"}")[1])
    machine.wait_until_succeeds("${runAs "mg-haswindow"}")

    # The session starts in the overview, which holds a modal grab and keeps a
    # window that maps afterwards from taking focus.
    machine.succeed("${runAs "mg-hideoverview"}")
    machine.succeed("${runAs "mg-activate"}")
    machine.wait_until_succeeds("${runAs "mg-hasfocus"}")
    machine.wait_until_succeeds("${runAs "mg-normalmode"}")

    # Hold Alt, tap Z, flick right, release: the gesture, driven from inside the
    # shell because the driver cannot hold a modifier while moving the pointer.
    # The first warp after the virtual device is created drops a coordinate.
    machine.succeed("${hook "Warp" "640.0 400.0"}")
    machine.succeed("${hook "Warp" "640.0 400.0"}")
    machine.succeed("${hook "Key" "65513 true"}")   # Alt_L down
    machine.succeed("${hook "Key" "122 true"}")     # z down
    machine.succeed("${hook "Key" "122 false"}")    # z up
    machine.succeed("${hook "Move" "300.0 0.0"}")
    machine.succeed("${hook "Key" "65513 false"}")  # Alt_L up commits

    machine.wait_until_succeeds(
        "${runAs "mg-shell gdbus call --session -d org.gnome.Shell -o /dev/matteopacini/Magunetto/Test -m org.freedesktop.DBus.Properties.Get dev.matteopacini.Magunetto.Test Log"} | grep -q snapped"
    )

    frame = numbers(machine.succeed("${hook "TargetFrame" ""}"))
    area = numbers(machine.succeed("${hook "WorkArea" ""}"))
    print("frame:", frame, "work area:", area)

    expected = area[0] + area[2] // 2
    assert frame[0] == expected, "expected right half origin " + str(expected) + ", got " + str(frame[0])

    machine.screenshot("snapped")
  '';
}
