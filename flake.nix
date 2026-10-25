{
  description = "HackiOS Fajita - XNU development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      clang = pkgs.llvmPackages.clang-unwrapped;
      lld = pkgs.llvmPackages.lld;

      # Tools for the development environment
      devPackages = with pkgs; [
        git
        bash
        python3
        android-tools
        dtc
        uv
        gnumake
        llvm
        clang
        lld
        patchelf
        curl
        perl
        xz
        gcc
        flex
        bison
        m4
        autoconf
        automake
      ];

      # Runtime libraries for the legacy Apple toolchain
      runtimePackages = with pkgs; [
        libuuid
        zlib
        ncurses5
        stdenv.cc.cc.lib
      ];

      runtimeLibs = pkgs.lib.makeLibraryPath (runtimePackages ++ [ pkgs.glibc ]);

      # FHS environment: the toolchain finds the loader and libraries
      # at the standard paths, so patchelf is not necessary.
      fhs = pkgs.buildFHSEnv {
        name = "hackios-fhs";

        targetPkgs =
          _:
          devPackages
          ++ runtimePackages
          ++ [
            pkgs.glibc.dev
          ];

        # Expose development headers inside the FHS filesystem
        extraOutputsToInstall = [ "dev" ];

        profile = ''
          export THEOS="$PWD/theos"

          export HACKIOS_CLANG="${clang}/bin/clang"
          export PATH="${clang}/bin:${lld}/bin:$PATH"

          export LD_LIBRARY_PATH="$THEOS/toolchain/linux/iphone/lib:$THEOS/toolchain/linux/iphone/lib64''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        '';

        runScript = "bash";
      };
    in
    {
      formatter.${system} = pkgs.nixfmt-rfc-style;

      packages.${system}.fhs = fhs;

      devShells.${system} = {
        # Default shell: FHS environment
        default = fhs.env;

        # Old shell: patches the downloaded binaries with patchelf
        patchelf = pkgs.mkShell {
          packages = devPackages;

          shellHook = ''
            # Project paths
            export THEOS="$PWD/theos"

            # Unwrapped LLVM toolchain for UEFI
            export HACKIOS_CLANG="${clang}/bin/clang"
            export PATH="${clang}/bin:${lld}/bin:$THEOS/toolchain/linux/iphone/bin:$PATH"

            # NixOS ELF interpreter
            export NIX_HOST_LOADER="${pkgs.stdenv.cc.bintools.dynamicLinker}"

            # Runtime libraries for legacy Apple toolchain
            export HACKIOS_LD64_LIB_PATH="$THEOS/toolchain/linux/iphone/lib:$THEOS/toolchain/linux/iphone/lib64:${runtimeLibs}"

            # Patch the downloaded ld64 binary when necessary
            LD64="$THEOS/toolchain/linux/iphone/bin/ld64"

            if [ -f "$LD64" ]; then
              CURRENT_INTERPRETER="$(patchelf --print-interpreter "$LD64")"
              CURRENT_RPATH="$(patchelf --print-rpath "$LD64")"

              if [ "$CURRENT_INTERPRETER" != "$NIX_HOST_LOADER" ] ||
                 [ "$CURRENT_RPATH" != "$HACKIOS_LD64_LIB_PATH" ]; then

                patchelf \
                  --set-interpreter "$NIX_HOST_LOADER" \
                  --force-rpath \
                  --set-rpath "$HACKIOS_LD64_LIB_PATH" \
                  "$LD64"

                echo "Patched ld64 for NixOS"
              fi
            fi

            # Fix runtime dependencies of the legacy LLVM LTO library
            LTO="$THEOS/toolchain/linux/iphone/lib/libLTO.so.10svn"

            if [ -f "$LTO" ] &&
               [ "$(patchelf --print-rpath "$LTO")" != "$HACKIOS_LD64_LIB_PATH" ]; then

              patchelf \
                --set-rpath "$HACKIOS_LD64_LIB_PATH" \
                "$LTO"

              echo "Patched libLTO for NixOS"
            fi
          '';
        };
      };
    };
}
