import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    popoutWidth: 380

    component NixIcon: Item {
        implicitWidth: root.iconSize
        implicitHeight: root.iconSize

        DSVGIcon {
            anchors.centerIn: parent
            source: Qt.resolvedUrl("nix-snowflake.svg")
            size: root.iconSize
            colorOverride: NixChannelService.behind ? Theme.primary : Theme.surfaceText
        }

        Rectangle {
            visible: NixChannelService.behind
            width: 8
            height: 8
            radius: 4
            color: Theme.primary
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -2
            anchors.rightMargin: -2
        }
    }

    horizontalBarPill: NixIcon {}

    verticalBarPill: NixIcon {}

    popoutContent: Component {
        Item {
            id: popoutRoot

            property var closePopout: null
            property var parentPopout: null

            readonly property var current: NixChannelService.current

            implicitHeight: layout.implicitHeight

            function close() {
                if (popoutRoot.closePopout)
                    popoutRoot.closePopout();
            }

            PopoutComponent {
                id: layout
                width: parent.width
                headerText: "Nix Channel Status"
                closePopout: popoutRoot.closePopout
                detailsText: {
                    const svc = NixChannelService;
                    if (svc.linkDown && !popoutRoot.current)
                        return "No network connection.";
                    if (svc.fetchError && !popoutRoot.current)
                        return svc.fetchError;
                    if (!popoutRoot.current)
                        return svc.checking || svc.lastChecked === 0 ? "Checking…" : "Channel " + svc.channelName + " not found on status.nixos.org.";
                    return svc.channelName + " · updated " + svc.formatAge(popoutRoot.current.updatedAt) + " · checked " + svc.formatAge(svc.lastChecked);
                }

                headerActions: Component {
                    Row {
                        spacing: Theme.spacingXS

                        DActionButton {
                            iconName: "open_in_new"
                            tooltipText: "Open status.nixos.org"
                            onClicked: {
                                Qt.openUrlExternally("https://status.nixos.org");
                                popoutRoot.close();
                            }
                        }

                        DActionButton {
                            iconName: "settings"
                            tooltipText: "Open plugin settings"
                            onClicked: {
                                popoutRoot.close();
                                PopoutService.openSettingsWithTab("plugins");
                            }
                        }

                        DActionButton {
                            iconName: "refresh"
                            tooltipText: "Check now"
                            enabled: !NixChannelService.checking
                            onClicked: NixChannelService.refresh()
                        }
                    }
                }

                Column {
                    width: parent.width
                    leftPadding: Theme.spacingS
                    spacing: Theme.spacingM
                    visible: popoutRoot.current !== null || NixChannelService.lockError !== ""

                    StyledText {
                        width: parent.width - parent.leftPadding
                        text: {
                            const svc = NixChannelService;
                            const cur = popoutRoot.current;
                            if (svc.lockMode && svc.lockError)
                                return svc.lockError;
                            if (!cur)
                                return "";
                            if (svc.inSync)
                                return "Up to date · " + svc.shortRev(cur.revision);
                            if (svc.behind)
                                return (svc.lockMode ? "Update available · " : "New revision · ") + svc.shortRev(svc.baseRevision) + " → " + svc.shortRev(cur.revision);
                            if (svc.lockMode && svc.lock)
                                return "Locked " + svc.shortRev(svc.baseRevision) + " is newer than " + svc.shortRev(cur.revision);
                            return "Revision " + svc.shortRev(cur.revision);
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: NixChannelService.lockMode && NixChannelService.lockError ? Theme.error : (NixChannelService.behind ? Theme.primary : Theme.surfaceText)
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        width: parent.width - parent.leftPadding
                        visible: NixChannelService.fetchError !== "" && popoutRoot.current !== null
                        text: NixChannelService.fetchError + " — showing the last result."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        spacing: Theme.spacingS
                        visible: NixChannelService.behind

                        DButton {
                            buttonHeight: 32
                            text: "Compare"
                            iconName: "open_in_new"
                            onClicked: {
                                Qt.openUrlExternally(NixChannelService.compareUrl());
                                popoutRoot.close();
                            }
                        }

                        DButton {
                            buttonHeight: 32
                            visible: !NixChannelService.lockMode
                            text: "Mark seen"
                            iconName: "done"
                            onClicked: NixChannelService.markSeen()
                        }
                    }
                }
            }
        }
    }
}
