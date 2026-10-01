/*
 * SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: MIT
 */

{
  lib,
  stdenvNoCC,
  godot,
  makeWrapper,
  dejavu_fonts,
  inter,
  makeFontsConf,
  release ? false,
}:

let
  fontsConf = makeFontsConf { fontDirectories = [
    dejavu_fonts
    inter
  ]; };
in
stdenvNoCC.mkDerivation {
  pname = if release then "gradjoeng-release" else "gradjoeng";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../..;
    fileset = lib.fileset.unions [
      ../../project.godot
      ../../export_presets.cfg
      ../../main.tscn
      ../../icon.svg
      ../../src
      ../../tests
    ];
  };

  nativeBuildInputs = [
    godot
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    godot --headless --path . --import
    mkdir -p build
  '' + (if release then ''
    mkdir -p $HOME/.local/share/godot/export_templates
    ln -s ${godot.export-template}/share/godot/export_templates/* $HOME/.local/share/godot/export_templates/
    godot --headless --path . --export-release Linux build/gradjoeng
  '' else ''
    godot --headless --path . --export-pack Linux build/gradjoeng.pck
  '') + ''
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    patchShebangs tests/run.sh
    tests/run.sh
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
  '' + (if release then ''
    install -Dm755 build/gradjoeng $out/share/gradjoeng/gradjoeng
    mkdir -p $out/nix-support
    echo "file binary-dist $out/share/gradjoeng/gradjoeng" >> $out/nix-support/hydra-build-products
    makeWrapper $out/share/gradjoeng/gradjoeng $out/bin/gradjoeng \
      --add-flags "--" \
  '' else ''
    install -Dm644 build/gradjoeng.pck $out/share/gradjoeng/gradjoeng.pck
    makeWrapper ${lib.getExe godot} $out/bin/gradjoeng \
      --add-flags "--main-pack $out/share/gradjoeng/gradjoeng.pck --" \
  '') + ''
      --set-default FONTCONFIG_FILE ${fontsConf}
    runHook postInstall
  '';

  meta = {
    description = "Live view of Gradient CI events";
    mainProgram = "gradjoeng";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
