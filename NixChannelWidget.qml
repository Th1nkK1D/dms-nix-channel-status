import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    component NixIcon: DSVGIcon {
        source: Qt.resolvedUrl("nix-snowflake.svg")
        size: root.iconSize
        colorOverride: Theme.surfaceText
    }

    horizontalBarPill: NixIcon {}

    verticalBarPill: NixIcon {}
}
