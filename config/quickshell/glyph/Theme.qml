pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settings
import "schemes.js" as Schemes

// glyph: black, white dots, one red. Palette, fonts, motion, state (theme, silence) and hypr/kitty look — here
Singleton {
    id: root

    // state survives restart; lock (separate process) reads it too
    readonly property alias state: st
    // color — where from (launcher → style, settings → STYLE), like scheme in caelestia: nothing — black, white and red; wall —
    // from wallpaper tones by variant, like dynamic in caelestia (tonal spot, fruit salad… — schemes.js); scheme — ready palette, theme
    // has its own. Palette — { light, c: greys by roles below, accent, red, ansi: 16 kitty colors }
    readonly property var pal: make({})
    readonly property bool light: pal.light

    // light theme — same layout, greys reversed; red unchanged
    readonly property var glyphDark: ["#000000", "#0E0E0E", "#1A1A1A", "#2A2A2A", "#4A4A4A", "#8C8C8C", "#F2F2F2"]
    readonly property var glyphLight: ["#E9E9E9", "#FFFFFF", "#F1F1F1", "#D9D9D9", "#B8B8B8", "#6E6E6E", "#0B0B0B"]
    readonly property var greys: pal.c
    readonly property color bg: greys[0]   // background, wallpaper
    readonly property color s1: greys[1]   // bar, panels
    readonly property color s2: greys[2]   // tiles, off
    readonly property color s3: greys[3]   // lines, dim dots
    readonly property color mute: greys[4] // inactive
    readonly property color grey: greys[5] // labels, secondary
    readonly property color fg: greys[6]   // text, on, focus
    readonly property color ink: light ? s1 : bg // text on white tile
    readonly property color accent: pal.accent // at most one thing on screen, only "live"
    readonly property color red: pal.red       // alarm: battery, critical, wrong password
    readonly property color nothingRed: "#D71921"
    readonly property color glow: light ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(1, 1, 1, 0.6)
    readonly property color scrim: fade(bg, light ? 0.8 : 0.74)

    readonly property string dot: "Doto"                   // digits and short words, no smaller than 26px
    readonly property string ui: "Space Grotesk"
    readonly property string mono: "Space Mono"            // labels in caps
    readonly property string nf: "JetBrainsMono Nerd Font" // icons

    // layout canvas 1920×1080 → screen. ponytail: by first screen, second screen same layout (scale — hypr), home only stretches
    // bento to right edge
    readonly property real s: {
        const sc = Quickshell.screens[0];
        return sc ? Math.min(sc.width / 1920, sc.height / 1080) : 1;
    }
    // per-screen own settings — in state.screens by monitor model: it's the monitor itself, not port (same monitor in another port or via
    // dock — its own). Two identical or no model — by port name. Model same as in hyprctl (Rules.key)
    function sid(name) {
        const m = Quickshell.screens.find(s => s.name === name)?.model.trim();
        return m && Quickshell.screens.filter(s => s.model.trim() === m).length === 1 ? m : name;
    }
    // by name — old record (before models) or a duplicate left as one
    function own(name) { return st.screens[sid(name)] ?? st.screens[name]; }
    // screen settings by output name: own, else shared; bar and home default to present
    function scr(name, key) { return own(name)?.[key] ?? { wall: st.wall, widgets: st.widgets }[key] ?? true; }
    // undefined — drop own, screen takes shared. Record by port name copied under model but stays: duplicate returns —
    // screen searched by port again
    function setScr(name, key, v) {
        const o = Object.assign({}, own(name)), all = Object.assign({}, st.screens);
        if (v === undefined) delete o[key];
        else o[key] = v;
        all[sid(name)] = o;
        st.screens = all;
    }

    // glide: ease-out-quart, no overshoot — like bezier glide in hypr
    readonly property var glide: [0.25, 1, 0.5, 1, 1, 1]
    readonly property int t: 350

    // wallpapers drawn from per-screen copy (picker makes it, magick): original can be 40MB png, would load for seconds.
    // ponytail: no copy (cache cleared, path typed by hand) — empty, grid and orb until picker opened
    readonly property string wallCache: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/glyph/walls"
    function wallSrc(p) { return p ? `${wallCache}/${p.slice(p.lastIndexOf("/") + 1)}.jpg` : ""; }
    function url(p) { return p ? "file://" + p.split("/").map(encodeURIComponent).join("/") : ""; }

    // ---- wallpaper tones: up to four to choose, like android. They're in glyph.json: lock (separate process) takes ready ones and doesn't flash
    // red ----
    // wallpaper colors come from: first screen — own or shared (own on all screens — shared invisible anywhere)
    readonly property string wall: scr(Quickshell.screens[0]?.name, "wall")
    readonly property var tones: wall ? st.tones : []
    function hueName(c) {
        const h = Qt.color(c).hslHue * 360;
        return ["red", "orange", "yellow", "green", "teal", "blue", "violet", "pink", "red"][[15, 40, 65, 160, 195, 250, 290, 335, 361].findIndex(x => h < x)];
    }
    // palette as it would be with st replaced by o ({ paint, scheme, at, variant, light }): shell lives by it (o empty), samples
    // STYLE show it too. No tones (grey wallpaper, no image) — nothing
    function make(o) {
        const k = Object.assign({ paint: st.paint, scheme: st.scheme, at: st.paintAt, variant: st.variant, light: st.light }, o);
        if (k.paint === "scheme") return Schemes.ALL.find(p => p.id === k.scheme) ?? Schemes.ALL[0];
        // 16 ANSI glyph: in light 0↔15 and 7↔8, so white isn't lost on white
        const base = { light: k.light, c: k.light ? glyphLight : glyphDark, accent: nothingRed, red: nothingRed,
                       ansi: k.light ? [15, 1, 2, 3, 4, 5, 6, 8, 7, 9, 10, 11, 12, 13, 14, 0].map(i => ansi[i]) : ansi };
        const src = tones[Math.min(k.at, tones.length - 1)];
        return k.paint === "wall" && src ? Schemes.dynamic(src, k.variant, base) : base;
    }
    // theme: palette's own or pair from its group (mocha → latte, dawn → main); no pair (nord, dracula…) — don't change theme,
    // otherwise st.light would diverge from screen and surface on source change
    function pair(l) { return st.paint !== "scheme" ? null : pal.light === l ? pal : Schemes.ALL.find(x => x.group === pal.group && x.light === l) ?? null; }
    function setLight(l) {
        const p = pair(l);
        if (st.paint === "scheme" && !p) return;
        if (p) st.scheme = p.id;
        st.light = l;
    }
    // choice for launcher (style) and settings (STYLE): blocks { head, items: [{ name, pal, fill, dot, now, run }] }; pal — palette,
    // if chosen, fill — sample circle, dot — smaller circle in it (accent), now — current. First where color comes from, under it —
    // what this source has: wallpaper tones and variants or palettes by group; theme at end
    readonly property var styles: {
        const set = (k, v) => () => st[k] = v, at = Math.min(st.paintAt, tones.length - 1);
        const it = (name, p, now, run, fill) => ({ name, pal: p, fill: fill ?? p.c[1], dot: p.accent, now, run });
        const own = st.paint === "wall" ? [
            { head: "tones", items: tones.map((t, i) => it(hueName(t), make({ at: i }), at === i, set("paintAt", i), t)) },
            // circle — grey mute of variant (shows which color greys went to), accent in it; amount — color share, in order
            { head: "variant", items: tones.length ? Schemes.VARIANTS.map((v, i) => {
                const p = make({ variant: v.id });
                return Object.assign(it(v.name, p, st.variant === v.id, set("variant", v.id), p.c[4]), { amount: i / (Schemes.VARIANTS.length - 1) });
            }) : [] }
        ] : st.paint === "scheme" ? Schemes.GROUPS.map(g => ({ head: g, items: Schemes.ALL.filter(p => p.group === g).map(p =>
            Object.assign(it(p.name, p, st.scheme === p.id, () => { st.scheme = p.id; st.light = p.light; }), { extra: g })) })) : [];
        return [{ head: "source", items: [
            it("nothing", make({ paint: "" }), !st.paint || st.paint === "wall" && !tones.length, set("paint", ""), nothingRed),
            it("wallpaper", make({ paint: "wall" }), st.paint === "wall" && !!tones.length, set("paint", "wall"), tones[0]),
            it("palette", make({ paint: "scheme" }), st.paint === "scheme", set("paint", "scheme"))
        ] }].concat(own.filter(b => b.items.length), [
            { head: "theme", items: [["dark", false], ["light", true]].map(([n, l]) => it(n, make({ light: l, scheme: pair(l)?.id ?? st.scheme }),
                light === l, () => setLight(l))) }
        ]);
    }
    // like score in material you, but simpler: quantizer cuts image into 16 equal-area pieces and returns average color
    // of each. Vote saturated (chroma — max − min channels — above 0.12; below, large washed fills win, not image color):
    // hue leads, the one with more (±15°), among its own — most saturated. Then up to three others, no closer than 30°
    // from each other. No saturated — no tones, red remains. Calls quantizer in shell.qml (not here: Theme loads lock too)
    function pick(cols) {
        const ch = c => c.hsvSaturation * c.hsvValue, d = (a, b) => Math.abs((a.hsvHue - b.hsvHue + 1.5) % 1 - 0.5);
        const all = Array.from(cols), live = all.filter(c => ch(c) > 0.12);
        const score = c => 0.7 * live.filter(o => d(o, c) < 1 / 24).length / all.length + 0.3 * ch(c);
        const out = [];
        for (const c of live.sort((a, b) => score(b) - score(a)))
            if (out.length < 4 && out.every(o => d(o, c) >= 1 / 12)) out.push(c);
        return out.map(c => c.toString());
    }
    // brightness, relative, like WCAG
    function lum(c) { c = Qt.lighter(c, 1); const f = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); }
    // what to write over color c: black or white, where contrast larger (brightness threshold 0.18 — per WCAG)
    function on(c) { return lum(c) > 0.18 ? "#000000" : "#FFFFFF"; }

    function fade(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    // panel/tile/pill corner radius — by corners setting (prefs → WINDOWS → panels): 0 straight, 100 as intended
    function corner(px) { return px * st.corners / 100; }
    // clock by 12/24 setting: "09" or "9"
    function hh(d) { const h = d.getHours(); return st.clock24 ? String(h).padStart(2, "0") : String(h % 12 || 12); }
    function hex(c) { return c.toString().slice(1, 7).toUpperCase(); }

    readonly property string riceState: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/rice"
    // like Rules: apply() at start must see glyph.json, not defaults
    Component.onCompleted: stateFile.waitForJob()

    FileView {
        id: stateFile
        path: root.riceState + "/glyph.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        // write — once per turn end: writeAdapter() on every field in a row confuses neighbors
        onAdapterUpdated: Qt.callLater(stateFile.writeAdapter)
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: st
            property bool light: false
            property string paint: ""     // where color from: empty — nothing, wall — wallpaper, scheme — palette
            property string scheme: "mocha" // which palette, id from schemes.js
            property int paintAt: 0       // which wallpaper tone
            property var tones: []        // wallpaper tones, written by quantizer; empty — grey wallpaper or no image
            property string variant: "tonalspot" // how wallpaper tone becomes palette, id from schemes.js (VARIANTS)
            property bool dnd: false  // new ones not shown, critical — always
            property int unread: 0    // for lock
            // ---- what prefs tweak ----
            property var widgets: ["weather", "calendar", "cpu", "player", "buds", "system"] // home bento in order, see kinds
            property bool clock24: true
            property bool blink: true      // clock colon blinks
            property string name: ""       // in greeting; empty — $USER
            property bool grid: true       // dot grid on wallpaper
            property bool orb: true        // halftone orb
            // wallpaper (picker wall/Walls, drawn by components/Wall): image path; empty — grid and orb. Picker folder can be changed here
            property string wall: ""
            property string wallDir: ""    // empty — ~/Pictures/Wallpapers
            property int wallLook: 0       // 0 dots, 1 grey photo, 2 color
            property int wallPitch: 10     // dot step, px
            property int wallBright: 85    // %, from background to image
            property string gif: ""        // cat tile gif (services/Gifs), path; empty — first in folder
            property string gifDir: ""     // empty — ~/Pictures/Gifs
            property int rounding: 20      // hypr windows
            property int corners: 100      // shell panel corners, % of own; circles stay circles (Theme.corner)
            property bool edges: true      // Glyph edge bars (volume/brightness, flashes, progress)
            property int briSteps: 20      // brightness from keys: divisions on scale, 40/20/10 — step 2.5/5/10 %
            property bool quickHover: true // quick settings on hover right edge
            property bool deckHover: true  // deck — bottom center panel, pops on edge hover
            property var deck: ["clock", "weather", "perf", "net", "media"] // its sections in order, see decks
            property var bar: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power"] // bar tray top to bottom, see bars
            property bool barTitle: true   // window title stacked in bar
            property string barAt: "left" // left or top; calendar, battery card, home, island and Glyph flash follow bar
            // per-monitor own, by model (Theme.sid): { "TS2700-S6-1": { bar: false, home: false, wall: "…", widgets: […] } }; none — shared (Theme.scr)
            property var screens: ({})
            // recording (quick/Rec, Sys.recArgs)
            property int recArea: 0        // 0 whole monitor, 1 area (slurp)
            property int recAudio: 0       // 0 no sound, 1 system, 2 mic, 3 both one track
            property int recFps: 60
            property int recQuality: 2     // medium, high, very_high, ultra
            property bool recCursor: true
            property bool vpnPortal: false // tunnel dropped due to portal, restore in open network (vpn/Vpn)
        }
    }

    // bento widgets: id → width in cells (3 cols × 3 rows of 220). Doesn't fit — not shown
    readonly property var kinds: ({ weather: 1, calendar: 1, cpu: 1, ram: 1, gpu: 1, disk: 1, battery: 1, buds: 1, player: 2, system: 3, cat: 1, cava: 1 })
    // deck sections
    readonly property var decks: ["clock", "weather", "perf", "net", "media"]
    // bar tray
    readonly property var bars: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power", "cat"]

    // ---- look of everything outside shell. Only shell.qml calls: on start, on theme and color change ----
    // hypr inherits demonshot: monitor, input, idle, night light and motion set by its Rules (shell.qml), animations — from
    // hypr config. From here — gaps/frame/blur/shadows from its rules.json, and glyph's own — frame colors, shadows, groups, background and
    // rounding 20 (without them red glow and demonshot groups from hypr/variables.lua would remain).
    // Back to demonshot: `rice switch` does hyprctl reload, its applyAll repaints
    function hypr(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]); }

    // kitty includes this file after its colors (include in kitty.conf); demonshot writes its palette there too
    FileView { id: kitty; path: Quickshell.env("HOME") + "/.config/demonshot/kitty.conf"; printErrors: false }
    // 16 ANSI from concept: pastel only for terminal. Light theme rearranges them (make)
    readonly property var ansi: ["#0E0E0E", "#D71921", "#9BB59A", "#D9C38A", "#8EA3C2", "#B79BC2", "#8FB8B8", "#C9C9C9",
                                 "#4A4A4A", "#F0434B", "#B5CCB4", "#E8D6A8", "#AABBD4", "#CDB6D6", "#ABCDCD", "#F2F2F2"]

    function apply() {
        // game mode (Rules.store.game) — over settings, like ultra: frame 1, no gaps/rounding, tearing for
        // windows with immediate (games, hyprland/rules.lua). Left — own values return, allow_tearing — false, as in general.lua
        const r = Rules.store, g = r.game;
        const c = x => `"rgb(${hex(x)})"`;
        // shadow: in dark — barely visible white glow, in light — soft black
        const shadow = light ? "rgba(0000002E)" : `rgba(${hex(fg)}1A)`;
        hypr(`hl.config({ general = { gaps_in = ${g ? 0 : r.gapsIn}, gaps_out = ${g ? 0 : r.gapsOut}, border_size = ${g ? 1 : r.border}, allow_tearing = ${g}, `
           + `col = { active_border = ${c(fg)}, inactive_border = ${c(s3)} } }, `
           + `decoration = { rounding = ${g ? 0 : st.rounding}, blur = { enabled = ${Rules.blurOn} }, shadow = { enabled = ${Rules.shadowOn}, color = "${shadow}" } }, `
           + `group = { col = { border_active = ${c(fg)}, border_inactive = ${c(s3)}, border_locked_active = ${c(fg)}, border_locked_inactive = ${c(mute)} }, `
           + `groupbar = { font_family = "${mono}", text_color = ${c(fg)}, col = { active = ${c(s3)}, inactive = ${c(s1)}, locked_active = ${c(s3)}, locked_inactive = ${c(s1)} } } }, `
           + `misc = { background_color = ${c(bg)} } })`);

        kitty.setText("# glyph: written by Theme.apply(), don't edit by hand\n" + [
            ["font_family", "Space Mono"], ["window_padding_width", "26 30"], ["cursor_trail", "0"],
            ["foreground", fg], ["background", s1], ["cursor", fg], ["cursor_text_color", s1],
            ["selection_foreground", fg], ["selection_background", s3], ["url_color", grey],
            ["active_border_color", fg], ["inactive_border_color", s3],
            ["active_tab_foreground", ink], ["active_tab_background", fg],
            ["inactive_tab_foreground", grey], ["inactive_tab_background", s1], ["tab_bar_background", bg]
        ].concat(pal.ansi.map((c, i) => ["color" + i, c])).map(([k, v]) => `${k} ${typeof v === "string" ? v : v.toString().slice(0, 7).toUpperCase()}`).join("\n") + "\n");
        Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);
    }

    // gtk and qt — only on color change (shell.qml): apply() called on every corner ring step too. Templates — own term/
    // (dark glyph palette): its colors in them change to colors of same roles in palette (greys, red, qt also
    // green/yellow/blue… from ansi), copies — in riceState/glyph, links ~/.config/… — to copies. Nothing to change — back to
    // term/, as rice sets. Real file (not link) not touched, like rice. Two-pass replace via @n@: palette color
    // may match glyph color replaced next. gtk and qt take colors on next launch: gtk reads its gtk.css
    // once, poking theme doesn't help (tested on gtk 3 and 4).
    // ponytail: light theme here is dark — gtk base dark (adw-gtk3-dark): wallpaper — same variant in dark, palettes —
    // dark pair (latte → mocha), nothing — glyph; light — also change gtk-theme and color-scheme. btop not painted — its folder
    // linked whole into repo, no place for copy; if needed — color_theme path to copy
    function apps() {
        const from = glyphDark.concat(ansi.slice(1, 7));
        const p = pal.light ? pair(false) ?? make({ light: false }) : pal;
        const to = p.c.concat([p.red], p.ansi.slice(2, 7));
        const pairs = from.map((c, i) => [c, "#" + hex(Qt.lighter(to[i], 1))]).filter(([a, b]) => a !== b);
        const sed = pairs.map(([a], i) => ["-e", `s/${a}/@${i}@/gI`]).concat(pairs.map(([, b], i) => ["-e", `s/@${i}@/${b}/g`])).reduce((x, y) => x.concat(y), []);
        Quickshell.execDetached(["bash", "-c", `t=$1 o=$2; shift 2
for f in gtk-3.0/gtk.css gtk-4.0/gtk.css qtengine.colors; do
    l=$HOME/.config/$f
    [ -L "$l" ] || [ ! -e "$l" ] || continue
    if [ $# -gt 0 ]; then mkdir -p "$(dirname "$o/$f")" && sed "$@" "$t/$f" > "$o/$f" && ln -sfn "$o/$f" "$l"; else ln -sfn "$t/$f" "$l"; fi
done`,
            "bash", Quickshell.shellPath("term"), riceState + "/glyph"].concat(sed));
    }
}