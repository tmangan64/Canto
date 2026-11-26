{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware.nix
      # Networking
      ../../modules/networking/tailscale.nix
      # Security
      ../../modules/security/scanning.nix
      # Desktop
      ../../modules/desktop/gnome.nix
      ../../modules/desktop/qt.nix
      # Apps
      ../../modules/apps/vscode.nix
      ../../modules/apps/shell.nix
      ../../modules/apps/firefox.nix
      ../../modules/apps/devenv.nix
      ../../modules/apps/manuskript.nix
      ../../modules/apps/obsidian.nix
      ../../modules/apps/writing.nix
      ../../modules/apps/nicotine.nix
      ../../modules/apps/boxes.nix
      ../../modules/apps/rust.nix
      ../../modules/apps/kicad.nix
      ../../modules/apps/fido2-manage.nix
    ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Hostname
  networking.hostName = "canto";

  # Networking
  networking.networkmanager.enable = true;

  # Timezone
  time.timeZone = "Europe/Jersey";

  # Locale
  i18n.defaultLocale = "en_GB.UTF-8";

  # Keymap
  services.xserver.xkb = {
    layout = "gb";
    variant = "";
  };
  console.keyMap = "uk";

  # GNOME desktop (GDM, PipeWire audio, CUPS printing)
  blackwall.gnome.enable = true;

  # Adwaita-Qt systemwide - matches the prefer-dark GNOME setting above
  blackwall.qt.enable = true;

  # Workstation - do not run a Tailscale SSH server
  blackwall.tailscale.ssh = false;

  # VS Code (extensions are declared in modules/apps/vscode.nix)
  blackwall.vscode.enable = true;

  # Ghostty + fish
  blackwall.shell.enable = true;

  # Firefox with the Adwaita theme
  blackwall.firefox.enable = true;

  # devenv.sh + direnv for per-project dev shells
  blackwall.devenv.enable = true;

  # Manuskript (themed by blackwall.qt)
  blackwall.manuskript.enable = true;

  # Obsidian with the Adwaita theme
  blackwall.obsidian.enable = true;

  # Fantasia Archive (upstream AppImage, wrapped by appimageTools)
  blackwall.fantasia-archive.enable = true;

  # Nicotine+ (GTK4/libadwaita, so no extra theming)
  blackwall.nicotine.enable = true;

  # GNOME Boxes on libvirt/QEMU (adds mizutani to the libvirtd group)
  blackwall.boxes.enable = true;

  # Rust & Cargo
  blackwall.rust.enable = true;

  # KiCad with the full library set, including the 3D models (wxGTK, so it is
  # themed by GNOME rather than blackwall.qt)
  blackwall.kicad.enable = true;

  # Token2 Key Manager 0.2.2 (upstream .deb, not the older nixpkgs build) -
  # the fido2-manage CLI, token2-piv-tool and the Tauri GUI, plus pcscd
  blackwall.fido2-manage.enable = true;

  # nmap + nuclei; templates come from nixpkgs, not nuclei's own downloader
  blackwall.scanning.enable = true;

  # Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages (vscode, claude-code)
  nixpkgs.config.allowUnfree = true;

  # User account
  users.users.mizutani = {
    isNormalUser = true;
    description = "Teague Mangan";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ ];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    claude-code
  ];

  system.stateVersion = "26.05";
}
