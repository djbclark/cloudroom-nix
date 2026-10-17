{
  description = "NixOS module and packages for Cloudroom core (github.com/davidondrej/cloudroom-core)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAll (
        pkgs:
        {
          cloudroom-core = pkgs.callPackage ./pkgs/cloudroom-core.nix { };
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.cloudroom-core;
        }
        # Prebuilt downloads, pinned by hash: for hosts that should compile nothing.
        // nixpkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") (
          pkgs.callPackage ./pkgs/prebuilt.nix { }
        )
      );

      nixosModules.cloudroom = ./module.nix;
      nixosModules.default = self.nixosModules.cloudroom;

      overlays.default = final: _prev: {
        cloudroom-core = final.callPackage ./pkgs/cloudroom-core.nix { };
      };

      formatter = forAll (pkgs: pkgs.nixfmt-rfc-style);
    };
}
