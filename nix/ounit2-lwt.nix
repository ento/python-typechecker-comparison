{ lib,
  fetchFromGitHub,
  buildDunePackage,
  ocaml,
  lwt,
  seq,
  ounit2,
}:
buildDunePackage rec {
  pname = "ounit2-lwt";
  version = "2.2.6";
  useDune2 = true;

  src = fetchFromGitHub {
    owner  = "gildor478";
    repo   = "ounit";
    rev    = "v${version}";
    sha256 = "sha256-4R5A0Xrln48FvpWcjUS2K1qk4x0cDA7OkNGLeWEgiBE=";
  };

  checkInputs = [ ounit2 ];
  buildInputs = [
    lwt
    seq
    ounit2
  ];

  meta = {
    homepage = "https://github.com/gildor478/ounit";
    description = "OUnit testing framework (Lwt)";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}
