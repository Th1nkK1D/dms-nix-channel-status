import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginSettings {
    pluginId: NixChannelService.pluginId

    StringSetting {
        settingKey: "lockPath"
        label: I18n.trFor("nixChannelStatus", "flake.lock path")
        description: I18n.trFor("nixChannelStatus", "Path to your flake.lock, or the flake directory holding it. Highlight the icon when the channel is ahead of this lock's input. Leave empty to highlight every new channel revision until you mark it seen.")
    }

    StringSetting {
        settingKey: "input"
        label: I18n.trFor("nixChannelStatus", "Flake input")
        description: I18n.trFor("nixChannelStatus", "The nixpkgs input to compare against, as named in your flake.nix.")
        placeholder: "nixpkgs"
        defaultValue: "nixpkgs"
    }

    SelectionSetting {
        settingKey: "channel"
        label: I18n.trFor("nixChannelStatus", "Channel")
        description: I18n.trFor("nixChannelStatus", "Auto follows the lock input's branch or channel URL, falling back to %1.").arg(NixChannelService.fallbackChannel)
        defaultValue: NixChannelService.autoChannel
        options: [
            {
                label: I18n.trFor("nixChannelStatus", "Auto"),
                value: NixChannelService.autoChannel
            }
        ].concat(NixChannelService.channels.filter(c => c.current || c.channel === NixChannelService.channelSetting).map(c => ({
                    label: c.channel + " (" + c.status + ")",
                    value: c.channel
                })))
    }

    SelectionSetting {
        settingKey: "idleColor"
        label: I18n.trFor("nixChannelStatus", "Idle icon color")
        description: I18n.trFor("nixChannelStatus", "Theme color of the snowflake when nothing is pending.")
        defaultValue: NixChannelService.defaultIdleColor
        options: NixChannelService.colorOptions
    }

    SelectionSetting {
        settingKey: "iconColor"
        label: I18n.trFor("nixChannelStatus", "Update icon color")
        description: I18n.trFor("nixChannelStatus", "Theme color the snowflake takes when an update is pending.")
        defaultValue: NixChannelService.defaultColor
        options: NixChannelService.colorOptions
    }

    SelectionSetting {
        settingKey: "dotColor"
        label: I18n.trFor("nixChannelStatus", "Update dot color")
        description: I18n.trFor("nixChannelStatus", "Theme color of the dot shown when an update is pending.")
        defaultValue: NixChannelService.defaultColor
        options: NixChannelService.colorOptions
    }
}
