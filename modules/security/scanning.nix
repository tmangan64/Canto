{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.scanning;

  templatesDir = "${pkgs.nuclei-templates}/share/nuclei-templates";
in
{
  options.blackwall.scanning = {
    enable = mkEnableOption "network and web vulnerability scanning tools";

    nmap = mkOption {
      type = types.bool;
      default = true;
      description = "Install nmap.";
    };

    nmapRawSockets = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install a setcap wrapper so nmap can open raw sockets without sudo -
        needed for SYN (-sS), UDP (-sU) and OS detection (-O) scans.

        Off by default: the capability is granted to every local user, not just
        the scanning account, and `sudo nmap` covers the same ground. Turn it on
        if running the whole scan chain under sudo gets in the way.
      '';
    };

    nuclei = mkOption {
      type = types.bool;
      default = true;
      description = "Install nuclei together with the nuclei-templates corpus.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages =
      optional cfg.nmap pkgs.nmap
      ++ optionals cfg.nuclei [
        pkgs.nuclei
        pkgs.nuclei-templates
      ];

    # nmap ships its binary unprivileged; the wrapper is the NixOS-blessed way
    # to hand it capabilities without making it setuid root.
    security.wrappers = mkIf (cfg.nmap && cfg.nmapRawSockets) {
      nmap = {
        owner = "root";
        group = "root";
        capabilities = "cap_net_raw,cap_net_admin,cap_net_bind_service+eip";
        source = "${pkgs.nmap}/bin/nmap";
      };
    };

    # Left to itself, nuclei git-clones the template corpus into
    # ~/.local/nuclei-templates on first run and re-checks it afterwards, which
    # puts the ruleset outside the flake. Point it at the nixpkgs copy instead
    # and refuse the download, so templates move only when the flake is bumped.
    # Takes effect on the next login, since these are session variables.
    #
    # nuclei still writes its own state (config.yaml, .nuclei-ignore, the
    # template index) under ~/.config/nuclei and ~/.cache/nuclei - the store
    # path only has to be readable.
    environment.sessionVariables = mkIf cfg.nuclei {
      NUCLEI_TEMPLATES_DIR = templatesDir;
      DISABLE_NUCLEI_TEMPLATES_PUBLIC_DOWNLOAD = "true";
    };
  };
}
