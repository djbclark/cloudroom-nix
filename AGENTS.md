# cloudroom-nix

**Unmaintained since 2026-10-17:** djbclark moved to upstream BB; see github.com/djbclark/bb-nix and forgejo.mit.edu/djbclark/bb-build. Make no changes here unless djbclark asks.

Public (github.com/djbclark/cloudroom-nix, Apache-2.0 like upstream, 2026-10-16): NixOS module
`services.cloudroom` and packages for github.com/davidondrej/cloudroom-core. README.md is the
user documentation; keep it in step with `module.nix`.

1. Generic only: nothing about djbclark's hosts goes here. The deployment (vps-primary) is in
   site-djbclark, `nixos/vps-primary/configuration.nix` and `docs/bb-vps-primary.md` (BB replaced Cloudroom there).
2. No Nix on the Mac. Builds and hash computation run in Forgejo CI
   (forgejo.mit.edu/djbclark/cloudroom-core-build, `nix-build` workflow); vps-primary only when
   that is the only good option or actually the fastest (djbclark, 2026-10-16).
3. Upgrade: bump `pkgs/cloudroom-core.nix` (rev, hash, cargoHash) and the PIN lines in
   `pkgs/prebuilt.nix` from the build repo's run, in one commit.
4. Open (djbclark, 2026-10-16): a nixpkgs PR (package, maybe module) waits on upstream's answer to
   davidondrej/cloudroom-core#26. If upstream makes the agent PATH configurable, drop the host-wide
   `/usr/local/bin` and `/bin` links first; then ask djbclark again before opening it.
