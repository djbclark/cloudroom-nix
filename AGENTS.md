# cloudroom-nix

Public (github.com/djbclark/cloudroom-nix, Apache-2.0 like upstream, 2026-10-16): NixOS module
`services.cloudroom` and packages for github.com/davidondrej/cloudroom-core. README.md is the
user documentation; keep it in step with `module.nix`.

1. Generic only: nothing about djbclark's hosts goes here. The deployment (vps-primary) is in
   site-djbclark, `nixos/vps-primary/configuration.nix` and `docs/cloudroom-vps-primary.md`.
2. No Nix on the Mac. Builds and hash computation run in Forgejo CI
   (forgejo.mit.edu/djbclark/cloudroom-core-build, `nix-build` workflow), never on vps-primary.
3. Upgrade: bump `pkgs/cloudroom-core.nix` (rev, hash, cargoHash) and the PIN lines in
   `pkgs/prebuilt.nix` from the build repo's run, in one commit.
