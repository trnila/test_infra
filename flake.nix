{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.nextbike.url = "github:trnila/nextbike_rides_viewer";
  outputs =
    {
      self,
      nixpkgs,
      nextbike,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      nixosConfigurations.pi = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./configuration.nix
          nextbike.nixosModules.default

          (
            { modulesPath, ... }:
            {
              imports = [
                "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
              ];
              sdImage.compressImage = false;
            }
          )
        ];
      };
      sdImage = self.nixosConfigurations.pi.config.system.build.sdImage;

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixos-rebuild
              pkgs.prek
            ];
          };
        }
      );
    };
}
