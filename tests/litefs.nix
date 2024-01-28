{ pkgs, self, ... }:
pkgs.testers.runNixOSTest {
  name = "litefs";

  nodes.litefs = {
    imports = [ self.nixosModules.services-litefs ];
    services.litefs.mounts = {
      test = {
        user = "testuser";
        settings = {
          fuse.dir = "/srv/litefs/test";
          lease.type = "static";
        };
      };
    };

    users.users.testuser.isSystemUser = true;
    users.users.testuser.group = "users";
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("litefs-test.service")
  '';
}
