{
  description = "Gradjöng: live view of Gradient CI events";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }: (utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs { inherit system; };
  in {
    packages = rec {
      gradjoeng = pkgs.callPackage ./nix/packages/gradjoeng.nix { };
      default = gradjoeng;
    };

    checks.gradjoeng = self.packages.${system}.gradjoeng;

    devShells.default = pkgs.mkShell {
      packages = [
        (pkgs.python3.withPackages (ps: self.packages.${system}.gradjoeng.dependencies ++ [ ps.pytest ]))
      ];
      shellHook = ''
        export PYTHONPATH="$PWD/src''${PYTHONPATH:+:$PYTHONPATH}"
      '';
    };
  }));
}
