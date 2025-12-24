{
  description = "Traggo Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        traggoSource = pkgs.fetchFromGitHub {
          owner = "traggo";
          repo = "server";
          rev = "v0.7.1";
          sha256 = "0zc95iclvbc9v2yyjl4jmm8amg400704q98y3amzqrx9s9lrf5ag";
        };

        traggoUi = pkgs.stdenv.mkDerivation {
          pname = "traggo-ui";
          version = "0.7.1";

          src = "${traggoSource}/ui";

          yarnOfflineCache = pkgs.fetchYarnDeps {
            yarnLock = "${traggoSource}/ui/yarn.lock";
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
            ln -s ${traggoSource}/schema.graphql ../schema.graphql
            yarn --offline generate
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -R build/. $out/
            runHook postInstall
          '';
        };

        gqlgen_0_17_53 = pkgs.buildGoModule rec {
          pname = "gqlgen";
          version = "0.17.53";
          src = pkgs.fetchFromGitHub {
            owner = "99designs";
            repo = "gqlgen";
            rev = "v${version}";
            sha256 = "05xirhw62n40sv33s3xsg7sf447iqi46032jyll1pdlc6dfp3f4f";
          };
          vendorHash = "sha256-XqfO5xpmM+tumnhUjXuvWdQLs6HWVDG+TTomcBTMGk8=";
          
          doCheck = false;

          preBuild = ''
            cp vendor/go.mod.saved go.mod
            cp vendor/go.sum.saved go.sum
          '';

          overrideModAttrs = old: {
            preBuild = ''
              go get golang.org/x/tools@latest
              go mod tidy
            '';
            installPhase = ''
              go mod vendor
              mkdir -p $out
              cp -r vendor/* $out/
              cp go.mod $out/go.mod.saved
              cp go.sum $out/go.sum.saved
            '';
          };
        };
      in
      {
        packages.default = pkgs.buildGoModule {
          pname = "traggo-server";
          version = "0.7.1";

          src = traggoSource;

          proxyVendor = true;
          vendorHash = "sha256-7zaJpL0L7b0KwkKX1ifbzwqz9QihmDg/bhx0g0d6B/M=";

          nativeBuildInputs = [ gqlgen_0_17_53 ];

          preBuild = ''
            export HOME=$TMPDIR
            
            # Copy the built frontend assets
            mkdir -p ui/build
            cp -r ${traggoUi}/* ui/build/

            # Generate Go code using gqlgen from nixpkgs
            export GOCACHE=$TMPDIR/go-cache
            # gqlgen runs go mod tidy which might fail due to missing test deps in proxy.
            gqlgen generate || true
            
            if [ ! -f generated/gqlmodel/generated.go ]; then
               echo "gqlgen generation failed!"
               exit 1
            fi
          '';

          tags = [ "netgo" "osusergo" "sqlite_omit_load_extension" ];
          ldflags = [
            "-s" "-w"
            "-X main.BuildMode=prod"
          ];
          
          doCheck = false;
        };
        
        packages.ui = traggoUi;
      }
    );
}
