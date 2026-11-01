import QtQuick
import qs.Modules.Plugins

PluginSettings {
    pluginId: NixChannelService.pluginId

    StringSetting {
        settingKey: "lockPath"
        label: "flake.lock path"
        description: "Highlight the icon when the channel is ahead of this lock's input. Leave empty to highlight every new channel revision until you mark it seen."
    }

    StringSetting {
        settingKey: "input"
        label: "Flake input"
        description: "The nixpkgs input to compare against, as named in your flake.nix."
        placeholder: "nixpkgs"
        defaultValue: "nixpkgs"
    }

    SelectionSetting {
        settingKey: "channel"
        label: "Channel"
        description: "Auto follows the lock input's branch, falling back to " + NixChannelService.fallbackChannel + "."
        defaultValue: NixChannelService.autoChannel
        options: [
            {
                label: "Auto",
                value: NixChannelService.autoChannel
            }
        ].concat(NixChannelService.channels.filter(c => c.current || c.channel === NixChannelService.channelSetting).map(c => ({
                    label: c.channel + " (" + c.status + ")",
                    value: c.channel
                })))
    }

    SelectionSetting {
        settingKey: "idleColor"
        label: "Idle icon color"
        description: "Theme color of the snowflake when nothing is pending."
        defaultValue: NixChannelService.defaultIdleColor
        options: NixChannelService.colorOptions
    }

    SelectionSetting {
        settingKey: "iconColor"
        label: "Update icon color"
        description: "Theme color the snowflake takes when an update is pending."
        defaultValue: NixChannelService.defaultColor
        options: NixChannelService.colorOptions
    }

    SelectionSetting {
        settingKey: "dotColor"
        label: "Update dot color"
        description: "Theme color of the dot shown when an update is pending."
        defaultValue: NixChannelService.defaultColor
        options: NixChannelService.colorOptions
    }
}
