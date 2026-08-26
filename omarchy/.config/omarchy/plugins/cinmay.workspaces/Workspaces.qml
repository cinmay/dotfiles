import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "cinmay.workspaces"

  function configuredWorkspaceIds() {
    return [1, 6, 10, 11, 12, 13, 14, 15]
  }

  function configuredWorkspaceLabel(id) {
    switch (id) {
    case 1: return "home"
    case 6: return "terminal"
    case 10: return "editor"
    case 11: return "music"
    case 12: return "chatgpt"
    case 13: return "obsidian"
    case 14: return "discord"
    case 15: return "git"
    default: return ""
    }
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceLabel(id) {
    var workspace = workspaceById(id)
    if (workspace !== null) {
      var name = String(workspace.name || "")
      if (name && name !== String(id)) return name
    }

    var configured = configuredWorkspaceLabel(id)
    return configured || (id === 10 ? "0" : String(id))
  }

  function workspaceIds() {
    var ids = configuredWorkspaceIds()
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: workspaceButton

        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property string labelText: root.workspaceLabel(modelData)
        readonly property string focusedLabelText: "\uDB85\uDCFB " + labelText
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: focused ? focusedLabelText : labelText
        opacity: occupied || focused ? 1 : 0.55
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Math.ceil(Math.max(Style.space(20), labelMetrics.advanceWidth + Style.space(12)))
        fixedHeight: root.barSize
        tooltipText: "Workspace " + modelData
        onPressed: function() { root.focusWorkspace(modelData) }

        TextMetrics {
          id: labelMetrics
          font.family: workspaceButton.fontFamily
          font.pixelSize: workspaceButton.fontSize
          text: workspaceButton.focusedLabelText
        }
      }
    }
  }
}
