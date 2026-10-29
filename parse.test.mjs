// parse.js is a QML JS library: strip its pragma and eval it as a script.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const lib = {};
vm.runInNewContext(readFileSync(new URL("parse.js", import.meta.url), "utf8").replace(".pragma library", ""), lib);
// Values built in the vm context have its prototypes, which deepEqual rejects; round-trip them.
const plain = fn => (...args) => JSON.parse(JSON.stringify(fn(...args)));
const ctx = { parseLock: plain(lib.parseLock), parseChannels: plain(lib.parseChannels) };

const lock = JSON.stringify({
    root: "root",
    version: 7,
    nodes: {
        root: { inputs: { nixpkgs: "nixpkgs_2", tools: "tools", pinned: ["tools", "nixpkgs"], tarball: "tarball", git: "git" } },
        tools: { inputs: { nixpkgs: "nixpkgs" }, locked: { rev: "t00l" } },
        nixpkgs: { locked: { rev: "decoy", lastModified: 1 }, original: { ref: "nixpkgs-unstable" } },
        nixpkgs_2: { locked: { rev: "mine", lastModified: 1793110635 }, original: { ref: "nixos-unstable" } },
        tarball: { locked: { narHash: "sha256-x" } },
        git: { locked: { rev: "g1t" }, original: { type: "git", ref: "refs/heads/nixos-25.11" } }
    }
});

assert.deepEqual(ctx.parseLock(lock, "nixpkgs"),{ rev: "mine", lastModified: 1793110635000, ref: "nixos-unstable" });
assert.equal(ctx.parseLock(lock, "pinned").rev, "decoy");
assert.throws(() => ctx.parseLock(lock, "missing"), /no input "missing"/);
assert.throws(() => ctx.parseLock(lock, "tarball"), /no git revision/);
assert.equal(ctx.parseLock(lock, "git").ref, "nixos-25.11");

const prom = JSON.stringify({
    status: "success",
    data: {
        result: [
            { metric: { __name__: "channel_revision", channel: "nixos-unstable", revision: "abc", status: "rolling", current: "1" }, value: [0, "1"] },
            { metric: { __name__: "channel_update_time", channel: "nixos-unstable" }, value: [0, "1793155758"] },
            { metric: { __name__: "channel_revision", channel: "nixos-25.11", revision: "old", status: "unmaintained", current: "0" }, value: [0, "1"] },
            { metric: { __name__: "channel_update_time", channel: "orphan" }, value: [0, "5"] }
        ]
    }
});
assert.deepEqual(ctx.parseChannels(prom), [
    { channel: "nixos-25.11", revision: "old", status: "unmaintained", current: false, updatedAt: 0 },
    { channel: "nixos-unstable", revision: "abc", status: "rolling", current: true, updatedAt: 1793155758000 }
]);

assert.throws(() => ctx.parseChannels(JSON.stringify({ status: "success", data: { result: [] } })), /no channel data/);
assert.throws(() => ctx.parseChannels(JSON.stringify({ status: "error", error: "bad query" })), /bad query/);

console.log("parse.js ok");
