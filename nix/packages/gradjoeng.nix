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
  makeDesktopItem,
  copyDesktopItems,
  dejavu_fonts,
  inter,
  makeFontsConf,
  release ? false,
}:

let
  inherit (stdenvNoCC.hostPlatform) isDarwin;
  preset = if isDarwin then "macOS" else "Linux";
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
  ] ++ lib.optionals (!isDarwin) [
    copyDesktopItems
  ];

  desktopItems = lib.optionals (!isDarwin) [
    (makeDesktopItem {
      name = "gradjoeng";
      desktopName = "Gradjöng";
      comment = "Live view of Gradient CI events";
      exec = "gradjoeng";
      icon = "gradjoeng";
      categories = [ "Development" ];
    })
  ];

  buildPhase = let
    templates = if isDarwin then
      "$HOME/Library/Application Support/Godot/export_templates/"
    else
      "$HOME/.local/share/godot/export_templates";
  in ''
    runHook preBuild

    export HOME=$TMPDIR
    godot --headless --path . --import
    mkdir -p build
  '' + (if release then ''
    mkdir -p "${templates}"
    ln -s ${godot.export-template}/share/godot/export_templates/* "${templates}"
    godot --headless --path . --export-release ${preset} ${if isDarwin then "build/gradjoeng.app" else "build/gradjoeng"}
  '' else ''
    godot --headless --path . --export-pack ${preset} build/gradjoeng.pck
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

  installPhase =
    ''
      runHook preInstall
      install -Dm644 icon.svg $out/share/icons/hicolor/scalable/apps/gradjoeng.svg
    ''
    + (
      if release then
        if isDarwin then ''
          mkdir -p $out/Applications
          cp -R build/gradjoeng.app $out/Applications/
          mkdir -p $out/bin
          makeWrapper $out/Applications/gradjoeng.app/Contents/MacOS/gradjoeng $out/bin/gradjoeng \
            --add-flags "--"
        ''
      else ''
          install -Dm755 build/gradjoeng $out/share/gradjoeng/gradjoeng
          mkdir -p $out/nix-support
          echo "file binary-dist $out/share/gradjoeng/gradjoeng" >> $out/nix-support/hydra-build-products
          makeWrapper $out/share/gradjoeng/gradjoeng $out/bin/gradjoeng \
            --add-flags "--" \
        ''
    else ''
      install -Dm644 build/gradjoeng.pck $out/share/gradjoeng/gradjoeng.pck
      makeWrapper ${lib.getExe godot} $out/bin/gradjoeng \
        --add-flags "--main-pack $out/share/gradjoeng/gradjoeng.pck --" \
    ''
    )
    + lib.optionalString (!isDarwin) ''
      --set-default FONTCONFIG_FILE ${fontsConf}
    ''
    + ''
      runHook postInstall
    '';

  meta = {
    description = "Live view of Gradient CI events";
    mainProgram = "gradjoeng";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
