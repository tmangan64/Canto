{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.blackwall.tailscale;
in
{
  options.blackwall.tailscale = {
    ssh = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Run the Tailscale SSH server (`tailscale up --ssh`).

        Access is still gated by tailnet ACLs, but set this to false on
        machines that should never accept SSH from the tailnet - e.g.
        workstations, as opposed to servers.
      '';
    };
  };

  config = {
    services.tailscale = {
      enable = true;
      extraUpFlags = optional cfg.ssh "--ssh";
    };
  };
}
