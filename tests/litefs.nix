{ pkgs, self, ... }:
pkgs.testers.runNixOSTest {
  name = "litefs";

  nodes.litefs = {
    imports = [ self.nixosModules.services-litefs ];

    config = {
      services.litefs.mounts = {
        test = {
          user = "testuser";
          settings = {
            fuse.dir = "/srv/litefs/test";
            lease.type = "static";
          };
        };
      };

      users.users.testuser = {
        iSystemUser = true;
        group = "users";
      };
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("litefs-test.service")
  '';
}
