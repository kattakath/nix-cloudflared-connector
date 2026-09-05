{
  description = "Nix flake — a hardened NixOS module for a boot-time, loginless Cloudflare Tunnel token connector (remotely-managed). Token via EnvironmentFile, never in argv or the Nix store.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  nixConfig = {
    extra-substituters = [ "https://kattakath.cachix.org" ];
    extra-trusted-public-keys = [
      "kattakath.cachix.org-1:y/w6wnb4ZArdlbfWJ82c81uCXeYgG/sGDUYCszavmEw="
    ];
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = systems: f: lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in
    {
      nixosModules.cloudflared-connector = ./modules/cloudflared-connector.nix;
      nixosModules.default = self.nixosModules.cloudflared-connector;

      # Eval check: the module produces a hardened unit that reads the token from an
      # EnvironmentFile (never argv) and honours extraArgs.
      checks = forAll linuxSystems (
        system: pkgs:
        let
          sys = lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.default
              (
                { ... }:
                {
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
                }
              )
            ];
          };
          unit = sys.config.systemd.services.cloudflared-connector.serviceConfig;
        in
        {
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

      formatter = forAll linuxSystems (_: pkgs: pkgs.nixfmt-rfc-style);
    };
}
