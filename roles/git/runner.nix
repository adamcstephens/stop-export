{
  config,
  inputs,
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
        labels = [
          "debian/${pkgs.system}:docker://docker.io/node:lts"
          "local/${pkgs.system}:host"
          "local:host"
        ];

        hostPackages = [
          config.nix.package

          inputs.attic.packages.${pkgs.system}.attic
          inputs.sower.packages.${pkgs.system}.seed-ci

          pkgs.bash
          pkgs.cachix
          pkgs.coreutils
          pkgs.curl
          pkgs.gawk
          pkgs.gitMinimal
          pkgs.gnused
          pkgs.jq
          pkgs.nodejs
          pkgs.nushell
          pkgs.wget
        ];

        settings = {
          runner.envs = {
            ATTIC_ENDPOINT = site.attic.url;
            ATTIC_URL = site.attic.url;
            ATTIC_CACHE = site.attic.cacheName;
          };

          container = {
            force_pull = true;
            network = "bridge";

            # probably don't do this if you don't trust your users
            valid_volumes = [ "/nix" ];
          };

          host.workdir_parent = "/var/lib/gitea-runner/default/.cache/act";
        };

        tokenFile = config.age.secrets."runner-token.env".path;
        url = "https://${config.stop.hostnames.git}";
      };
    };

    systemd.services.nixpkgs-git-refresh = {
      path = [ pkgs.git ];
      script = ''
        #!${lib.getExe pkgs.bash}
        [ ! -e .git ] && git clone https://github.com/nixos/nixpkgs.git ./
        git fetch origin
        git reset --hard origin/master
      '';

      serviceConfig = {
        DynamicUser = true;
        User = "nixpkgs";
        StateDirectory = "nixpkgs";
        WorkingDirectory = "%S/nixpkgs";
      };
    };

    systemd.timers.nixpkgs-git-refresh = {
      wantedBy = [ "timers.target" ];

      timerConfig.OnCalendar = "hourly";
    };

    fileSystems."/srv/nixpkgs" = {
      device = "/var/lib/private/nixpkgs";
      options = [ "bind" ];
    };

    virtualisation.podman.enable = true;
  };
}
