{ lib, withSystem, ... }:
{
  flake.packages.aarch64-linux = withSystem "aarch64-linux" (
    { pkgs, self', ... }:
    let
      kp = [
        {
          name = "x13s-cfg";
          patch = null;
          extraStructuredConfig = with lib.kernel; {
            EFI_ARMSTUB_DTB_LOADER = lib.mkForce yes;
            OF_OVERLAY = lib.mkForce yes;
            BTRFS_FS = lib.mkForce yes;
            BTRFS_FS_POSIX_ACL = lib.mkForce yes;
            MEDIA_CONTROLLER = lib.mkForce yes;
            SND_USB_AUDIO_USE_MEDIA_CONTROLLER = lib.mkForce yes;
            SND_USB = lib.mkForce yes;
            SND_USB_AUDIO = lib.mkForce module;
            USB_XHCI_PCI = lib.mkForce module;
            NO_HZ_FULL = lib.mkForce yes;
            HZ_100 = lib.mkForce yes;
            HZ_250 = lib.mkForce no;
            DRM_AMDGPU = lib.mkForce no;
            DRM_NOUVEAU = lib.mkForce no;
            QCOM_TSENS = lib.mkForce yes;
            NVMEM_QCOM_QFPROM = lib.mkForce yes;
            ARM_QCOM_CPUFREQ_NVMEM = lib.mkForce yes;
            VIRTIO_PCI = lib.mkForce module;
            # QCOM_PD_MAPPER = lib.mkForce module;
          };
        }
      ];

      linux_x13s_pkg =
        { buildLinux, ... }@args:
        let
          version = "6.7.0";
          modDirVersion = "${version}";
        in
        # rev = "b8cd563c115473e27fa4778c1eca7b25f6f9a7ee";
        buildLinux (
          args
          // {
            inherit version modDirVersion;

            src = pkgs.fetchFromGitHub {
              repo = "linux";
              name = "x13s-linux-${modDirVersion}";
              owner = "jhovold";
              hash = "sha256-7LSxxXtTitbBKFlFJtlfhBgY6Ld0/1cbP3SBAk15ZRc="; # https://github.com/jhovold/linux
              rev = "wip/sc8280xp-v6.7";
              # owner = "steev";
              # hash = "sha256-lg52pgvL3Js69DganSnSu+cQoyECj1OTgs49a7OWqg0=";
              # rev = "lenovo-x13s-v${version}"; # https://github.com/steev/linux/
            };
            kernelPatches = (args.kernelPatches or [ ]) ++ kp;

            extraMeta.branch = lib.versions.majorMinor version;
          }
          // (args.argsOverride or { })
        );
    in
    {
      "x13s/linux" = pkgs.callPackage linux_x13s_pkg { defconfig = "johan_defconfig"; };

      pd-mapper = pkgs.callPackage ./qrtr/pd-mapper.nix { inherit (self'.packages) qrtr; };
      qrtr = pkgs.callPackage qrtr/qrtr.nix { };

      "x13s/uefi-firmware" = pkgs.callPackage ./uefi-firmware.nix { };
      "x13s/uefi-image" = pkgs.callPackage ./uefi-image.nix {
        uefi-firmware = self'.packages."x13s/uefi-firmware";
      };

      "x13s/extra-firmware" = pkgs.callPackage ./extra-firmware.nix { };
    }
  );
}
