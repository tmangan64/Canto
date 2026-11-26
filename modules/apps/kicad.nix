{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.kicad;

  # with3d and addons only change the wrapper script that sits in front of
  # kicad-base, so both are cheap to flip - the compiled suite stays on the same
  # store path and keeps coming from the binary cache. The remaining upstream
  # flags (withNgspice, withScripting, withI18n) are cmake arguments to
  # kicad-base, so they are left alone on purpose: turning any of them off
  # means an hours-long local build of KiCad itself.
  kicad = pkgs.kicad.override {
    inherit (cfg) with3d addons;
  };
in
{
  options.blackwall.kicad = {
    enable = mkEnableOption "KiCad, an electronics design automation suite";

    with3d = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install the packages3d library, which is where the 3D viewer and STEP
        export get their component bodies from. It is the largest library in the
        set at roughly 440MB. Without it footprints keep their model references
        and the rest of the suite is unaffected - the viewer just renders a bare
        board.
      '';
    };

    addons = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "with pkgs.kicadAddons; [ kikit kikit-library ]";
      description = ''
        Plugins to register with KiCad, taken from pkgs.kicadAddons. These are
        passed through the package's own addons argument rather than installed
        from the in-app Plugin and Content Manager, which unpacks into
        ~/.local/share/kicad and would put them outside the flake.
      '';
    };
  };

  config = mkIf cfg.enable {
    # wxWidgets on GTK3, so the window chrome follows the GNOME theme, fonts and
    # prefer-dark setting without needing blackwall.qt. The schematic and board
    # canvases are separate: those draw from KiCad's own colour themes, chosen
    # per editor under Preferences, and ignore the desktop setting entirely.
    environment.systemPackages = [ kicad ];
  };
}
