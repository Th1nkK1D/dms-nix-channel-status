# DMS Nix Channel Status

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar plugin that watches one
[status.nixos.org](https://status.nixos.org) channel and lights up its Nix snowflake when the
channel has moved past the nixpkgs revision pinned in your `flake.lock`.

> Work in progress — the bar icon is in place, the channel check is not implemented yet.

## Requirements

- DankMaterialShell >= 2.0.0
- `curl`

## Install from source

```bash
git clone https://github.com/Th1nkK1D/dms-nix-channel-status.git
ln -s "$PWD/dms-nix-channel-status" ~/.config/dms/plugins/nixChannelStatus
```

Then **Settings → Plugins → Scan for Plugins**, enable _Nix Channel Status_ and add it to a bar
section under **Settings → Dank Bar**.

## Development

```bash
./dev.sh link       # symlink this repo into the DMS plugins directory
./dev.sh watch      # reload the plugin on save
./dev.sh reload     # reload once
./dev.sh status     # is it loaded?
./dev.sh logs       # journalctl --user -fu dms
./dev.sh fmt        # qmlformat -i *.qml
./dev.sh fmt-check  # fail if anything is unformatted
```

Editing `NixChannelService.qml` needs a full `systemctl --user restart dms` — QML caches singletons
per engine, so `plugins reload` only picks up widget and settings changes.

See `AGENTS.md` for API notes.

## License

MIT — see [LICENSE](LICENSE). The Nix snowflake (`nix-snowflake.svg`, flattened to a single fill)
is from [NixOS/nixos-artwork](https://github.com/NixOS/nixos-artwork/tree/master/logo), designed by
Simon Frankau and revised by Tim Cuthbertson, licensed
[CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/).
