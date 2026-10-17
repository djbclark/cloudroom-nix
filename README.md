# cloudroom-nix

A NixOS module and Nix packages for [Cloudroom core](https://github.com/davidondrej/cloudroom-core):
one Rust service that runs coding agents (Codex, Claude Code, Pi, Cursor) on a Linux machine as an
unprivileged account, behind a token-protected HTTP API, keeping their history on that machine.

This is an unofficial port of upstream's Ubuntu installer (`install/install.sh`,
`install/cloudroom.service`, `install/configure.py --storage-only`): the same accounts,
directories, disk policy and systemd unit, written as `services.cloudroom`. Apache-2.0, like
upstream. It runs on vps-primary, a NixOS 26.05 host, since 2026-10-16.

## Use

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.cloudroom-nix.url = "github:djbclark/cloudroom-nix";
  inputs.cloudroom-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, cloudroom-nix, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        cloudroom-nix.nixosModules.default
        ./configuration.nix
        {
          services.cloudroom = {
            enable = true;
            codex.model = "gpt-5.5";        # any model your Codex login offers
            tailscaleServe.enable = true;   # optional: HTTPS on your tailnet name
            # memoryMax = "3G";             # optional: cap the core and its agents together
          };
        }
      ];
    };
  };
}
```

Without flakes, `imports = [ /path/to/cloudroom-nix/module.nix ];` works the same way.

After the switch:

```bash
api() { sudo awk -F= '/^CLOUDROOM_TOKEN=/{print "header = \"Authorization: Bearer " $2 "\""}' /etc/cloudroom/core.env |
  curl --config - --silent --show-error --fail-with-body "$@"; }
api http://127.0.0.1:9840/v1/ready      # {"ready":true}
```

then upstream's [docs/setup.md](https://github.com/davidondrej/cloudroom-core/blob/main/docs/setup.md)
from "Run your first task". The Cloudroom desktop app connects with the HTTPS URL (from
`tailscale serve status`) and the token (Settings, Connect your own Core).

### Log the harnesses in, once, as the agent account

1. Codex: `sudo -u cloudroom-agent -H codex login --device-auth`, with the `codex` of
   `services.cloudroom.codex.package` (`systemctl show -p Environment cloudroom` names it as
   `CLOUDROOM_CODEX_BINARY`).
2. Claude Code: as `cloudroom-agent`, Anthropic's native installer
   (`curl -fsSL https://claude.ai/install.sh | bash`) into `~/.local/bin`, then run `claude` once to
   log in, so `~/.claude` exists; the core looks there. `claudeCode.enable` (default on) turns on
   `programs.nix-ld` for that binary.
3. `sudo systemctl restart cloudroom`.

## Options

All under `services.cloudroom`, each with a description in `module.nix`:

| Option | Default | |
| --- | --- | --- |
| `enable` | `false` | |
| `package` | `cloudroom-core` from source | `packages.x86_64-linux.cloudroom-core-bin` compiles nothing |
| `port` | `9840` | loopback only, always |
| `serviceUid`, `agentUid` | `9840`, `9841` | the disk policy names the agent's ids |
| `agentUser` | `cloudroom-agent` | no sudo, no SSH key |
| `codex.enable`, `codex.package`, `codex.model` | `true`, `pkgs.codex`, required | `codex-npm-bin` is Codex 0.154.0, the version upstream tested |
| `claudeCode.enable` | `true` | enables `programs.nix-ld` |
| `extraPackages` | `[ ]` | tools for the agents' PATH |
| `environment` | `{ }` | more `CLOUDROOM_*` settings (not secrets) |
| `memoryHigh`, `memoryMax` | `null` | systemd caps for the core and all its agents |
| `tailscaleServe.enable` | `false` | `tailscale serve` on 443; never funnel |

## Packages

| Package | |
| --- | --- |
| `cloudroom-core` (`default`) | from source, `rustPlatform.buildRustPackage`; Linux |
| `cloudroom-core-bin` | prebuilt static musl binary, x86_64-linux, pinned by hash |
| `codex-npm-bin` | the `@openai/codex` npm release upstream tested, x86_64-linux, pinned by hash |

The two `-bin` packages are built by Forgejo CI at forgejo.mit.edu (upstream at a pinned tag and
commit, in a digest-pinned `rust:alpine` container, with `cargo test` as the gate) and published
there as generic packages, so a host can run Cloudroom without compiling anything.
`overlays.default` adds `cloudroom-core` to nixpkgs.

## What the module does to the host

1. Accounts `cloudroom` (the service) and `cloudroom-agent` (the agents), directories
   `/var/lib/cloudroom/history` (the journal: back it up), `/code` (workspaces), `/etc/cloudroom`.
2. `cloudroom-setup.service` writes `/etc/cloudroom/storage.json` from the module at each start
   (it must be a real file the agent cannot write: a store path or `/etc/static` link is refused)
   and makes `/etc/cloudroom/core.env` once, a root-only `CLOUDROOM_TOKEN` that never enters the
   Nix store.
3. `cloudroom.service` is upstream's unit with store paths: `Delegate=yes`, the four ambient
   capabilities, `NoNewPrivileges`, history kept locally (`CLOUDROOM_LOCAL_HISTORY=1`).
4. **Host-wide links.** The core starts agents with `PATH=/usr/local/bin:/usr/bin:/bin` and calls
   `/bin/ps`, `/bin/df`, `/bin/bash` and `/usr/bin/sha512sum` by absolute path; none exist on
   NixOS. tmpfiles links `/usr/local/bin` to `/run/current-system/sw/bin` and adds the four
   links. A host that already uses `/usr/local/bin` is not a fit as is.
5. Agents run commands without approval prompts, so follow upstream: one trusted user per
   machine. `/tmp`, `/var/tmp`, `/code`, `/home` and `/var/lib/cloudroom` must share one
   filesystem; the core refuses to start otherwise.
