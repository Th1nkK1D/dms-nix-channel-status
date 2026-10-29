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

    property string channelSetting: autoChannel
    property string lockPath: ""
    property string inputName: "nixpkgs"

    property var channels: []
    property var _request: null
    readonly property bool checking: _request !== null
    property string fetchError: ""
    property double lastChecked: 0
    property double nextDue: 0
    property double now: Date.now()

    property var lock: null
    property string lockError: ""

    property var seen: ({})

    // Without a network backend networkStatus is always "disconnected", which says nothing.
    readonly property bool linkDown: NetworkService.networkAvailable && NetworkService.networkStatus === "disconnected"
    readonly property bool lockMode: lockPath !== ""
    readonly property string channelName: channelSetting !== autoChannel ? channelSetting : ((lock && lock.ref) || fallbackChannel)
    readonly property var current: channels.find(c => c.channel === channelName) ?? null
    readonly property string baseRevision: lockMode ? (lock ? lock.rev : "") : (seen[channelName] || "")
    readonly property bool inSync: current !== null && current.revision === baseRevision
    readonly property bool behind: {
        if (!current || !baseRevision || inSync)
            return false;
        return !lockMode || lock.lastModified < current.updatedAt;
    }

    function loadSettings() {
        channelSetting = PluginService.loadPluginData(pluginId, "channel", autoChannel) || autoChannel;
        lockPath = String(PluginService.loadPluginData(pluginId, "lockPath", "") || "").trim();
        inputName = String(PluginService.loadPluginData(pluginId, "input", "nixpkgs") || "").trim() || "nixpkgs";
        seen = PluginService.loadPluginState(pluginId, "seen", {}) || {};
        if (lockMode) {
            lockView.reload();
        } else {
            lock = null;
            lockError = "";
        }
        _adoptSeen();
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
                throw new Error(xhr.status === 0 ? "network error" : "HTTP " + xhr.status);
            channels = Parse.parseChannels(xhr.responseText);
            fetchError = "";
            lastChecked = at;
            nextDue = at + periodMs;
        } catch (e) {
            fetchError = "status.nixos.org check failed (" + e.message + ")";
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
            return "just now";
        if (mins < 60)
            return mins + "m ago";
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return hours + "h ago";
        const leftover = hours % 24;
        return Math.floor(hours / 24) + "d" + (leftover ? " " + leftover + "h" : "") + " ago";
    }

    function compareUrl() {
        return "https://github.com/NixOS/nixpkgs/compare/" + baseRevision + "..." + current.revision;
    }

    FileView {
        id: lockView
        path: root.lockMode ? Paths.expandTilde(root.lockPath) : ""
        printErrors: false
        watchChanges: true
        onFileChanged: lockSettle.restart()
        onLoaded: {
            try {
                root.lock = Parse.parseLock(text(), root.inputName);
                root.lockError = "";
            } catch (e) {
                root.lock = null;
                root.lockError = e.message;
            }
        }
        onLoadFailed: {
            root.lock = null;
            root.lockError = "Can't read " + root.lockPath;
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
            root._onFetched(xhr, "timed out");
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
        target: PluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                root.loadSettings();
        }
    }

    Component.onCompleted: loadSettings()
}
