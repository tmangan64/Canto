{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.vscode;
in
{
  options.blackwall.vscode = {
    enable = mkEnableOption "Visual Studio Code";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.vscode-with-extensions.override {
        vscodeExtensions = (with pkgs.vscode-extensions; [
          bbenoist.nix              # Nix language support
          piousdeer.adwaita-theme   # Adwaita theme
        ])
        # markdown-table-prettify is not packaged in nixpkgs, so it is fetched
        # from the marketplace by hand. Version and hash move together - after
        # bumping the version, nix-prefetch-url the vsix URL built in
        # pkgs/applications/editors/vscode/extensions/mktplcExtRefToFetchArgs.nix
        # to get the new hash.
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            publisher = "darkriszty";
            name = "markdown-table-prettify";
            version = "4.1.0";
            hash = "sha256-i9lOJC492I0IuQwADwvZKFqODJi7E9j5P+wxFaqXk70=";
          }
        ];
      })
    ];

    # writes /etc/gitconfig - `config` is the NixOS option, and it takes
    # gitconfig's own section.key layout rather than home-manager's names
    programs.git = {
      enable = true;
      config.user = {
        name = "tmangan64";
        email = "teague.mangan@icloud.com";
      };
    };
  };
}
