{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.fantasia-archive;

  pname = "fantasia-archive";
  version = "0.1.15";

  # Releases live in the -v1 repository. The original vishiri/fantasia-archive
  # stopped at 0.1.13 and no longer gets builds, so do not point this there.
  # Note the capital I in "appImage" - upstream has spelled that asset both
  # ways across releases, so the URL needs rechecking on every version bump.
  zip = pkgs.fetchurl {
    url = "https://github.com/vishiri/fantasia-archive-v1/releases/download/v${version}/Fantasia.Archive-${version}-linux-appImage.zip";
    hash = "sha256-4JwG/qi/6dFgR+OdjkHlv2JybenK7FxQmakXgmVH6m4=";
  };

  # appimageTools only accepts a bare AppImage, but upstream ships it zipped,
  # so unwrap it first. The archive holds exactly one file.
  appimage = pkgs.runCommand "${pname}-${version}.AppImage"
    { nativeBuildInputs = [ pkgs.unzip ]; }
    ''
      unzip -j ${zip} '*.AppImage' -d .
      mv ./*.AppImage "$out"
    '';

  # The unpacked squashfs, used only to lift out the bundled desktop entry and
  # icon - wrapType2 installs the binary but none of the desktop integration.
  contents = pkgs.appimageTools.extract {
    inherit pname version;
    src = appimage;
  };

  fantasia-archive = pkgs.appimageTools.wrapType2 {
    inherit pname version;
    src = appimage;

    extraInstallCommands = ''
      install -Dm444 ${contents}/fantasiaarchive.desktop \
        $out/share/applications/${pname}.desktop
      install -Dm444 \
        ${contents}/usr/share/icons/hicolor/512x512/apps/fantasiaarchive.png \
        $out/share/icons/hicolor/512x512/apps/fantasiaarchive.png

      # Upstream sets Exec=AppRun, which is the launcher inside the image and
      # is not on PATH once the image has been unpacked into the store.
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    '';

    meta = {
      description = "Database manager for world building";
      homepage = "https://github.com/vishiri/fantasia-archive-v1";
      license = licenses.gpl3Only;
      platforms = [ "x86_64-linux" ];
      mainProgram = pname;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
    };
  };
in
{
  options.blackwall.fantasia-archive = {
    enable = mkEnableOption "Fantasia Archive, a world building database";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ fantasia-archive ];
  };
}
