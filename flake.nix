{
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.tar.gz";
    flake-utils.url = "github:numtide/flake-utils";
    native-sdk = {
      # Pin the published v0.5.1 tag commit explicitly. The upstream repo also
      # has a branch named v0.5.1, so a symbolic ref would be ambiguous.
      url = "github:vercel-labs/native?rev=f7aa92af6dcece250feba852af4d22e7f5429312";
      flake = false;
    };
  };

  outputs = inputs@{ nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        nativeCli = pkgs.stdenv.mkDerivation {
          pname = "native-sdk-cli";
          version = "0.5.1";
          src = inputs.native-sdk;
          nativeBuildInputs = [ pkgs.zig ];
          dontConfigure = true;

          buildPhase = ''
            runHook preBuild
            export HOME="$TMPDIR"
            export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
            export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
            zig build cli -Doptimize=ReleaseFast --prefix native-cli-out
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p "$out/bin"
            cp native-cli-out/bin/native "$out/bin/native"
            runHook postInstall
          '';
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            nativeCli
            pkgs.git
            pkgs.jq
            pkgs.ripgrep
            pkgs.zig
          ];

          shellHook = ''
            export ZEIT_DEV_SHELL=1
            export NATIVE_SDK_PATH="${inputs.native-sdk}"
            export NATIVE_SDK_SKILLS_ROOT="${inputs.native-sdk}"
          '';
        };
      }
    );
}
