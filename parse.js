.pragma library

function parseChannels(text) {
    const json = JSON.parse(text);
    if (json.status !== "success")
        throw new Error(json.error || "query failed");
    const byName = {};
    for (const r of json.data.result) {
        const m = r.metric;
        if (!byName[m.channel])
            byName[m.channel] = {
                channel: m.channel,
                revision: "",
                status: "",
                current: false,
                updatedAt: 0
            };
        const c = byName[m.channel];
        if (m.__name__ === "channel_revision") {
            c.revision = m.revision;
            c.status = m.status;
            c.current = m.current === "1";
        } else if (m.__name__ === "channel_update_time") {
            c.updatedAt = parseInt(r.value[1]) * 1000;
        }
    }
    const channels = Object.values(byName).filter(c => c.revision).sort((a, b) => a.channel.localeCompare(b.channel));
    // An exporter outage still answers "success", just with no series; keep the last good data.
    if (channels.length === 0)
        throw new Error("no channel data");
    return channels;
}

// Channel tarballs (channels.nixos.org/<channel>/nixexprs.tar.xz) and FlakeHub releases
// (flakehub.com/f/NixOS/nixpkgs/0.2505.*) carry the channel in the URL rather than a ref.
function channelOf(original) {
    if (!original)
        return "";
    if (original.ref)
        return original.ref.replace(/^refs\/heads\//, "");
    const url = original.url || "";
    const flakehub = url.match(/flakehub\.com\/f\/NixOS\/nixpkgs\/0\.(\d\d)(\d\d)\./);
    if (flakehub)
        return "nixos-" + flakehub[1] + "." + flakehub[2];
    const tarball = url.match(/\/((?:nixos|nixpkgs)-[^/]+)\/nixexprs\.tar\.xz/);
    return tarball ? tarball[1] : "";
}

// Input refs are a node name, or a `follows` path of input names walked from the root node.
function parseLock(text, input) {
    const lock = JSON.parse(text);
    const nodes = lock.nodes;
    const resolve = ref => {
        if (typeof ref === "string")
            return ref;
        if (!Array.isArray(ref))
            return null;
        return ref.reduce((name, next) => name && nodes[name].inputs ? resolve(nodes[name].inputs[next]) : null, lock.root);
    };
    const node = nodes[resolve((nodes[lock.root].inputs || {})[input])];
    if (!node)
        return null;
    return {
        rev: (node.locked && node.locked.rev) || "",
        lastModified: ((node.locked && node.locked.lastModified) || 0) * 1000,
        ref: channelOf(node.original)
    };
}
