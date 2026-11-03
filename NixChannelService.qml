pragma Singleton

import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import "parse.js" as Parse

Item {
    id: root

    readonly property string pluginId: "nixChannelStatus"
    readonly property string autoChannel: "auto"
    readonly property string fallbackChannel: "nixos-unstable"
    readonly property string endpoint: "https://prometheus.nixos.org/api/v1/query?query=" + encodeURIComponent("channel_revision or channel_update_time")
    readonly property int periodMs: 3600 * 1000
    readonly property int retryMs: 5 * 60 * 1000

    readonly property string defaultColor: "primary"
    readonly property string defaultIdleColor: "surfaceText"
    readonly property var colorLabels: ({
            primary: I18n.trFor("nixChannelStatus", "Primary"),
            secondary: I18n.trFor("nixChannelStatus", "Secondary"),
            tertiary: I18n.trFor("nixChannelStatus", "Tertiary"),
            surfaceText: I18n.trFor("nixChannelStatus", "Surface text"),
            success: I18n.trFor("nixChannelStatus", "Success"),
            info: I18n.trFor("nixChannelStatus", "Info"),
            warning: I18n.trFor("nixChannelStatus", "Warning"),
            error: I18n.trFor("nixChannelStatus", "Error")
        })
    readonly property var colorOptions: Object.keys(colorLabels).map(token => ({
                label: colorLabels[token],
                value: token
            }))

    property string channelSetting: autoChannel
    property string lockPath: ""
    property string inputName: "nixpkgs"
    property string idleColorToken: defaultIdleColor
    property string iconColorToken: defaultColor
    property string dotColorToken: defaultColor

    property var channels: []
    property var _request: null
    readonly property bool checking: _request !== null
    property string fetchError: ""
    property double lastChecked: 0
    property double nextDue: 0
    property double now: Date.now()

    property var lock: null
    property string lockError: ""

    property string compareKey: ""
    property string compareStatus: ""

    property var seen: ({})

    // Without a network backend networkStatus is always "disconnected", which says nothing.
    readonly property bool linkDown: NetworkService.networkAvailable && NetworkService.networkStatus === "disconnected"
    readonly property bool lockMode: lockPath !== ""
    readonly property string lockFile: {
        if (!lockMode)
            return "";
        let path = Paths.expandTilde(lockPath).replace(/\/+$/, "");
        if (!path.startsWith("/"))
            path = Paths.strip(Paths.home) + "/" + path;
        return path.endsWith(".lock") ? path : path + "/flake.lock";
    }
    readonly property string channelName: channelSetting !== autoChannel ? channelSetting : ((lock && lock.ref) || fallbackChannel)
    readonly property var current: channels.find(c => c.channel === channelName) ?? null
    readonly property string baseRevision: lockMode ? (lock ? lock.rev : "") : (seen[channelName] || "")
    readonly property bool inSync: current !== null && current.revision === baseRevision
    // A channel revision is always committed before the channel moves to it, so a lock committed
    // after that move is newer; for an older lock only GitHub can tell which side is ahead.
    readonly property string wantedCompare: lockMode && lock && current && !inSync && lock.lastModified < current.updatedAt ? lock.rev + "..." + current.revision : ""
    readonly property bool behind: {
        if (!current || !baseRevision || inSync)
            return false;
        if (!lockMode)
            return true;
        if (lock.lastModified >= current.updatedAt)
            return false;
        return compareKey !== wantedCompare || compareStatus !== "behind";
    }

    onWantedCompareChanged: compare()

    function loadSettings() {
        const input = String(PluginService.loadPluginData(pluginId, "input", "nixpkgs") || "").trim() || "nixpkgs";
        const inputChanged = input !== inputName;
        inputName = input;
        channelSetting = PluginService.loadPluginData(pluginId, "channel", autoChannel) || autoChannel;
        lockPath = String(PluginService.loadPluginData(pluginId, "lockPath", "") || "").trim();
        idleColorToken = PluginService.loadPluginData(pluginId, "idleColor", defaultIdleColor) || defaultIdleColor;
        iconColorToken = PluginService.loadPluginData(pluginId, "iconColor", defaultColor) || defaultColor;
        dotColorToken = PluginService.loadPluginData(pluginId, "dotColor", defaultColor) || defaultColor;
        seen = PluginService.loadPluginState(pluginId, "seen", {}) || {};
        if (!lockMode) {
            lock = null;
            lockError = "";
        } else if (inputChanged) {
            lockView.reload();
        }
        _adoptSeen();
    }

    // Page 2 of one-commit pages leaves out the commit and file lists, which run to megabytes here.
    function compare() {
        const key = wantedCompare;
        if (!key || key === compareKey)
            return;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200 || key !== wantedCompare)
                return;
            try {
                compareStatus = JSON.parse(xhr.responseText).status;
                compareKey = key;
            } catch (e) {}
        };
        xhr.open("GET", "https://api.github.com/repos/NixOS/nixpkgs/compare/" + key + "?per_page=1&page=2");
        xhr.send();
    }

    function refresh() {
        if (checking)
            return;
        if (lockMode)
            lockView.reload();
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE)
                _onFetched(xhr, "");
        };
        _request = xhr;
        fetchTimeout.restart();
        xhr.open("GET", endpoint);
        xhr.send();
    }

    function _onFetched(xhr, failure) {
        if (xhr !== _request)
            return;
        _request = null;
        fetchTimeout.stop();
        const at = Date.now();
        try {
            if (failure)
                throw new Error(failure);
            if (xhr.status !== 200)
                throw new Error(xhr.status === 0 ? I18n.trFor("nixChannelStatus", "network error") : "HTTP " + xhr.status);
            channels = Parse.parseChannels(xhr.responseText);
            fetchError = "";
            lastChecked = at;
            nextDue = at + periodMs;
            compare();
        } catch (e) {
            fetchError = I18n.trFor("nixChannelStatus", "status.nixos.org check failed (%1)").arg(e.message);
            nextDue = at + retryMs;
        }
        _adoptSeen();
    }

    function _adoptSeen() {
        if (!lockMode && current && !seen[channelName])
            markSeen();
    }

    function markSeen() {
        if (!current)
            return;
        const next = Object.assign({}, seen);
        next[channelName] = current.revision;
        seen = next;
        PluginService.savePluginState(pluginId, "seen", next);
    }

    function shortRev(rev) {
        return String(rev || "").substring(0, 7);
    }

    function formatAge(epochMs) {
        const mins = Math.max(0, Math.floor((now - epochMs) / 60000));
        if (mins < 1)
            return I18n.trFor("nixChannelStatus", "just now");
        if (mins < 60)
            return I18n.trFor("nixChannelStatus", "%1m ago").arg(mins);
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return I18n.trFor("nixChannelStatus", "%1h ago").arg(hours);
        const days = Math.floor(hours / 24);
        const leftover = hours % 24;
        return leftover ? I18n.trFor("nixChannelStatus", "%1d %2h ago").arg(days).arg(leftover) : I18n.trFor("nixChannelStatus", "%1d ago").arg(days);
    }

    function compareUrl() {
        return "https://github.com/NixOS/nixpkgs/compare/" + baseRevision + "..." + current.revision;
    }

    FileView {
        id: lockView
        path: root.lockFile
        printErrors: false
        watchChanges: true
        onFileChanged: lockSettle.restart()
        onLoaded: {
            try {
                const parsed = Parse.parseLock(text(), root.inputName);
                if (!parsed)
                    throw new Error(I18n.trFor("nixChannelStatus", "No input \"%1\" in flake.lock").arg(root.inputName));
                if (!parsed.rev)
                    throw new Error(I18n.trFor("nixChannelStatus", "Input \"%1\" has no git revision").arg(root.inputName));
                root.lock = parsed;
                root.lockError = "";
            } catch (e) {
                root.lock = null;
                root.lockError = e.message;
            }
        }
        onLoadFailed: {
            root.lock = null;
            root.lockError = I18n.trFor("nixChannelStatus", "Can't read %1").arg(root.lockFile);
        }
    }

    // An in-place write fires the first change on truncate; reading then gets a partial file, and
    // FileView ignores a reload while a read of the same path is still in flight.
    Timer {
        id: lockSettle
        interval: 300
        onTriggered: lockView.reload()
    }

    Timer {
        id: fetchTimeout
        interval: 20000
        onTriggered: {
            const xhr = root._request;
            root._onFetched(xhr, I18n.trFor("nixChannelStatus", "timed out"));
            xhr.abort();
        }
    }

    // Qt timers stop during suspend, so tick each minute against wall time instead of sleeping
    // an hour. Singletons outlive the plugin, hence the loaded check.
    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now();
            if (root.now >= root.nextDue && PluginService.isPluginLoaded(root.pluginId))
                root.refresh();
        }
    }

    Connections {
        target: root
        function onLinkDownChanged() {
            if (!root.linkDown && (root.fetchError !== "" || Date.now() >= root.nextDue) && PluginService.isPluginLoaded(root.pluginId))
                root.refresh();
        }
    }

    Connections {
        target: PluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                root.loadSettings();
        }
    }

    Component.onCompleted: loadSettings()
}
