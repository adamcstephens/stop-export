{ config, lib, ... }:
let
  cfg = config.stop.hardware.m600;
in
{
  options.stop.hardware.m600 = {
    enable = lib.mkEnableOption "Enable the m600 hardware profile";
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.availableKernelModules = [
      "ahci"
      "nvme"
      "pl2303"
      "r8169"
      "sd_mod"
      "usb-common"
      "usbcore"
      "usbserial"
      "xhci_hcd"
      "xhci_pci"
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    hardware.enableAllFirmware = true;
    hardware.cpu.intel.updateMicrocode = true;

    stop.hardware.physical.enable = true;
  };
}
