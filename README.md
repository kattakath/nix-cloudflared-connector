# nix-cloudflared-connector

[![CI](https://github.com/ismailkattakath/nix-cloudflared-connector/actions/workflows/ci.yml/badge.svg)](https://github.com/ismailkattakath/nix-cloudflared-connector/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Built with Nix](https://img.shields.io/badge/built%20with-Nix-5277C3.svg?logo=nixos&logoColor=white)](https://nixos.org)

**A hardened NixOS module for a boot-time, loginless Cloudflare Tunnel connector** —
the *remotely-managed (token)* model that upstream `services.cloudflared` doesn't
support. Zero interactive login, no `cert.pem`; the token is read from an
`EnvironmentFile`, so it never lands in argv or the world-readable Nix store.

> Status: early / beta. Used in production on a headless Raspberry Pi.

## Why this exists

Upstream `services.cloudflared` only drives **locally-managed** tunnels: it wants a
credentials JSON + in-repo ingress and runs `cloudflared tunnel run <uuid>` — no
token support. A **remotely-managed (token)** tunnel comes up at boot with no login
and keeps its ingress/DNS in the Cloudflare account (dashboard or IaC), not your
NixOS config. This is a small, hardened `systemd` unit for exactly that.

## Prerequisites

- **Nix** with flakes enabled (`experimental-features = nix-command flakes`).
- **NixOS** (this is a NixOS module).
- A **remotely-managed Cloudflare Tunnel** already created in your Cloudflare
  account, and its **connector token**.

## Install

```nix
{
  inputs.cloudflared-connector.url = "github:ismailkattakath/nix-cloudflared-connector";

  # in your nixosSystem modules:
  #   cloudflared-connector.nixosModules.default
}
```

```nix
services.cloudflared-connector = {
  enable = true;
  tokenFile = "/run/agenix/cloudflared-token"; # a file with one line: TUNNEL_TOKEN=<token>
  # extraArgs = [ "--loglevel" "debug" ];      # optional
};
```

Place `tokenFile` out-of-band (agenix/sops/manual) with a single line
`TUNNEL_TOKEN=<token>`. **Never commit the token.** The unit retries on failure, so
placing the file after first boot self-heals without a rebuild.

### Options (`services.cloudflared-connector`)

| Option | Default | Meaning |
|---|---|---|
| `enable` | `false` | Enable the connector unit |
| `package` | `pkgs.cloudflared` | cloudflared package |
| `tokenFile` | `/etc/secrets/cloudflared-token` | `EnvironmentFile` with `TUNNEL_TOKEN=…` |
| `extraArgs` | `[ ]` | Extra args to `cloudflared tunnel run` |
| `restartSec` | `5` | systemd `RestartSec` |

## Security

- The token is passed via `EnvironmentFile` (env var `TUNNEL_TOKEN`), **never on the
  command line** (argv is world-readable via `/proc`) and **never in the Nix store**.
- The unit runs under `DynamicUser` with a strict `systemd` hardening profile
  (`ProtectSystem=strict`, `NoNewPrivileges`, `MemoryDenyWriteExecute`, a
  `@system-service` syscall filter, restricted address families, …).
- The token file lives on the host only (mode-lock it, e.g. `0600 root`).

## When to use something else

| You want… | Use |
|---|---|
| A **locally-managed** tunnel (credentials JSON + in-repo ingress) | upstream [`services.cloudflared`](https://search.nixos.org/options?query=services.cloudflared) |
| A **remotely-managed (token)** connector at boot, no login | **this** |

## Used in production

See it wired into a real fleet in **[kattakath/nix-config](https://github.com/kattakath/nix-config)** —
[`hosts/nixpi.nix`](https://github.com/kattakath/nix-config/blob/main/hosts/nixpi.nix)
enables it on a headless Raspberry Pi reached only over the tunnel (token planted on
the SD card's firmware partition).

## License

MIT © Ismail Kattakath
