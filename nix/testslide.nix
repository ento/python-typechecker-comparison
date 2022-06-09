{ lib,
  buildPythonPackage,
  fetchPypi,
  psutil,
  pygments,
  typeguard
}:
buildPythonPackage rec {
  pname = "TestSlide";
  version = "2.7.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-I+zgufW3BLM7l46ch5eTYDRRatw8R0Pr2u1mSqcAw8s=";
  };
  propagatedBuildInputs = [
    psutil
    pygments
    typeguard
  ];
}
