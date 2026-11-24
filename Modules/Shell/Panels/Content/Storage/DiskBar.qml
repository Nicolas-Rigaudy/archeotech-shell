import QtQuick
import QtQuick.Layouts
import "../../../../../Commons" as Commons
import "../../../../../Services/System" as SysSvc
import "../../../../../Services/System/StorageLogic.js" as Logic
import "Glyph.js" as G

// Free space of / for the Storage panel: size line, a used bar with what the
// selection frees overlaid at its end, "Selected frees X → Y free", and on btrfs
// the metadata / unallocated line (warning colour when it is tight: a full disk
// on btrfs can be out of metadata before it is out of data space).
ColumnLayout {
    id: bar
    property real freeing: 0          // bytes the current selection frees

    readonly property var store: SysSvc.Storage
    readonly property real _size: store.size > 0 ? store.size : 1
    readonly property bool _btrfs: store.metadataFree >= 0 || store.unallocated >= 0
    readonly property bool _tight: store.metadataTight || (store.unallocated >= 0 && store.unallocated < Logic.GIB)
    readonly property color _levelColor: store.level === "critical" ? Commons.Appearance.colors.error
                                       : store.level === "warn" ? Commons.Appearance.colors.warning
                                       : Commons.Appearance.colors.textPrimary
    spacing: Commons.Appearance.spacing.s2

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "/   " + (bar.store.fstype || "") + "   " + Logic.formatBytes(bar.store.size)
            color: Commons.Appearance.colors.textSecondary
            font.family: Commons.Appearance.font.mono
            font.pixelSize: Commons.Appearance.font.sizeMd
        }
        Text {
            text: "<b>" + Logic.formatBytes(bar.store.free) + "</b> free  ·  " + bar.store.freePct + " %"
            textFormat: Text.StyledText
            color: bar._levelColor
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeLg
        }
    }

    // Track = whole disk; fill = used; the accent block = what the selection frees.
    Rectangle {
        id: track
        Layout.fillWidth: true
        Layout.preferredHeight: 12
        radius: height / 2
        color: Commons.Appearance.colors.recessedTrack
        border.width: 1
        border.color: Commons.Appearance.colors.glassBorder
        clip: true
        readonly property real _used: Math.min(1, bar.store.used / bar._size)
        readonly property real _free: Math.min(_used, Math.max(0, bar.freeing) / bar._size)
        Rectangle {
            width: track.width * track._used
            height: parent.height
            radius: parent.radius
            color: Commons.Appearance.colors.overlay0
        }
        Rectangle {
            visible: track._free > 0
            x: track.width * (track._used - track._free)
            width: Math.max(2, track.width * track._free)
            height: parent.height
            color: Commons.Appearance.colors.accent
            opacity: 0.85
            Behavior on width { Commons.Tween { spatial: true } }
            Behavior on x { Commons.Tween { spatial: true } }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: bar.freeing > 0
        text: "Selected frees <b>" + Logic.formatBytes(bar.freeing) + "</b>  →  "
              + Logic.formatBytes(bar.store.free + bar.freeing) + " free"
        textFormat: Text.StyledText
        color: Commons.Appearance.colors.textSecondary
        font.family: Commons.Appearance.font.family
        font.pixelSize: Commons.Appearance.font.sizeMd
        elide: Text.ElideRight
    }
    Text {
        Layout.fillWidth: true
        visible: bar._btrfs
        text: (bar._tight ? G.alert + "  " : "") + "btrfs metadata "
              + (bar.store.metadataFree >= 0 ? Logic.formatBytes(bar.store.metadataFree) + " free" : "unknown")
              + "  ·  unallocated " + (bar.store.unallocated >= 0 ? Logic.formatBytes(bar.store.unallocated) : "unknown")
        color: bar._tight ? Commons.Appearance.colors.warning : Commons.Appearance.colors.textMuted
        font.family: Commons.Appearance.font.mono
        font.pixelSize: Commons.Appearance.font.sizeBase
        elide: Text.ElideRight
    }
}
