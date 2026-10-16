import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.akira.omaestrata"
  ipcTarget: "io.github.akira.omaestrata"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property var snapshot: null
  property string stateText: "connecting"
  property string sshTarget: "akira@192.168.1.168"
  property int refreshSeconds: 10
  property string processPattern: "strata"
  readonly property real panelWidth: Style.space(360)

  function refresh() { if (hostWidget && hostWidget.refresh) hostWidget.refresh() }
  function toggle() { if (opened) close(); else open() }
  function open() { controller.show(); refresh() }
  function close() { controller.hide() }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    padding: Style.spacing.md
    contentWidth: popup.fittedContentWidth(root.panelWidth + popup.padding * 2)
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function") root.bar.switchPanelFrom(root.hostWidget || root, direction)
      }
      onReturnRequested: root.refresh()
      onTextKey: function(t) { if (t === "r" || t === "R") root.refresh() }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(9)
        anchors.top: parent.top

        Text {
          width: parent.width
          text: "STRATA SERVER"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.letterSpacing: 1
        }
        Row {
          spacing: Style.space(6)
          Text {
            text: root.stateText === "ok" && root.snapshot ? (root.snapshot.online ? "● ONLINE" : "● OFFLINE") : (root.stateText === "connecting" ? "◌ CHECKING" : "● SSH ERROR")
            color: root.stateText === "ok" && root.snapshot && root.snapshot.online ? Color.accent : (root.stateText === "ok" ? Color.foreground : Color.accent)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
          Item { width: 1; height: 1 }
        }
        Text {
          width: parent.width
          text: "Model  " + (root.snapshot && root.snapshot.online ? root.snapshot.model : "—")
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        Rectangle { width: parent.width; height: 1; color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.35) }
        Text {
          text: "CPU  " + (root.snapshot ? Model.percent(root.snapshot.cpu) : "—") + "  ·  host utilization"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        Repeater {
          model: root.snapshot ? root.snapshot.gpus : []
          delegate: Column {
            width: content.width
            spacing: Style.space(2)
            Text {
              width: parent.width
              text: modelData.name + "  " + Model.percent(modelData.utilization)
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              text: "VRAM  " + Model.memory(modelData)
              color: root.bar ? Qt.darker(root.bar.foreground, 1.35) : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
        Text {
          visible: root.snapshot && root.snapshot.error !== ""
          width: parent.width
          text: "GPU metrics unavailable: " + (root.snapshot ? root.snapshot.error : "")
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          color: Color.accent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          visible: root.stateText === "connecting" || root.stateText === "error"
          width: parent.width
          text: root.stateText === "connecting" ? "Connecting to " + root.sshTarget + "…" : "SSH failed. Check key-based login and connectivity to " + root.sshTarget + "."
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          color: root.bar ? Qt.darker(root.bar.foreground, 1.35) : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        Row {
          spacing: Style.space(12)
          Text {
            text: "↻ Refresh  (R)"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
          }
          Text {
            text: "Every " + root.refreshSeconds + "s"
            color: root.bar ? Qt.darker(root.bar.foreground, 1.35) : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }
      }
    }
  }
}
