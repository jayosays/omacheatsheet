import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "jo.omacheatsheet"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function toggleOverlay() {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.toggle !== "function")
      return
    root.bar.shell.toggle(root.moduleName)
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "OCS"
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: "OmaCheatSheet"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggleOverlay()
    }
  }
}
