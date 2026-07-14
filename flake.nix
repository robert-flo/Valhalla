{
  description = "HyDE - HyprDots Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          ravnvm = import ./Scripts/ravnvm { inherit pkgs; };
        in
        {
          default = {
            type = "app";
            program = "${ravnvm.defaultPackage}/bin/ravnvm";
          };
          ravnvm = {
            type = "app";
            program = "${ravnvm.defaultPackage}/bin/ravnvm";
          };
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          ravnvm = import ./Scripts/ravnvm { inherit pkgs; };
        in
        {
          default = ravnvm.defaultPackage;
          ravnvm = ravnvm.defaultPackage;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              qemu
              curl
              python3
              git
              coreutils
              findutils
              gnused
              gawk
            ];
          };
        }
      );
    };
}
