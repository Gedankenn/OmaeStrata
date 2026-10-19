import QtQuick
import Quickshell
import Quickshell.Io
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
  readonly property string label: Model.compact(snapshot, stateText, vertical)
  readonly property string tooltip: Model.tooltip(snapshot, stateText)
  readonly property string widgetLabel: Model.widgetActionLabel(snapshot, stateText, serverLaunchState, vertical)
  readonly property string widgetActionTooltip: serverLaunchState === "starting" ? "Starting Strata over SSH" : (serverLaunchState === "error" ? "Click to retry starting Strata over SSH" : (!serverOnline ? "Click to start Strata over SSH; right-click for details; middle-click to refresh" : tooltip))
  property string serverLaunchState: "idle"
  property bool startRequested: false
  property var generationTokS: null
  property var prefillTokS: null
  property string serverLaunchError: ""
  readonly property bool serverOnline: !!(snapshot && snapshot.online)
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened : false
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
    panelLoader.item.serverLaunchState = root.serverLaunchState
    panelLoader.item.generationTokS = root.generationTokS
    panelLoader.item.prefillTokS = root.prefillTokS
    panelLoader.item.serverLaunchError = root.serverLaunchError
  }
  function refresh() { statusProc.running = false; Qt.callLater(function() { statusProc.running = true }) }
  function startServer() {
    if (serverStartProc.running || serverOnline) return false
    serverLaunchError = ""
    generationTokS = null
    prefillTokS = null
    serverLaunchState = "starting"
    serverStartProc.running = true
    startMetrics()
    return true
  }
  function requestStart() {
    if (serverStartProc.running || serverLaunchState === "starting") return false
    if (serverOnline) { togglePanel(); return false }
    if (stateText === "connecting") { startRequested = true; return true }
    return startServer()
  }
  function startMetrics() { if (!metricsProc.running) metricsProc.running = true }
  function consumeServerLine(line) {
    var rates = Model.parseThroughputLine(line)
    if (!rates) return
    if (rates.generationTokS !== null) generationTokS = rates.generationTokS
    if (rates.prefillTokS !== null) prefillTokS = rates.prefillTokS
  }
  function consumeMetricsLine(line) {
    var rates = Model.parseMetricsLine(line)
    if (!rates) return
    generationTokS = rates.generationTokS
    prefillTokS = rates.prefillTokS
    if (rates.model && snapshot) {
      var updated = {}
      for (var key in snapshot) updated[key] = snapshot[key]
      updated.model = rates.model
      if (rates.latestLog) updated.latestLog = rates.latestLog
      snapshot = updated
    }
  }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function closeForPopoutSwitch() { close() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onSnapshotChanged: {
    if (serverOnline) {
      serverLaunchState = "running"
      startMetrics()
    } else if (!serverStartProc.running) {
      metricsProc.running = false
    }
    if (root.startRequested) {
      root.startRequested = false
      if (root.serverOnline) Qt.callLater(root.open)
      else Qt.callLater(root.startServer)
    }
    injectPanel()
  }
  onStateTextChanged: {
    if (stateText === "error" && startRequested) startRequested = false
    injectPanel()
  }
  onServerLaunchStateChanged: injectPanel()
  onGenerationTokSChanged: injectPanel()
  onPrefillTokSChanged: injectPanel()
  onServerLaunchErrorChanged: injectPanel()
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
        if (parsed) {
          root.snapshot = parsed
          root.stateText = "ok"
          if (parsed.online) root.serverLaunchState = "running"
        } else root.stateText = "error"
        root.injectPanel()
      }
    }
    onRunningChanged: if (running) root.stateText = "connecting"
  }

  Process {
    id: metricsProc
    command: Model.metricsCommand(root.sshTarget)
    stdout: SplitParser { onRead: function(line) { root.consumeMetricsLine(line) } }
    // Scan only the newest model log; the helper emits its filename/model and
    // numeric rates, never raw log content, prompts, or generated text.
    stderr: SplitParser { onRead: function(line) {} }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: {
      if ((root.serverOnline || serverStartProc.running) && !metricsProc.running) root.startMetrics()
    }
  }

  Process {
    id: serverStartProc
    command: Model.startCommand(root.sshTarget)
    stdout: SplitParser { onRead: function(line) { root.consumeServerLine(line) } }
    // Drain but never display arbitrary remote stderr; it may contain sensitive
    // request or environment details. The exit status is enough for the UI.
    stderr: SplitParser { onRead: function(line) {} }
    onRunningChanged: {
      if (running && root.serverLaunchState !== "running") root.serverLaunchState = "starting"
    }
    onExited: function(exitCode) {
      root.serverLaunchState = exitCode === 0 ? "stopped" : "error"
      root.serverLaunchError = exitCode === 0 ? "" : "SSH or Strata startup failed (exit " + exitCode + ")."
      root.refresh()
    }
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
    text: Model.clean(root.widgetLabel, 46)
    tooltipText: Model.clean(root.widgetActionTooltip, 450)
    fontSize: 13
    horizontalMargin: 8
    verticalPadding: 6
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refresh()
      else if (b === Qt.RightButton) root.togglePanel()
      else if (b === Qt.LeftButton && !root.serverOnline && root.serverLaunchState !== "starting") root.requestStart()
      else root.togglePanel()
    }
  }
}
