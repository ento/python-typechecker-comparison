{ lib,
  buildPythonPackage,
  fetchPypi,
  typing-extensions,
  typing-inspect
}:
buildPythonPackage rec {
  pname = "pyre-extensions";
  version = "0.0.27";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-dnYHc21dLaTbM3fgFnRndqGVmH+zxhx7OLRCFg5ndx8=";
  };
  propagatedBuildInputs = [
    typing-extensions
    typing-inspect
  ];
}
