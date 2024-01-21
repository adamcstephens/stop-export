{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.stop.hardware.x13s;

  dtbName = "sc8280xp-lenovo-thinkpad-x13s.dtb";
  linuxPackages_x13s = pkgs.linuxPackagesFor self.packages.aarch64-linux."x13s/linux";
  dtb = "${linuxPackages_x13s.kernel}/dtbs/qcom/${dtbName}";

  alsa-ucm-conf-env.ALSA_CONFIG_UCM2 = "${
    self.packages.aarch64-linux."x13s/alsa-ucm-conf"
  }/share/alsa/ucm2";
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
    environment.systemPackages = [
      pkgs.efibootmgr
      pkgs.sbctl
    ];

    hardware.enableAllFirmware = true;
    hardware.firmware = [ self.packages.aarch64-linux."x13s/extra-firmware" ];

    systemd.services.pd-mapper = {
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${lib.getExe self.packages.aarch64-linux.pd-mapper}";
        Restart = "always";
      };
    };

    environment.sessionVariables = alsa-ucm-conf-env;
    systemd.user.services.pipewire.environment = alsa-ucm-conf-env;
    systemd.user.services.wireplumber.environment = alsa-ucm-conf-env;

    boot = {
      loader.efi.canTouchEfiVariables = true;
      loader.systemd-boot.enable = false;
      loader.systemd-boot.extraFiles = {
        "${dtbName}" = dtb;
      };

      lanzaboote = {
        enable = true;
        pkiBundle = "/etc/secureboot";
      };

      blacklistedKernelModules = [ "wwan" ];

      supportedFilesystems = lib.mkForce [
        "ext4"
        "btrfs"
        "vfat"
      ];

      initrd.supportedFilesystems = lib.mkForce [
        "btrfs"
        "vfat"
      ];

      kernelPackages = linuxPackages_x13s;

      kernelParams = [
        # jhovold recommended
        "efi=noruntime"
        "clk_ignore_unused"
        "pd_ignore_unused"
        "arm64.nopauth"

        # blacklist graphics in initrd so the firmware can load from disk
        "rd.driver.blacklist=msm"
      ];

      initrd = {
        includeDefaultModules = false;

        kernelModules = [
          "nvme"
          "phy-qcom-qmp-pcie"
          "pcie-qcom"

          "i2c-core"
          "i2c-hid"
          "i2c-hid-of"
          "i2c-qcom-geni"

          "leds_qcom_lpg"
          "pwm_bl"
          "qrtr"
          "pmic_glink_altmode"
          "gpio_sbu_mux"
          "phy-qcom-qmp-combo"
          "gpucc_sc8280xp"
          "dispcc_sc8280xp"
          "phy_qcom_edp"
          "panel-edp"
          # "msm"
        ];
      };
    };

    # default is performance
    powerManagement.cpuFreqGovernor = "ondemand";

    services.kanata = {
      enable = true;
      keyboards.thinkpad = {
        config = builtins.readFile ./thinkpad.kbd;
        devices = [ "/dev/input/by-path/platform-894000.i2c-event-kbd" ];
      };
    };
    hardware.uinput.enable = true;

    systemd.services.bluetooth = {
      serviceConfig = {
        # disabled because btmgmt call hangs
        # ExecStartPre = [
        #   ""
        #   "${pkgs.util-linux}/bin/rfkill block bluetooth"
        #   "${pkgs.bluez5-experimental}/bin/btmgmt public-addr ${cfg.bluetoothMac}"
        #   "${pkgs.util-linux}/bin/rfkill unblock bluetooth"
        # ];
        RestartSec = 5;
        Restart = "on-failure";
      };
    };
  };
}
