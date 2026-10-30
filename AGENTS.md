# Agent Instructions

## Do Not Tie Settings to One PC

- Settings, scripts, and branch names must not depend on one machine. Do not use a
  hostname, a machine serial number, or a fixed absolute home path.
- Give a branch a name from its purpose (for example `cck/dev`), not from a host. Do not
  recommend a hostname as a branch name.
- Get machine values when the script runs: `$HOME`, `id -un`, the `XDG_*` directories,
  and the detected architecture.
