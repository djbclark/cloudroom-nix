# Prebuilt Cloudroom core and Codex CLI for x86_64-linux, downloaded by hash, so a host that
# uses them compiles nothing. Built by Forgejo CI (forgejo.mit.edu/djbclark/cloudroom-core-build:
# upstream at a pinned tag in a digest-pinned rust:alpine container, `cargo test` as the gate)
# and published as Forgejo generic packages. To upgrade, paste that run's PIN lines below.
#
#   cloudroom-core-bin  bin/cloudroom: upstream github.com/davidondrej/cloudroom-core, static musl
#   codex-npm-bin       bin/codex: the @openai/codex npm package (node launcher and its static
#                       binary) at the version upstream's docs/setup.md tested
{
  fetchurl,
  runCommandLocal,
  lib,
}:
let
  meta = {
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
in
{
  # PIN cloudroom: core-v0.1.61, upstream commit 0735d6801e9a.
  cloudroom-core-bin =
    let
      bin = fetchurl {
        url = "PIN_CORE_URL";
        hash = "PIN_CORE_HASH";
        executable = true;
      };
    in
    runCommandLocal "cloudroom-core-bin-0.1.61"
      {
        meta = meta // {
          description = "Cloudroom core: runs coding agents on a Linux machine behind an HTTP API";
          homepage = "https://github.com/davidondrej/cloudroom-core";
          license = lib.licenses.asl20;
          mainProgram = "cloudroom";
        };
      }
      ''
        install -D -m 0755 ${bin} $out/bin/cloudroom
      '';

  # PIN codex: @openai/codex 0.154.0, the version cloudroom-core's docs/setup.md tested.
  codex-npm-bin =
    let
      tarball = fetchurl {
        url = "PIN_CODEX_URL";
        hash = "PIN_CODEX_HASH";
      };
    in
    runCommandLocal "codex-npm-bin-0.154.0"
      {
        meta = meta // {
          description = "OpenAI Codex CLI, as published on npm";
          homepage = "https://github.com/openai/codex";
          license = lib.licenses.asl20;
          mainProgram = "codex";
        };
      }
      ''
        mkdir -p $out/lib $out/bin
        tar -xzf ${tarball} -C $out/lib
        # The launcher finds its platform package next to it in node_modules; node resolves
        # through this link to the real path.
        ln -s $out/lib/node_modules/@openai/codex/bin/codex.js $out/bin/codex
      '';
}
