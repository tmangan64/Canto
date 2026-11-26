{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.blackwall.boxes;
in
{
  options.blackwall.boxes = {
    enable = mkEnableOption "GNOME Boxes, a graphical front end for libvirt/QEMU virtual machines";

    usbRedirection = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Allow guests to claim host USB devices through SPICE. This installs a
        setuid helper (spice-client-glib-usb-acl-helper), so leave it off if
        nothing will ever need a USB device passed into a VM.
      '';
    };

    swtpm = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Provide an emulated TPM 2.0 device. Windows 11 refuses to install
        without one, and its absence shows up as a generic "this PC can't run
        Windows 11" error rather than anything pointing at the TPM.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Boxes talks to libvirt, which is a daemon rather than a library here -
    # without this the app starts but every VM creation fails at the connect
    # step. The default qemu.package is qemu_kvm, so guests run at native
    # speed rather than falling back to full emulation.
    virtualisation.libvirtd = {
      enable = true;
      qemu.swtpm.enable = cfg.swtpm;
    };

    virtualisation.spiceUSBRedirection.enable = cfg.usbRedirection;

    # Boxes runs its VMs under the user's own session daemon (qemu:///session),
    # but it still reads the system connection to list networks and storage
    # pools, and that socket is group-owned by libvirtd.
    users.users.mizutani.extraGroups = [ "libvirtd" ];

    # GTK4 and libadwaita, so it follows the GNOME theme without blackwall.qt.
    # virt-viewer brings remote-viewer, which is the fallback when the display
    # embedded in the Boxes window misbehaves.
    environment.systemPackages = with pkgs; [
      gnome-boxes
      virt-viewer
    ];
  };
}
