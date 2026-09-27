{
  lib,
  python3Packages,
  dejavu_fonts,
  fontconfig,
  makeFontsConf,
  mesa,
}:

let
  fontsConf = makeFontsConf { fontDirectories = [ dejavu_fonts ]; };
in
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "gradjoeng";
  version = "0.1.0";
  pyproject = true;

  src = lib.fileset.toSource {
    root = ../..;
    fileset = lib.fileset.unions [
      ../../pyproject.toml
      ../../src
      ../../tests
    ];
  };

  build-system = with python3Packages; [
    setuptools
  ];

  dependencies = with python3Packages; [
    moderngl
    pygame-ce
    websockets
  ];

  makeWrapperArgs = [
    "--unset PYTHONPATH"
    "--set-default FONTCONFIG_FILE ${fontsConf}"
    "--prefix PATH : ${lib.makeBinPath [ fontconfig ]}"
  ];

  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
  ] ++ [ fontconfig ];

  pytestFlags = [ "-rs" ];

  preCheck = ''
    export HOME=$(mktemp -d)
    export FONTCONFIG_FILE=${fontsConf}
    export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
    export __EGL_VENDOR_LIBRARY_DIRS=${mesa}/share/glvnd/egl_vendor.d
    export EGL_PLATFORM=surfaceless LIBGL_ALWAYS_SOFTWARE=1
  '';

  pythonImportsCheck = [ "gradjoeng" ];

  meta = {
    description = "Live view of Gradient CI events";
    homepage = "https://github.com/wavelens/gradient";
    mainProgram = "gradjoeng";
  };
})
