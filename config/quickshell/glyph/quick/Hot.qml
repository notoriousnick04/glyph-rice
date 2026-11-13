import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// hot edge: the cursor lingers at the right edge - quick settings go out (Quick.peek). 2px stripe to bottom 80%:
// The top corner and scroll bars at the edge are almost unaffected
PanelWindow {
    id: root

    signal triggered

    visible: Theme.state.quickHover
    anchors { right: true; bottom: true }
    implicitWidth: 2
    implicitHeight: Math.round(screen.height * 0.8)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "glyph-hot"

    HoverHandler { id: hov; onHoveredChanged: hovered ? dwell.restart() : dwell.stop() }
    Timer { id: dwell; interval: 150; onTriggered: if (hov.hovered) root.triggered() }
}
