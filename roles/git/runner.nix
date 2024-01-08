{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.stop.roles.git.runner;
  site = config.stop.sites.${config.stop.site};
in
{
  options.stop.roles.git.runner = {
    enable = lib.mkEnableOption "git runner service";
  };

  config = lib.mkIf cfg.enable {
    age.secrets."runner-token.env".file = ./runner-token.env.age;

    services.gitea-actions-runner = {
      package = pkgs.forgejo-actions-runner;

      instances.default = {
        enable = true;
        name = config.networking.hostName;
        labels = [ "stop/${pkgs.system}:docker://${config.stop.hostnames.git}/adam/stop-builder" ];

        settings = {
          runner.envs = {
            ATTIC_URL = site.attic.url;
            ATTIC_CACHE = site.attic.cacheName;
          };

          container = {
            force_pull = true;
            network = "bridge";

            # probably don't do this if you don't trust your users
            valid_volumes = [ "/nix" ];
          };
        };

        tokenFile = config.age.secrets."runner-token.env".path;
        url = "https://${config.stop.hostnames.git}";
      };
    };

    virtualisation.podman.enable = true;
  };
}
