{ config, lib, ... }:
let
  cfg = config.stop.hardware.rpi;
in
{
  options.stop.hardware.rpi = {
    enable = lib.mkEnableOption "raspberry pi hardware profile";
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = [
      "systemd.journald.forward_to_kmsg"
      "console=ttyAMA0,115200"
      "console=tty0"
    ];

    services.journald.extraConfig = ''
      SystemMaxUse=250M
    '';
  };
}
