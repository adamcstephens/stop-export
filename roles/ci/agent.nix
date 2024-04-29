{
  config,
  lib,
  pkgs,
  site,
  ...
}:
let
  cfg = config.stop.roles.ci.agent;
in
{
  options.stop.roles.ci.agent = {
    enable = lib.mkEnableOption "Enable the  service";
  };

  config = lib.mkIf cfg.enable {
    age.secrets.woodpecker-agent-secret = {
      owner = "woodpecker-agent";
      file = ./agent-secret.age;
    };

    services.woodpecker-agents.agents = {
      # docker = {
      #   enable = true;
      #   package = agentPackage;
      #   environment = {
      #     DOCKER_HOST = "unix:///run/podman/podman.sock";
      #     WOODPECKER_BACKEND = "docker";
      #     WOODPECKER_SERVER = "https://${site.services.woodpecker}";
      #   };
      #   environmentFile = [config.age.secrets.woodpecker-agent-secret.path];
      #   extraGroups = [
      #     "docker"
      #   ];
      # };
      local = {
        enable = true;

        environment = {
          WOODPECKER_BACKEND = "local";
          WOODPECKER_FILTER_LABELS = "type=local,system=${pkgs.system}";
          WOODPECKER_MAX_WORKFLOWS = "1";
          WOODPECKER_SERVER = "${site.services.woodpecker-grpc}:9000";
          WOODPECKER_GRPC_SECURE = "false";
        };
        environmentFile = [ config.age.secrets.woodpecker-agent-secret.path ];
      };
    };

    systemd.services.woodpecker-agent-local = {
      serviceConfig.User = "woodpecker-agent";
      path = [
        pkgs.woodpecker-plugin-git
        pkgs.bash
        pkgs.coreutils
        pkgs.git
        pkgs.git-lfs
        pkgs.gnutar
        pkgs.gzip
        pkgs.nix
      ];
    };

    users.groups.woodpecker-agent = { };
    users.users.woodpecker-agent = {
      isSystemUser = true;
      group = "woodpecker-agent";
    };
  };
}
