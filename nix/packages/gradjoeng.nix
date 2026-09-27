{
  lib,
  stdenvNoCC,
  godot,
  makeWrapper,
  dejavu_fonts,
  inter,
  makeFontsConf,
}:

let
  fontsConf = makeFontsConf { fontDirectories = [
    dejavu_fonts
    inter
  ]; };
in
stdenvNoCC.mkDerivation {
  pname = "gradjoeng";
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
    godot --headless --path . --export-pack Linux gradjoeng.pck
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
    install -Dm644 gradjoeng.pck $out/share/gradjoeng/gradjoeng.pck
    makeWrapper ${godot}/bin/godot $out/bin/gradjoeng \
      --add-flags "--main-pack $out/share/gradjoeng/gradjoeng.pck --" \
      --set-default FONTCONFIG_FILE ${fontsConf}
    runHook postInstall
  '';

  meta = {
    description = "Live view of Gradient CI events";
    mainProgram = "gradjoeng";
    platforms = lib.platforms.linux;
  };
}
