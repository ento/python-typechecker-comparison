{ lib,
  fetchFromGitHub,
  buildDunePackage,
  ocaml,
  ppxlib,
  ounit2,
  odoc
}:
buildDunePackage rec {
  pname = "ppx_make";
  version = "0.3.0";
  useDune2 = true;

  src = fetchFromGitHub {
    owner  = "bn-d";
    repo   = pname;
    rev    = "v${version}";
    sha256 = "sha256-7/2Tgbito7ksfFUYuKVOtHj0oI1Lxunr7HbiuwoHa+M=";
  };

  checkInputs = [ ounit2 ];
  buildInputs = [
    ppxlib
    odoc
  ];

  meta = {
    homepage = "https://github.com/bn-d/ppx_make";
    description = "Ppxlib based make deriver";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}
