{ config, lib, ... }:
let
  cfg = config.stop.hardware.ups;
  site = config.stop.sites.${config.stop.site};
in
{
  options.stop.hardware.ups = {
    enable = lib.mkEnableOption "Enable ups related software and monitoring";
  };

  config = lib.mkIf cfg.enable {
    services.apcupsd.enable = true;

    services.prometheus.exporters.apcupsd = {
      enable = true;
      listenAddress = "127.0.0.1";
    };

    services.grafana-agent.settings.metrics.configs = [
      {
        name = "apcupsd";
        scrape_configs = [
          {
            job_name = "apcupsd";
            metrics_path = "/metrics";
            static_configs = [
              {
                targets = [
                  "${config.services.prometheus.exporters.apcupsd.listenAddress}:${builtins.toString config.services.prometheus.exporters.apcupsd.port}"
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
