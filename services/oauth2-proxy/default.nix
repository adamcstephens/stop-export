{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.stop.services.oauth2-proxy;

  cliFlags = lib.concatStringsSep " " cfg.flags;
in
{
  options.stop.services.oauth2-proxy = {
    enable = lib.mkEnableOption "oauth2-proxy service";

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "path to systemd service environment file. e.g. `/run/my/secrets`";
      default = null;
    };

    flags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "list of command line flags";
      default = [ ];
    };

    package = lib.mkOption {
      type = lib.types.package;
      description = "";
      default = pkgs.oauth2-proxy;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.oauth2-proxy = {
      description = "OAuth2 Proxy";
      wantedBy = [ "multi-user.target" ];
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        DynamicUser = true;
        Restart = "always";
        ExecStart = "${cfg.package}/bin/oauth2-proxy ${cliFlags}";

        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
      };
    };
  };
}
