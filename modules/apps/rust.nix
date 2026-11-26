{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.rust;
in
{
  options.blackwall.rust = {
    enable = mkEnableOption "Rust toolchain";

    tauri = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install the Tauri CLI, Node.js and the GTK/WebKit libraries a Tauri v2
        app links against. Also sets PKG_CONFIG_PATH so cargo can find them.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      rustc
      cargo
      rustfmt
      clippy
      rust-analyzer
      pkg-config
      gcc # cargo shells out to cc as the linker driver
      fontconfig
      wayland
      libxkbcommon
    ] ++ optionals cfg.tauri [
      cargo-tauri
      nodejs
      openssl
      glib
      gtk3
      webkitgtk_4_1
      libsoup_3
      librsvg
      libayatana-appindicator # system tray
    ];


    environment.sessionVariables = {
      # rust-analyzer resolves std sources through this
      RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";

      # The .pc files live in the dev outputs, which systemPackages does not
      # install, and NixOS sets no PKG_CONFIG_PATH of its own. Listing the dev
      # outputs here is what lets the tauri -sys crates configure.

      PKG_CONFIG_PATH = makeSearchPathOutput "dev" "lib/pkgconfig" (
        with pkgs; [
          fontconfig
          openssl
          glib
          gtk3
          webkitgtk_4_1
          libsoup_3
          librsvg
          libayatana-appindicator
        ]
      );
    };
  };
}
