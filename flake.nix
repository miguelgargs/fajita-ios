{
  description = "Dev shell with git, python3, android-tools, dtc and uv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            git
            python3
            android-tools
            dtc
            uv
            llvm
            patchelf
          ];
          shellHook = ''
                      export HACKIOS_CLANG="${pkgs.llvmPackages.clang-unwrapped}/bin/clang"
                      export PATH="${pkgs.llvmPackages.clang-unwrapped}/bin:${pkgs.llvmPackages.lld}/bin:$PATH"
            	        export THEOS="$PWD/theos"
            	        export NIX_HOST_LOADER="${pkgs.stdenv.cc.bintools.dynamicLinker}"
            	        export HACKIOS_LD64_LIB_PATH="$THEOS/toolchain/linux/iphone/lib:$THEOS/toolchain/linux/iphone/lib64:${
                       pkgs.lib.makeLibraryPath [
                         pkgs.libuuid
                         pkgs.stdenv.cc.cc.lib
                         pkgs.glibc
                         pkgs.zlib
                         pkgs.ncurses5
                       ]
                     }"
                      # Patch the downloaded linker for NixOS
            LD64="$THEOS/toolchain/linux/iphone/bin/ld64"
            NIX_INTERPRETER="${pkgs.stdenv.cc.bintools.dynamicLinker}"

            if [ -f "$LD64" ]; then
              if [ "$(patchelf --print-interpreter "$LD64")" != "$NIX_INTERPRETER" ] ||
                 [ "$(patchelf --print-rpath "$LD64")" != "$HACKIOS_LD64_LIB_PATH" ]; then

                patchelf \
                  --set-interpreter "$NIX_INTERPRETER" \
                  --force-rpath \
                  --set-rpath "$HACKIOS_LD64_LIB_PATH" \
                  "$LD64"

                echo "Patched ld64 for NixOS"
              fi
            fi
          '';
        };
      });
    };
}
