{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.stop.hardware.x13s;
in
{
  options.stop.hardware.x13s = {
    enable = lib.mkEnableOption "x13s hardware support";

    bluetoothMac = lib.mkOption {
      type = lib.types.str;
      description = "mac address to set on boot";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.sbctl ];

    boot = {
      loader.systemd-boot.enable = false;
      lanzaboote = {
        enable = true;
        pkiBundle = "/etc/secureboot";
      };
    };
    hardware.uinput.enable = true;

    nixos-x13s.enable = true;

    services.kanata = {
      enable = true;
      keyboards.thinkpad = {
        config = builtins.readFile ./thinkpad.kbd;
        devices = [ "/dev/input/by-path/platform-894000.i2c-event-kbd" ];
      };
    };
  };
}
