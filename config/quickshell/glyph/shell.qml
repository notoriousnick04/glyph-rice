//@ pragma IconTheme Rice
// own icon theme, not from qtengine: if it doesn't load, Qt looks only in hicolor, and kcalc etc. get empty circles (#11)
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "bar"
import "buds"
import "cal"
import "charms"
import "clip"
import "deck"
import "glyph"
import "home"
import "launcher"
import "power"
import "prefs"
import "quick"
import "settings"
import "shot"
import "vpn"
import "wall"

// glyph: rice in the spirit of nothing os. Home on wallpaper, bar, launcher, quick settings,
// Glyph bars along edges instead of OSD, notification island, power menu, settings, deck (dashboard at bottom), clipboard, charms (emoji and symbols), screenshots, vpn, wallpapers. Locking — separate process (lock.qml).
// Switches with demonshot via `rice switch` / Rice app — hypr binds are shared (shell:*), each shell takes its own
ShellRoot {
    id: shell

    Launcher { id: launcher }
    Quick { id: quick; onPowerRequested: power.open(); onSettingsRequested: prefs.open() }
    Power { id: power }
    Prefs { id: prefs; onWallRequested: walls.open() }
    Glyph {}
    Buds {}
    Cal { id: cal }
    Clip { id: clip }
    Charms { id: charms }
    Deck { id: deck }
    Shot { id: shot }
    Vpn { id: vpn }
    Walls { id: walls }

    Variants {
        model: Quickshell.screens
        Scope {
            id: s
            required property var modelData
            Back { screen: s.modelData }
            // bar and home can be removed from a screen (settings → display), wallpapers stay. Here, not in window: visible from own
            // screen — loop (window recreates, screen changes)
            Home { screen: s.modelData; visible: Theme.scr(s.modelData.name, "home") }
            Hot { screen: s.modelData; onTriggered: quick.peek() }
            Bar {
                screen: s.modelData
                visible: Theme.scr(s.modelData.name, "bar")
                onMarkClicked: launcher.toggle()
                onTrayClicked: quick.toggle()
                onPowerClicked: power.visible ? power.close() : power.open()
                onClockClicked: cal.toggle()
            }
        }
    }

    // hypr like demonshot: its Rules (settings/Rules.qml, same ~/.config/demonshot/rules.json) sets monitor, input,
    // motion, nightlight and hypridle; on top Theme.apply — own border colors, rounding and kitty. We call it on theme change too
    Component.onCompleted: {
        hypr();
        if (Theme.state.paint) Theme.apps(); // rice start sets links to term/ — color must be restored
        Rules.night();
        Rules.idle();
    }
    // what lives in hypr config. It rereads it itself: saved any hypr file (links live — both git pull and branch
    // switch), hyprctl reload — and returns defaults from variables.lua: demonshot borders, monitor, input, animations. Apply
    // own on top again. hyprctl eval configreloaded doesn't send — no loop. Nightlight and hypridle — own processes, reload doesn't touch them
    function hypr() {
        Rules.monitor();
        Rules.input();
        Rules.motion();
        Theme.apply();
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "configreloaded") shell.hypr(); }
    }
    // screen connected — its scale and refresh from prefs → display (Rules.store.outs)
    Connections {
        target: Quickshell
        function onScreensChanged() { Rules.monitor(true); }
    }
    Connections {
        target: Theme
        function onGreysChanged() { paint.restart(); }
    }
    // theme or color changed (style, new wallpapers) — windows, kitty, gtk and qt. After 300 ms: new wallpaper tones don't arrive at once,
    // and gtk shouldn't be touched twice
    Timer { id: paint; interval: 300; onTriggered: { Theme.apply(); Theme.apps(); } }
    // wallpaper tones (Theme.pick) — here, not in Theme: lock loads it too, it's enough to have ready ones from glyph.json. Empty — wallpaper copy
    // didn't load (greys give 16 colors): old tones remain. New wallpaper — from first tone
    ColorQuantizer {
        source: Theme.url(Theme.wallSrc(Theme.wall))
        depth: 4
        rescaleSize: 64
        onColorsChanged: {
            if (!colors.length) return;
            const t = Theme.pick(colors);
            if (t.join() === Theme.state.tones.join()) return;
            Theme.state.tones = t;
            Theme.state.paintAt = 0;
        }
    }
    Connections {
        target: Theme.state
        function onRoundingChanged() { Theme.apply(); }
    }
    // ultra mode toggles blur and shadows on top of settings — repaint windows (refresh and motion set by Rules.setMode itself).
    // Game mode — same and also animations
    Connections {
        target: Rules.store
        function onUltraChanged() { Theme.apply(); }
        function onGameChanged() { Rules.motion(); Theme.apply(); }
    }

    // tap Super — launcher on release; any Super+<key> on the way sends interrupt, and launcher doesn't open
    property bool interrupted: false
    Shortcut {
        name: "launcher"
        description: "launcher (tap Super)"
        onReleased: {
            if (!shell.interrupted) launcher.toggle();
            shell.interrupted = false;
        }
    }
    Shortcut { name: "launcherArm"; description: "Super press — reset interrupt"; onPressed: shell.interrupted = false }
    Shortcut { name: "launcherInterrupt"; description: "Super+<key> — don't open launcher"; onPressed: shell.interrupted = true }
    // Super+Space (altar in demonshot) — deck, dashboard at bottom: launcher already on Super tap
    Shortcut { name: "altar"; description: "deck: dashboard at bottom"; onPressed: deck.toggle() }
    Shortcut { name: "quick"; description: "quick settings"; onPressed: quick.toggle() }
    Shortcut { name: "ward"; description: "quick settings"; onPressed: quick.toggle() } // Super+N in demonshot — same toggles
    Shortcut { name: "settings"; description: "settings"; onPressed: prefs.toggle() }
    Shortcut { name: "power"; description: "power menu"; onPressed: power.visible ? power.close() : power.open() }
    Shortcut { name: "shot"; description: "screenshot"; onPressed: shot.open() }
    Shortcut { name: "pact"; description: "vpn: clash verge"; onPressed: vpn.toggle() }
    Shortcut { name: "clip"; description: "clipboard"; onPressed: clip.toggle() }
    Shortcut { name: "charms"; description: "emoji, kaomoji, symbols"; onPressed: charms.toggle() }
    Shortcut { name: "wall"; description: "wallpapers"; onPressed: walls.toggle() }
    Shortcut { name: "game"; description: "game mode"; onPressed: Rules.store.game = !Rules.store.game }

    component Shortcut: GlobalShortcut { appid: "shell" }
}