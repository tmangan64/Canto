{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.nicotine;
in
{
  options.blackwall.nicotine = {
    enable = mkEnableOption "Nicotine+, a graphical client for the Soulseek network";

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Open the listening port, so other peers can open connections to this
        machine. Soulseek still works without it - Nicotine+ falls back to
        asking the server to have the peer dial out instead - but two peers
        that are both unreachable cannot transfer at all, so closing this
        drops a share of searches and downloads silently.
      '';
    };

    listenPort = mkOption {
      type = types.port;
      default = 2234;
      description = ''
        Port incoming peer connections arrive on. Must match the value in
        Preferences > Network > Listening port, which Nicotine+ keeps in its
        own config file - this option only opens the firewall, it does not
        configure the application.
      '';
    };
  };

  config = mkIf cfg.enable {
    # GTK4 and libadwaita, so it picks up the GNOME theme, fonts and the
    # prefer-dark setting on its own - nothing like blackwall.qt is needed.
    environment.systemPackages = [ pkgs.nicotine-plus ];

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.listenPort ];
  };
}
