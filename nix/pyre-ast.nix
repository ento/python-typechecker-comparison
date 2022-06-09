{ lib,
  fetchFromGitHub,
  buildDunePackage,
  ocaml,
  ppx_sexp_conv,
  ppx_compare,
  ppx_hash,
  ppx_deriving,
  ppx_make,
  stdio,
  sexplib,
  cmdliner,
  odoc
}:
let
  dune = ''
synopsis: "Full-fidelity Python parser in OCaml"
description:
  "pyre-ast is an OCaml library to parse Python source files into abstract syntax trees. Under the hood, it relies on the CPython parser to do the parsing work and therefore the result is always 100% compatible with the official CPython implementation."
maintainer: ["grievejia@gmail.com"]
authors: ["Jia Chen"]
license: "MIT"
homepage: "https://github.com/grievejia/pyre-ast"
doc: "https://grievejia.github.io/pyre-ast/doc"
bug-reports: "https://github.com/grievejia/pyre-ast/issues"
depends: [
  "dune" {>= "2.8"}
  "base" {>= "v0.14.1"}
  "ppx_sexp_conv" {>= "v0.14.0"}
  "ppx_compare" {>= "v0.14.0"}
  "ppx_hash" {>= "v0.14.0"}
  "ppx_deriving" {>= "5.2.1"}
  "ppx_make" {>= "0.2.1"}
  "odoc" {with-doc}
]
build: [
  ["dune" "subst"] {dev}
  [
    "dune"
    "build"
    "-p"
    name
    "-j"
    jobs
    "@install"
    "@runtest" {with-test}
    "@doc" {with-doc}
  ]
]
dev-repo: "git+https://github.com/grievejia/pyre-ast.git"
'';
in
buildDunePackage rec {
  pname = "pyre-ast";
  version = "0.1.8";
  useDune2 = true;

  minimalOCamlVersion = "3.10";

  src = fetchFromGitHub {
    owner  = "grievejia";
    repo   = pname;
    rev    = version;
    sha256 = "sha256-fCVIG12vpHU4zASEF1vOPFSvQVZJaeTr61zm8tGs5P8=";
  };

  checkInputs = [
    stdio
    sexplib
    cmdliner
  ];
  buildInputs = [
    ppx_sexp_conv
    ppx_compare
    ppx_hash
    ppx_deriving
    ppx_make
    odoc
  ];
  doCheck = lib.versionAtLeast ocaml.version "3.10";

  meta = {
    homepage = "https://github.com/grievejia/pyre-ast";
    description = "Full-fidelity Python parser in OCaml";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}
