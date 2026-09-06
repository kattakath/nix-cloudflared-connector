{
  description = "Nix flake — a hardened NixOS module for a boot-time, loginless Cloudflare Tunnel token connector (remotely-managed). Token via EnvironmentFile, never in argv or the Nix store.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-substituters = [ "https://kattakath.cachix.org" ];
    extra-trusted-public-keys = [
      "kattakath.cachix.org-1:y/w6wnb4ZArdlbfWJ82c81uCXeYgG/sGDUYCszavmEw="
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
    }:
    let
      inherit (nixpkgs) lib;
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      # The module only ever deploys on Linux, but the tree is EDITED on darwin —
      # so the formatter and its check must exist there too, or `nix fmt` on the
      # machine that actually runs it is a no-such-output error.
      fmtSystems = linuxSystems ++ [ "aarch64-darwin" ];
      forAll = systems: f: lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});

      # treefmt owns `nix fmt` and supplies its own `checks.treefmt` gate, pinned by
      # THIS flake's lock. Bare nixfmt as the formatter is a trap: `nix fmt` hands it
      # every file in the tree, README.md and LICENSE included, which it cannot parse.
      # upstream option treefmt-nix.lib.evalModule exists -> using it (the
      # non-flake-parts entry point; this flake is plain).
      treefmtEval = forAll fmtSystems (
        _: pkgs:
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
          programs.deadnix.enable = true;
          programs.statix.enable = true;
        }
      );
    in
    {
      nixosModules.cloudflared-connector = ./modules/cloudflared-connector.nix;
      nixosModules.default = self.nixosModules.cloudflared-connector;

      checks = forAll fmtSystems (
        system: pkgs:
        let
          sys = lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.default
              (_: {
                boot.loader.grub.enable = false;
                fileSystems."/" = {
                  device = "/dev/sda1";
                  fsType = "ext4";
                };
                system.stateVersion = "24.05";
                services.cloudflared-connector = {
                  enable = true;
                  tokenFile = "/run/cloudflared-token";
                  extraArgs = [
                    "--loglevel"
                    "debug"
                  ];
                };
              })
            ];
          };
          unit = sys.config.systemd.services.cloudflared-connector.serviceConfig;
        in
        {
          treefmt = treefmtEval.${system}.config.build.check self;
        }
        # Eval check: the module produces a hardened unit that reads the token from an
        # EnvironmentFile (never argv) and honours extraArgs. The fixture above is a
        # NixOS system, so it only exists where the module can actually be built.
        // lib.optionalAttrs (lib.elem system linuxSystems) {
          module-evaluates = pkgs.runCommand "cloudflared-connector-eval" { } ''
            test "${unit.EnvironmentFile}" = "/run/cloudflared-token"
            test "${lib.boolToString (unit.NoNewPrivileges && unit.MemoryDenyWriteExecute)}" = "true"
            case "${unit.ExecStart}" in
              *"tunnel run --loglevel debug") : ;;
              *) echo "unexpected ExecStart: ${unit.ExecStart}" >&2; exit 1 ;;
            esac
            echo ok > "$out"
          '';
        }
      );

      formatter = forAll fmtSystems (system: _: treefmtEval.${system}.config.build.wrapper);
    };
}
