{
  perSystem =
    {
      inputs',
      lib,
      pkgs,
      self',
      ...
    }:
    let
      stop = (import ../hosts/stop.nix { inherit lib; }).stop;
      site = stop.sites.${stop.site.content};
    in
    {
      packages.flake-tools =
        pkgs.runCommandNoCC "flake-tools"
          {
            nativeBuildInputs = [ pkgs.makeWrapper ];
            buildInputs = [ pkgs.nushell ];
          }
          ''
            mkdir -p $out/bin
            cp ${../bin/flake-build} $out/bin/flake-build
            patchShebangs $out/bin

            wrapProgram $out/bin/flake-build --prefix PATH : ${
              lib.makeBinPath [
                inputs'.attic.packages.attic
                pkgs.coreutils
                pkgs.nix
                pkgs.nix-eval-jobs
              ]
            }
          '';

      packages.docker-image =
        let
          nvfetcher = import ../_sources/generated.nix {
            inherit (pkgs)
              fetchgit
              fetchurl
              fetchFromGitHub
              dockerTools
              ;
          };
        in
        pkgs.dockerTools.streamLayeredImage {
          name = "${stop.hostnames.git}/adam/stop-builder";

          fromImage = nvfetcher."nix-${pkgs.system}".src.outPath;
          tag = "latest-${pkgs.system}";

          # upstream nix image is using 100 layers already
          maxLayers = 115;

          contents = [
            self'.packages.flake-tools
            # act expects nodejs
            pkgs.nodejs

            (pkgs.writeTextFile {
              name = "nix.conf";
              destination = "/etc/nix/nix.conf";
              text = ''
                builders-use-substitutes = true
                experimental-features = nix-command flakes
                extra-substituters = ${site.nix.cache}
                extra-trusted-public-keys = ${site.nix.publicKey}
                store = unix:///host/nix/var/nix/daemon-socket/socket?root=/host
              '';
            })
          ];

          # forgejo uses /bin/sleep as the entrypoint
          extraCommands = ''
            mkdir -p bin
            ln -s ${pkgs.coreutils}/bin/sleep bin/sleep
          '';

          # replace the entire path so we can prepend /bin
          config.Env = [
            "PATH=/bin:/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin"
          ];
        };
    };
}
