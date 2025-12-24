{
  description = "Traggo UI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        traggo-server-src = pkgs.fetchFromGitHub {
          owner = "traggo";
          repo = "server";
          rev = "v0.7.1";
          sha256 = "0zc95iclvbc9v2yyjl4jmm8amg400704q98y3amzqrx9s9lrf5ag";
        };

      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "traggo-ui";
          version = "0.7.1";

          src = "${traggo-server-src}/ui";

          yarnOfflineCache = pkgs.fetchYarnDeps {
            yarnLock = "${traggo-server-src}/ui/yarn.lock";
            hash = "sha256-BDQ7MgRWBRQQfjS5UCW3KJ0kJrkn4g9o4mU0ZH+vhX0=";
          };

          nativeBuildInputs = with pkgs; [
            yarn
            nodejs
            yarnConfigHook
            yarnBuildHook
          ];

          env.NODE_OPTIONS = "--openssl-legacy-provider";

          preBuild = ''
            ln -s ${traggo-server-src}/schema.graphql ../schema.graphql
            yarn --offline generate
          '';

          installPhase = ''
            runHook preInstall
            cp -r build $out
            runHook postInstall
          '';
        };
      }
    );
}
