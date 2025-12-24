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

          src = pkgs.fetchFromGitHub {
            owner = "traggo";
            repo = "server";
            rev = "v0.7.1";
            sha256 = "0zc95iclvbc9v2yyjl4jmm8amg400704q98y3amzqrx9s9lrf5ag";
          };

          proxyVendor = true;
          vendorHash = "sha256-7zaJpL0L7b0KwkKX1ifbzwqz9QihmDg/bhx0g0d6B/M=";

          nativeBuildInputs = [ gqlgen_0_17_53 ];

          preBuild = ''
            export HOME=$TMPDIR
            
            # Generate dummy UI files (Frontend build skipped due to legacy dependency incompatibilities)
            mkdir -p ui/build
            touch ui/build/index.html
            touch ui/build/manifest.json
            touch ui/build/service-worker.js
            touch ui/build/asset-manifest.json
            touch ui/build/favicon.ico
            touch ui/build/favicon-16x16.png
            touch ui/build/favicon-32x32.png
            touch ui/build/favicon-192x192.png
            touch ui/build/favicon-256x256.png

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
      }
    );
}
