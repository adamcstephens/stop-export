{ config, lib, ... }:
let
  cfg = config.stop.roles.ci.typhon;
  site = config.stop.sites.${config.stop.site};
in
{
  options.stop.roles.ci.typhon = {
    enable = lib.mkEnableOption "typhon service";
  };

  config = lib.mkIf cfg.enable {
    age.secrets.typhon-admin-password = {
      file = ./typhon-admin-password.age;
      owner = "typhon";
    };

    services.typhon = {
      enable = true;

      hashedPasswordFile = config.age.secrets.typhon-admin-password.path;
    };

    services.consul.services.typhon = {
      hostnames = [ site.services.typhon ];

      address = config.stop.roles.grid.ip.internal.ipv4;
      port = 3000;

      overrides = {
        checks = [
          {
            tcp = "localhost:3000";
            interval = "5s";
          }
        ];
      };

      sidecar = {
        enable = true;
        adminBindPort = 19026;
      };
    };

    stop.roles.builder.client.enable = true;
  };
}
