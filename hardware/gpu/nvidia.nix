{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.stop.hardware.gpu.nvidia;
in
{
  options.stop.hardware.gpu.nvidia = {
    enable = lib.mkEnableOption "Enable the nvidia gpu support";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.nvtop
      pkgs.python310Packages.gpustat
    ];

    hardware.opengl = {
      enable = true;
      extraPackages = [
        pkgs.nvidia-vaapi-driver
        pkgs.vaapiVdpau
      ];
    };

    hardware.nvidia.modesetting.enable = true;

    services.xserver.videoDrivers = [ "nvidia" ];
  };
}
