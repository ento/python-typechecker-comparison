{ pkgs ? import <nixpkgs> {}
}:
let
  pyre = pkgs.callPackage ./nix/pyre.nix {};
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    buck
    hyperfine
    ninja
    nodejs
    pyre
    python3
    watchman
    yarn
  ];
  shellHook = ''
    # Fix "ImportError: libstdc++.so.6: cannot open shared object file: No such file"
    # Taken from: https://nixos.wiki/wiki/Packaging/Quirks_and_Caveats
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib/:$LD_LIBRARY_PATH

    if [ ! -d env ]; then
      python3 -m venv env
    fi
    . env/bin/activate
    # Use ninja installed by Nix
    if pip freeze | grep ninja; then
      pip uninstall ninja
    fi
  '';
}
