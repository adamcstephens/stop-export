{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.stop.roles.desktop;

  nvfetcher = import ../../_sources/generated.nix {
    inherit (pkgs)
      fetchgit
      fetchurl
      fetchFromGitHub
      dockerTools
      ;
  };

  riverMaster = (pkgs.river.override { wlroots_0_16 = pkgs.wlroots_0_17; }).overrideAttrs (old: rec {
    version = "0.3.0-dev-${builtins.substring 0 7 src.rev}";
    src = nvfetcher.river.src;
  });

  riverLauncher = pkg: ''
    export PATH=${pkg}/bin:$PATH
    export MANPATH=${pkg.man}/share/man
    ${lib.optionalString config.stop.hardware.gpu.nvidia.enable "export WLR_NO_HARDWARE_CURSORS=1"}
    $HOME/.config/river/start
  '';
in
{
  config = lib.mkIf cfg.wayland.enable {
    programs.river = {
      enable = true;
      package = null;
    };

    services.xserver = {
      displayManager.session =
        if config.stop.manageHomeManager then
          [
            {
              manage = "desktop";
              name = "stop-river";
              start = ''
                /run/current-system/sw/bin/systemd-cat --identifier=river ${lib.getExe config.programs.river.package}
              '';
            }
          ]
        else
          [
            {
              manage = "desktop";
              name = "river";
              start = riverLauncher pkgs.river;
            }
            {
              manage = "desktop";
              name = "river-master";
              start = riverLauncher riverMaster;
            }
          ];
    };
  };
}
