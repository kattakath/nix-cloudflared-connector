# Contributing

A small, focused, single-module flake. Keep it that way.

## Dev loop
```sh
nix fmt                                  # treefmt: nixfmt + deadnix + statix
nix flake check                          # module eval + formatting checks
nix build .#checks.x86_64-linux.module-evaluates
```

## Guidelines
- Keep the module dependency-free (`config`/`lib`/`pkgs` only) and hardened.
- Never put a token **value** in code; the token is always operator-supplied via `tokenFile`.
- New options need a `description` and, where useful, an `example`.
- Update `README.md` for user-facing changes; CI (`nix flake check`) must pass.
