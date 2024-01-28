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
      lanzaboote = {
        enable = true;
        pkiBundle = "/etc/secureboot";
      };
      loader.systemd-boot.enable = !config.boot.lanzaboote.enable;
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
