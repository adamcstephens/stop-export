{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.stop.hardware.physical;
  site = config.stop.sites.${config.stop.site};
in
{
  options.stop.hardware.physical = {
    enable = lib.mkEnableOption "the machine is physical hardware";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.smartmontools ];

    services.smartd.enable = true;
    services.udev.extraRules = ''
      SUBSYSTEM=="nvme", KERNEL=="nvme[0-9]*", GROUP="disk"
    '';

    services.prometheus.exporters.smartctl = {
      enable = true;
      listenAddress = "127.0.0.1";
    };

    services.grafana-agent.settings.metrics.configs = [
      {
        name = "smartctl";
        scrape_configs = [
          {
            job_name = "smartctl";
            metrics_path = "/metrics";
            static_configs = [
              {
                targets = [
                  "${config.services.prometheus.exporters.smartctl.listenAddress}:${builtins.toString config.services.prometheus.exporters.smartctl.port}"
                ];
              }
            ];
          }
        ];

        remote_write =
          let
            remoteWriteTargets = builtins.map (p: {
              url = p;
              # put hostname in instance instead of localhost:1234
              write_relabel_configs = [
                {
                  replacement = config.networking.hostName;
                  target_label = "instance";
                  action = "replace";
                }
              ];
            }) site.promRemoteWriteEndpoints;
          in
          remoteWriteTargets;
      }
    ];
  };
}
