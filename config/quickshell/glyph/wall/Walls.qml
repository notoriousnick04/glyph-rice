import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import "../prefs"

// wallpapers: Super+Shift+W or settings → look. Not image grid — whole screen is preview: selected assembles from dots
// in wave from strip at bottom. Strip — circles-miniatures in dots, selected centered in ring (it glows by share of path through collection),
// red dot under currently live. First circle — NOTHING: no image, only grid and orb.
// ←→ / wheel — browse, tab — view (dots / grey photo / color), ↑↓ — dot step, shift ↑↓ — brightness, ↵ or click on
// selected — set, esc — as before. Images — from Theme.state.wallDir, per-screen copies — in Theme.wallCache (once)
PanelWindow {
    id: root

    readonly property string dir: Theme.state.wallDir || Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property var looks: ["dots", "mono", "color"]
    // copies — in physical screen pixels, with margin for crop
    readonly property string res: {
        const s = Quickshell.screens[0];
        return s ? `${Math.round(s.width * s.devicePixelRatio)}x${Math.round(s.height * s.devicePixelRatio)}^` : "2880x1800^";
    }

    property var files: [] // originals that already have a copy, by name
    property var fresh: [] // what current pass found
    readonly property var list: [""].concat(files)
    // selected — by path, number — from it: while cache being written, new ones land in middle and strip doesn't shift
    property string pick: ""
    readonly property int sel: Math.max(0, list.indexOf(pick))
    property int look: 0
    property int pitch: 10
    property int bright: 85

    function name(p) { return p ? p.slice(p.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "") : "nothing"; }
    function go(d) { pick = list[Math.max(0, Math.min(list.length - 1, sel + d))]; }

    // preview — when stopped browsing: each image — decode and 20MB in video memory, on fast scroll that's stutter.
    // Strip moves immediately
    property string view: ""
    onPickChanged: settle.restart()
    Timer { id: settle; interval: 160; onTriggered: root.view = root.pick }

    // strip moves as one animation: pos catches sel, circles compute place from fractional distance to it
    property real pos: sel
    Behavior on pos { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    // circle at distance d: selected 190, neighbors 128, further 12 less, not below 64; between integers — straight
    function size(d) { d = Math.abs(d); return d < 1 ? 190 - 62 * d : Math.max(64, 128 - (d - 1) * 12); }
    // circle centers on integer d, beyond 9 not needed — not visible there
    readonly property var at: {
        const a = [0];
        for (let k = 1; k <= 10; k++) a.push(a[k - 1] + (size(k - 1) + size(k)) / 2 + (k === 1 ? 44 : 22));
        return a;
    }
    function off(d) {
        const a = Math.min(Math.abs(d), 9), k = Math.floor(a), x = at[k] + (at[k + 1] - at[k]) * (a - k);
        return d < 0 ? -x : x;
    }

    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    Binding { target: Sys; property: "wallOpen"; value: root.visible }

    // several screens — wallpaper to all (shared; own per screen removed) or only to this one where picker opened
    property string mon: ""
    property bool own: false
    function open() {
        const s = Theme.state;
        mon = Hyprland.focusedMonitor?.name ?? "";
        // "" — own "no wallpaper". Single screen (second disabled) — no switcher, wallpapers shared, and own "all" removes
        own = Quickshell.screens.length > 1 && Theme.own(mon)?.wall !== undefined;
        pick = Theme.scr(mon, "wall");
        view = pick;
        look = s.wallLook;
        pitch = s.wallPitch;
        bright = s.wallBright;
        if (!scan.running) {
            fresh = [];
            scan.running = true;
        }
        shown = true;
        stage.forceActiveFocus();
    }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }
    function apply() {
        const s = Theme.state;
        if (own) Theme.setScr(mon, "wall", pick);
        else {
            s.wall = pick;
            for (const n in s.screens) if (s.screens[n].wall !== undefined) Theme.setScr(n, "wall", undefined);
        }
        s.wallLook = look;
        s.wallPitch = pitch;
        s.wallBright = bright;
        close();
    }

    // per-screen copies. One bash checks fresh without one process per file; missing or older than original — magick, three at once
    // (8k png eats hundreds MB). Ready — string to stdout. Write to temp and move: interrupted magick
    // won't leave broken copy newer than original
    Process {
        id: scan
        command: ["bash", "-c", `shopt -s nullglob nocaseglob; mkdir -p "$2"; todo=()
for f in "$1"/*.{jpg,jpeg,png,webp}; do
    if [ "$2/\${f##*/}.jpg" -nt "$f" ]; then printf '%s\\n' "$f"; else todo+=("$f"); fi
done
[ \${#todo[@]} -eq 0 ] || printf '%s\\0' "\${todo[@]}" | xargs -0 -P 3 -I{} sh -c 'b=$(basename "$1")
magick "$1[0]" -resize "$3" -quality 90 "$2/.$b.jpg" 2>/dev/null && mv "$2/.$b.jpg" "$2/$b.jpg" && printf "%s\\n" "$1"' _ {} "$2" "$3"`,
            "bash", root.dir, Theme.wallCache, root.res]
        stdout: SplitParser {
            onRead: f => {
                root.fresh.push(f);
                if (!root.files.includes(f)) root.files = root.files.concat([f]).sort();
            }
        }
        // removed from folder — out; unchanged don't touch: new array would recreate whole strip
        onExited: {
            const f = root.fresh.slice().sort();
            if (f.join("\n") !== root.files.join("\n")) root.files = f;
        }
    }

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-wall"

    Stage {
        id: stage
        opacity: root.t
        focus: true
        Keys.onPressed: e => {
            const up = e.key === Qt.Key_Up, down = e.key === Qt.Key_Down;
            if (e.key === Qt.Key_Left || e.key === Qt.Key_H) root.go(-1);
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_L) root.go(1);
            else if (e.key === Qt.Key_Home) root.pick = "";
            else if (e.key === Qt.Key_Tab) root.look = (root.look + 1) % 3;
            else if (e.key === Qt.Key_Backtab) root.look = (root.look + 2) % 3;
            else if ((up || down) && e.modifiers & Qt.ShiftModifier) root.bright = Math.max(10, Math.min(100, root.bright + (up ? 5 : -5)));
            else if (up || down) root.pitch = Math.max(4, Math.min(32, root.pitch + (up ? 1 : -1)));
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.apply();
            else if (e.key === Qt.Key_Escape) root.close();
            else return;
            e.accepted = true;
        }

        // same as under home wallpaper: grid and orb — visible at NOTHING and in wave to it; image covered — not drawn
        Rectangle { anchors.fill: parent; color: Theme.bg }
        Image {
            visible: Theme.state.grid && !prev.item?.opaque
            anchors.fill: parent
            fillMode: Image.Tile
            source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="1.5" fill="#${Theme.hex(Theme.s2)}"/></svg>`)
        }
        Orb { visible: Theme.state.orb && !prev.item?.opaque; x: stage.width - 720; y: stage.height - 580 }
        // preview lives while picker visible: closed — two screen images unloaded
        Loader {
            id: prev
            anchors.fill: parent
            active: root.visible
            sourceComponent: Wall {
                path: root.files.includes(root.view) ? Theme.wallSrc(root.view) : ""
                look: root.look
                pitch: root.pitch
                bright: root.bright / 100
                origin: Qt.point(width / 2, 850)
            }
        }

        // wheel — browse; click away — remove focus from handles
        MouseArea {
            anchors.fill: parent
            property real acc: 0
            onClicked: stage.forceActiveFocus()
            onWheel: w => {
                acc += w.angleDelta.y || w.angleDelta.x;
                while (Math.abs(acc) >= 120) {
                    root.go(acc > 0 ? -1 : 1);
                    acc -= Math.sign(acc) * 120;
                }
            }
        }

        // over image labels must read: top and bottom background fades out
        Rectangle {
            width: parent.width
            height: 380
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.fade(Theme.bg, 0.85) }
                GradientStop { position: 1; color: Theme.fade(Theme.bg, 0) }
            }
        }
        Rectangle {
            y: parent.height - height
            width: parent.width
            height: 460
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.fade(Theme.bg, 0) }
                GradientStop { position: 1; color: Theme.fade(Theme.bg, 0.9) }
            }
        }

        // Doto number and name
        Column {
            x: 150 - 30 * (1 - root.t)
            y: 110
            Lb { text: `wallpaper · ${root.files.length} in ${root.dir.replace(Quickshell.env("HOME"), "~")}` }
            Row {
                topPadding: 18
                spacing: 10
                Num { id: idx; text: String(root.sel).padStart(2, "0"); font.pixelSize: 150 }
                Num { anchors.baseline: idx.baseline; text: "/" + String(root.list.length - 1).padStart(2, "0"); font.pixelSize: 54; color: Theme.mute }
            }
            Lb { topPadding: 22; width: 700; elide: Text.ElideRight; text: root.name(root.pick); px: 14; color: Theme.fg }
        }

        // view and handles
        Column {
            anchors { right: parent.right; rightMargin: 150 - 30 * (1 - root.t) }
            y: 110
            spacing: 30
            Pick { visible: Quickshell.screens.length > 1; anchors.right: parent.right; label: "for"; opts: ["all", root.mon.toLowerCase()]; cur: root.own ? 1 : 0; onPicked: i => root.own = i === 1 }
            Pick { label: "look"; opts: root.looks; cur: root.look; onPicked: i => root.look = i }
            Row {
                anchors.right: parent.right
                spacing: 36
                Dial { size: 120; label: "dot · px"; from: 4; to: 32; live: true; value: root.pitch; onMoved: v => root.pitch = v }
                Dial { size: 120; label: "light · %"; from: 10; to: 100; step: 5; live: true; value: root.bright; onMoved: v => root.bright = v }
            }
        }

        // strip. Selected always center — ring stands, circles move under it. Circles same size 190 and scaled by scale:
        // dot layer (Art) drawn once, changing width would redraw on every frame for all fifteen
        Ring {
            x: stage.width / 2 - width / 2
            y: 850 - height / 2
            width: root.size(0) + 36
            height: width
            n: 60
            dot: 4
            f: root.list.length > 1 ? root.sel / (root.list.length - 1) : 0
        }
        Repeater {
            model: root.list
            Item {
                id: th
                required property string modelData
                required property int index
                readonly property real d: index - root.pos
                visible: Math.abs(d) < 7.5
                x: stage.width / 2 + root.off(d) - 95
                y: 850 - 95
                width: 190
                height: 190
                scale: root.size(d) / 190
                opacity: 1 - Math.abs(d) * 0.12

                Loader {
                    anchors.fill: parent
                    active: th.visible && !!th.modelData
                    sourceComponent: Art { url: "file://" + Theme.wallSrc(th.modelData).split("/").map(encodeURIComponent).join("/"); step: 6 }
                }
                Rectangle {
                    visible: !th.modelData
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.bg
                    border { width: 1; color: Theme.s3 }
                    Lb { anchors.centerIn: parent; text: "nothing" }
                }
                // live now
                Rectangle {
                    visible: th.modelData === Theme.scr(root.mon, "wall")
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: th.index === root.sel ? 36 : 22 }
                    width: 10
                    height: 10
                    radius: 5
                    color: Theme.accent
                }
                TapHandler {
                    onTapped: {
                        if (th.index === root.sel) root.apply();
                        else root.pick = th.modelData;
                    }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }

        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 56 }
            spacing: 34
            Lb { text: "←→ browse" }
            Lb { text: "tab look" }
            Lb { text: "↑↓ dot size" }
            Lb { text: "shift ↑↓ light" }
            Lb { text: "↵ set" }
            Lb { text: "esc back"; TapHandler { onTapped: root.close() } }
        }
    }
}