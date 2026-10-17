# Cloudroom core built from source.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "cloudroom-core";
  version = "0.1.61";

  src = fetchFromGitHub {
    owner = "davidondrej";
    repo = "cloudroom-core";
    # tag core-v0.1.61
    rev = "0735d6801e9a0f3d276b0c38d626ef8a10e31c25";
    hash = "sha256-tr/tqE5+I4pgbNPquyZbV4NrN1k/4AZyyt7A1r//ylU=";
  };

  cargoHash = "sha256-04Te7AqpUol57ptP/XfV+xzwoQcFVZwdkhAM2r0uVic=";

  # Upstream's tests need a disposable VM (extra system users, sudo, PostgreSQL, cgroups);
  # its own CI runs them, and so does the prebuilt package's build.
  doCheck = false;

  meta = {
    description = "Runs coding agents (Codex, Claude Code, Pi, Cursor) on a Linux machine behind an HTTP API";
    homepage = "https://github.com/davidondrej/cloudroom-core";
    license = lib.licenses.asl20;
    mainProgram = "cloudroom";
    platforms = lib.platforms.linux;
  };
}
