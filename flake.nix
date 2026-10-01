/*
 * SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: MIT
 */

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
      release = pkgs.callPackage ./nix/packages/gradjoeng.nix { release = true; };
      default = gradjoeng;
    };

    checks.gradjoeng = self.packages.${system}.gradjoeng;

    devShells.default = pkgs.mkShell {
      packages = [ pkgs.godot ];
    };
  }));
}
