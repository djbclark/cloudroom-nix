# services.cloudroom: Cloudroom core (github.com/davidondrej/cloudroom-core, Apache-2.0) on
# NixOS. One Rust service that runs coding agents (Codex; Claude Code, Pi, Cursor once their
# CLIs are installed and logged in) as an unprivileged account behind a token-protected HTTP
# API, keeping their history on this machine.
#
# A NixOS port of upstream's Ubuntu installer (install/install.sh, install/cloudroom.service,
# install/configure.py --storage-only): same accounts, directories, policy file and unit. It
# needs no flake: `imports = [ ./module.nix ];` works too. Usage and the reasons behind each
# choice: README.md.
#
#   inputs.cloudroom-nix.url = "github:djbclark/cloudroom-nix";
#   imports = [ inputs.cloudroom-nix.nixosModules.default ];
#   services.cloudroom = { enable = true; codex.model = "..."; };
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cloudroom;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    types
    ;

  agentHome = "/home/${cfg.agentUser}";

  # Upstream's install/configure.py writes exactly these keys; the disk thresholds keep their
  # defaults (warn at 5 GB free, pause below 2 GB, resume above 2.5 GB).
  storagePolicy = pkgs.writeText "cloudroom-storage.json" (
    builtins.toJSON {
      agent_uid = cfg.agentUid;
      agent_gid = cfg.agentUid;
      cache_dir = "/var/cache/${cfg.agentUser}";
      cgroup_root = "/sys/fs/cgroup/system.slice/cloudroom.service/agents";
    }
  );

  # What the core and its agents find on PATH. The core starts agents with
  # PATH=/usr/local/bin:/usr/bin:/bin plus the agent's ~/.local/bin (src/runtime/mod.rs), so
  # /usr/local/bin becomes a link to the system profile (tmpfiles below).
  tools =
    with pkgs;
    [
      bash
      coreutils
      curl
      file
      findutils
      gawk
      git
      gnugrep
      gnused
      gnutar
      gzip
      jq
      nodejs_24
      openssl
      procps
      python3
      ripgrep
      unzip
      util-linux
      which
      xz
    ]
    ++ cfg.extraPackages;
in
{
  options.services.cloudroom = {
    enable = mkEnableOption "Cloudroom core, a runner for coding agents";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./pkgs/cloudroom-core.nix { };
      defaultText = lib.literalMD "cloudroom-core built from source";
      description = ''
        Package providing `bin/cloudroom`. The flake's `cloudroom-core-bin` is a prebuilt
        static x86_64-linux binary, for hosts that should compile nothing.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 9840;
      description = ''
        Loopback port of the plain-HTTP API. It never listens elsewhere: reach it remotely
        through an HTTPS proxy on this machine, such as `tailscaleServe`.
      '';
    };

    serviceUid = mkOption {
      type = types.int;
      default = 9840;
      description = "uid and gid of the `cloudroom` service account.";
    };

    agentUser = mkOption {
      type = types.str;
      default = "cloudroom-agent";
      description = ''
        Account the agents run as. It gets no sudo and no SSH key: agents run commands
        without approval prompts. Its home is `/home/<name>`.
      '';
    };

    agentUid = mkOption {
      type = types.int;
      default = 9841;
      description = "uid and gid of the agent account (the storage policy names them).";
    };

    codex = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Offer Codex (the default harness). Log in once as the agent account.";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.codex;
        defaultText = lib.literalExpression "pkgs.codex";
        description = ''
          Package providing `bin/codex`. Upstream tested Codex 0.154.0; the flake's
          `codex-npm-bin` is that npm release, prebuilt (x86_64-linux).
        '';
      };
      model = mkOption {
        type = types.str;
        example = "gpt-5.5";
        description = "Default Codex model (`CLOUDROOM_CODEX_MODEL`); clients may pick per session.";
      };
    };

    claudeCode.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Let the agent account install Claude Code with Anthropic's native installer (into
        `~/.local/bin`, where the core looks for it). Enables `programs.nix-ld`, which that
        generic glibc binary needs.
      '';
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "More tools for the agents' PATH (they are added to the system profile).";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        CLOUDROOM_HARNESS = "claude-code";
      };
      description = "Extra `CLOUDROOM_*` settings for the service (never secrets: they reach the store).";
    };

    memoryHigh = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "2560M";
      description = "systemd `MemoryHigh` for the service, agents included (they run in its subtree).";
    };

    memoryMax = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "3G";
      description = "systemd `MemoryMax` for the service, agents included.";
    };

    tailscaleServe.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Publish the API on this node's tailnet name over HTTPS (port 443) with `tailscale serve`.
        Needs `services.tailscale` and HTTPS certificates enabled for the tailnet. Never funnel.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion =
          lib.meta.availableOn pkgs.stdenv.hostPlatform cfg.package
          && (cfg.codex.enable -> lib.meta.availableOn pkgs.stdenv.hostPlatform cfg.codex.package);
        message = "services.cloudroom: package or codex.package is not available on this platform.";
      }
      {
        assertion = cfg.tailscaleServe.enable -> config.services.tailscale.enable;
        message = "services.cloudroom.tailscaleServe needs services.tailscale.enable.";
      }
    ];

    users.groups.cloudroom.gid = cfg.serviceUid;
    users.users.cloudroom = {
      isSystemUser = true;
      uid = cfg.serviceUid;
      group = "cloudroom";
      home = "/var/lib/cloudroom";
      createHome = true;
      homeMode = "700";
    };
    users.groups.${cfg.agentUser}.gid = cfg.agentUid;
    users.users.${cfg.agentUser} = {
      isNormalUser = true;
      uid = cfg.agentUid;
      group = cfg.agentUser;
      home = agentHome;
      homeMode = "700";
      shell = pkgs.bash;
    };

    environment.systemPackages = tools;
    programs.nix-ld.enable = mkIf cfg.claudeCode.enable true;

    systemd.tmpfiles.rules = [
      "d /var/lib/cloudroom/history 0700 cloudroom cloudroom -"
      "d /etc/cloudroom 0750 root cloudroom -"
      "d /code 0700 ${cfg.agentUser} ${cfg.agentUser} -"
      # Paths upstream calls by absolute name (src/runtime, src/workspace/storage.rs,
      # docs/observability.md), and the agents' system PATH directory.
      "d /usr/local 0755 root root -"
      "L+ /usr/local/bin - - - - /run/current-system/sw/bin"
      "L+ /bin/bash - - - - /run/current-system/sw/bin/bash"
      "L+ /bin/ps - - - - /run/current-system/sw/bin/ps"
      "L+ /bin/df - - - - /run/current-system/sw/bin/df"
      "L+ /usr/bin/sha512sum - - - - /run/current-system/sw/bin/sha512sum"
    ]
    # The core stats every harness home at start and exits if one is missing; Codex creates
    # its own only at the first login.
    ++ lib.optional cfg.codex.enable "d ${agentHome}/.codex 0700 ${cfg.agentUser} ${cfg.agentUser} -";

    # The policy must be a real file whose ancestors the agent cannot write (a /nix/store path
    # or an /etc/static link is refused). The API token never enters the store: it is made
    # here once, root-only.
    systemd.services.cloudroom-setup = {
      description = "Cloudroom core: policy file and API token";
      before = [ "cloudroom.service" ];
      requiredBy = [ "cloudroom.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [
        pkgs.coreutils
        pkgs.openssl
      ];
      script = ''
        install -d -m 0750 -o root -g cloudroom /etc/cloudroom
        install -m 0600 -o cloudroom -g cloudroom ${storagePolicy} /etc/cloudroom/storage.json
        if [ ! -s /etc/cloudroom/core.env ]; then
          umask 077
          printf 'CLOUDROOM_TOKEN=%s\n' "$(openssl rand -hex 32)" > /etc/cloudroom/core.env.new
          mv /etc/cloudroom/core.env.new /etc/cloudroom/core.env
        fi
        chown root:root /etc/cloudroom/core.env
        chmod 0600 /etc/cloudroom/core.env
      '';
    };

    systemd.services.cloudroom = {
      description = "Cloudroom core";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = tools;
      environment = {
        CLOUDROOM_LISTEN = "127.0.0.1:${toString cfg.port}";
        CLOUDROOM_STORE = "self-hosted";
        CLOUDROOM_LOCAL_HISTORY = "1";
        CLOUDROOM_STATE_DIR = "/var/lib/cloudroom/history";
        CLOUDROOM_STORAGE_POLICY = "/etc/cloudroom/storage.json";
        CLOUDROOM_ACCOUNT_HOME = agentHome;
        CLOUDROOM_REPOSITORY = "/code";
      }
      // optionalAttrs cfg.codex.enable {
        CLOUDROOM_CODEX_BINARY = lib.getExe cfg.codex.package;
        CLOUDROOM_CODEX_HOME = "${agentHome}/.codex";
        CLOUDROOM_CODEX_MODEL = cfg.codex.model;
      }
      // cfg.environment;
      # Upstream's install/cloudroom.service, with store paths.
      serviceConfig = {
        User = "cloudroom";
        Group = "cloudroom";
        ExecStartPre = "+${pkgs.coreutils}/bin/install -d -m 0700 -o ${cfg.agentUser} -g ${cfg.agentUser} /var/cache/${cfg.agentUser}";
        ExecStart = lib.getExe cfg.package;
        # CLOUDROOM_TOKEN only (cloudroom-setup.service).
        EnvironmentFile = "/etc/cloudroom/core.env";
        Delegate = "yes";
        RuntimeDirectory = "cloudroom";
        RuntimeDirectoryMode = "0711";
        # The core attaches children to cgroups, then drops all their capabilities.
        AmbientCapabilities = [
          "CAP_SETUID"
          "CAP_SETGID"
          "CAP_DAC_READ_SEARCH"
          "CAP_KILL"
        ];
        CapabilityBoundingSet = [
          "CAP_SETUID"
          "CAP_SETGID"
          "CAP_DAC_READ_SEARCH"
          "CAP_KILL"
        ];
        NoNewPrivileges = true;
        UMask = "0077";
        LimitNOFILE = 524288;
        KillMode = "control-group";
        TimeoutStopSec = 10;
        Restart = "on-failure";
        RestartSec = 5;
      }
      // optionalAttrs (cfg.memoryHigh != null) { MemoryHigh = cfg.memoryHigh; }
      // optionalAttrs (cfg.memoryMax != null) { MemoryMax = cfg.memoryMax; };
    };

    systemd.services.cloudroom-tailscale-serve = mkIf cfg.tailscaleServe.enable {
      description = "Serve Cloudroom core on the tailnet over HTTPS";
      after = [
        "tailscaled.service"
        "cloudroom.service"
      ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "${pkgs.coreutils}/bin/timeout 120 ${pkgs.bash}/bin/sh -c 'until ${config.services.tailscale.package}/bin/tailscale status >/dev/null 2>&1; do sleep 1; done'";
        ExecStart = "${config.services.tailscale.package}/bin/tailscale serve --bg --https=443 http://127.0.0.1:${toString cfg.port}";
        ExecStop = "${config.services.tailscale.package}/bin/tailscale serve --https=443 off";
      };
    };
  };
}
