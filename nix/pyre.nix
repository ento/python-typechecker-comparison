{ lib,
  stdenv,
  fetchFromGitHub,
  ocamlPackages,
  writeScript,
  python3,
  python3Packages,
  rsync,
  buck,
  watchman,
  sqlite }:
let
  # Manually set version - the setup script requires
  # hg and git + keeping the .git directory around.
  version = "0.9.13";  # also change typeshed revision below with $pyre-src/.typeshed-version
  src = fetchFromGitHub {
    owner = "facebook";
    repo = "pyre-check";
    #rev = "v${version}"
    #sha256 = "sha256-YGReyAuH0LK9RsyMEnSn5XqSVsCMTilTBGvBsjp1VrE=";
    # First commit with passing build after https://github.com/facebook/pyre-check/commit/82693a802feec2d54d35cfc18e1ea4c5bb4583d5
    rev = "f15d93c0b68def7f0b58c4e4c3f0249b71dcf507";
    sha256 = "sha256-Mdr6QUUS2y2OoLwT+Xwhp6FVvg3M7alf0D4lzX5+D0w=";
  };
  versionFile = writeScript "version.ml" ''
    cat > "./version.ml" <<EOF
    open Core
    let build_info () =
    "pyre-nixpkgs ${version}"
    let version () =
    "${version}"

    let log_version_banner () =
      Log.info "Running as pid: %d" (Pid.to_int (Unix.getpid ()));
      Log.info "Version: %s" (version ());
      Log.info "Build info: %s" (build_info ())
    EOF

    cat > "./hack_parallel/hack_parallel/utils/get_build_id.c" <<EOF
    const char* const BuildInfo_kRevision = "${version}";
    const unsigned long BuildInfo_kRevisionCommitTimeUnix = 0ul;
    EOF
    '';
  ounit2-lwt = ocamlPackages.callPackage ./ounit2-lwt.nix {};
  ppx_make = ocamlPackages.callPackage ./ppx_make.nix {};
  pyre-ast = ocamlPackages.callPackage ./pyre-ast.nix { inherit ppx_make; };
  pyre-bin = stdenv.mkDerivation {
    inherit version src;
    pname = "pyre";

    # https://github.com/facebook/pyre-check/blob/v0.9.13/scripts/setup.py#L27-L40
    buildInputs = with ocamlPackages; [
      ocaml
      base64
      core
      re2
      dune_2
      ppx_deriving_yojson
      ounit
      menhir
      lwt
      ounit2
      ounit2-lwt
      pyre-ast
      mtime
      # python36Packages.python36Full # TODO
    ];
    nativeBuildInputs = with ocamlPackages; [ findlib ];
    propagatedBuildInputs = with ocamlPackages; [
      ppx_deriving
      ppx_sexp_message
      ppx_sexp_conv
    ];

    preBuild = ''
    # build requires HOME to be set
    export HOME=$TMPDIR

    # "external" because https://github.com/facebook/pyre-check/pull/8/files
    #sed "s/%VERSION%/external/" source/dune.in > source/dune
    substituteInPlace ./source/dune.in \
        --replace "-w A" "-w A-16"

    rm ./scripts/generate-version-number.sh
    ln -sf ${versionFile} ./scripts/generate-version-number.sh

    substituteInPlace ./scripts/setup.py \
        --replace "/usr/bin/env python3" "${python3}/bin/python3"

    patchShebangs ./scripts/setup.sh

    mkdir $(pwd)/build
    export OCAMLFIND_DESTDIR=$(pwd)/build
    export OCAMLPATH=$OCAMLPATH:$(pwd)/build

    cd source
    '';

    #makefile = "source/Makefile";

    buildFlags = ["dune" "release"];

    doCheck = true;
    # ./scripts/run-python-tests.sh # TODO: once typeshed and python bits are added

    # Note that we're not installing the typeshed yet.
    # Improvement for a future version.
    installPhase = ''
      install -D ./_build/default/main.exe $out/bin/pyre.bin
    '';

    meta = with lib; {
      description = "A performant type-checker for Python 3";
      homepage = https://pyre-check.org;
      license = licenses.mit;
      platforms = ocamlPackages.ocaml.meta.platforms;
      maintainers = with maintainers; [ teh ];
    };
  };
  pyre-extensions = python3Packages.callPackage ./pyre-extensions.nix {};
  testslide = python3Packages.callPackage ./testslide.nix {};
  typeshed = stdenv.mkDerivation {
    inherit version;
    pname = "typeshed";
    src = fetchFromGitHub {
      owner = "python";
      repo = "typeshed";
      rev = "acc0167dc19dec6873985ff9d84d28d66421e60a";
      sha256 = "sha256-9Sme8bnqCw4jRUEzakSaOLmXW7HEmYRjZDA0JQ3thxU=";
    };
    phases = [ "unpackPhase" "installPhase" ];
    installPhase = "cp -r $src $out";
  };
in python3.pkgs.buildPythonApplication {
  inherit version src;
  pname = "pyre-check";
  #patches = [ ./pyre-bdist-wheel.patch ];

  # The build-pypi-package script does some funky stuff with build
  # directories - easier to patch it a bit than to replace it
  # completely though:
  postPatch = ''
    mkdir ./build
    substituteInPlace scripts/pypi/build_pypi_package.py \
        --replace '"_build/default/main.exe"' '"${pyre-bin}/bin/pyre.bin"' \
        --replace 'Path(build_root)' 'Path("./build"); build_root = str(build_path.resolve())'
    #for file in client/pyre.py client/commands/initialize.py client/commands/tests/initialize_test.py; do
    #  substituteInPlace "$file" \
    #      --replace '"watchman"' '"${watchman}/bin/watchman"'
    #done
    #substituteInPlace client/buck.py \
    #   --replace '"buck"' '"${buck}/bin/buck"'
    #substituteInPlace client/tests/buck_test.py \
    #    --replace '"buck"' '"${buck}/bin/buck"'
  '';

  buildInputs = with python3.pkgs; [ pyre-bin twine ];
  nativeBuildInputs = [
    rsync # only required for build-pypi-package.sh
    testslide
  ];
  propagatedBuildInputs = with python3.pkgs; [
    async_generator
    click
    dataclasses-json
    intervaltree
    libcst
    psutil
    pyre-extensions
    tabulate
    typing-extensions
  ];
  buildPhase = ''
    bash scripts/run-python-tests.sh

    # TODO: better to do this before running tests
    substituteInPlace client/find_directories.py \
        --replace 'Path(sys.prefix)' "Path('$out')"

    PYTHONPATH=$PYTHONPATH:scripts python -m scripts.pypi --version ${version} --typeshed-path ${typeshed}
    cp -r scripts/dist dist
  '';
  doInstallCheck = false;
  dontUseSetuptoolsCheck = true;
}
