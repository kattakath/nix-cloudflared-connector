# Security Policy

The connector token is a secret. This module passes it via a systemd
`EnvironmentFile` (`TUNNEL_TOKEN=…`), so it never appears in argv (`/proc` is
world-readable) nor in the world-readable Nix store. Place the token file
out-of-band (agenix/sops/manual), mode-locked (e.g. `0600 root`), and never commit
it. The unit runs under `DynamicUser` with a strict hardening profile.

## Reporting a vulnerability

Open a **private** security advisory via GitHub ("Security" → "Report a
vulnerability"), or contact the maintainer directly. Do not file public issues for
undisclosed vulnerabilities.
