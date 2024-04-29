{
  config,
  lib,
  site,
  ...
}:
let
  cfg = config.stop.roles.ci.server;
in
{
  imports = [
    ./agent.nix
    ./hydra.nix
    ./typhon.nix
  ];

  options.stop.roles.ci.server = {
    enable = lib.mkEnableOption "Enable the woodpecker service";
  };

  config = lib.mkIf cfg.enable {
    age.secrets.woodpecker-secret-env = {
      owner = "woodpecker-server";
      file = ./server-env.age;
    };

    services.woodpecker-server = {
      enable = true;

      environment = {
        WOODPECKER_HOST = "https://${site.services.woodpecker}";
        WOODPECKER_ADMIN = "adam";

        WOODPECKER_GITEA = "true";
        WOODPECKER_GITEA_URL = "https://${site.services.git}";

        WOODPECKER_SERVER_ADDR = "127.0.0.1:8000";
        WOODPECKER_GRPC_ADDR = ":9000";
        WOODPECKER_ENVIRONMENT = "SOWER_URL:https://${site.services.sower},ATTIC_URL:${site.attic.url},ATTIC_CACHE:${site.attic.cacheName}";
      };
      environmentFile = config.age.secrets.woodpecker-secret-env.path;
    };

    services.consul.services.woodpecker = {
      hostnames = [ site.services.woodpecker ];

      address = config.stop.roles.grid.ip.internal.ipv4;
      port = 8000;

      overrides = {
        checks = [
          {
            tcp = "localhost:8000";
            interval = "10s";
          }
        ];
      };

      sidecar = {
        enable = true;
        adminBindPort = 19024;
      };
    };

    # not sure how to get consul to route this grpc? will expose on the network for now
    networking.firewall.allowedTCPPorts = [ 9000 ];
    # services.consul.services.woodpecker-grpc = {
    #   hostnames = [ site.services.woodpecker-grpc ];
    #
    #   address = config.stop.roles.grid.ip.internal.ipv4;
    #   port = 9000;
    #
    #   overrides = {
    #     checks = [
    #       {
    #         tcp = "localhost:9000";
    #         interval = "10s";
    #       }
    #     ];
    #   };
    #
    #   sidecar = {
    #     enable = true;
    #     adminBindPort = 19025;
    #     protocol = "grpc";
    #     gatewayListener = "git-ssh";
    #   };
    # };

    users.groups.woodpecker-server = { };
    users.users.woodpecker-server = {
      isSystemUser = true;
      group = "woodpecker-server";
    };
  };
}
