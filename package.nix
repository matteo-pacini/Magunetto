{
  lib,
  stdenvNoCC,
  glib,
}:
let
  uuid = "magunetto@matteopacini.me";
in
stdenvNoCC.mkDerivation {
  pname = "gnome-shell-extension-magunetto";
  version = "0.1.0";

  # The directory is named after the UUID, whose "@" is not allowed in a store
  # path name, so the source is given an explicit name.
  src = builtins.path {
    path = ./. + "/${uuid}";
    name = "magunetto-source";
  };

  nativeBuildInputs = [ glib ];

  buildPhase = ''
    runHook preBuild
    glib-compile-schemas --strict schemas
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/gnome-shell/extensions
    cp -r -T . $out/share/gnome-shell/extensions/${uuid}
    runHook postInstall
  '';

  passthru.extensionUuid = uuid;

  meta = {
    description = "Radial window snapper for GNOME Shell";
    longDescription = ''
      Hold a shortcut to raise a radial menu, flick the pointer toward a
      direction, and release to snap the focused window to that region of the
      screen. Targets GNOME Shell 50 only.
    '';
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
