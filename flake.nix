{
  description = "Dev shell with git, python3, android-tools, dtc and uv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
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
          ];
          shellHook = ''
          export HACKIOS_CLANG="${pkgs.llvmPackages.clang-unwrapped}/bin/clang"
          export PATH="${pkgs.llvmPackages.clang-unwrapped}/bin:${pkgs.llvmPackages.lld}/bin:$PATH"
	  export THEOS="$PWD/theos"
        '';
        };
      });
    };
}
