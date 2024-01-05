{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.stop.hardware.gpu.amd;
in
{
  options.stop.hardware.gpu.amd = {
    enable = lib.mkEnableOption "Enable the amd gpu support";
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.kernelModules = [ "amdgpu" ];

    environment.systemPackages = [
      pkgs.nvtop-amd
      pkgs.rocmPackages.rocminfo
    ];

    hardware.opengl = {
      enable = true;
      extraPackages = [
        pkgs.rocm-opencl-icd
        pkgs.rocm-opencl-runtime
      ];
    };
  };
}
