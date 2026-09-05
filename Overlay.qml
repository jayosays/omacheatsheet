pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "Hotkeys.js" as Hotkeys

// Fullscreen read-only cheat sheet. Rebuilds from live Hyprland binds on open.

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool loading: false
  property string errorText: ""
  property var bindings: []
  property var columns: []
  property var defaultActions: ({})
  property bool defaultsReady: false
  property string searchQuery: ""
  property int filteredCount: 0

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color accent: Color.accent
  property color muted: Color.muted
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int pageMargin: Math.max(Style.gapsOut, Style.space(10))
  property int contentPadding: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(36), Style.font.heading + Style.spacing.controlPaddingY * 2)
  property real listScale: 1
  readonly property int groupGap: Math.max(4, Math.round(Style.spacing.xl * listScale))
  readonly property int rowGap: Math.max(1, Math.round(Style.space(2) * listScale))
  readonly property int columnGap: Style.spacing.xl
  readonly property int titleSize: Math.max(9, Math.round(Style.font.subtitle * listScale))
  readonly property int rowSize: Math.max(8, Math.round(Style.font.bodySmall * listScale))
  readonly property int keyWidth: Math.round(Style.space(168) * Math.min(1.12, listScale))
  readonly property int footerHeight: Math.max(Style.space(22), Style.font.caption + Style.spacing.sm)

  readonly property int bindingCount: root.bindings.length
  readonly property bool filtering: String(root.searchQuery || "").replace(/^\s+|\s+$/g, "") !== ""
  readonly property bool moreBelow: scroller.visible
    && columnsRow.implicitHeight > listPane.height + 8
    && (scroller.contentY + scroller.height) < (scroller.contentHeight - 8)

  function open(payloadJson) {
    root.opened = true
    root.clearSearch()
    root.refresh()
    Qt.callLater(function() {
      if (searchField) searchField.forceActiveFocus()
    })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "jo.omacheatsheet")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function refresh() {
    root.loading = true
    root.errorText = ""
    if (!defaultsProc.running) defaultsProc.running = true
    if (!bindProc.running) bindProc.running = true
  }

  function withoutRedundantXf86(rows) {
    var hasTypedChord = ({})
    for (var i = 0; i < rows.length; i++) {
      var combo = String(rows[i].rawCombo || rows[i].keys || "")
      if (combo.toUpperCase().indexOf("XF86") === -1)
        hasTypedChord[rows[i].action] = true
    }

    var out = []
    for (var j = 0; j < rows.length; j++) {
      var combo2 = String(rows[j].rawCombo || rows[j].keys || "")
      var bareXf86 = combo2.indexOf("+") === -1 && combo2.toUpperCase().indexOf("XF86") === 0
      if (bareXf86 && hasTypedChord[rows[j].action]) continue
      out.push(rows[j])
    }
    return out
  }

  function applyDump(raw) {
    root.bindings = root.withoutRedundantXf86(Hotkeys.parseDump(raw))
    root.rebuildColumns()
    root.loading = false
    if (root.bindings.length === 0 && !root.errorText)
      root.errorText = "No keybindings were reported."
  }

  function clearSearch() {
    root.searchQuery = ""
    if (searchField) searchField.text = ""
  }

  function applySearch(text) {
    var next = String(text || "")
    if (searchField && searchField.text !== next) searchField.text = next
    if (root.searchQuery === next) {
      root.rebuildColumns()
      return
    }
    root.searchQuery = next
    root.rebuildColumns()
  }

  function keyName(key) {
    if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key)
    if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key)
    if (key >= Qt.Key_F1 && key <= Qt.Key_F35) return "F" + (key - Qt.Key_F1 + 1)
    switch (key) {
      case Qt.Key_Escape: return "Esc"
      case Qt.Key_Return:
      case Qt.Key_Enter: return "Enter"
      case Qt.Key_Space: return "Space"
      case Qt.Key_Tab: return "Tab"
      case Qt.Key_Backspace: return "Backspace"
      case Qt.Key_Delete: return "Delete"
      case Qt.Key_Left: return "Left"
      case Qt.Key_Right: return "Right"
      case Qt.Key_Up: return "Up"
      case Qt.Key_Down: return "Down"
      case Qt.Key_Home: return "Home"
      case Qt.Key_End: return "End"
      case Qt.Key_Insert: return "Insert"
      case Qt.Key_PageUp: return "Page Up"
      case Qt.Key_PageDown: return "Page Down"
      case Qt.Key_Comma: return ","
      case Qt.Key_Period: return "."
      case Qt.Key_Minus: return "-"
      case Qt.Key_Equal: return "="
      case Qt.Key_Slash: return "/"
      case Qt.Key_Question: return "?"
      case Qt.Key_Semicolon: return ";"
      case Qt.Key_Apostrophe: return "'"
      case Qt.Key_Backslash: return "\\"
      case Qt.Key_BracketLeft: return "["
      case Qt.Key_BracketRight: return "]"
      case Qt.Key_QuoteLeft: return "`"
      case Qt.Key_Print: return "Print"
      case Qt.Key_ScrollLock: return "Scroll Lock"
      case Qt.Key_Pause: return "Pause"
      case Qt.Key_Menu: return "Menu"
      case Qt.Key_VolumeUp: return "Vol +"
      case Qt.Key_VolumeDown: return "Vol −"
      case Qt.Key_VolumeMute: return "Mute"
      case Qt.Key_MicMute: return "Mic Mute"
      case Qt.Key_MediaPlay: return "Play"
      case Qt.Key_MediaPause: return "Pause"
      case Qt.Key_MediaStop: return "Stop"
      case Qt.Key_MediaNext: return "Next Track"
      case Qt.Key_MediaPrevious: return "Prev Track"
      case Qt.Key_MonBrightnessUp: return "Brightness +"
      case Qt.Key_MonBrightnessDown: return "Brightness −"
      case Qt.Key_Calculator: return "Calculator"
      case Qt.Key_Eject: return "Eject"
    }
    return ""
  }

  function comboFromEvent(event) {
    if (!event) return ""
    var key = event.key
    if (key === Qt.Key_Shift || key === Qt.Key_Control || key === Qt.Key_Alt
        || key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R
        || key === Qt.Key_AltGr || key === Qt.Key_Hyper_L || key === Qt.Key_Hyper_R)
      return ""
    if (key === Qt.Key_Escape || key === Qt.Key_Backspace || key === Qt.Key_Delete
        || key === Qt.Key_Left || key === Qt.Key_Right || key === Qt.Key_Home
        || key === Qt.Key_End || key === Qt.Key_Tab || key === Qt.Key_Backtab)
      return ""

    var mods = event.modifiers
    var superM = !!(mods & Qt.MetaModifier)
    var ctrlM = !!(mods & Qt.ControlModifier)
    var altM = !!(mods & Qt.AltModifier)
    var shiftM = !!(mods & Qt.ShiftModifier)

    if (ctrlM && !superM && !altM && (key === Qt.Key_A || key === Qt.Key_U))
      return ""

    var hasChordMod = superM || ctrlM || altM
    var producesText = event.text && event.text.length > 0 && event.text.charCodeAt(0) >= 32
    if (!hasChordMod && producesText) return ""

    var name = root.keyName(key)
    if (!name && producesText && event.text.length === 1) name = event.text
    if (!name) return ""

    var parts = []
    if (superM) parts.push("Super")
    if (ctrlM) parts.push("Ctrl")
    if (altM) parts.push("Alt")
    if (shiftM) parts.push("Shift")
    parts.push(name)
    return parts.join(" + ")
  }

  function rebuildColumns() {
    var rows = Hotkeys.filterBindings(root.bindings, root.searchQuery)
    root.filteredCount = rows.length
    var groups = Hotkeys.groupBindings(rows, root.defaultsReady ? root.defaultActions : null)
    var count = Hotkeys.columnCount(sheet.width - root.contentPadding * 2)
    root.listScale = 1
    root.columns = Hotkeys.packColumns(groups, count)
    if (scroller) scroller.contentY = 0
    Qt.callLater(root.fitListScale)
  }

  function fitListScale() {
    if (!listPane || !columnsRow) return
    if (listPane.height <= 0 || columnsRow.implicitHeight <= 0) return
    if (columnsRow.implicitHeight > listPane.height) return
    var ratio = (listPane.height - 8) / columnsRow.implicitHeight
    var next = Math.min(1.2, ratio)
    if (next <= 1.02) return
    root.listScale = next
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!root.opened || !event || !event.name) return
      var name = String(event.name)
      if (name === "configreloaded" || name === "config.reloaded") root.refresh()
    }
  }

  Process {
    id: defaultsProc
    command: ["bash", "-c", "cat -- \"$0\"/default/hypr/bindings/*.lua", root.omarchyPath || "/usr/share/omarchy"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.defaultActions = Hotkeys.parseDefaultActions(text)
        root.defaultsReady = true
        if (root.bindings.length > 0) root.rebuildColumns()
      }
    }
  }

  Process {
    id: bindProc
    command: [(root.omarchyPath || "/usr/share/omarchy") + "/bin/omarchy-menu-keybindings", "--print"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyDump(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.bindings.length === 0) {
        root.loading = false
        root.errorText = "Could not read the live Hyprland keybindings."
      }
    }
  }

  Component.onCompleted: defaultsProc.running = true

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-omacheatsheet"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: sheet
      anchors.fill: parent
      anchors.margins: root.pageMargin
      radius: root.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentPadding
      onWidthChanged: root.rebuildColumns()
      onHeightChanged: root.rebuildColumns()

      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        anchors.topMargin: sheet.contentTopInset
        anchors.rightMargin: sheet.contentRightInset
        anchors.bottomMargin: sheet.contentBottomInset
        anchors.leftMargin: sheet.contentLeftInset
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.dismiss()
            event.accepted = true
            return
          }
          var combo = root.comboFromEvent(event)
          if (combo) {
            root.applySearch(combo)
            if (searchField) searchField.cursorPosition = combo.length
            event.accepted = true
          }
        }

      Column {
        anchors.fill: parent
        spacing: Style.spacing.md

        Item {
          width: parent.width
          height: root.headerHeight

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "OmaCheatSheet"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.loading
              ? "Reading live binds…"
              : (root.filtering
                  ? (root.filteredCount > 0
                      ? root.filteredCount + " of " + root.bindingCount + "  ·  Esc to close"
                      : "No matches  ·  Esc to close")
                  : (root.bindingCount > 0
                      ? root.bindingCount + " shortcuts  ·  Esc to close"
                      : "Esc to close"))
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        TextField {
          id: searchField
          width: parent.width
          placeholderText: "Filter actions or type a shortcut…"
          foreground: root.foreground
          accent: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          onTextChanged: root.applySearch(text)
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.dismiss()
              event.accepted = true
            }
          }
        }

        Item {
          id: listPane
          width: parent.width
          height: Math.max(0, parent.height - y)

          Text {
            visible: !root.loading && root.filteredCount === 0
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.filtering
              ? "No matching shortcuts."
              : (root.errorText || "No keybindings were reported.")
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }

          Flickable {
            id: scroller
            visible: root.filteredCount > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: moreHint.visible ? moreHint.top : parent.bottom
            anchors.bottomMargin: moreHint.visible ? Style.spacing.xs : 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: columnsRow.implicitHeight
            flickableDirection: Flickable.VerticalFlick

            Row {
              id: columnsRow
              width: scroller.width
              spacing: root.columnGap

              Repeater {
                model: root.columns

                Column {
                  id: columnBlock
                  required property var modelData
                  readonly property var columnData: modelData
                  width: root.columns.length > 0
                    ? (columnsRow.width - root.columnGap * (root.columns.length - 1)) / root.columns.length
                    : columnsRow.width
                  spacing: root.groupGap

                  Repeater {
                    model: columnBlock.columnData.groups

                    Column {
                      id: groupBlock
                      required property var modelData
                      readonly property var groupData: modelData
                      width: columnBlock.width
                      spacing: root.rowGap

                      Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        text: groupBlock.groupData.title
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: root.titleSize
                        font.bold: true
                      }

                      Repeater {
                        model: groupBlock.groupData.items

                        Row {
                          id: bindRow
                          required property var modelData
                          width: groupBlock.width
                          spacing: Style.space(10)

                          Text {
                            width: Math.min(root.keyWidth, parent.width * 0.46)
                            textFormat: Text.PlainText
                            text: bindRow.modelData.prettyKeys
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: root.rowSize
                            font.bold: true
                            elide: Text.ElideRight
                          }

                          Text {
                            width: parent.width - x
                            textFormat: Text.PlainText
                            text: bindRow.modelData.action
                            color: root.muted
                            font.family: root.fontFamily
                            font.pixelSize: root.rowSize
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          Item {
            id: moreHint
            visible: root.moreBelow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root.footerHeight

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              height: 1
              color: root.border
            }

            Text {
              anchors.fill: parent
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              textFormat: Text.PlainText
              text: "More shortcuts below  ·  scroll down"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
    }

    onVisibleChanged: if (visible) {
      Qt.callLater(function() {
        if (searchField) searchField.forceActiveFocus()
        root.rebuildColumns()
      })
    }
  }
}
