{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (config.boot.loader) efi;
  cfg = config.stop.hardware.x13s;

  dtbName = "x13s67rc3.dtb";
  linuxPackages_x13s = pkgs.linuxPackagesFor self.packages.aarch64-linux.linux_x13s;
  dtb = "${linuxPackages_x13s.kernel}/dtbs/qcom/sc8280xp-lenovo-thinkpad-x13s.dtb";
in
{
  options.stop.hardware.x13s = {
    enable = lib.mkEnableOption "x13s hardware support";
  };

  config = lib.mkIf cfg.enable {
    hardware.enableAllFirmware = true;

    systemd.services.pd-mapper = {
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${lib.getExe self.packages.aarch64-linux.pd-mapper}";
        Restart = "always";
      };
    };

    # https://dumpstack.io/1675806876_thinkpad_x13s_nixos.html
    boot = {
      loader.efi.canTouchEfiVariables = true;
      loader.systemd-boot.enable = true;

      supportedFilesystems = lib.mkForce [
        "ext4"
        "btrfs"
        "ntfs"
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

        "dtb=${dtbName}"
      ];

      initrd = {
        # TODO : test this
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
          "msm"
        ];
      };
    };

    services.kanata = {
      enable = true;
      keyboards.thinkpad = {
        config = builtins.readFile ./thinkpad.kbd;
        devices = [ "/dev/input/by-path/platform-894000.i2c-event-kbd" ];
      };
    };
    hardware.uinput.enable = true;

    # TODO: can this be improved? moved to dtb option? is it even reproducible?
    system.activationScripts.x13s-dtb = ''
      in_package="${dtb}"
      esp_tool_folder="${efi.efiSysMountPoint}/"
      in_esp="''${esp_tool_folder}${dtbName}"
      >&2 echo "Ensuring $in_esp in EFI System Partition"
      if ! ${pkgs.diffutils}/bin/cmp --silent "$in_package" "$in_esp"; then
        ls -l "$in_esp" || true
        >&2 echo "Copying $in_package -> $in_esp"
        mkdir -p "$esp_tool_folder"
        cp "$in_package" "$in_esp"
        sync
      fi
    '';
  };
}
