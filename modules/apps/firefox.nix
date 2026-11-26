{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.firefox;
  theme = pkgs.firefox-gnome-theme;

  # Firefox takes a dropdown's background from the page's own CSS but the item
  # text colour from the colour scheme, so a page that hardcodes a white
  # background under a dark scheme renders white text on white - an <option>
  # list you have to guess your way through. Pinning both halves to the same
  # system colours keeps them readable without forcing every site light: on a
  # page Firefox treats as light these resolve to black on white, on a page
  # that opts into dark they resolve to light on dark. A user-origin
  # !important outranks an author !important, which is what makes this stick
  # on the sites that set only one half.
  dropdownContrastCss = ''
    select,
    select option,
    select optgroup {
      background-color: Field !important;
      color: FieldText !important;
    }

    select option:checked {
      background-color: SelectedItem !important;
      color: SelectedItemText !important;
    }
  '';
in
{
  options.blackwall.firefox = {
    enable = mkEnableOption "Firefox with the Adwaita (GNOME) theme";
  };

  config = mkIf cfg.enable {
    programs.firefox = {
      enable = true;

      # Set as defaults, not locked, so anything changed in about:config sticks.
      preferences = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "svg.context-properties.content.enabled" = true;
        "browser.theme.dark-private-windows" = false;
        "widget.gtk.rounded-bottom-corners.enabled" = true;
        "browser.uidensity" = 0;
      };
      preferencesStatus = "default";
    };

    # Default browser
    xdg.mime.defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
    };
    environment.sessionVariables.DEFAULT_BROWSER = "${config.programs.firefox.finalPackage}/bin/firefox";

    # Firefox only reads userChrome.css from inside a profile directory, so the
    # theme has to be linked into each one. Runs per user on switch and login.
    system.userActivationScripts.firefox-gnome-theme.text = ''
      profileDir="$HOME/.mozilla/firefox"

      # Firefox only creates a profile on its first launch, which happens after
      # this script has already run - so the first session would be unthemed and
      # the theme would not appear until the next rebuild or login. Seed a
      # profile up front so there is always something to link the theme into.
      if [ -z "$(find "$profileDir" -maxdepth 1 -mindepth 1 -name '*.*' -type d -print -quit 2>/dev/null)" ]; then
        mkdir -p "$profileDir/default.default"
        printf '%s\n' \
          '[General]' \
          'StartWithLastProfile=1' \
          'Version=2' \
          "" \
          '[Profile0]' \
          'Name=default' \
          'IsRelative=1' \
          'Path=default.default' \
          'Default=1' \
          > "$profileDir/profiles.ini"
      fi

      for profile in "$profileDir"/*.*/; do
        [ -d "$profile" ] || continue

        rm -rf "$profile/chrome/firefox-gnome-theme"
        mkdir -p "$profile/chrome"
        ln -sfn ${theme}/share/firefox-gnome-theme "$profile/chrome/firefox-gnome-theme"

        echo '@import "firefox-gnome-theme/userChrome.css";' > "$profile/chrome/userChrome.css"

        # @import has to come before any rule of our own, so the theme is
        # pulled in first and the overrides below it.
        cat > "$profile/chrome/userContent.css" <<'USERCONTENT'
@import "firefox-gnome-theme/userContent.css";

${dropdownContrastCss}
USERCONTENT
      done
    '';
  };
}
