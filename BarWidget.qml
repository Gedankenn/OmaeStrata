import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.akira.omaestrata"
  property var snapshot: null
  property string stateText: "connecting"
  readonly property string sshTarget: String(setting("sshTarget", "akira@192.168.1.168"))
  readonly property int refreshSeconds: Math.max(5, Math.min(120, parseInt(setting("refreshSeconds", 10), 10) || 10))
  readonly property string processPattern: String(setting("strataProcessPattern", "strata"))
  readonly property string label: Model.compact(snapshot)
  readonly property string tooltip: Model.tooltip(snapshot, stateText)
  readonly property bool opened: panel.opened
  readonly property bool popoutSwitchClosing: false
  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.settings = root.settings
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
    panelLoader.item.snapshot = root.snapshot
    panelLoader.item.stateText = root.stateText
    panelLoader.item.sshTarget = root.sshTarget
    panelLoader.item.refreshSeconds = root.refreshSeconds
    panelLoader.item.processPattern = root.processPattern
  }
  function refresh() { statusProc.running = false; Qt.callLater(function() { statusProc.running = true }) }
  function togglePanel() { panel.toggle() }
  function open() { panel.open() }
  function close() { panel.close() }
  function closeForPopoutSwitch() { panel.close() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onSnapshotChanged: injectPanel()
  onStateTextChanged: injectPanel()
  onSshTargetChanged: refresh()
  Component.onCompleted: refresh()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  Process {
    id: statusProc
    command: Model.command(root.sshTarget, root.processPattern)
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseSnapshot(text)
        if (parsed) { root.snapshot = parsed; root.stateText = "ok" }
        else root.stateText = "error"
        root.injectPanel()
      }
    }
    onRunningChanged: if (running) root.stateText = "connecting"
  }

  Timer {
    interval: root.refreshSeconds * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.clean(root.label, 46)
    tooltipText: Model.clean(root.tooltip, 450)
    fontSize: 14
    horizontalMargin: 8
    verticalPadding: 8
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
