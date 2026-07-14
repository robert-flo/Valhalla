{
  pkgs ? import <nixpkgs> { },
}:

let
  ravnvm = pkgs.writeShellApplication {
    name = "ravnvm";
    runtimeInputs = with pkgs; [
      qemu
      curl
      git
      openssh
      coreutils
      findutils
      gnused
      gawk
    ];
    text = builtins.readFile ./ravnvm.sh;
  };
in
{
  defaultPackage = ravnvm;

  mkRavnVM =
    {
      memory ? "4G",
      cpus ? 2,
      extraArgs ? "",
    }:
    pkgs.writeShellApplication {
      name = "run-ravnvm";
      runtimeInputs = [ ravnvm ];
      text = ''
        VM_MEMORY="${memory}" VM_CPUS="${toString cpus}" VM_EXTRA_ARGS="${extraArgs}" ravnvm "$@"
      '';
    };
}
