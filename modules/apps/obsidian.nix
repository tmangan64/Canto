{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.obsidian;

  # birneee/obsidian-adwaita-theme has no tags or releases, so it is pinned to
  # a commit. Version is the manifest.json version plus that commit's date.
  theme = pkgs.stdenvNoCC.mkDerivation {
    pname = "obsidian-adwaita-theme";
    version = "0.5.0-unstable-2025-09-25";

    src = pkgs.fetchFromGitHub {
      owner = "birneee";
      repo = "obsidian-adwaita-theme";
      rev = "75efcbbd6a89abc04265b467997fb60638de9157";
      hash = "sha256-snjCfPNMUhfHxD+4WGSSvHnvoMhRS03KxOmZwYULMTM=";
    };

    dontBuild = true;

    # The directory name has to match manifest.json's "name" - that is the
    # string Obsidian looks up when appearance.json asks for a theme.
    installPhase = ''
      runHook preInstall
      install -Dm644 theme.css manifest.json -t $out/share/obsidian/themes/Adwaita
      runHook postInstall
    '';

    meta = {
      description = "Obsidian theme in the style of the GNOME Adwaita design";
      homepage = "https://github.com/birneee/obsidian-adwaita-theme";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  };
in
{
  options.blackwall.obsidian = {
    enable = mkEnableOption "Obsidian with the Adwaita (GNOME) theme";

    vaults = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "$HOME/Notes" ];
      description = ''
        Extra vault directories to install the theme into, on top of the ones
        Obsidian has already opened. Expanded by the shell, so $HOME works.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      obsidian
    ];

    # Obsidian themes live inside a vault rather than in a shared directory,
    # and vaults are ordinary folders anywhere on disk, so the theme has to be
    # copied into each one. Obsidian's own list of vaults is the only record of
    # where they are. Runs per user on switch and login.
    system.userActivationScripts.obsidian-adwaita-theme.text = ''
      PATH=${makeBinPath [ pkgs.jq pkgs.coreutils ]}:$PATH

      known=$(jq -r '.vaults[]?.path // empty' \
        "''${XDG_CONFIG_HOME:-$HOME/.config}/obsidian/obsidian.json" 2>/dev/null || true)

      for vault in $known ${escapeShellArgs cfg.vaults}; do
        [ -d "$vault" ] || continue

        # Copied, not symlinked: Obsidian writes into the themes directory when
        # it checks a theme for updates, and the store path is read-only.
        rm -rf "$vault/.obsidian/themes/Adwaita"
        mkdir -p "$vault/.obsidian/themes"
        cp -rT ${theme}/share/obsidian/themes/Adwaita "$vault/.obsidian/themes/Adwaita"
        chmod -R u+w "$vault/.obsidian/themes/Adwaita"

        # Select it only when nothing is selected yet, so a theme picked later
        # in Appearance settings is not reset on the next rebuild.
        appearance="$vault/.obsidian/appearance.json"
        if [ ! -e "$appearance" ]; then
          echo '{"cssTheme":"Adwaita"}' > "$appearance"
        elif [ -z "$(jq -r '.cssTheme // ""' "$appearance" 2>/dev/null)" ]; then
          tmp=$(mktemp)
          if jq '.cssTheme = "Adwaita"' "$appearance" > "$tmp"; then
            mv "$tmp" "$appearance"
          else
            rm -f "$tmp"
          fi
        fi
      done
    '';
  };
}
