# Contributing

A small, focused, single-module flake. Keep it that way.

## Dev loop
```sh
nix flake check                          # module eval check
nix run nixpkgs#nixfmt-rfc-style -- .     # format (CI enforces)
nix build .#checks.x86_64-linux.module-evaluates
```

## Guidelines
- Keep the module dependency-free (`config`/`lib`/`pkgs` only) and hardened.
- Never put a token **value** in code; the token is always operator-supplied via `tokenFile`.
- New options need a `description` and, where useful, an `example`.
- Update `README.md` for user-facing changes; CI (format + eval) must pass.
