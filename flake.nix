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
      formatter.${system} = pkgs.nixfmt-rfc-style;

      runtimeLibs = pkgs.lib.makeLibraryPath [
        pkgs.libuuid
        pkgs.zlib
        pkgs.ncurses5
        pkgs.stdenv.cc.cc.lib
        pkgs.glibc
      ];
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
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
          gnumake
          gcc
        ];

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
}
