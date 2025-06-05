{ pkgs ? import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/25.05.tar.gz";
  }) {}
}:

pkgs.mkShellNoCC {
  packages = with pkgs; [
    typst
  ];
}
