# DMS Nix Channel Status

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar plugin that watches one
[status.nixos.org](https://status.nixos.org) channel and lights up its Nix snowflake when the
channel has moved past the nixpkgs revision pinned in your `flake.lock`.

The snowflake turns your accent colour when there is something to update:

- **With a `flake.lock`** — the channel's revision differs from the one your lock pins, and the
  channel moved after your locked commit. It clears by itself once you `nix flake update`; the lock
  file is watched, so no refresh is needed.
- **Without one** — the channel has a revision you haven't marked seen yet.

Click it for a popout with the channel, when it last updated, `Up to date · 31ecbac` or
`Update available · f05535a → 31ecbac`, and a **Compare** button that opens the GitHub diff
between the two. The header has a settings shortcut and **Check now**.

## Requirements

- DankMaterialShell >= 2.0.0

## Install from source

```bash
git clone https://github.com/Th1nkK1D/dms-nix-channel-status.git
ln -s "$PWD/dms-nix-channel-status" ~/.config/dms/plugins/nixChannelStatus
```

Then **Settings → Plugins → Scan for Plugins**, enable _Nix Channel Status_ and add it to a bar
section under **Settings → Dank Bar**.

## Configure

**Settings → Plugins → Nix Channel Status**:

| Field          | Meaning                                                        | Default          |
| -------------- | -------------------------------------------------------------- | ---------------- |
| flake.lock path | lock to compare against; `~` is expanded                      | empty (seen mode) |
| Flake input    | the input to read from the lock, as named in your `flake.nix`  | `nixpkgs`        |
| Channel        | channel to watch; _Auto_ uses the input's branch (`original.ref`) | Auto, else `nixos-unstable` |

## How it works

Every hour (and on **Check now**) the plugin asks the Prometheus instance behind status.nixos.org
for `channel_revision` and `channel_update_time` in one request, made with QML's built-in
`XMLHttpRequest` (no external tools). The schedule is checked against the wall clock once a minute,
so a missed check after suspend or an offline stretch runs within a minute of coming back; a failed
or empty answer is retried after 5 minutes and the last good result stays on screen.

The lock input is resolved through the root node's `inputs`, following `follows` paths, so another
input's pinned nixpkgs is never mistaken for yours.

## Development

```bash
./dev.sh link       # symlink this repo into the DMS plugins directory
./dev.sh watch      # reload the plugin on save
./dev.sh reload     # reload once
./dev.sh status     # is it loaded?
./dev.sh logs       # journalctl --user -fu dms
./dev.sh fmt        # qmlformat -i *.qml
./dev.sh fmt-check  # fail if anything is unformatted
node parse.test.mjs # self-check for the lock and channel parsers
```

Editing `NixChannelService.qml` needs a full `systemctl --user restart dms` — QML caches singletons
per engine, so `plugins reload` only picks up widget and settings changes.

See `AGENTS.md` for API notes.

## License

MIT — see [LICENSE](LICENSE). The Nix snowflake (`nix-snowflake.svg`, flattened to a single fill)
is from [NixOS/nixos-artwork](https://github.com/NixOS/nixos-artwork/tree/master/logo), designed by
Simon Frankau and revised by Tim Cuthbertson, licensed
[CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/).
