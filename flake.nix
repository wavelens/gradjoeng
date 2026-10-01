/*
 * SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: MIT
 */

{
  description = "Gradjöng: live view of Gradient CI events";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: {
    overlays.default = final: prev: {
      gradjoeng = final.callPackage ./nix/packages/gradjoeng.nix { release = true; };
    };

    nixosModules.default = {
      nixpkgs.overlays = [ self.overlays.default ];
    };
  } // (flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ self.overlays.default ];
    };
  in {
    packages = {
      gradjoeng = pkgs.callPackage ./nix/packages/gradjoeng.nix { };
      release = pkgs.gradjoeng;
      default = pkgs.gradjoeng;
    };

    checks.gradjoeng = self.packages.${system}.gradjoeng;

    devShells.default = pkgs.mkShell {
      packages = [ pkgs.godot ];
    };
  }));
}
