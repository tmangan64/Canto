{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.fido2-manage;

  pname = "token2-key-manager";
  version = "0.2.2";

  # nixpkgs.fido2-manage tracks the repository's `legacy` branch - the shell
  # script plus the Tk GUI, last built 2025-06-06. This is the Rust rewrite from
  # `main`, which ships the Tauri GUI and the PIV tooling, so the two collide on
  # the fido2-manage name and only one can be installed.
  #
  # Upstream builds Linux packages in CI rather than offering a source build, so
  # this unpacks the .deb. Of the four Linux assets it is the leanest: the
  # AppImage carries its own GTK and WebKit (92MB, and its launcher forces
  # GDK_BACKEND=x11), whereas the .deb declares those as system libraries and
  # autoPatchelfHook can point them at nixpkgs, keeping the native Wayland path.
  token2-key-manager = pkgs.stdenv.mkDerivation {
    inherit pname version;

    src = pkgs.fetchurl {
      url = "https://github.com/token2/fido2-manage/releases/download/${version}/Token2-key-manager_${version}_amd64.deb";
      hash = "sha256-Kp6OvtqRteI42i1Niy8inrnR7cPbZremMyRnUg1xHkY=";
    };

    nativeBuildInputs = with pkgs; [
      dpkg
      autoPatchelfHook
      # The GUI is WebKitGTK, so it needs the GSettings schemas, the
      # gdk-pixbuf loader cache and XDG_DATA_DIRS set at runtime. Without the
      # schemas in particular, GTK aborts on startup rather than degrading.
      wrapGAppsHook3
    ];

    # Everything the .deb's Depends line expects to find on the system, plus
    # what the vendored libraries below pull in themselves. libpcsclite is
    # deliberately taken from nixpkgs rather than from the vendored copy: the
    # socket path is compiled in, and nixpkgs builds it with ipcdir=/run/pcscd,
    # which is where the NixOS pcscd unit listens.
    buildInputs = with pkgs; [
      glib
      gtk3
      webkitgtk_4_1
      libsoup_3
      cairo
      pango
      gdk-pixbuf
      librsvg
      dbus
      wayland
      pcsclite
      systemdLibs
      zlib
      stdenv.cc.cc.lib
    ];

    # libt2piv is Token2's own PIV library and has no nixpkgs counterpart, so
    # the vendored copies are kept wholesale rather than unbundled one by one -
    # that is the combination upstream builds and tests against. Note this
    # leaves an Ubuntu-built libcrypto.so.3 in the closure, which only moves
    # when upstream cuts a release.
    installPhase = ''
      runHook preInstall

      install -Dm755 -t $out/lib opt/${pname}/*.so*

      # autoPatchelfHook searches the output's own lib directory before any
      # buildInput, so the vendored libpcsclite has to go for the nixpkgs one
      # to win. Both were built with the same ipcdir, so this is belt and
      # braces rather than a fix - but it keeps the socket path and the pcscd
      # that opens it on the same nixpkgs bump.
      rm $out/lib/libpcsclite.so.1

      # The .deb puts shell wrappers in /usr/bin that set LD_LIBRARY_PATH and
      # exec these; autoPatchelfHook writes $out/lib into the rpath instead, so
      # the real binaries can go straight into bin.
      install -Dm755 -t $out/bin \
        opt/${pname}/token2-key-manager \
        opt/${pname}/fido2-manage \
        opt/${pname}/token2-piv-tool

      install -Dm444 usr/share/applications/${pname}.desktop \
        -t $out/share/applications
      install -Dm444 usr/share/icons/hicolor/256x256/apps/${pname}.png \
        -t $out/share/icons/hicolor/256x256/apps

      runHook postInstall
    '';

    meta = {
      description = "Token2 Key Manager, a GUI and CLI for FIDO2, PIV and OATH keys";
      homepage = "https://github.com/token2/fido2-manage";
      license = licenses.bsd2;
      platforms = [ "x86_64-linux" ];
      mainProgram = "token2-key-manager";
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
    };
  };
in
{
  options.blackwall.fido2-manage = {
    enable = mkEnableOption "Token2 Key Manager, the fido2-manage CLI and its Tauri GUI";

    pcscd = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Run the PC/SC smart card daemon. Both the FIDO2 and the PIV side reach
        the key over PC/SC - Token2 keys tunnel their FIDO applet through the
        CCID channel, and PIV is a smart card interface to begin with - so the
        GUI reports no device without it. Only raw-HID FIDO keys over USB work
        with this off.
      '';
    };
  };

  config = mkIf cfg.enable {
    # One package, three binaries: the token2-key-manager GUI (registered in
    # the app grid), the fido2-manage CLI and token2-piv-tool.
    environment.systemPackages = [ token2-key-manager ];

    services.pcscd.enable = cfg.pcscd;

    # libfido2's 70-u2f.rules tags known FIDO keys with uaccess, which hands
    # /dev/hidraw* to whoever holds the active session. Without it the raw-HID
    # path only works under sudo, and the GUI never elevates. The CCID path
    # above goes through pcscd and does not depend on this.
    services.udev.packages = [ pkgs.libfido2 ];
  };
}
