{
  lib,
  stdenvNoCC,
  gettext,
  glib,
}:
let
  uuid = "magunetto@matteopacini.me";

  # The catalogues sit outside the extension directory, so that neither their
  # sources nor the tooling beside them can reach an installed tree. Taking them
  # as a second path keeps this derivation's source narrow: a change under tests/
  # still does not rebuild the package.
  po = builtins.path {
    path = ./po;
    name = "magunetto-po";
  };
in
stdenvNoCC.mkDerivation {
  pname = "gnome-shell-extension-magunetto";
  version = "0.4.1";

  # The directory is named after the UUID, whose "@" is not allowed in a store
  # path name, so the source is given an explicit name.
  src = builtins.path {
    path = ./. + "/${uuid}";
    name = "magunetto-source";
  };

  nativeBuildInputs = [
    gettext
    glib
  ];

  # initTranslations() binds to the extension's own locale/ when it exists, so
  # the catalogues are compiled into the tree rather than into the store's
  # share/locale. That is one layout for the zip, this package, and the three
  # distro packages alike.
  buildPhase = ''
    runHook preBuild
    glib-compile-schemas --strict schemas
    while read -r locale; do
        install -d "locale/$locale/LC_MESSAGES"
        msgfmt --check --output-file="locale/$locale/LC_MESSAGES/${uuid}.mo" \
            "${po}/$locale.po"
    done < <(grep -vE '^[[:space:]]*(#|$)' "${po}/LINGUAS")
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
