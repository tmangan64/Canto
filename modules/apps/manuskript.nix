{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.manuskript;

  # Courtesy of Claude Opus
  # The nixpkgs build copies Manuskript's source tree wholesale, so its launcher
  # lands in $out/resources and its icons in $out/icons - neither of which any
  # desktop environment looks at, which is why GNOME shows no entry at all.
  # Upstream's own .desktop file and icons are reused here, moved to the paths
  # XDG searches, with Exec made absolute so the entry does not depend on the
  # session's PATH and StartupWMClass added so the running window keeps the icon
  # instead of showing up as a second, unnamed one.
  manuskript = pkgs.runCommand "manuskript-desktop-entry-${pkgs.manuskript.version}"
    { inherit (pkgs.manuskript) meta; } ''
    mkdir -p $out/share/applications
    ln -s ${pkgs.manuskript}/bin $out/bin
    ln -s ${pkgs.manuskript}/share/manuskript $out/share/manuskript

    sed -E "s|^(Try)?Exec=manuskript\$|\1Exec=${pkgs.manuskript}/bin/manuskript|" \
      ${pkgs.manuskript}/resources/ch.theologeek.Manuskript.desktop \
      > $out/share/applications/ch.theologeek.Manuskript.desktop
    echo "StartupWMClass=manuskript" \
      >> $out/share/applications/ch.theologeek.Manuskript.desktop

    # Icon= names the desktop entry's ID, not the upstream file names
    mkdir -p $out/share/icons/hicolor/scalable/apps
    ln -s ${pkgs.manuskript}/icons/Manuskript/manuskript.svg \
      $out/share/icons/hicolor/scalable/apps/ch.theologeek.Manuskript.svg
    for px in 16 32 64 128 256 512; do
      mkdir -p $out/share/icons/hicolor/"$px"x"$px"/apps
      ln -s ${pkgs.manuskript}/icons/Manuskript/icon-"$px"px.png \
        $out/share/icons/hicolor/"$px"x"$px"/apps/ch.theologeek.Manuskript.png
    done
  '';
in
{
  options.blackwall.manuskript = {
    enable = mkEnableOption "Manuskript, an open source writing tool";
  };

  config = mkIf cfg.enable {
    # Manuskript is a PyQt5 app, so it has no theme of its own - it renders
    # with whatever Qt style the session provides.
    assertions = [{
      assertion = config.blackwall.qt.enable;
      message = ''
        blackwall.manuskript needs blackwall.qt.enable = true, otherwise
        Manuskript falls back to the default Qt widget style instead of Adwaita.
      '';
    }];

    environment.systemPackages = [ manuskript ];
  };
}
