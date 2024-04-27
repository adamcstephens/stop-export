{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.tfyolo;

  jsonType = (pkgs.formats.json { }).type;

  links = lib.foldlAttrs (
    acc: name: value:
    acc
    + ''
      ln -s ${value} ./${name}
    ''
  ) "" cfg.files;
  nix2tfjson = inputs.terranix.lib.terranixConfiguration {
    inherit (pkgs) system;
    modules = [ cfg.finalSettings ];
  };

  localBackendFile = inputs.terranix.lib.terranixConfiguration {
    inherit (pkgs) system;
    modules = [ { terraform.backend.local.path = "../tfyolo.tfstate"; } ];
  };
in
{
  options.tfyolo = {
    enable = lib.mkEnableOption "the tfyolo service";

    package = lib.mkOption {
      type = lib.types.package;
      description = "terraform package";
      default = pkgs.opentofu;
    };

    files = lib.mkOption {
      type = lib.types.attrsOf lib.types.pathInStore;
      description = "";
      default = { };
    };

    localBackend = lib.mkEnableOption (lib.mdDoc "local state storage in /var/lib");

    settings = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule { freeformType = jsonType; });
      description = "nix code to transform to tfjson with terranix";
      default = null;
    };

    finalSettings = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule { freeformType = jsonType; });
      description = "The final settings that will be applied. Overriding here can allow one to collect from multiple locations besides the single nixos configuration (e.g. a flake)";
      default = cfg.settings;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeScriptBin "tfyolo" ''
        if [ ! -d /var/lib/tfyolo/tf ]; then
          echo "Unable to access tfyolo files, maybe you need to sudo?"
          exit 1
        fi

        cd /var/lib/tfyolo/tf
        ${lib.getExe cfg.package} "$@"
      '')
    ];

    systemd.services.tfyolo = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];

      path = [ cfg.package ];

      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        StateDirectory = "tfyolo";
        WorkingDirectory = "/var/lib/tfyolo";
      };

      script = ''
        rm -rf tf
        mkdir tf
        cd tf
        ${links}
        ${lib.optionalString (cfg.settings != null) "ln -s ${nix2tfjson.out} config.tf.json"}
        ${lib.optionalString (
          cfg.localBackend != null
        ) "ln -s ${localBackendFile.out} local-backend.tf.json"}
        ${lib.getExe cfg.package} init
        ${lib.getExe cfg.package} apply -auto-approve
      '';
    };
  };
}
