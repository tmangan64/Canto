{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.qt;
in
{
  options.blackwall.qt = {
    enable = mkEnableOption "Adwaita theming for Qt applications";

    style = mkOption {
      type = types.enum [
        "adwaita"
        "adwaita-dark"
        "adwaita-highcontrast"
        "adwaita-highcontrastinverse"
      ];
      default = "adwaita-dark";
      description = ''
        Which adwaita-qt style Qt applications use. QT_STYLE_OVERRIDE is a
        fixed value, so this does not follow the GNOME light/dark switch -
        it has to match org/gnome/desktop/interface color-scheme by hand.
      '';
    };
  };

  config = mkIf cfg.enable {
    # adwaita-qt draws the widgets; qgnomeplatform feeds Qt the GNOME fonts,
    # icon theme, cursor and dialog behaviour read from dconf. Both the Qt5
    # and Qt6 builds are installed, so PyQt5 apps and Qt6 apps match.
    qt = {
      enable = true;
      platformTheme = "gnome";
      style = cfg.style;
    };
  };
}
