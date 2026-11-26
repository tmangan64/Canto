{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.shell;

  # Ghostty requires OpenGL 4.3 but Canto only has an Ivy Bridge Intel 4000.

  # Courtesy of Claude Opus
  # Ghostty needs OpenGL 4.3, but this machine's Intel HD 4000 (Ivy Bridge)
  # tops out at 4.2, so the GPU path fails to create a surface. Force llvmpipe
  # (OpenGL 4.6) for Ghostty alone - a session-wide override would push every
  # other GL app onto software rendering too. The desktop entries hardcode an
  # absolute path to the binary, so they are rewritten to reach the wrapper.
  #
  # The desktop entry is not the only such file: it sets DBusActivatable=true,
  # so GNOME starts Ghostty by asking D-Bus for com.mitchellh.ghostty, which
  # hands off to the packaged systemd user unit. Both of those also hardcode the
  # binary, so all three directories are copied and rewritten - otherwise the
  # launcher silently starts the unwrapped binary and dies on the GL surface
  # while 'ghostty' from a shell (which finds the wrapper on PATH) works.
  ghostty = pkgs.runCommand "ghostty-software-gl-${pkgs.ghostty.version}"
    {
      nativeBuildInputs = [ pkgs.makeWrapper ];
      inherit (pkgs.ghostty) meta;
    } ''
    mkdir -p $out/bin $out/share

    makeWrapper ${pkgs.ghostty}/bin/ghostty $out/bin/ghostty \
      --set LIBGL_ALWAYS_SOFTWARE 1

    for d in ${pkgs.ghostty}/share/*; do
      case "$(basename "$d")" in
        applications|dbus-1|systemd)
          cp -r --no-preserve=mode,ownership "$d" $out/share/
          ;;
        *)
          ln -s "$d" $out/share/
          ;;
      esac
    done

    find $out/share -type f -exec \
      sed -i "s|${pkgs.ghostty}/bin/ghostty|$out/bin/ghostty|g" {} +
  '';
in
{
  options.blackwall.shell = {
    enable = mkEnableOption "Ghostty + fish";
  };

  config = mkIf cfg.enable {
    programs.fish = {
      enable = true;
      shellAbbrs = {
        build = "sudo nixos-rebuild switch --flake ~/Projects/Nix/Canto#canto";
        blackwall = "ssh -p 6622 mizutani@82.112.156.122";
      };

      # NixOS has no fish_greeting or functions options - those are
      # home-manager's. Both go through interactiveShellInit instead, which is
      # sourced into every interactive fish session.
      interactiveShellInit = ''
        # Can't be fucked each time
        set -g fish_greeting

        # `ls -l` after every directory change. Hooking the PWD variable rather
        # than wrapping cd in a `go` function keeps plain cd in use, so its
        # completions and history-based autosuggestions behave normally - a
        # custom wrapper has no history to suggest from, and fish's own
        # completions for the Go toolchain hijack the name `go`.
        #
        # Fires for anything that moves the shell (cd, pushd, popd, z), not
        # just cd. The guard stops it emitting a listing into the output of
        # command substitutions like (pwd).
        function __blackwall_auto_ls --on-variable PWD --description 'ls -l on directory change'
          status is-command-substitution; and return
          ls -l
        end
      '';

      # The Astronaut prompt, sourced straight out of the fish package rather
      # than copied in, so it tracks the packaged version.
      #
      # Choosing it in `fish_config` instead writes
      # ~/.config/fish/functions/fish_prompt.fish, and that directory comes
      # first in $fish_function_path - so any such file shadows this and has to
      # be deleted for the declarative prompt to apply.
      promptInit = "source ${pkgs.fish}/share/fish/prompts/astronaut.fish";
    };


    # fish as the login shell, so every terminal starts in it
    users.users.mizutani.shell = pkgs.fish;

    environment.systemPackages = [ ghostty ];

    # Ghostty reads only $XDG_CONFIG_HOME/ghostty/config. It ignores
    # XDG_CONFIG_DIRS entirely - there is no reference to that variable in the
    # binary - so the previous environment.etc."xdg/ghostty/config" was never
    # read and working-directory never applied. The file lives in /etc and is
    # symlinked into the user's config dir below, which is the one path Ghostty
    # does look at.
    environment.etc."ghostty/config".text = ''
      working-directory = home

      # Open maximised rather than at the default window size. This asks the
      # compositor to maximise, so GNOME keeps the titlebar and the window
      # stays resizable; `fullscreen = true` instead would hide both.
      maximize = true
    '';

    # L+ replaces whatever is at the path, so a stale hand-written config does
    # not block this. The flip side: edits to ~/.config/ghostty/config will not
    # survive - change the file above instead.
    systemd.user.tmpfiles.rules = [
      "L+ %h/.config/ghostty/config - - - - /etc/ghostty/config"
    ];
  };
}
