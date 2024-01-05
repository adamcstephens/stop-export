{
  lib,
  pkgs,
  routerCommon,
  self,
}:
pkgs.testers.runNixOSTest {
  name = "bgp-routing";

  nodes = {
    router = lib.recursiveUpdate routerCommon {
      config.stop.roles.router = {
        bgp = {
          enable = true;
          neighbors = {
            client.address = "192.168.1.1";
          };
        };
      };
    };

    client = {
      imports = [
        ../roles/grid/exabgp.nix
        self.nixosModules.services-exabgp
      ];
      stop.roles.grid.bgp.enable = true;
    };
  };

  testScript = ''
    start_all()

    router.wait_for_unit("network-online.target")
    client.wait_for_unit("network-online.target")
    client.wait_for_unit("exabgp.service")
  '';
}
