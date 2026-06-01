{
  description = "whyCARE OS - Autonomous Control Plane";

  # ── Architectural Dependencies ──
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    lanzaboote.url = "github:nix-community/lanzaboote";
    niri-flake.url = "github:sodiboo/niri-flake";
    hyprland.url = "github:hyprwm/Hyprland";

    # ── Fish plugins (no longer in nixpkgs, use flake inputs) ──
    fish-bobthefish-theme = {
      url = "github:oh-my-fish/theme-bobthefish";
      flake = false;
    };
    fish-keytool-completions = {
      url = "github:Jomik/fish-keytool";
      flake = false;
    };

    rycee-nurpkgs = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ── Deployment Graph ──
  outputs = inputs@{ self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # ── HM with fish plugins from inputs ──
      malachi-config = import ./home/default.nix;
    in
    {
      # ── NixOS system config ──
      nixosConfigurations = {
        coffin = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            # 1. Base Host State
            ./system/host/coffin/default.nix

            # 2. Autonomous Ingestion Router
            ./system/host/coffin/ingested/default.nix

            # 3. Comin GitOps Daemon Integration
            inputs.comin.nixosModules.comin
            ./modules/nixos/comin-daemon/default.nix

            # 4. Third-Party Modules
            inputs.sops-nix.nixosModules.sops
            inputs.lanzaboote.nixosModules.lanzaboote
            inputs.niri-flake.nixosModules.niri
            inputs.hyprland.nixosModules.default
            inputs.home-manager.nixosModules.home-manager

            # 5. Nixpkgs Config + Core Daemon Trust & Caching
            {
              nixpkgs.config.allowUnfree = true;

              nix.settings = {
                trusted-users = [ "root" "malachi" ];
                substituters = [
                  "https://cache.nixos.org"
                  "https://nix-community.cachix.org"
                  "https://niri.cachix.org"
                  "https://hyprland.cachix.org"
                ];
                trusted-public-keys = [
                  "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBc="
                  "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
                  "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
                ];
              };
            }

            # 6. rycee firefox-addons overlay
            {
              nixpkgs.overlays = [
                (final: prev: {
                  inherit (inputs.rycee-nurpkgs.lib.x86_64-linux) buildFirefoxXpiAddon;
                })
              ];
            }

            # 7. Fish plugins overlay
            {
              nixpkgs.overlays = [
                (final: prev: {
                  fish-bobthefish-theme = inputs.fish-bobthefish-theme;
                  fish-keytool-completions = inputs.fish-keytool-completions;
                })
              ];
            }

            # 8. User Environment Generation
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  addons = inputs.rycee-nurpkgs.packages.x86_64-linux;
                };
                users.malachi = malachi-config;
              };
            }
          ];
        };
      };

      # ── Home-Manager standalone (for `home-manager switch` CLI) ──
      homeConfigurations.malachi = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs;
          addons = inputs.rycee-nurpkgs.packages.x86_64-linux;
        };
        modules = [
          malachi-config
          {
            nixpkgs.overlays = [
              (final: prev: {
                fish-bobthefish-theme = inputs.fish-bobthefish-theme;
                fish-keytool-completions = inputs.fish-keytool-completions;
              })
            ];
          }
        ];
      };
    };
}
