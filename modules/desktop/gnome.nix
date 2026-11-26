{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.gnome;
in
{
  options.blackwall.gnome = {
    enable = mkEnableOption "GNOME desktop environment";

    printing = mkOption {
      type = types.bool;
      default = true;
      description = "Enable CUPS printing support";
    };

    audio = mkOption {
      type = types.bool;
      default = true;
      description = "Enable PipeWire audio (with ALSA and PulseAudio compatibility)";
    };
  };

  config = mkIf cfg.enable {
    # GNOME with the GDM display manager
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    services.printing.enable = cfg.printing;

    environment.systemPackages = with pkgs; [
      gnome-tweaks
    ];

    # PipeWire replaces PulseAudio
    services.pulseaudio.enable = mkIf cfg.audio false;
    security.rtkit.enable = mkIf cfg.audio true;
    services.pipewire = mkIf cfg.audio {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # For JACK applications:
      # jack.enable = true;
    };

    # Default GNOME settings - these are dconf defaults, so anything changed
    # later in the GUI still wins and persists in the user database.
    programs.dconf.profiles.user = {
      enableUserDb = true;
      databases = [{
        settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            accent-color = "green";
            show-battery-percentage = true;
            enable-hot-corners = false;
          };

          "org/gnome/desktop/screensaver" = {
            picture-uri = "file://${pkgs.nixos-artwork.wallpapers.simple-blue.gnomeFilePath}";
            primary-color = "#3a4ba0";
            secondary-color = "#2f302f";
          };

          # Super+F1 (Launch1) opens a terminal
          "org/gnome/settings-daemon/plugins/media-keys" = {
            custom-keybindings = [
              "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            ];
          };
          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
            name = "launch terminal";
            command = "ghostty";
            binding = "Launch1";
          };
        };
      }];
    };
  };
}
