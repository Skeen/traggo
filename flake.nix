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
      in
      {
        packages.default = pkgs.buildGoModule {
          pname = "traggo-server";
          version = "0.0.1";
          src = ./.;

          proxyVendor = true;
          vendorHash = "sha256-tTwuxCwJmvUeaiI7Ku0E1RIsL60/ml3RHaZzbQ5YnDo=";

          nativeBuildInputs = [ pkgs.gqlgen ];

          # Fix for go mod failing due to missing generated internal packages
          overrideModAttrs = old: {
            preBuild = ''
              mkdir -p generated/gqlmodel generated/gqlschema
              echo "package gqlmodel" > generated/gqlmodel/dummy.go
              echo "package gqlschema" > generated/gqlschema/dummy.go
              
              echo 'package main; import _ "github.com/99designs/gqlgen/graphql"' > tools.go
              
              # Update go.sum for the new dependency and update tools
              export GOMODCACHE=$TMPDIR/go-mod-cache
              go get golang.org/x/tools@latest github.com/99designs/gqlgen@latest
              go mod tidy
            '';
            
            installPhase = ''
              mkdir -p $out
              export GOMODCACHE=$TMPDIR/modcache
              # We need to download modules based on the modified go.mod
              go mod download
              
              # Copy the download cache to output (GOPROXY structure)
              cp -r $TMPDIR/modcache/cache/download/* $out
              
              # Save the modified go.mod/sum
              cp go.mod $out/go.mod.saved
              cp go.sum $out/go.sum.saved
            '';
          };

          preBuild = ''
            export HOME=$TMPDIR
            
            # Restore go.mod/sum from cached copy in goModules
            GO_MODULES_PATH=$(echo $GOPROXY | sed 's|file://||')
            cp $GO_MODULES_PATH/go.mod.saved go.mod
            cp $GO_MODULES_PATH/go.sum.saved go.sum
            
            # Re-create tools.go
            echo 'package main; import _ "github.com/99designs/gqlgen/graphql"' > tools.go

            # Create dummy generated files so gqlgen can load the package structure if needed
            mkdir -p generated/gqlmodel generated/gqlschema
            echo "package gqlmodel" > generated/gqlmodel/dummy.go
            echo "package gqlschema" > generated/gqlschema/dummy.go

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
