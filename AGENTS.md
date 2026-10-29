# dms-nix-channel-status

DankMaterialShell (DMS) bar plugin: polls status.nixos.org hourly (plus manual refresh) for one
channel and tints a Nix snowflake icon when that channel is ahead of the nixpkgs input locked in a
user-chosen `flake.lock`.

## Environment facts (NixOS, DMS 2.0.0 "Dux Shell")
- DMS QML source (read-only, canonical API reference): the running `dms` unpacks it to
  `/run/user/$UID/dms-shell/<hash>/` (only exists while DMS runs; was `danklinux-shell` before 2.0).
  - Plugin docs + JSON schema + examples: `PLUGINS/{README.md,plugin-schema.json,*Example*/}`
  - Plugin base classes: `Modules/Plugins/{PluginComponent,PluginSettings,PopoutComponent,SelectionSetting,StringSetting,...}.qml`
  - Widgets: import `qs.DCommon.Widgets` (`DIcon`, `DSVGIcon`, `DButton`, `DDropdown`, `StyledText`, ...).
    `qs.Widgets` `Dank*` names are deprecated shims that log a warning.
  - Theme colors: `Common/Theme.qml` (`Theme.surfaceText`, `Theme.primary`, `Theme.spacingM`, ...).
  - `Common/Proc.qml` → `Proc.runCommand(id, argv, (stdout, exitCode) => {}, debounceMs, timeoutMs, owner)`.
  - Plugin IPC: `DMSShellIPC.qml` target `plugins` (`reload`, `status`).
- Config dir is `~/.config/dms` (`~/.config/DankMaterialShell` is a symlink to it). Plugins live in
  `~/.config/dms/plugins/`; plugin settings in `~/.config/dms/plugin_settings.json[pluginId]`.
- Runtime state: `~/.local/state/dms/plugins/<pluginId>_state.json`.
- DMS runs as `systemctl --user dms.service`; logs: `journalctl --user -fu dms`.
- Manifest: `dependencies` replaces the deprecated `requires`.

## Data sources
- Channels: `https://prometheus.nixos.org/api/v1/query?query=channel_revision or channel_update_time`
  (status.nixos.org is a static page that queries this). `channel_revision` carries labels
  `channel`, `revision`, `status` (`stable|rolling|unmaintained`), `current` (`"1"` = maintained);
  `channel_update_time` value is a unix timestamp string.
- Lock: resolve the input via `nodes.root.inputs[<input>]`, never by node name — the node literally
  named `nixpkgs` may belong to another input (`nixpkgs_2` is the user's in practice). An input value
  that is an array is a `follows` path to walk from root. Use `locked.rev`, `locked.lastModified`,
  `original.ref` (default channel).
- agent-guard blocks shell commands that mention a `flake.lock` path; inspect lock files with the
  Read tool instead.

## Dev commands
```bash
./dev.sh link      # symlink repo into ~/.config/dms/plugins/nixChannelStatus
./dev.sh watch     # auto-reload plugin on .qml/.json save (uses nix shell nixpkgs#watchexec)
./dev.sh reload    # dms ipc call plugins reload nixChannelStatus
./dev.sh status    # dms ipc call plugins status nixChannelStatus
./dev.sh logs      # journalctl --user -fu dms
./dev.sh fmt       # qmlformat -i *.qml
./dev.sh fmt-check # exit 1 if any *.qml is unformatted
node parse.test.mjs # self-check for parse.js (pure JSON parsing, kept out of QML so node can run it)
```
First time: Settings → Plugins → Scan for Plugins → enable → add "Nix Channel Status" to a bar section.

## Conventions
- No arbitrary comments. Only comment what the code cannot say itself: external quirks, non-obvious
  framework contracts, or why a workaround exists. Never restate what the next line already reads as.
- Format QML with `qmlformat` (default settings, ships with `qt6.qtdeclarative`) — run `./dev.sh fmt`
  before committing. `qmllint` is not used: it can't resolve DMS's `qs.*` imports, so every DMS
  singleton shows up as a false "unqualified access".
- Service logic lives in Singleton `NixChannelService.qml` (registered in `qmldir`); widgets read it
  and call its actions.
- Don't *re-declare* injected props (`pluginId`, `pluginService`, `pluginData`) in PluginComponent/PluginSettings.
  But `PluginSettings.pluginId` is `required` — assign `pluginId: NixChannelService.pluginId`, or the
  settings accordion silently loads nothing.
- Commits: a single conventional-commit subject line (`fix:`, `feat:`, `docs:`), no body. Name the concrete
  changes, not a vague summary.
