{
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.tar.gz";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            bun
            git
            jq
            nodejs_24
            ripgrep
            zig
          ];

          shellHook = ''
            export ZEIT_DEV_SHELL=1
            export NATIVE_SDK_SKILLS_ROOT="$PWD/node_modules/@native-sdk/cli"
          '';
        };
      }
    );
}
