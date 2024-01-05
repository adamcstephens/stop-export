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
          version = "6.7.0-rc8";
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
              hash = "sha256-qtmSSELuZfu3hTamcRv3rG8mPr8eI7rA1uVbyKSU4NI="; # https://github.com/jhovold/linux
              rev = "wip/sc8280xp-v6.7-rc8";
              # owner = "steev";
              # hash = "sha256-lg52pgvL3Js69DganSnSu+cQoyECj1OTgs49a7OWqg0=";
              # rev = "lenovo-x13s-v${version}"; # https://github.com/steev/linux/
            };
            kernelPatches = (args.kernelPatches or [ ]) ++ kp;

            extraMeta.branch = lib.versions.majorMinor version;
          }
          // (args.argsOverride or { })
        );
      # nurl https://github.com/kvalo/ath11k-firmware
      ath11k_fw_src = pkgs.fetchFromGitHub {
        name = "ath11k-firmware-src";
        owner = "kvalo";
        repo = "ath11k-firmware";
        rev = "5f72c2124a9b29b9393fb5e8a0f2e0abb130750f";
        hash = "sha256-l7tAxG7udr7gRHZuXRQNzWKtg5JJS+vayk44ZmisfKg=";
      };

      x13s-tplg = pkgs.fetchgit {
        name = "x13s-tplg-audioreach-topology";
        url = "https://git.linaro.org/people/srinivas.kandagatla/audioreach-topology.git";
        rev = "1ade4f466b05a86a7c7bdd51f719c08714580d14";
        hash = "sha256-GFGcm+KicTfNXSY8oMJlqBkrjdyb05C65hqK0vfCQvI=";
      };

      # nurl https://github.com/linux-surface/aarch64-firmware
      aarch64-fw = pkgs.fetchFromGitHub {
        name = "aarch64-fw-src";
        owner = "linux-surface";
        repo = "aarch64-firmware";
        rev = "9f07579ee64aba56419cfd0fbbca9f26741edc90";
        hash = "sha256-Lyav0RtoowocrhC7Q2Y72ogHhgFuFli+c/us/Mu/Ugc=";
      };
      # TODO: https://github.com/alsa-project/alsa-ucm-conf

      ath11k_fw = pkgs.runCommandNoCC "ath11k_fw" { } ''
        mkdir -p $out/lib/firmware/ath11k/
        cp -r --no-preserve=mode,ownership ${ath11k_fw_src}/* $out/lib/firmware/ath11k/

        ${remove-dupe-fw}
      '';

      cenunix_fw_src = pkgs.fetchzip {
        url = "https://github.com/cenunix/x13s-firmware/releases/download/1.0.0/x13s-firmware.tar.gz";
        sha256 = "sha256-cr0WMKbGeJyQl5S8E7UEB/Fal6FY0tPenEpd88KFm9Q=";
        stripRoot = false;
      };

      remove-dupe-fw = ''
        pushd ${pkgs.linux-firmware}
        shopt -s extglob
        shopt -s globstar
        for file in */**; do
          if [ -f "$file" ] && [ -f "$out/$file" ]; then
            echo "Duplicate file $file"
            rm -fv "$out/$file"
          fi
        done
        popd
      '';
    in
    rec {
      linux_x13s = pkgs.callPackage linux_x13s_pkg { defconfig = "johan_defconfig"; };

      x13s_extra_fw = pkgs.runCommandNoCC "x13s_extra_fw" { } ''
        mkdir -p $out/lib/firmware/qcom/sc8280xp/

        pushd "${cenunix_fw_src}"
        mkdir -p $out/lib/firmware/qcom/sc8280xp/LENOVO/21BX
        mkdir -p $out/lib/firmware/qca
        mkdir -p $out/lib/firmware/ath11k/WCN6855/hw2.0/
        cp -v my-repo/qcvss8280.mbn $out/lib/firmware/qcom/sc8280xp/LENOVO/21BX
        cp -v my-repo/hpnv21.8c $out/lib/firmware/qca/hpnv21.b8c
        popd

        # cp ${x13s-tplg}/prebuilt/qcom/sc8280xp/LENOVO/21BX/audioreach-tplg.bin $out/lib/firmware/qcom/sc8280xp/SC8280XP-LENOVO-X13S-tplg.bin
        # cp -r --no-preserve=mode,ownership ${x13s-tplg}/prebuilt/* $out/lib/firmware/

        cp -r --no-preserve=mode,ownership ${aarch64-fw}/firmware/qcom/* $out/lib/firmware/qcom/

        ${remove-dupe-fw}
      '';

      # see https://github.com/szclsya/x13s-alarm
      pd-mapper = pkgs.callPackage ./qrtr/pd-mapper.nix { inherit qrtr; };
      qrtr = pkgs.callPackage qrtr/qrtr.nix { };
      qmic = pkgs.callPackage qrtr/qmic.nix { };
      rmtfs = pkgs.callPackage qrtr/rmtfs.nix { inherit qmic qrtr; };
    }
  );
}
