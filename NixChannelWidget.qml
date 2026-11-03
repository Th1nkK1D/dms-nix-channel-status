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
            colorOverride: NixChannelService.behind ? (Theme[NixChannelService.iconColorToken] ?? Theme.primary) : (Theme[NixChannelService.idleColorToken] ?? Theme.surfaceText)
        }

        Rectangle {
            visible: NixChannelService.behind
            width: 8
            height: 8
            radius: 4
            color: Theme[NixChannelService.dotColorToken] ?? Theme.primary
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

            readonly property var current: NixChannelService.current

            implicitHeight: layout.implicitHeight

            function close() {
                if (popoutRoot.closePopout)
                    popoutRoot.closePopout();
            }

            PopoutComponent {
                id: layout
                width: parent.width
                headerText: I18n.trFor("nixChannelStatus", "Nix Channel Status")
                detailsText: {
                    const svc = NixChannelService;
                    if (svc.linkDown && !popoutRoot.current)
                        return I18n.trFor("nixChannelStatus", "No network connection.");
                    if (svc.fetchError && !popoutRoot.current)
                        return svc.fetchError;
                    if (!popoutRoot.current)
                        return svc.checking || svc.lastChecked === 0 ? I18n.trFor("nixChannelStatus", "Checking…") : I18n.trFor("nixChannelStatus", "Channel %1 not found on status.nixos.org.").arg(svc.channelName);
                    return I18n.trFor("nixChannelStatus", "%1 · updated %2 · checked %3").arg(svc.channelName).arg(svc.formatAge(popoutRoot.current.updatedAt)).arg(svc.formatAge(svc.lastChecked));
                }

                headerActions: Component {
                    Row {
                        spacing: Theme.spacingXS

                        DActionButton {
                            iconName: "open_in_new"
                            tooltipText: I18n.trFor("nixChannelStatus", "Open status.nixos.org")
                            onClicked: {
                                Qt.openUrlExternally("https://status.nixos.org");
                                popoutRoot.close();
                            }
                        }

                        DActionButton {
                            iconName: "settings"
                            tooltipText: I18n.trFor("nixChannelStatus", "Open plugin settings")
                            onClicked: {
                                popoutRoot.close();
                                PopoutService.openSettingsWithTab("plugins");
                            }
                        }

                        DActionButton {
                            iconName: "refresh"
                            tooltipText: I18n.trFor("nixChannelStatus", "Check now")
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
                            const base = svc.shortRev(svc.baseRevision);
                            const rev = svc.shortRev(cur.revision);
                            if (svc.inSync)
                                return I18n.trFor("nixChannelStatus", "Up to date · %1").arg(rev);
                            if (svc.behind)
                                return (svc.lockMode ? I18n.trFor("nixChannelStatus", "Update available · %1 → %2") : I18n.trFor("nixChannelStatus", "New revision · %1 → %2")).arg(base).arg(rev);
                            if (svc.lockMode && svc.lock)
                                return I18n.trFor("nixChannelStatus", "Locked %1 is newer than %2").arg(base).arg(rev);
                            return I18n.trFor("nixChannelStatus", "Revision %1").arg(rev);
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: NixChannelService.lockMode && NixChannelService.lockError ? Theme.error : (NixChannelService.behind ? Theme.primary : Theme.surfaceText)
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        width: parent.width - parent.leftPadding
                        visible: NixChannelService.fetchError !== "" && popoutRoot.current !== null
                        text: I18n.trFor("nixChannelStatus", "%1 — showing the last result.").arg(NixChannelService.fetchError)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        spacing: Theme.spacingS
                        visible: NixChannelService.behind

                        DButton {
                            buttonHeight: 32
                            text: I18n.trFor("nixChannelStatus", "Compare")
                            iconName: "open_in_new"
                            onClicked: {
                                Qt.openUrlExternally(NixChannelService.compareUrl());
                                popoutRoot.close();
                            }
                        }

                        DButton {
                            buttonHeight: 32
                            visible: !NixChannelService.lockMode
                            text: I18n.trFor("nixChannelStatus", "Mark seen")
                            iconName: "done"
                            onClicked: NixChannelService.markSeen()
                        }
                    }
                }
            }
        }
    }
}
