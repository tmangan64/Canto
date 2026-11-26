{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.devenv;
in
{
  options.blackwall.devenv = {
    enable = mkEnableOption "devenv.sh per-project development environments";

    direnv = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install direnv with nix-direnv, so a project's devenv shell is entered
        automatically on cd. Needs a logout/login before the shell hook loads.
      '';
    };

    trustedUsers = mkOption {
      type = types.listOf types.str;
      default = [ "@wheel" ];
      description = ''
        Users allowed to pass their own settings to the nix daemon. devenv
        specifies `system` per invocation, which an untrusted user may not do -
        the daemon drops the setting and devenv fails to resolve the shell
        derivation.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.devenv
      pkgs.git # devenv resolves the project root from the git repository
    ];

    # direnv's fish/bash hooks are wired up by this module
    programs.direnv = mkIf cfg.direnv {
      enable = true;
      nix-direnv.enable = true;
    };

    nix.settings = {
      # devenv builds its own derivations, so it needs the flakes CLI
      experimental-features = [ "nix-command" "flakes" ];

      # merged with the NixOS default, which already trusts root
      trusted-users = cfg.trustedUsers;

      # prebuilt devenv closures, rather than compiling them here
      substituters = [ "https://devenv.cachix.org" ];
      trusted-public-keys = [
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      ];
    };
  };
}
